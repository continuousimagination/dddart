/// Real generated-repository races against the parent-owned local emulator only.
library;

import 'dart:io';

import 'package:dddart/dddart.dart';
import 'package:dddart_repository_dynamodb/dddart_repository_dynamodb.dart';
import 'package:dddart_shared_model_fixture/versioned_model.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'conditional_binding.dart';

class _CountingClient extends http.BaseClient {
  final http.Client inner = http.Client();
  int puts = 0;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if ((request.headers['x-amz-target'] ??
            request.headers['X-Amz-Target'] ??
            '')
        .endsWith('.PutItem')) {
      puts++;
    }
    request.followRedirects = false;
    return inner.send(request);
  }

  @override
  void close() => inner.close();
}

void main() {
  final endpoint =
      Platform.environment['SSG_LOCAL_DYNAMO_ENDPOINT'] ??
      'http://127.0.0.1:61033';
  final endpointUri = Uri.parse(endpoint);
  if (endpointUri.scheme != 'http' ||
      !const {'127.0.0.1', 'localhost', '::1'}.contains(endpointUri.host) ||
      endpointUri.userInfo.isNotEmpty ||
      endpointUri.hasQuery ||
      endpointUri.hasFragment) {
    throw StateError(
      'The conditional fixture requires a loopback HTTP endpoint.',
    );
  }
  var created = false;
  final table = 'ssg-u10-child-${UuidValue.generate().uuid}';
  final transports = <_CountingClient>[];
  final connections = <DynamoConnection>[];
  DynamoConnection connect() {
    final transport = _CountingClient();
    transports.add(transport);
    final connection = DynamoConnection(
      region: 'us-east-1',
      endpoint: endpoint,
      credentials: AwsClientCredentials(
        accessKey: 'SSGLOCALTEST',
        secretKey: 'SSGLOCALTEST',
        sessionToken: 'SSGLOCALTEST',
      ),
      httpClient: transport,
    );
    connections.add(connection);
    return connection;
  }

  final admin = connect();
  final first = ConditionalProbeDynamoRepository(connect(), tableName: table);
  final second = ConditionalProbeDynamoRepository(connect(), tableName: table);
  VersionedRecord proposal(UuidValue id, String text, [int revision = 0]) =>
      VersionedRecord(
        text: text,
        tags: ['synthetic'],
        id: id,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        revision: Revision(revision),
      );
  Future<Object> attempt(Future<Object?> Function() action) async {
    try {
      return await action() ?? true;
    } on PreconditionFailedException catch (error) {
      return error;
    }
  }

  setUpAll(() async {
    try {
      await admin.client
          .listTables(limit: 1)
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      throw StateError(
        'Required local DynamoDB fixture is unavailable. Start the pinned '
        'loopback fixture or set SSG_LOCAL_DYNAMO_ENDPOINT before this suite.',
      );
    }
    await admin.client.createTable(
      tableName: table,
      keySchema: [KeySchemaElement(attributeName: 'id', keyType: KeyType.hash)],
      attributeDefinitions: [
        AttributeDefinition(
          attributeName: 'id',
          attributeType: ScalarAttributeType.s,
        ),
      ],
      billingMode: BillingMode.payPerRequest,
    );
    created = true;
  });
  tearDownAll(() async {
    try {
      if (created) await admin.client.deleteTable(tableName: table);
    } finally {
      for (final connection in connections) {
        connection.dispose();
      }
      for (final transport in transports) {
        transport.close();
      }
    }
  });
  test('two independent concurrent creates commit exactly once', () async {
    final id = UuidValue.generate();
    final before = transports.fold(0, (sum, t) => sum + t.puts);
    final outcomes = await Future.wait([
      attempt(
        () => first.save(
          proposal(id, 'A'),
          precondition: const WritePrecondition.absent(),
        ),
      ),
      attempt(
        () => second.save(
          proposal(id, 'B'),
          precondition: const WritePrecondition.absent(),
        ),
      ),
    ]);
    final winner = outcomes.whereType<VersionedRecord>().single;
    expect(outcomes.whereType<PreconditionFailedException>(), hasLength(1));
    expect(winner.revision, Revision(1));
    expect((await second.getById(id)).text, winner.text);
    expect(transports.fold(0, (sum, t) => sum + t.puts) - before, 2);
  });
  test(
    'same-revision writers race and older copies cannot overwrite newer state',
    () async {
      for (final reverse in [false, true]) {
        final id = UuidValue.generate();
        await first.save(
          proposal(id, 'initial'),
          precondition: const WritePrecondition.absent(),
        );
        final actions = [
          () => first.save(
            proposal(id, 'A', 1),
            precondition: WritePrecondition.atRevision(Revision(1)),
          ),
          () => second.save(
            proposal(id, 'B', 1),
            precondition: WritePrecondition.atRevision(Revision(1)),
          ),
        ];
        final outcomes = await Future.wait(
          (reverse ? actions.reversed : actions).map(attempt),
        );
        final winner = outcomes.whereType<VersionedRecord>().single;
        expect(outcomes.whereType<PreconditionFailedException>(), hasLength(1));
        expect(winner.revision, Revision(2));
        expect((await first.getById(id)).text, winner.text);
        final newer = await second.save(
          proposal(id, 'newest', 2),
          precondition: WritePrecondition.atRevision(Revision(2)),
        );
        await expectLater(
          first.save(
            proposal(id, 'stale', 1),
            precondition: WritePrecondition.atRevision(Revision(1)),
          ),
          throwsA(isA<PreconditionFailedException>()),
        );
        final observed = await first.getById(id);
        expect(observed.revision, newer.revision);
        expect(observed.text, 'newest');
      }
    },
  );
  test(
    'retirement leaves only fence metadata and prevents recreation',
    () async {
      final id = UuidValue.generate();
      final original = proposal(id, 'private-payload');
      await first.save(
        original,
        precondition: const WritePrecondition.absent(),
      );
      await second.deleteById(
        id,
        precondition: WritePrecondition.atRevision(Revision(1)),
      );
      final raw = await admin.client.getItem(
        tableName: table,
        key: {'id': AttributeValue(s: id.uuid)},
        consistentRead: true,
      );
      expect(AttributeValueConverter.attributeMapToJsonMap(raw.item!), {
        'id': id.uuid,
        'revision': 2,
        '__dddart_retired': true,
      });
      await expectLater(
        first.getById(id),
        throwsA(
          isA<RepositoryException>().having(
            (e) => e.type,
            'type',
            RepositoryExceptionType.notFound,
          ),
        ),
      );
      await expectLater(
        first.save(original, precondition: const WritePrecondition.absent()),
        throwsA(isA<PreconditionFailedException>()),
      );
      await expectLater(
        second.deleteById(
          id,
          precondition: WritePrecondition.atRevision(Revision(1)),
        ),
        throwsA(isA<PreconditionFailedException>()),
      );
    },
  );
  test('update versus retirement allows exactly one mutation', () async {
    for (final reverse in [false, true]) {
      final id = UuidValue.generate();
      await first.save(
        proposal(id, 'initial'),
        precondition: const WritePrecondition.absent(),
      );
      final actions = <Future<Object?> Function()>[
        () => first.save(
          proposal(id, 'update', 1),
          precondition: WritePrecondition.atRevision(Revision(1)),
        ),
        () async {
          await second.deleteById(
            id,
            precondition: WritePrecondition.atRevision(Revision(1)),
          );
          return true;
        },
      ];
      final outcomes = await Future.wait(
        (reverse ? actions.reversed : actions).map(attempt),
      );
      expect(outcomes.whereType<PreconditionFailedException>(), hasLength(1));
      final raw = await admin.client.getItem(
        tableName: table,
        key: {'id': AttributeValue(s: id.uuid)},
        consistentRead: true,
      );
      final wire = AttributeValueConverter.attributeMapToJsonMap(raw.item!);
      expect(wire['revision'], 2);
      if (wire['__dddart_retired'] == true) {
        expect(wire.keys, hasLength(3));
      } else {
        expect(wire['text'], 'update');
      }
    }
  });
}
