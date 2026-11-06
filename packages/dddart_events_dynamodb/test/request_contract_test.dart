import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_events_distributed/dddart_events_distributed.dart';
import 'package:dddart_events_dynamodb/dddart_events_dynamodb.dart';
import 'package:dddart_repository_dynamodb/dddart_repository_dynamodb.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  test(
      'position, payload and occurrence are committed in one guarded transaction',
      () async {
    final requests = <Map<String, dynamic>>[];
    final httpClient = MockClient((request) async {
      final json = jsonDecode(request.body) as Map<String, dynamic>;
      requests.add(json);
      return http.Response(
        '{}',
        200,
        headers: {'content-type': 'application/x-amz-json-1.0'},
      );
    });
    final sdk = DynamoDB(
      region: 'us-east-1',
      credentials: AwsClientCredentials(accessKey: 'test', secretKey: 'test'),
      client: httpClient,
    );
    addTearDown(() {
      sdk.close();
      httpClient.close();
    });
    final aggregate =
        AggregateReference(kind: 'game', id: UuidValue.generate());
    final envelope = EventEnvelope(
      aggregate: aggregate,
      event: StoredEvent<Identity>(
        id: UuidValue.generate(),
        createdAt: DateTime.now().toUtc(),
        aggregateId: aggregate.id,
        eventType: 'changed.v1',
        eventJson: '{}',
      ),
    );
    final store =
        DynamoAggregateEventRepository(client: sdk, tableName: 'test_events');
    expect((await store.append(envelope)).position, 1);
    final transaction = requests.singleWhere(
      (request) => request.containsKey('TransactItems'),
    )['TransactItems'] as List;
    expect(transaction, hasLength(3));
    expect(
      (transaction.first as Map)['Update']['ConditionExpression'],
      contains('attribute_not_exists(pk)'),
    );
    expect((transaction[1] as Map)['Put']['Item']['position']['N'], '1');
    expect(
      (transaction.last as Map)['Put']['Item']['pk']['S'],
      'e#${envelope.id.uuid}',
    );
    expect(
      requests
          .where((request) => request.containsKey('Key'))
          .every((request) => request['ConsistentRead'] == true),
      isTrue,
    );
  });

  test('a DynamoDB byte-limited page never jumps over an unreturned record',
      () async {
    final identities = IdentityCodecRegistry();
    final aggregate =
        AggregateReference(kind: 'document', id: UuidValue.generate());
    final now = DateTime.now().toUtc();
    final envelope = EventEnvelope(
      aggregate: aggregate,
      event: StoredEvent<Identity>(
        id: UuidValue.generate(),
        createdAt: now,
        aggregateId: aggregate.id,
        eventType: 'changed.v1',
        eventJson: '{}',
      ),
    );
    final httpClient = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      if (body.containsKey('KeyConditionExpression')) {
        expect(body['Limit'], 100);
        expect(body['ConsistentRead'], isTrue);
        return http.Response(
          jsonEncode({
            'Items': [
              {
                'wire': {'S': envelope.canonicalJson(identities)},
                'position': {'N': '1'},
                'ingestedAt': {'S': now.toIso8601String()},
                'expiresAt': {
                  'N':
                      '${now.add(const Duration(days: 7)).millisecondsSinceEpoch ~/ 1000}',
                },
              }
            ],
            'LastEvaluatedKey': {
              'pk': {'S': 'stream'},
              'sk': {'S': 'p#1'},
            },
          }),
          200,
        );
      }
      return http.Response(
        jsonEncode({
          'Item': {
            'position': {'N': '3'},
            'logical': {'S': aggregate.toKey(identities)},
          },
        }),
        200,
      );
    });
    final sdk = DynamoDB(
      region: 'us-east-1',
      client: httpClient,
      credentials: AwsClientCredentials(accessKey: 'test', secretKey: 'test'),
    );
    addTearDown(() {
      sdk.close();
      httpClient.close();
    });
    final store = DynamoAggregateEventRepository(
      client: sdk,
      tableName: 'test_events',
      clock: () => now,
    );
    final result = await store.read(
      aggregate,
      after: EventCheckpoint(
        streamKey: aggregate.toKey(identities),
        position: 0,
        observedAt: now,
      ),
    );
    expect(result.hasMore, isTrue);
    expect(result.checkpoint.position, 1);
    expect(result.checkpoint.observedAt, now);
  });
}
