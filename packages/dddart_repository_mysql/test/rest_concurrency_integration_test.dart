@Tags(['requires-mysql'])
library;

import 'dart:async';
import 'dart:io' as io;

import 'package:dddart/dddart.dart';
import 'package:dddart_repository_mysql/dddart_repository_mysql.dart';
import 'package:dddart_rest/dddart_rest.dart';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';

import 'integration_test_models.dart';
import 'test_helpers.dart';

void main() {
  test(
      'independent HTTP servers and MySQL connections enforce one atomic If-Match winner',
      () async {
    final settings = TestMysqlHelper();
    final admin = await settings.connect();
    addTearDown(settings.disconnect);
    final database =
        'rest_cas_${UuidValue.generate().uuid.replaceAll('-', '')}';
    await admin.execute('CREATE DATABASE $database');
    addTearDown(() => admin.execute('DROP DATABASE $database'));
    MysqlConnection connect() => MysqlConnection(
          host: settings.host,
          port: settings.port,
          database: database,
          user: settings.user,
          password: settings.password,
        );
    final a = connect();
    final b = connect();
    await a.open();
    await b.open();
    addTearDown(a.close);
    addTearDown(b.close);
    final first = SimpleProductMysqlRepository(a);
    final second = SimpleProductMysqlRepository(b);
    await first.createTables();
    final original = SimpleProduct(name: 'original', price: 0);
    await first.save(original);
    final serializer = SimpleProductJsonSerializer();
    var entered = 0;
    final release = Completer<void>();
    Future<void> barrier() async {
      if (++entered == 2) release.complete();
      await release.future;
    }

    Future<io.HttpServer> start(SimpleProductMysqlRepository repository) async {
      final app = HttpServer()
        ..registerResource(
          CrudResource<SimpleProduct, UuidValue, void>(
            path: '/products',
            repository: GatedRepository(repository, barrier),
            serializer: serializer,
          ),
        );
      return shelf_io.serve(
        app.buildHandler(),
        io.InternetAddress.loopbackIPv4,
        0,
      );
    }

    final one = await start(first);
    final two = await start(second);
    addTearDown(() => one.close(force: true));
    addTearDown(() => two.close(force: true));
    final client = http.Client();
    addTearDown(client.close);
    final uriOne =
        Uri.parse('http://127.0.0.1:${one.port}/products/${original.id}');
    final uriTwo =
        Uri.parse('http://127.0.0.1:${two.port}/products/${original.id}');
    final reads = await Future.wait([client.get(uriOne), client.get(uriTwo)]);
    expect(reads.every((r) => r.statusCode == 200), isTrue);
    expect(reads[0].headers['etag'], reads[1].headers['etag']);
    final responses = await Future.wait([
      client.put(
        uriOne,
        headers: {
          'content-type': 'application/json',
          'if-match': reads[0].headers['etag']!,
        },
        body: serializer.serialize(
          SimpleProduct(id: original.id, name: 'one', price: 1),
        ),
      ),
      client.put(
        uriTwo,
        headers: {
          'content-type': 'application/json',
          'if-match': reads[1].headers['etag']!,
        },
        body: serializer.serialize(
          SimpleProduct(id: original.id, name: 'two', price: 2),
        ),
      ),
    ]);
    expect(responses.map((r) => r.statusCode), unorderedEquals([200, 412]));
    final winner = responses.singleWhere((r) => r.statusCode == 200);
    final persisted = await first.getVersioned(original.id);
    expect(persisted.aggregate.name, serializer.deserialize(winner.body).name);
    expect(
      persisted.aggregate.price,
      serializer.deserialize(winner.body).price,
    );
    expect(RevisionETag.tryDecode(winner.headers['etag']!), persisted.revision);
  });
}

class GatedRepository
    implements
        Repository<SimpleProduct, UuidValue>,
        ConditionalAggregateRepository<SimpleProduct, UuidValue> {
  GatedRepository(this.inner, this.barrier);
  final SimpleProductMysqlRepository inner;
  final Future<void> Function() barrier;
  @override
  Future<SimpleProduct> getById(UuidValue id) => inner.getById(id);
  @override
  Future<VersionedAggregate<SimpleProduct, UuidValue>> getVersioned(
    UuidValue id,
  ) =>
      inner.getVersioned(id);
  @override
  Future<void> save(SimpleProduct aggregate) =>
      throw StateError('Conditional HTTP requests must not call ordinary save');
  @override
  Future<void> deleteById(UuidValue id) => inner.deleteById(id);
  @override
  Future<String> saveConditional(
    SimpleProduct aggregate, {
    required ExpectedRevision expected,
  }) async {
    await barrier();
    return inner.saveConditional(aggregate, expected: expected);
  }

  @override
  Future<void> deleteConditional(
    UuidValue id, {
    required ExpectedRevision expected,
  }) =>
      inner.deleteConditional(id, expected: expected);
}
