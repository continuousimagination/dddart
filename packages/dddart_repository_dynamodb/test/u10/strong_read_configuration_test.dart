/// Exercises generated table selection and consistency against SDK wire calls.
library;

import 'dart:convert';
import 'package:dddart/dddart.dart';
import 'package:dddart_repository_dynamodb/dddart_repository_dynamodb.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'binding.dart';
import 'shared_model.dart';

void main() {
  final id = UuidValue.fromString('00000000-0000-4000-8000-000000000001');
  final now = DateTime.utc(2026, 9, 21);
  final record = RemoteRecord(
    id: id,
    createdAt: now,
    updatedAt: now,
    text: 'synthetic',
  );
  test(
    'strong point read uses trusted runtime table and shared serializer',
    () async {
      final connection = DynamoConnection(
        region: 'us-east-1',
        credentials: AwsClientCredentials(accessKey: 'test', secretKey: 'test'),
        httpClient: MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['TableName'], 'runtime-records');
          expect(body['ConsistentRead'], isTrue);
          expect(body['Key'], {
            'id': {'S': id.uuid},
          });
          return http.Response(
            jsonEncode({
              'Item': {
                'id': {'S': id.uuid},
                'createdAt': {'S': now.toIso8601String()},
                'updatedAt': {'S': now.toIso8601String()},
                'text': {'S': record.text},
              },
            }),
            200,
          );
        }),
      );
      final Repository<RemoteRecord> repo = ProbeDynamoRepository(
        connection,
        tableName: 'runtime-records',
        readConsistency: DynamoReadConsistency.strong,
      );
      expect((await repo.getById(id)).text, record.text);
      connection.dispose();
    },
  );
  test(
    'default consistency remains eventual and annotation table is retained',
    () async {
      final connection = DynamoConnection(
        region: 'us-east-1',
        credentials: AwsClientCredentials(accessKey: 'test', secretKey: 'test'),
        httpClient: MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['TableName'], 'records');
          expect(body['ConsistentRead'], isFalse);
          return http.Response('{}', 200);
        }),
      );
      await expectLater(
        ProbeDynamoRepository(connection).getById(id),
        throwsA(isA<RepositoryException>()),
      );
      connection.dispose();
    },
  );
  test('invalid runtime table names fail before network I/O', () {
    final connection = DynamoConnection(region: 'us-east-1');
    for (final name in ['', 'ab', 'invalid/name', 'aws.reserved', 'a' * 256]) {
      expect(
        () => ProbeDynamoRepository(connection, tableName: name),
        throwsArgumentError,
      );
    }
    connection.dispose();
  });
  test(
    'generated repository suppresses raw provider values and never repeats save',
    () async {
      const marker = 'restricted-dynamo-provider-value';
      var sends = 0;
      final connection = DynamoConnection(
        region: 'us-east-1',
        credentials: AwsClientCredentials(accessKey: 'test', secretKey: 'test'),
        httpClient: MockClient((request) async {
          sends++;
          return http.Response(
            jsonEncode({'__type': 'InternalServerError', 'message': marker}),
            500,
          );
        }),
      );
      try {
        await ProbeDynamoRepository(connection).save(record);
        fail('Expected provider failure');
      } on RepositoryException catch (error) {
        expect(error.type, RepositoryExceptionType.unknown);
        expect(error.toString(), isNot(contains(marker)));
      }
      expect(sends, 1);
      connection.dispose();
    },
  );
}
