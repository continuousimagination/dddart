part of 'order_with_custom_repo.dart';

/// Custom repository implementation extending the generated base class.
class OrderWithCustomRepoMysqlRepository
    extends OrderWithCustomRepoMysqlRepositoryBase {
  /// Creates a new custom repository instance.
  OrderWithCustomRepoMysqlRepository(super.connection);

  @override
  Future<List<OrderWithCustomRepo>> findByCustomerName(
    String customerName,
  ) async {
    final sql = '''
      SELECT * FROM $tableName
      WHERE customerName = ?
      ORDER BY createdAt DESC
    ''';

    final rows = await _connection.query(sql, [customerName]);
    final results = <OrderWithCustomRepo>[];

    for (final row in rows) {
      final json = _rowToJson(row);

      // Load related entities
      final orderId = _dialect.decodeUuid(row['id']);
      final itemsJson = await _loadOrderItem(orderId);
      json['items'] = itemsJson;

      final order = _serializer.fromJson(json);
      results.add(order);
    }

    return results;
  }

  @override
  Future<List<OrderWithCustomRepo>> findByMinimumAmount(
    double minAmount,
  ) async {
    // First, get all orders
    final sql = 'SELECT * FROM $tableName ORDER BY createdAt DESC';
    final rows = await _connection.query(sql);
    final results = <OrderWithCustomRepo>[];

    for (final row in rows) {
      final json = _rowToJson(row);

      // Load related entities
      final orderId = _dialect.decodeUuid(row['id']);
      final itemsJson = await _loadOrderItem(orderId);
      json['items'] = itemsJson;

      final order = _serializer.fromJson(json);

      // Filter by total amount (calculated property)
      if (order.totalAmount.amount >= minAmount) {
        results.add(order);
      }
    }

    return results;
  }
}
