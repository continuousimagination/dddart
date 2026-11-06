@Tags(['requires-dynamodb'])
library;

import 'dart:io';

import 'package:dddart/dddart.dart';
import 'package:dddart_events_distributed/dddart_events_distributed.dart';
import 'package:dddart_events_dynamodb/dddart_events_dynamodb.dart';
import 'package:dddart_repository_dynamodb/dddart_repository_dynamodb.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

void main() {
  late DynamoDB client;
  late String table;
  late DateTime now;
  late AggregateReference<UuidValue> aggregate;
  DynamoAggregateEventRepository repository({DynamoDB? database}) =>
      DynamoAggregateEventRepository(
        client: database ?? client,
        tableName: table,
        clock: () => now,
      );
  EventEnvelope event({UuidValue? id, String body = '{"value":1}'}) =>
      EventEnvelope(
        aggregate: aggregate,
        event: StoredEvent<Identity>(
          id: id ?? UuidValue.generate(),
          aggregateId: aggregate.id,
          eventType: 'changed.v1',
          eventJson: body,
          createdAt: DateTime.utc(1990),
        ),
      );
  setUp(() async {
    now = DateTime.utc(2026, 11, 6);
    aggregate = AggregateReference(kind: 'game', id: UuidValue.generate());
    table = 'dddart_events_${UuidValue.generate().uuid.replaceAll('-', '')}';
    client = _client();
    await client.createTable(
      tableName: table,
      attributeDefinitions: [
        AttributeDefinition(
          attributeName: 'pk',
          attributeType: ScalarAttributeType.s,
        ),
        AttributeDefinition(
          attributeName: 'sk',
          attributeType: ScalarAttributeType.s,
        ),
      ],
      keySchema: [
        KeySchemaElement(attributeName: 'pk', keyType: KeyType.hash),
        KeySchemaElement(attributeName: 'sk', keyType: KeyType.range),
      ],
      billingMode: BillingMode.payPerRequest,
    );
  });
  tearDown(() async {
    await client.deleteTable(tableName: table);
    client.close();
  });

  test(
      'concurrent instances expose committed positions without skipped inserts',
      () async {
    final first = repository();
    final checkpoint = await first.head(aggregate);
    final events = List.generate(20, (_) => event());
    await Future.wait(events.map((envelope) => repository().append(envelope)));
    final duplicate = event();
    final accepted = await Future.wait(
      List.generate(10, (_) => repository().append(duplicate)),
    );
    expect(accepted.map((record) => record.position).toSet(), {21});
    var cursor = checkpoint;
    final records = <RecordedEvent>[];
    var more = true;
    while (more) {
      final page = await repository().read(aggregate, after: cursor, limit: 3);
      records.addAll(page.events);
      cursor = page.checkpoint;
      more = page.hasMore;
    }
    expect(
      records.map((record) => record.position),
      List.generate(21, (index) => index + 1),
    );
    expect(
      records.map((record) => record.envelope.id).toSet(),
      {...events.map((envelope) => envelope.id), duplicate.id},
    );
    await expectLater(
      first.append(event(id: duplicate.id, body: '{"value":2}')),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.type,
          'type',
          RepositoryExceptionType.duplicate,
        ),
      ),
    );
    expect((await repository().head(aggregate)).position, 21);
  });

  test(
      'lost transaction acknowledgment is idempotent across a fresh invocation',
      () async {
    final httpClient = _LostAcknowledgmentClient();
    final uncertain = _client(httpClient: httpClient);
    addTearDown(() {
      uncertain.close();
      httpClient.close();
    });
    final envelope = event();
    await expectLater(
      repository(database: uncertain).append(envelope),
      throwsA(isA<http.ClientException>()),
    );
    final record = await repository().append(envelope);
    expect(record.position, 1);
    expect((await repository().head(aggregate)).position, 1);
    expect((await repository().getById(envelope.id)).id, envelope.id);
  });

  test('TTL lag is enforced on reads while heads survive payload expiration',
      () async {
    final store = repository();
    final checkpoint = await store.head(aggregate);
    final envelope = event();
    await store.append(envelope);
    now = now.add(const Duration(days: 8));
    await expectLater(
      repository().read(aggregate, after: checkpoint),
      throwsA(isA<EventHistoryExpired>()),
    );
    await expectLater(
      repository().getById(envelope.id),
      throwsA(isA<RepositoryException>()),
    );
    final fresh = await repository().head(aggregate);
    expect(fresh.position, 1);
    expect((await repository().read(aggregate, after: fresh)).events, isEmpty);
    await repository().append(envelope);
    final recovered = await repository().read(aggregate, after: fresh);
    expect(recovered.events.single.position, 2);
    expect(recovered.events.single.envelope.id, envelope.id);
  });

  test('manual deletion preserves durable floors and fresh heads', () async {
    final checkpoint = await repository().head(aggregate);
    await repository().append(event());
    final middle = await repository().append(event());
    await repository().append(event());
    await repository().deleteById(middle.envelope.id);
    await expectLater(
      repository().read(aggregate, after: checkpoint),
      throwsA(isA<EventHistoryExpired>()),
    );
    final fresh = await repository().head(aggregate);
    await repository().append(event());
    expect(
      (await repository().read(aggregate, after: fresh)).events.single.position,
      4,
    );
  });

  test('channel resolution and duplicate rotations persist across instances',
      () async {
    DynamoEventChannelRepository channels() => DynamoEventChannelRepository(
          client: client,
          tableName: table,
          clock: () => now,
        );
    final initial = await Future.wait(
      List.generate(12, (_) => channels().resolve(aggregate)),
    );
    expect(initial.map((channel) => channel.id).toSet(), hasLength(1));
    final trigger = UuidValue.generate();
    final rotated = await Future.wait(
      List.generate(12, (_) => channels().rotate(aggregate, trigger)),
    );
    expect(
      rotated.map((rotation) => rotation.current.id).toSet(),
      hasLength(1),
    );
    final next = rotated.first.current;
    expect(next.id, isNot(initial.first.id));
    expect(await channels().find(initial.first.id), isNull);
    expect((await channels().find(next.id))!.aggregate, aggregate);
    final again = await channels().rotate(aggregate, UuidValue.generate());
    expect(again.current.id, isNot(next.id));
    await expectLater(
      channels().rotate(
        AggregateReference(kind: 'other', id: UuidValue.generate()),
        trigger,
      ),
      throwsStateError,
    );
  });

  test(
      'maintenance uses ingestion time, never backdated domain occurrence time',
      () async {
    final old = await repository().append(event());
    now = now.add(const Duration(hours: 1));
    final current = await repository().append(event());
    await repository()
        .deleteOlderThan(now.subtract(const Duration(minutes: 30)));
    await expectLater(
      repository().getById(old.envelope.id),
      throwsA(isA<RepositoryException>()),
    );
    expect(
      (await repository().getById(current.envelope.id)).id,
      current.envelope.id,
    );
  });
}

DynamoDB _client({http.Client? httpClient}) => DynamoDB(
      region: 'us-east-1',
      endpointUrl:
          Platform.environment['DYNAMODB_ENDPOINT'] ?? 'http://127.0.0.1:8000',
      credentials: AwsClientCredentials(accessKey: 'local', secretKey: 'local'),
      client: httpClient,
    );

class _LostAcknowledgmentClient extends http.BaseClient {
  final _inner = http.Client();
  bool _lost = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _inner.send(request);
    final transaction =
        request.headers['X-Amz-Target']?.endsWith('TransactWriteItems') ??
            false;
    if (!_lost && transaction && response.statusCode == 200) {
      _lost = true;
      await response.stream.drain<void>();
      throw http.ClientException('Simulated lost transaction acknowledgment');
    }
    return response;
  }

  @override
  void close() => _inner.close();
}
