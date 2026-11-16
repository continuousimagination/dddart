import 'dart:io' as io;

import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_repository_rest/dddart_repository_rest.dart';
import 'package:dddart_rest/dddart_rest.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';

import '../../dddart/test/support/conditional_aggregate_contract.dart';
import 'test_models.dart';

Future<(RestConnection, RestConnection, Future<void> Function())>
    serve<T extends AggregateRoot<I>, I extends Identity>(
  String path,
  JsonSerializer<T> serializer, {
  IdentityCodecRegistry? codecs,
}) async {
  final storage = InMemoryConditionalRepository<T, I>(
    clone: (value) => serializer.deserialize(serializer.serialize(value)),
  );
  final app = HttpServer()
    ..registerResource(
      CrudResource<T, I, void>(
        path: path,
        repository: storage,
        serializer: serializer,
        identityCodecs: codecs,
      ),
    );
  final server = await shelf_io.serve(
    app.buildHandler(),
    io.InternetAddress.loopbackIPv4,
    0,
  );
  final first = RestConnection(baseUrl: 'http://127.0.0.1:${server.port}');
  final second = RestConnection(baseUrl: first.baseUrl);
  return (
    first,
    second,
    () async {
      first.dispose();
      second.dispose();
      await server.close(force: true);
    }
  );
}

void main() {
  group('generated UUID client over real HTTP', () {
    conditionalAggregateContract<TestUser, UuidValue>(
      open: () async {
        final (a, b, close) = await serve<TestUser, UuidValue>(
          '/users',
          TestUserJsonSerializer(),
        );
        return (TestUserRestRepository(a), TestUserRestRepository(b), close);
      },
      create: (value, id) =>
          TestUser(id: id, name: '$value', email: 'a@example.com'),
      value: (item) => int.parse(item.name),
    );
  });
  group('generated native custom-interface client over real HTTP', () {
    conditionalAggregateContract<NativeIssue, NativeId>(
      open: () async {
        final codecs = issueIdentityCodecs();
        final (a, b, close) = await serve<NativeIssue, NativeId>(
          '/native-issues',
          NativeIssueJsonSerializer.withIdentityCodecs(codecs),
          codecs: codecs,
        );
        return (
          NativeIssueRestRepository(a, identityCodecs: codecs),
          NativeIssueRestRepository(b, identityCodecs: codecs),
          close
        );
      },
      create: (value, id) => NativeIssue(
        id: id ?? NativeId('${UuidValue.generate().uuid}/%, café'),
        title: '$value',
      ),
      value: (item) => int.parse(item.title),
    );
  });
  group('generated scoped client over real HTTP', () {
    conditionalAggregateContract<ScopedIssue, ScopedId>(
      open: () async {
        final codecs = issueIdentityCodecs();
        final (a, b, close) = await serve<ScopedIssue, ScopedId>(
          '/scoped-issues',
          ScopedIssueJsonSerializer.withIdentityCodecs(codecs),
          codecs: codecs,
        );
        return (
          ScopedIssueRestRepository(a, identityCodecs: codecs),
          ScopedIssueRestRepository(b, identityCodecs: codecs),
          close
        );
      },
      create: (value, id) => ScopedIssue(
        id: id ?? ScopedId(UuidValue.generate().uuid, 7),
        title: '$value',
      ),
      value: (item) => int.parse(item.title),
    );
  });
  test(
      'snapshots remain independent across reads and deliberate conflict recovery',
      () async {
    final codecs = issueIdentityCodecs();
    final (a, b, close) = await serve<NativeIssue, NativeId>(
      '/native-issues',
      NativeIssueJsonSerializer.withIdentityCodecs(codecs),
      codecs: codecs,
    );
    addTearDown(close);
    final client = NativeIssueRestRepository(a, identityCodecs: codecs);
    const first = NativeId('first/issue');
    const other = NativeId('other');
    await client.save(NativeIssue(id: first, title: '0'));
    await client.save(NativeIssue(id: other, title: 'other'));
    final old = await client.getVersioned(first);
    final second = await client.getVersioned(first);
    await client
        .getVersioned(other); // Must not replace the first record's token.
    await client.saveConditional(
      NativeIssue(id: first, title: 'winner'),
      expected: ExpectedRevision.match(second.revision),
    );
    await expectLater(
      client.saveConditional(
        NativeIssue(id: first, title: 'stale'),
        expected: ExpectedRevision.match(old.revision),
      ),
      throwsA(
        isA<RevisionConflictException<NativeId>>()
            .having((e) => e.id, 'id', first)
            .having((e) => e.expected.revision, 'revision', old.revision),
      ),
    );
    final reloaded = await client.getVersioned(first);
    await client.saveConditional(
      NativeIssue(id: first, title: '${reloaded.aggregate.title}+retry'),
      expected: ExpectedRevision.match(reloaded.revision),
    );
    expect((await client.getById(first)).title, 'winner+retry');
  });
  test(
      'lost response after persistence is uncertain, retains events and never retries',
      () async {
    final serializer = TestUserJsonSerializer();
    final storage = InMemoryConditionalRepository<TestUser, UuidValue>(
      clone: (a) => serializer.deserialize(serializer.serialize(a)),
    );
    final app = HttpServer()
      ..registerResource(
        CrudResource<TestUser, UuidValue, void>(
          path: '/users',
          repository: storage,
          serializer: serializer,
        ),
      );
    final handler = app.buildHandler();
    var calls = 0;
    final connection = RestConnection(
      baseUrl: 'https://example.com',
      httpClient: MockClient((request) async {
        calls++;
        final response = await handler(
          shelf.Request(
            request.method,
            request.url,
            headers: request.headers,
            body: request.body,
          ),
        );
        expect(response.statusCode, 201);
        throw http.ClientException('response lost after commit');
      }),
    );
    addTearDown(connection.dispose);
    final publisher = Publisher();
    final client =
        TestUserRestRepository(connection, eventPublisher: publisher);
    final value = TestUser(name: 'saved', email: 'a@example.com');
    value.raiseEvent(Changed(value.id));
    await expectLater(
      client.saveConditional(
        value,
        expected: const ExpectedRevision.absent(),
      ),
      throwsA(isA<ConditionalWriteUncertainException>()),
    );
    expect(calls, 1);
    expect((await storage.getById(value.id)).name, 'saved');
    expect(value.getUncommittedEvents(), hasLength(1));
    expect(publisher.events, isEmpty);
  });
  test('missing validators fail closed on reads and are uncertain after writes',
      () async {
    final value = TestUser(name: 'data', email: 'a@example.com');
    final connection = RestConnection(
      baseUrl: 'https://example.com',
      httpClient: MockClient(
        (_) async =>
            http.Response(TestUserJsonSerializer().serialize(value), 200),
      ),
    );
    addTearDown(connection.dispose);
    final client = TestUserRestRepository(connection);
    await expectLater(
      client.getVersioned(value.id),
      throwsA(isA<ConditionalCapabilityUnsupportedException>()),
    );
    await expectLater(
      client.saveConditional(
        value,
        expected: const ExpectedRevision.absent(),
      ),
      throwsA(isA<ConditionalWriteUncertainException>()),
    );
  });
  test('server and client share the canonical revision wire format', () {
    for (final token in [
      'opaque',
      'café/"value"',
      List.filled(1024, 'x').join(),
    ]) {
      final tag = RevisionETag.encode(token);
      expect(encodeRestRevisionETag(token), tag);
      expect(decodeRestRevisionETag(tag), token);
      expect(decodeRestRevisionETag('W/$tag'), isNull);
    }
  });
}

class Changed extends DomainEvent<UuidValue> {
  Changed(UuidValue id) : super(aggregateId: id);
}

class Publisher implements EventPublisher {
  final events = <DomainEvent<Identity>>[];
  @override
  Future<bool> publish(DomainEvent<Identity> event) async {
    events.add(event);
    return true;
  }
}
