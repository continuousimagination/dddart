part of 'user_with_custom_repo.dart';

/// Concrete implementation of UserRepository with custom query methods.
class UserWithCustomRepoDynamoRepository
    extends UserWithCustomRepoDynamoRepositoryBase {
  /// Creates a repository instance.
  UserWithCustomRepoDynamoRepository(super.connection);

  @override
  Future<UserWithCustomRepo?> findByEmail(String email) async {
    try {
      final response = await _connection.client.scan(
        tableName: tableName,
        filterExpression: 'email = :email',
        expressionAttributeValues: {
          ':email': AttributeValue(s: email),
        },
      );

      if (response.items == null || response.items!.isEmpty) {
        return null;
      }

      final item = response.items!.first;
      final json = AttributeValueConverter.attributeMapToJsonMap(item);
      return _serializer.fromJson(json);
    } catch (e) {
      throw _mapDynamoException(e, 'findByEmail');
    }
  }

  @override
  Future<List<UserWithCustomRepo>> findByLastName(String lastName) async {
    try {
      final response = await _connection.client.scan(
        tableName: tableName,
        filterExpression: 'lastName = :lastName',
        expressionAttributeValues: {
          ':lastName': AttributeValue(s: lastName),
        },
      );

      if (response.items == null || response.items!.isEmpty) {
        return [];
      }

      return response.items!.map((item) {
        final json = AttributeValueConverter.attributeMapToJsonMap(item);
        return _serializer.fromJson(json);
      }).toList();
    } catch (e) {
      throw _mapDynamoException(e, 'findByLastName');
    }
  }
}
