// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'binding.dart';

// **************************************************************************
// DynamoRepositoryGenerator
// **************************************************************************

/// Generated DynamoDB repository for [shared.RemoteRecord] aggregate.
///
/// This class can be used directly for basic CRUD operations or
/// extended
/// to add custom query methods.
class ProbeDynamoRepository implements Repository<shared.RemoteRecord> {
  /// Creates a repository instance.
  ///
  /// [connection] - A DynamoDB connection instance.
  ProbeDynamoRepository(
    this._connection, {
    this.readConsistency = DynamoReadConsistency.eventual,
    String? tableName,
  }) : tableName = tableName ?? 'records' {
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

  /// The table name for shared.RemoteRecord aggregates.
  final String tableName;

  /// The JSON serializer for shared.RemoteRecord aggregates.
  final _serializer = shared.RemoteRecordJsonSerializer();

  @override
  Future<shared.RemoteRecord> getById(UuidValue id) async {
    try {
      final response = await _connection.client.getItem(
        tableName: tableName,
        key: {'id': AttributeValue(s: id.toString())},
        consistentRead: readConsistency == DynamoReadConsistency.strong,
      );

      if (response.item == null || response.item!.isEmpty) {
        throw RepositoryException(
          'shared.RemoteRecord with ID $id not found',
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
  Future<void> save(shared.RemoteRecord aggregate) async {
    if (aggregate is VersionedAggregateRoot) {
      throw const RepositoryCapabilityException();
    }
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
          'shared.RemoteRecord with ID $id not found',
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
  /// final repo = ProbeDynamoRepository(connection);
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
  /// final command = ProbeDynamoRepository.getCreateTableCommand('records');
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
  /// final template = ProbeDynamoRepository.getCloudFormationTemplate('records');
  /// print(template);
  /// // Add to CloudFormation template
  /// ```
  static String getCloudFormationTemplate(String tableName) {
    final logicalId = _cloudFormationLogicalId(tableName);
    return '''
Resources:
  ${logicalId}Table:
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

  static String _cloudFormationLogicalId(String tableName) {
    final segments = tableName
        .split(RegExp('[^A-Za-z0-9]+'))
        .where((segment) => segment.isNotEmpty);
    var logicalId = segments
        .map((segment) => segment[0].toUpperCase() + segment.substring(1))
        .join();

    if (logicalId.isEmpty) logicalId = 'Dynamo';
    if (!RegExp('^[A-Za-z]').hasMatch(logicalId)) {
      logicalId = 'Dynamo$logicalId';
    }
    return logicalId;
  }
}

/// Generated abstract base DynamoDB repository for [shared.RemoteRecord] aggregate.
///
/// This abstract class implements the base Repository<shared.RemoteRecord> methods
/// (getById, save, deleteById) and declares custom methods as abstract.
///
/// Extend this class and implement the abstract methods to complete
/// the repository implementation.
abstract class CallbackDynamoRepositoryBase implements shared.RemotePort {
  /// Creates a repository instance.
  ///
  /// [connection] - A DynamoDB connection instance.
  CallbackDynamoRepositoryBase(
    this._connection, {
    this.readConsistency = DynamoReadConsistency.eventual,
    String? tableName,
  }) : tableName = tableName ?? 'records' {
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

  /// The table name for shared.RemoteRecord aggregates.
  final String tableName;

  /// The JSON serializer for shared.RemoteRecord aggregates.
  final _serializer = shared.RemoteRecordJsonSerializer();

  @override
  Future<shared.RemoteRecord> getById(UuidValue id) async {
    try {
      final response = await _connection.client.getItem(
        tableName: tableName,
        key: {'id': AttributeValue(s: id.toString())},
        consistentRead: readConsistency == DynamoReadConsistency.strong,
      );

      if (response.item == null || response.item!.isEmpty) {
        throw RepositoryException(
          'shared.RemoteRecord with ID $id not found',
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
  Future<void> save(shared.RemoteRecord aggregate) async {
    if (aggregate is VersionedAggregateRoot) {
      throw const RepositoryCapabilityException();
    }
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
          'shared.RemoteRecord with ID $id not found',
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
  /// final repo = CallbackDynamoRepositoryBase(connection);
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
  /// final command = CallbackDynamoRepositoryBase.getCreateTableCommand('records');
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
  /// final template = CallbackDynamoRepositoryBase.getCloudFormationTemplate('records');
  /// print(template);
  /// // Add to CloudFormation template
  /// ```
  static String getCloudFormationTemplate(String tableName) {
    final logicalId = _cloudFormationLogicalId(tableName);
    return '''
Resources:
  ${logicalId}Table:
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

  static String _cloudFormationLogicalId(String tableName) {
    final segments = tableName
        .split(RegExp('[^A-Za-z0-9]+'))
        .where((segment) => segment.isNotEmpty);
    var logicalId = segments
        .map((segment) => segment[0].toUpperCase() + segment.substring(1))
        .join();

    if (logicalId.isEmpty) logicalId = 'Dynamo';
    if (!RegExp('^[A-Za-z]').hasMatch(logicalId)) {
      logicalId = 'Dynamo$logicalId';
    }
    return logicalId;
  }

  // Custom methods (must be implemented by subclass)

  @override
  Future<shared.RemoteRecord Function(shared.RemoteRecord)> callback({
    int take = 20,
    String label = "\$label",
    shared.FilterMode mode = shared.FilterMode.all,
  });
}
