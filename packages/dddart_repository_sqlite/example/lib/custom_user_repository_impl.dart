part of 'custom_user.dart';

/// Uses the same connection and row decoding as the generated CRUD methods.
class CustomUserRepositoryImpl extends CustomUserSqliteRepositoryBase {
  CustomUserRepositoryImpl(super.connection);

  @override
  Future<List<CustomUser>> findActiveUsers({int limit = 20}) async {
    RangeError.checkValueInInterval(limit, 1, 100, 'limit');
    final rows = await _connection.query(
      'SELECT * FROM "custom_users" WHERE "isActive" = 1 '
      'ORDER BY "name", "id" LIMIT ?',
      [limit],
    );
    return [for (final row in rows) _serializer.fromJson(_rowToJson(row))];
  }
}
