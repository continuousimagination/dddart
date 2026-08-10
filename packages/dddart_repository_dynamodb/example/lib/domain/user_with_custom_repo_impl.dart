part of 'user_with_custom_repo.dart';

/// Concrete implementation of UserRepository with custom query methods.
class UserWithCustomRepoDynamoRepository
    extends UserWithCustomRepoDynamoRepositoryBase {
  /// Creates a repository instance.
  UserWithCustomRepoDynamoRepository(super.connection);

  /// The index used for exact email lookups.
  static const emailIndexName = 'email-index';

  /// The index used for last-name lookups ordered by email.
  static const lastNameIndexName = 'last-name-index';

  /// The largest page accepted by [findByLastName].
  static const maxLastNameResults = 100;

  /// Creates the example table with the indexes required by its read methods.
  Future<void> createTableWithIndexes() async {
    try {
      await _connection.client.createTable(
        tableName: tableName,
        keySchema: [
          KeySchemaElement(
            attributeName: 'id',
            keyType: KeyType.hash,
          ),
        ],
        attributeDefinitions: [
          AttributeDefinition(
            attributeName: 'id',
            attributeType: ScalarAttributeType.s,
          ),
          AttributeDefinition(
            attributeName: 'email',
            attributeType: ScalarAttributeType.s,
          ),
          AttributeDefinition(
            attributeName: 'lastName',
            attributeType: ScalarAttributeType.s,
          ),
        ],
        globalSecondaryIndexes: [
          GlobalSecondaryIndex(
            indexName: emailIndexName,
            keySchema: [
              KeySchemaElement(
                attributeName: 'email',
                keyType: KeyType.hash,
              ),
              KeySchemaElement(
                attributeName: 'id',
                keyType: KeyType.range,
              ),
            ],
            projection: Projection(projectionType: ProjectionType.all),
          ),
          GlobalSecondaryIndex(
            indexName: lastNameIndexName,
            keySchema: [
              KeySchemaElement(
                attributeName: 'lastName',
                keyType: KeyType.hash,
              ),
              KeySchemaElement(
                attributeName: 'email',
                keyType: KeyType.range,
              ),
            ],
            projection: Projection(projectionType: ProjectionType.all),
          ),
        ],
        billingMode: BillingMode.payPerRequest,
      );
    } catch (error) {
      throw _mapDynamoException(error, 'createTableWithIndexes');
    }
  }

  @override
  Future<UserWithCustomRepo?> findByEmail(String email) async {
    try {
      final response = await _connection.client.query(
        tableName: tableName,
        indexName: emailIndexName,
        keyConditionExpression: 'email = :email',
        expressionAttributeValues: {
          ':email': AttributeValue(s: email),
        },
        limit: 1,
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
  Future<List<UserWithCustomRepo>> findByLastName(
    String lastName, {
    required int limit,
  }) async {
    RangeError.checkValueInInterval(
      limit,
      1,
      maxLastNameResults,
      'limit',
    );

    try {
      final response = await _connection.client.query(
        tableName: tableName,
        indexName: lastNameIndexName,
        keyConditionExpression: 'lastName = :lastName',
        expressionAttributeValues: {
          ':lastName': AttributeValue(s: lastName),
        },
        limit: limit,
        scanIndexForward: true,
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
