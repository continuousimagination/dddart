// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product.dart';

// **************************************************************************
// DynamoRepositoryGenerator
// **************************************************************************

/// Generated DynamoDB repository for [Product] aggregate.
///
/// This class can be used directly for basic CRUD operations or
/// extended
/// to add custom query methods.
class ProductDynamoRepository implements QueryableRepository<Product> {
  /// Creates a repository instance.
  ///
  /// [connection] - A DynamoDB connection instance.
  ProductDynamoRepository(
    this._connection, {
    this.readConsistency = DynamoReadConsistency.eventual,
    String? tableName,
  }) : tableName = tableName ?? 'products' {
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

  /// The table name for Product aggregates.
  final String tableName;

  /// The JSON serializer for Product aggregates.
  final _serializer = ProductJsonSerializer();

  @override
  Future<Product> getById(UuidValue id) async {
    try {
      final response = await _connection.client.getItem(
        tableName: tableName,
        key: {'id': AttributeValue(s: id.toString())},
        consistentRead: readConsistency == DynamoReadConsistency.strong,
      );

      if (response.item == null || response.item!.isEmpty) {
        throw RepositoryException(
          'Product with ID $id not found',
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
  Future<void> save(Product aggregate) async {
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
          'Product with ID $id not found',
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
  Future<List<Product>> getAll() async {
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
  /// final repo = ProductDynamoRepository(connection);
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
  /// final command = ProductDynamoRepository.getCreateTableCommand('products');
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
  /// final template = ProductDynamoRepository.getCloudFormationTemplate('products');
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
}

// **************************************************************************
// SerializableGenerator
// **************************************************************************

class ProductJsonSerializer implements JsonSerializer<Product> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  ProductJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig = defaultConfig ?? const SerializationConfig();

  @override
  Map<String, dynamic> toJson(Product instance, [SerializationConfig? config]) {
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
      SerializationUtils.applyFieldRename(
        'description',
        effectiveConfig.fieldRename,
      ): instance.description,
      SerializationUtils.applyFieldRename(
        'inStock',
        effectiveConfig.fieldRename,
      ): instance.inStock,
      SerializationUtils.applyFieldRename('name', effectiveConfig.fieldRename):
          instance.name,
      SerializationUtils.applyFieldRename('price', effectiveConfig.fieldRename):
          instance.price,
    };
    return json;
  }

  @override
  Product fromJson(dynamic json, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize Product from null JSON',
        expectedType: 'Product',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'Product',
      );
    }
    try {
      return Product(
        description:
            json[SerializationUtils.applyFieldRename(
                  'description',
                  effectiveConfig.fieldRename,
                )]
                as String,
        inStock:
            json[SerializationUtils.applyFieldRename(
                  'inStock',
                  effectiveConfig.fieldRename,
                )]
                as bool,
        name:
            json[SerializationUtils.applyFieldRename(
                  'name',
                  effectiveConfig.fieldRename,
                )]
                as String,
        price:
            (json[SerializationUtils.applyFieldRename(
                  'price',
                  effectiveConfig.fieldRename,
                )]
                is int
            ? (json[SerializationUtils.applyFieldRename(
                        'price',
                        effectiveConfig.fieldRename,
                      )]
                      as int)
                  .toDouble()
            : json[SerializationUtils.applyFieldRename(
                    'price',
                    effectiveConfig.fieldRename,
                  )]
                  as double),
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
        'Failed to deserialize Product',
        expectedType: 'Product',
      );
    }
  }

  @override
  String serialize(Product object, [dynamic config]) {
    try {
      return jsonEncode(toJson(object, config as SerializationConfig?));
    } catch (_) {
      throw SerializationException(
        'Failed to serialize Product',
        expectedType: 'Product',
      );
    }
  }

  @override
  Product deserialize(String data, [dynamic config]) {
    try {
      final json = jsonDecode(data);
      if (json is! Map<String, dynamic>) {
        throw DeserializationException(
          'Expected JSON object',
          expectedType: 'Product',
        );
      }
      return fromJson(json, config as SerializationConfig?);
    } on DeserializationException {
      rethrow;
    } catch (_) {
      throw DeserializationException(
        'Invalid JSON input',
        expectedType: 'Product',
      );
    }
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    Product instance, [
    SerializationConfig? config,
  ]) {
    return ProductJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static Product decode(dynamic json, [SerializationConfig? config]) {
    return ProductJsonSerializer().fromJson(json, config);
  }
}
