// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_with_custom_repo.dart';

// **************************************************************************
// DynamoRepositoryGenerator
// **************************************************************************

/// Generated abstract base DynamoDB repository for [UserWithCustomRepo] aggregate.
///
/// This abstract class implements the base Repository<UserWithCustomRepo> methods
/// (getById, save, deleteById) and declares custom methods as abstract.
///
/// Extend this class and implement the abstract methods to complete
/// the repository implementation.
abstract class UserWithCustomRepoDynamoRepositoryBase
    implements UserRepository {
  /// Creates a repository instance.
  ///
  /// [connection] - A DynamoDB connection instance.
  UserWithCustomRepoDynamoRepositoryBase(
    this._connection, {
    this.readConsistency = DynamoReadConsistency.eventual,
    String? tableName,
  }) : tableName = tableName ?? 'users_with_custom_repo' {
    if (tableName != null &&
        (tableName.length < 3 ||
            tableName.length > 255 ||
            tableName.startsWith('aws.') ||
            !RegExp(r'^[A-Za-z0-9_.-]+$').hasMatch(tableName))) {
      throw ArgumentError('Invalid DynamoDB table name');
    }
  }

  /// Point-read consistency policy.
  final DynamoReadConsistency readConsistency;

  /// The DynamoDB connection instance.
  final DynamoConnection _connection;

  /// The table name for UserWithCustomRepo aggregates.
  final String tableName;

  /// The JSON serializer for UserWithCustomRepo aggregates.
  final _serializer = UserWithCustomRepoJsonSerializer();

  @override
  Future<UserWithCustomRepo> getById(UuidValue id) async {
    try {
      final response = await _connection.client.getItem(
        tableName: tableName,
        key: {'id': AttributeValue(s: id.toString())},
        consistentRead: readConsistency == DynamoReadConsistency.strong,
      );

      if (response.item == null || response.item!.isEmpty) {
        throw RepositoryException(
          'UserWithCustomRepo with ID $id not found',
          type: RepositoryExceptionType.notFound,
        );
      }

      // Convert DynamoDB AttributeValue map to JSON
      final json = AttributeValueConverter.attributeMapToJsonMap(
        response.item!,
      );

      return _serializer.fromJson(json);
    } on RepositoryException {
      rethrow;
    } catch (e) {
      throw _mapDynamoException(e, 'getById');
    }
  }

  @override
  Future<void> save(UserWithCustomRepo aggregate) async {
    try {
      final json = _serializer.toJson(aggregate);

      // Convert JSON to DynamoDB AttributeValue map
      final item = AttributeValueConverter.jsonMapToAttributeMap(json);

      // Upsert operation using PutItem
      await _connection.client.putItem(tableName: tableName, item: item);
    } catch (e) {
      throw _mapDynamoException(e, 'save');
    }
  }

  @override
  Future<void> deleteById(UuidValue id) async {
    try {
      // First check if item exists
      final getResponse = await _connection.client.getItem(
        tableName: tableName,
        key: {'id': AttributeValue(s: id.toString())},
        consistentRead: readConsistency == DynamoReadConsistency.strong,
      );

      if (getResponse.item == null || getResponse.item!.isEmpty) {
        throw RepositoryException(
          'UserWithCustomRepo with ID $id not found',
          type: RepositoryExceptionType.notFound,
        );
      }

      // Delete the item
      await _connection.client.deleteItem(
        tableName: tableName,
        key: {'id': AttributeValue(s: id.toString())},
      );
    } on RepositoryException {
      rethrow;
    } catch (e) {
      throw _mapDynamoException(e, 'deleteById');
    }
  }

  @override
  Future<List<UserWithCustomRepo>> getAll() async {
    try {
      final response = await _connection.client.scan(tableName: tableName);

      if (response.items == null || response.items!.isEmpty) {
        return [];
      }

      return response.items!.map((item) {
        final json = AttributeValueConverter.attributeMapToJsonMap(item);
        return _serializer.fromJson(json);
      }).toList();
    } catch (e) {
      throw _mapDynamoException(e, 'getAll');
    }
  }

  /// Maps typed SDK failures without exposing provider data or raw causes.
  RepositoryException _mapDynamoException(Object error, String operation) {
    return DynamoRepositoryException.map(error, operation);
  }

  /// Creates the DynamoDB table for this repository.
  ///
  /// This is a convenience method that uses the connection's client to
  /// create the table with the appropriate schema.
  ///
  /// Throws [RepositoryException] if table creation fails.
  ///
  /// Example:
  /// ```dart
  /// final repo = UserWithCustomRepoDynamoRepositoryBase(connection);
  /// await repo.createTable();
  /// ```
  Future<void> createTable() async {
    try {
      await _connection.client.createTable(
        tableName: tableName,
        keySchema: [
          KeySchemaElement(attributeName: 'id', keyType: KeyType.hash),
        ],
        attributeDefinitions: [
          AttributeDefinition(
            attributeName: 'id',
            attributeType: ScalarAttributeType.s,
          ),
        ],
        billingMode: BillingMode.payPerRequest,
      );
    } catch (e) {
      throw _mapDynamoException(e, 'createTable');
    }
  }

  /// Returns an AWS CLI command to create this table.
  ///
  /// This command can be executed in a terminal to create the table
  /// using the AWS CLI.
  ///
  /// Example:
  /// ```dart
  /// final command = UserWithCustomRepoDynamoRepositoryBase.getCreateTableCommand('users_with_custom_repo');
  /// print(command);
  /// // Copy and paste into terminal
  /// ```
  static String getCreateTableCommand(String tableName) {
    return '''
aws dynamodb create-table \\
  --table-name $tableName \\
  --attribute-definitions AttributeName=id,AttributeType=S \\
  --key-schema AttributeName=id,KeyType=HASH \\
  --billing-mode PAY_PER_REQUEST
'''
        .trim();
  }

  /// Returns a CloudFormation YAML template for this table.
  ///
  /// This template can be included in a CloudFormation stack to
  /// provision the table as infrastructure as code.
  ///
  /// Example:
  /// ```dart
  /// final template = UserWithCustomRepoDynamoRepositoryBase.getCloudFormationTemplate('users_with_custom_repo');
  /// print(template);
  /// // Add to CloudFormation template
  /// ```
  static String getCloudFormationTemplate(String tableName) {
    return '''
Resources:
  \${tableName.split('_').map((s) => s[0].toUpperCase() + s.substring(1)).join()}Table:
    Type: AWS::DynamoDB::Table
    Properties:
      TableName: $tableName
      AttributeDefinitions:
        - AttributeName: id
          AttributeType: S
      KeySchema:
        - AttributeName: id
          KeyType: HASH
      BillingMode: PAY_PER_REQUEST
'''
        .trim();
  }

  // Custom methods (must be implemented by subclass)

  @override
  Future<UserWithCustomRepo?> findByEmail(String email);

  @override
  Future<List<UserWithCustomRepo>> findByLastName(String lastName);
}

// **************************************************************************
// SerializableGenerator
// **************************************************************************

class UserWithCustomRepoJsonSerializer
    implements JsonSerializer<UserWithCustomRepo> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  UserWithCustomRepoJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig = defaultConfig ?? const SerializationConfig();

  @override
  Map<String, dynamic> toJson(
    UserWithCustomRepo instance, [
    SerializationConfig? config,
  ]) {
    final effectiveConfig = config ?? _defaultConfig;
    final json = <String, dynamic>{
      SerializationUtils.applyFieldRename('id', effectiveConfig.fieldRename):
          instance.id.toString(),
      SerializationUtils.applyFieldRename(
        'createdAt',
        effectiveConfig.fieldRename,
      ): instance.createdAt
          .toIso8601String(),
      SerializationUtils.applyFieldRename(
        'updatedAt',
        effectiveConfig.fieldRename,
      ): instance.updatedAt
          .toIso8601String(),
      SerializationUtils.applyFieldRename('email', effectiveConfig.fieldRename):
          instance.email,
      SerializationUtils.applyFieldRename(
        'firstName',
        effectiveConfig.fieldRename,
      ): instance.firstName,
      SerializationUtils.applyFieldRename(
        'lastName',
        effectiveConfig.fieldRename,
      ): instance.lastName,
    };
    return json;
  }

  @override
  UserWithCustomRepo fromJson(dynamic json, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize UserWithCustomRepo from null JSON',
        expectedType: 'UserWithCustomRepo',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'UserWithCustomRepo',
      );
    }
    try {
      return UserWithCustomRepo(
        email:
            json[SerializationUtils.applyFieldRename(
                  'email',
                  effectiveConfig.fieldRename,
                )]
                as String,
        firstName:
            json[SerializationUtils.applyFieldRename(
                  'firstName',
                  effectiveConfig.fieldRename,
                )]
                as String,
        lastName:
            json[SerializationUtils.applyFieldRename(
                  'lastName',
                  effectiveConfig.fieldRename,
                )]
                as String,
        id: UuidValue.fromString(
          json[SerializationUtils.applyFieldRename(
                'id',
                effectiveConfig.fieldRename,
              )]
              as String,
        ),
        createdAt:
            json[SerializationUtils.applyFieldRename(
                  'createdAt',
                  effectiveConfig.fieldRename,
                )] !=
                null
            ? DateTime.parse(
                json[SerializationUtils.applyFieldRename(
                      'createdAt',
                      effectiveConfig.fieldRename,
                    )]
                    as String,
              )
            : DateTime.now(),
        updatedAt:
            json[SerializationUtils.applyFieldRename(
                  'updatedAt',
                  effectiveConfig.fieldRename,
                )] !=
                null
            ? DateTime.parse(
                json[SerializationUtils.applyFieldRename(
                      'updatedAt',
                      effectiveConfig.fieldRename,
                    )]
                    as String,
              )
            : DateTime.now(),
      );
    } catch (e, stackTrace) {
      throw DeserializationException(
        'Failed to deserialize UserWithCustomRepo',
        expectedType: 'UserWithCustomRepo',
      );
    }
  }

  @override
  String serialize(UserWithCustomRepo object, [dynamic config]) {
    try {
      return jsonEncode(toJson(object, config as SerializationConfig?));
    } catch (_) {
      throw SerializationException(
        'Failed to serialize UserWithCustomRepo',
        expectedType: 'UserWithCustomRepo',
      );
    }
  }

  @override
  UserWithCustomRepo deserialize(String data, [dynamic config]) {
    try {
      final json = jsonDecode(data);
      if (json is! Map<String, dynamic>) {
        throw DeserializationException(
          'Expected JSON object',
          expectedType: 'UserWithCustomRepo',
        );
      }
      return fromJson(json, config as SerializationConfig?);
    } on DeserializationException {
      rethrow;
    } catch (_) {
      throw DeserializationException(
        'Invalid JSON input',
        expectedType: 'UserWithCustomRepo',
      );
    }
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    UserWithCustomRepo instance, [
    SerializationConfig? config,
  ]) {
    return UserWithCustomRepoJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static UserWithCustomRepo decode(
    dynamic json, [
    SerializationConfig? config,
  ]) {
    return UserWithCustomRepoJsonSerializer().fromJson(json, config);
  }
}
