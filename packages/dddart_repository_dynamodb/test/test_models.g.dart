// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'test_models.dart';

// **************************************************************************
// DynamoRepositoryGenerator
// **************************************************************************

/// Generated DynamoDB repository for [TestUser] aggregate.
///
/// This class can be used directly for basic CRUD operations or
/// extended
/// to add custom query methods.
class TestUserDynamoRepository implements QueryableRepository<TestUser> {
  /// Creates a repository instance.
  ///
  /// [connection] - A DynamoDB connection instance.
  TestUserDynamoRepository(this._connection);

  /// The DynamoDB connection instance.
  final DynamoConnection _connection;

  /// The table name for TestUser aggregates.
  String get tableName => 'test_users';

  /// The JSON serializer for TestUser aggregates.
  final _serializer = TestUserJsonSerializer();

  @override
  Future<TestUser> getById(UuidValue id) async {
    try {
      final response = await _connection.client.getItem(
        tableName: tableName,
        key: {'id': AttributeValue(s: id.toString())},
      );

      if (response.item == null || response.item!.isEmpty) {
        throw RepositoryException(
          'TestUser with ID $id not found',
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
  Future<void> save(TestUser aggregate) async {
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
      );

      if (getResponse.item == null || getResponse.item!.isEmpty) {
        throw RepositoryException(
          'TestUser with ID $id not found',
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
  Future<List<TestUser>> getAll() async {
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

  /// Maps DynamoDB exceptions to RepositoryException types.
  RepositoryException _mapDynamoException(Object error, String operation) {
    final errorString = error.toString();

    // Map ResourceNotFoundException to notFound
    if (errorString.contains('ResourceNotFoundException')) {
      return RepositoryException(
        'Resource not found during $operation: $errorString',
        type: RepositoryExceptionType.notFound,
        cause: error,
      );
    }

    // Map ConditionalCheckFailedException to duplicate
    if (errorString.contains('ConditionalCheckFailedException')) {
      return RepositoryException(
        'Conditional check failed during $operation: $errorString',
        type: RepositoryExceptionType.duplicate,
        cause: error,
      );
    }

    // Map network/connectivity errors to connection
    if (errorString.contains('connection') ||
        errorString.contains('network') ||
        errorString.contains('SocketException')) {
      return RepositoryException(
        'Connection error during $operation: $errorString',
        type: RepositoryExceptionType.connection,
        cause: error,
      );
    }

    // Map timeout errors to timeout
    if (errorString.contains('timeout') ||
        errorString.contains('TimeoutException')) {
      return RepositoryException(
        'Timeout during $operation: $errorString',
        type: RepositoryExceptionType.timeout,
        cause: error,
      );
    }

    // All other errors map to unknown
    return RepositoryException(
      'DynamoDB error during $operation: $errorString',
      type: RepositoryExceptionType.unknown,
      cause: error,
    );
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
  /// final repo = TestUserDynamoRepository(connection);
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
  /// final command = TestUserDynamoRepository.getCreateTableCommand('test_users');
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
  /// final template = TestUserDynamoRepository.getCloudFormationTemplate('test_users');
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

/// Generated DynamoDB repository for [TestProduct] aggregate.
///
/// This class can be used directly for basic CRUD operations or
/// extended
/// to add custom query methods.
class TestProductDynamoRepository implements QueryableRepository<TestProduct> {
  /// Creates a repository instance.
  ///
  /// [connection] - A DynamoDB connection instance.
  TestProductDynamoRepository(this._connection);

  /// The DynamoDB connection instance.
  final DynamoConnection _connection;

  /// The table name for TestProduct aggregates.
  String get tableName => 'custom_products';

  /// The JSON serializer for TestProduct aggregates.
  final _serializer = TestProductJsonSerializer();

  @override
  Future<TestProduct> getById(UuidValue id) async {
    try {
      final response = await _connection.client.getItem(
        tableName: tableName,
        key: {'id': AttributeValue(s: id.toString())},
      );

      if (response.item == null || response.item!.isEmpty) {
        throw RepositoryException(
          'TestProduct with ID $id not found',
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
  Future<void> save(TestProduct aggregate) async {
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
      );

      if (getResponse.item == null || getResponse.item!.isEmpty) {
        throw RepositoryException(
          'TestProduct with ID $id not found',
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
  Future<List<TestProduct>> getAll() async {
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

  /// Maps DynamoDB exceptions to RepositoryException types.
  RepositoryException _mapDynamoException(Object error, String operation) {
    final errorString = error.toString();

    // Map ResourceNotFoundException to notFound
    if (errorString.contains('ResourceNotFoundException')) {
      return RepositoryException(
        'Resource not found during $operation: $errorString',
        type: RepositoryExceptionType.notFound,
        cause: error,
      );
    }

    // Map ConditionalCheckFailedException to duplicate
    if (errorString.contains('ConditionalCheckFailedException')) {
      return RepositoryException(
        'Conditional check failed during $operation: $errorString',
        type: RepositoryExceptionType.duplicate,
        cause: error,
      );
    }

    // Map network/connectivity errors to connection
    if (errorString.contains('connection') ||
        errorString.contains('network') ||
        errorString.contains('SocketException')) {
      return RepositoryException(
        'Connection error during $operation: $errorString',
        type: RepositoryExceptionType.connection,
        cause: error,
      );
    }

    // Map timeout errors to timeout
    if (errorString.contains('timeout') ||
        errorString.contains('TimeoutException')) {
      return RepositoryException(
        'Timeout during $operation: $errorString',
        type: RepositoryExceptionType.timeout,
        cause: error,
      );
    }

    // All other errors map to unknown
    return RepositoryException(
      'DynamoDB error during $operation: $errorString',
      type: RepositoryExceptionType.unknown,
      cause: error,
    );
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
  /// final repo = TestProductDynamoRepository(connection);
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
  /// final command = TestProductDynamoRepository.getCreateTableCommand('custom_products');
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
  /// final template = TestProductDynamoRepository.getCloudFormationTemplate('custom_products');
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

/// Generated abstract base DynamoDB repository for [TestOrder] aggregate.
///
/// This abstract class implements the base Repository<TestOrder> methods
/// (getById, save, deleteById) and declares custom methods as abstract.
///
/// Extend this class and implement the abstract methods to complete
/// the repository implementation.
abstract class TestOrderDynamoRepositoryBase implements TestOrderRepository {
  /// Creates a repository instance.
  ///
  /// [connection] - A DynamoDB connection instance.
  TestOrderDynamoRepositoryBase(this._connection);

  /// The DynamoDB connection instance.
  final DynamoConnection _connection;

  /// The table name for TestOrder aggregates.
  String get tableName => 'test_orders';

  /// The JSON serializer for TestOrder aggregates.
  final _serializer = TestOrderJsonSerializer();

  @override
  Future<TestOrder> getById(UuidValue id) async {
    try {
      final response = await _connection.client.getItem(
        tableName: tableName,
        key: {'id': AttributeValue(s: id.toString())},
      );

      if (response.item == null || response.item!.isEmpty) {
        throw RepositoryException(
          'TestOrder with ID $id not found',
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
  Future<void> save(TestOrder aggregate) async {
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
      );

      if (getResponse.item == null || getResponse.item!.isEmpty) {
        throw RepositoryException(
          'TestOrder with ID $id not found',
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
  Future<List<TestOrder>> getAll() async {
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

  /// Maps DynamoDB exceptions to RepositoryException types.
  RepositoryException _mapDynamoException(Object error, String operation) {
    final errorString = error.toString();

    // Map ResourceNotFoundException to notFound
    if (errorString.contains('ResourceNotFoundException')) {
      return RepositoryException(
        'Resource not found during $operation: $errorString',
        type: RepositoryExceptionType.notFound,
        cause: error,
      );
    }

    // Map ConditionalCheckFailedException to duplicate
    if (errorString.contains('ConditionalCheckFailedException')) {
      return RepositoryException(
        'Conditional check failed during $operation: $errorString',
        type: RepositoryExceptionType.duplicate,
        cause: error,
      );
    }

    // Map network/connectivity errors to connection
    if (errorString.contains('connection') ||
        errorString.contains('network') ||
        errorString.contains('SocketException')) {
      return RepositoryException(
        'Connection error during $operation: $errorString',
        type: RepositoryExceptionType.connection,
        cause: error,
      );
    }

    // Map timeout errors to timeout
    if (errorString.contains('timeout') ||
        errorString.contains('TimeoutException')) {
      return RepositoryException(
        'Timeout during $operation: $errorString',
        type: RepositoryExceptionType.timeout,
        cause: error,
      );
    }

    // All other errors map to unknown
    return RepositoryException(
      'DynamoDB error during $operation: $errorString',
      type: RepositoryExceptionType.unknown,
      cause: error,
    );
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
  /// final repo = TestOrderDynamoRepository(connection);
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
  /// final command = TestOrderDynamoRepository.getCreateTableCommand('test_orders');
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
  /// final template = TestOrderDynamoRepository.getCloudFormationTemplate('test_orders');
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
  Future<List<TestOrder>> findByCustomerId(String customerId);

  @override
  Future<TestOrder?> findByOrderNumber(String orderNumber);
}

/// Generated DynamoDB repository for [TestAccount] aggregate.
///
/// This class can be used directly for basic CRUD operations or
/// extended
/// to add custom query methods.
class TestAccountDynamoRepository implements QueryableRepository<TestAccount> {
  /// Creates a repository instance.
  ///
  /// [connection] - A DynamoDB connection instance.
  TestAccountDynamoRepository(this._connection);

  /// The DynamoDB connection instance.
  final DynamoConnection _connection;

  /// The table name for TestAccount aggregates.
  String get tableName => 'test_accounts';

  /// The JSON serializer for TestAccount aggregates.
  final _serializer = TestAccountJsonSerializer();

  @override
  Future<TestAccount> getById(UuidValue id) async {
    try {
      final response = await _connection.client.getItem(
        tableName: tableName,
        key: {'id': AttributeValue(s: id.toString())},
      );

      if (response.item == null || response.item!.isEmpty) {
        throw RepositoryException(
          'TestAccount with ID $id not found',
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
  Future<void> save(TestAccount aggregate) async {
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
      );

      if (getResponse.item == null || getResponse.item!.isEmpty) {
        throw RepositoryException(
          'TestAccount with ID $id not found',
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
  Future<List<TestAccount>> getAll() async {
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

  /// Maps DynamoDB exceptions to RepositoryException types.
  RepositoryException _mapDynamoException(Object error, String operation) {
    final errorString = error.toString();

    // Map ResourceNotFoundException to notFound
    if (errorString.contains('ResourceNotFoundException')) {
      return RepositoryException(
        'Resource not found during $operation: $errorString',
        type: RepositoryExceptionType.notFound,
        cause: error,
      );
    }

    // Map ConditionalCheckFailedException to duplicate
    if (errorString.contains('ConditionalCheckFailedException')) {
      return RepositoryException(
        'Conditional check failed during $operation: $errorString',
        type: RepositoryExceptionType.duplicate,
        cause: error,
      );
    }

    // Map network/connectivity errors to connection
    if (errorString.contains('connection') ||
        errorString.contains('network') ||
        errorString.contains('SocketException')) {
      return RepositoryException(
        'Connection error during $operation: $errorString',
        type: RepositoryExceptionType.connection,
        cause: error,
      );
    }

    // Map timeout errors to timeout
    if (errorString.contains('timeout') ||
        errorString.contains('TimeoutException')) {
      return RepositoryException(
        'Timeout during $operation: $errorString',
        type: RepositoryExceptionType.timeout,
        cause: error,
      );
    }

    // All other errors map to unknown
    return RepositoryException(
      'DynamoDB error during $operation: $errorString',
      type: RepositoryExceptionType.unknown,
      cause: error,
    );
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
  /// final repo = TestAccountDynamoRepository(connection);
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
  /// final command = TestAccountDynamoRepository.getCreateTableCommand('test_accounts');
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
  /// final template = TestAccountDynamoRepository.getCloudFormationTemplate('test_accounts');
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

class TestUserJsonSerializer implements JsonSerializer<TestUser> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  TestUserJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig = defaultConfig ?? const SerializationConfig();

  @override
  Map<String, dynamic> toJson(
    TestUser instance, [
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
      SerializationUtils.applyFieldRename('name', effectiveConfig.fieldRename):
          instance.name,
    };
    return json;
  }

  @override
  TestUser fromJson(dynamic json, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize TestUser from null JSON',
        expectedType: 'TestUser',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'TestUser',
      );
    }
    try {
      return TestUser(
        email:
            json[SerializationUtils.applyFieldRename(
                  'email',
                  effectiveConfig.fieldRename,
                )]
                as String,
        name:
            json[SerializationUtils.applyFieldRename(
                  'name',
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
        'Failed to deserialize TestUser: $e',
        expectedType: 'TestUser',
      );
    }
  }

  @override
  String serialize(TestUser object, [dynamic config]) {
    return jsonEncode(toJson(object, config as SerializationConfig?));
  }

  @override
  TestUser deserialize(String data, [dynamic config]) {
    final json = jsonDecode(data);
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected JSON object but got ${json.runtimeType}',
        expectedType: 'TestUser',
      );
    }
    return fromJson(json, config as SerializationConfig?);
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    TestUser instance, [
    SerializationConfig? config,
  ]) {
    return TestUserJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static TestUser decode(dynamic json, [SerializationConfig? config]) {
    return TestUserJsonSerializer().fromJson(json, config);
  }
}

class TestProductJsonSerializer implements JsonSerializer<TestProduct> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  TestProductJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig = defaultConfig ?? const SerializationConfig();

  @override
  Map<String, dynamic> toJson(
    TestProduct instance, [
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
      SerializationUtils.applyFieldRename('name', effectiveConfig.fieldRename):
          instance.name,
      SerializationUtils.applyFieldRename('price', effectiveConfig.fieldRename):
          instance.price,
    };
    return json;
  }

  @override
  TestProduct fromJson(dynamic json, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize TestProduct from null JSON',
        expectedType: 'TestProduct',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'TestProduct',
      );
    }
    try {
      return TestProduct(
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
        'Failed to deserialize TestProduct: $e',
        expectedType: 'TestProduct',
      );
    }
  }

  @override
  String serialize(TestProduct object, [dynamic config]) {
    return jsonEncode(toJson(object, config as SerializationConfig?));
  }

  @override
  TestProduct deserialize(String data, [dynamic config]) {
    final json = jsonDecode(data);
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected JSON object but got ${json.runtimeType}',
        expectedType: 'TestProduct',
      );
    }
    return fromJson(json, config as SerializationConfig?);
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    TestProduct instance, [
    SerializationConfig? config,
  ]) {
    return TestProductJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static TestProduct decode(dynamic json, [SerializationConfig? config]) {
    return TestProductJsonSerializer().fromJson(json, config);
  }
}

class TestOrderJsonSerializer implements JsonSerializer<TestOrder> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  TestOrderJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig = defaultConfig ?? const SerializationConfig();

  @override
  Map<String, dynamic> toJson(
    TestOrder instance, [
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
      SerializationUtils.applyFieldRename(
        'customerId',
        effectiveConfig.fieldRename,
      ): instance.customerId,
      SerializationUtils.applyFieldRename(
        'orderNumber',
        effectiveConfig.fieldRename,
      ): instance.orderNumber,
      SerializationUtils.applyFieldRename('total', effectiveConfig.fieldRename):
          instance.total,
    };
    return json;
  }

  @override
  TestOrder fromJson(dynamic json, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize TestOrder from null JSON',
        expectedType: 'TestOrder',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'TestOrder',
      );
    }
    try {
      return TestOrder(
        customerId:
            json[SerializationUtils.applyFieldRename(
                  'customerId',
                  effectiveConfig.fieldRename,
                )]
                as String,
        orderNumber:
            json[SerializationUtils.applyFieldRename(
                  'orderNumber',
                  effectiveConfig.fieldRename,
                )]
                as String,
        total:
            (json[SerializationUtils.applyFieldRename(
                  'total',
                  effectiveConfig.fieldRename,
                )]
                is int
            ? (json[SerializationUtils.applyFieldRename(
                        'total',
                        effectiveConfig.fieldRename,
                      )]
                      as int)
                  .toDouble()
            : json[SerializationUtils.applyFieldRename(
                    'total',
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
        'Failed to deserialize TestOrder: $e',
        expectedType: 'TestOrder',
      );
    }
  }

  @override
  String serialize(TestOrder object, [dynamic config]) {
    return jsonEncode(toJson(object, config as SerializationConfig?));
  }

  @override
  TestOrder deserialize(String data, [dynamic config]) {
    final json = jsonDecode(data);
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected JSON object but got ${json.runtimeType}',
        expectedType: 'TestOrder',
      );
    }
    return fromJson(json, config as SerializationConfig?);
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    TestOrder instance, [
    SerializationConfig? config,
  ]) {
    return TestOrderJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static TestOrder decode(dynamic json, [SerializationConfig? config]) {
    return TestOrderJsonSerializer().fromJson(json, config);
  }
}

class TestAccountJsonSerializer implements JsonSerializer<TestAccount> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  TestAccountJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig = defaultConfig ?? const SerializationConfig();

  @override
  Map<String, dynamic> toJson(
    TestAccount instance, [
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
      SerializationUtils.applyFieldRename(
        'accountName',
        effectiveConfig.fieldRename,
      ): instance.accountName,
      SerializationUtils.applyFieldRename(
        'accountType',
        effectiveConfig.fieldRename,
      ): instance.accountType,
      SerializationUtils.applyFieldRename(
        'balance',
        effectiveConfig.fieldRename,
      ): instance.balance,
    };
    return json;
  }

  @override
  TestAccount fromJson(dynamic json, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize TestAccount from null JSON',
        expectedType: 'TestAccount',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'TestAccount',
      );
    }
    try {
      return TestAccount(
        accountName:
            json[SerializationUtils.applyFieldRename(
                  'accountName',
                  effectiveConfig.fieldRename,
                )]
                as String,
        accountType:
            json[SerializationUtils.applyFieldRename(
                  'accountType',
                  effectiveConfig.fieldRename,
                )]
                as String,
        balance:
            (json[SerializationUtils.applyFieldRename(
                  'balance',
                  effectiveConfig.fieldRename,
                )]
                is int
            ? (json[SerializationUtils.applyFieldRename(
                        'balance',
                        effectiveConfig.fieldRename,
                      )]
                      as int)
                  .toDouble()
            : json[SerializationUtils.applyFieldRename(
                    'balance',
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
        'Failed to deserialize TestAccount: $e',
        expectedType: 'TestAccount',
      );
    }
  }

  @override
  String serialize(TestAccount object, [dynamic config]) {
    return jsonEncode(toJson(object, config as SerializationConfig?));
  }

  @override
  TestAccount deserialize(String data, [dynamic config]) {
    final json = jsonDecode(data);
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected JSON object but got ${json.runtimeType}',
        expectedType: 'TestAccount',
      );
    }
    return fromJson(json, config as SerializationConfig?);
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    TestAccount instance, [
    SerializationConfig? config,
  ]) {
    return TestAccountJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static TestAccount decode(dynamic json, [SerializationConfig? config]) {
    return TestAccountJsonSerializer().fromJson(json, config);
  }
}
