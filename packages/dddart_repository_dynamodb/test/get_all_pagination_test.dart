import 'package:dddart/dddart.dart';
import 'package:dddart_repository_dynamodb/dddart_repository_dynamodb.dart';
import 'package:test/test.dart';

import 'test_models.dart';

void main() {
  test('getAll follows each Scan continuation key', () async {
    final continuationKey = {
      'id': AttributeValue(s: UuidValue.generate().toString()),
    };
    final firstUser = _userItem('first@example.test');
    final secondUser = _userItem('second@example.test');
    final client = _PagingDynamoDb([
      ScanOutput(items: [firstUser], lastEvaluatedKey: continuationKey),
      ScanOutput(items: [secondUser]),
    ]);
    final repository = TestUserDynamoRepository(_FakeConnection(client));

    final users = await repository.getAll();

    expect(users.map((user) => user.email), [
      'first@example.test',
      'second@example.test',
    ]);
    expect(client.exclusiveStartKeys, [isNull, same(continuationKey)]);

    client.close();
  });
}

Map<String, AttributeValue> _userItem(String email) {
  final now = DateTime.utc(2026);
  return {
    'id': AttributeValue(s: UuidValue.generate().toString()),
    'createdAt': AttributeValue(s: now.toIso8601String()),
    'updatedAt': AttributeValue(s: now.toIso8601String()),
    'name': AttributeValue(s: email.split('@').first),
    'email': AttributeValue(s: email),
  };
}

class _FakeConnection extends DynamoConnection {
  _FakeConnection(this._fakeClient) : super(region: 'us-east-1');

  final DynamoDB _fakeClient;

  @override
  DynamoDB get client => _fakeClient;
}

class _PagingDynamoDb extends DynamoDB {
  _PagingDynamoDb(this._pages) : super(region: 'us-east-1');

  final List<ScanOutput> _pages;
  final List<Map<String, AttributeValue>?> exclusiveStartKeys = [];

  @override
  Future<ScanOutput> scan({
    required String tableName,
    List<String>? attributesToGet,
    ConditionalOperator? conditionalOperator,
    bool? consistentRead,
    Map<String, AttributeValue>? exclusiveStartKey,
    Map<String, String>? expressionAttributeNames,
    Map<String, AttributeValue>? expressionAttributeValues,
    String? filterExpression,
    String? indexName,
    int? limit,
    String? projectionExpression,
    ReturnConsumedCapacity? returnConsumedCapacity,
    Map<String, Condition>? scanFilter,
    int? segment,
    Select? select,
    int? totalSegments,
  }) async {
    exclusiveStartKeys.add(exclusiveStartKey);
    return _pages.removeAt(0);
  }
}
