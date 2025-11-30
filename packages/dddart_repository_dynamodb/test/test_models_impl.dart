/// Implementation of test repository interfaces.
part of 'test_models.dart';

/// Implementation of TestOrderRepository for testing.
class TestOrderDynamoRepositoryImpl extends TestOrderDynamoRepositoryBase {
  /// Creates the repository implementation.
  TestOrderDynamoRepositoryImpl(super.connection);

  @override
  Future<List<TestOrder>> findByCustomerId(String customerId) async {
    // Scan the table for orders with matching customerId
    // Note: In production, you would use a GSI for this query
    final response = await _connection.client.scan(
      tableName: tableName,
      filterExpression: 'customerId = :customerId',
      expressionAttributeValues: {
        ':customerId': AttributeValue(s: customerId),
      },
    );

    if (response.items == null || response.items!.isEmpty) {
      return [];
    }

    return response.items!.map((item) {
      final json = AttributeValueConverter.attributeMapToJsonMap(item);
      return _serializer.fromJson(json);
    }).toList();
  }

  @override
  Future<TestOrder?> findByOrderNumber(String orderNumber) async {
    // Scan the table for order with matching orderNumber
    // Note: In production, you would use a GSI for this query
    final response = await _connection.client.scan(
      tableName: tableName,
      filterExpression: 'orderNumber = :orderNumber',
      expressionAttributeValues: {
        ':orderNumber': AttributeValue(s: orderNumber),
      },
    );

    if (response.items == null || response.items!.isEmpty) {
      return null;
    }

    final item = response.items!.first;
    final json = AttributeValueConverter.attributeMapToJsonMap(item);
    return _serializer.fromJson(json);
  }
}
