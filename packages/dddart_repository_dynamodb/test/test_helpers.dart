/// Test helpers and utilities for DynamoDB repository testing.
library;

import 'package:aws_dynamodb_api/dynamodb-2012-08-10.dart';
import 'package:dddart_repository_dynamodb/dddart_repository_dynamodb.dart';

/// Helper class for managing test DynamoDB connections.
///
/// Provides utilities for setting up and tearing down test database
/// connections and tables for DynamoDB Local.
class TestDynamoHelper {
  /// Creates a test DynamoDB helper.
  TestDynamoHelper({
    this.host = 'localhost',
    this.port = 8000,
    this.region = 'us-east-1',
  });

  /// DynamoDB Local host.
  final String host;

  /// DynamoDB Local port.
  final int port;

  /// AWS region (for DynamoDB Local, this is arbitrary).
  final String region;

  DynamoConnection? _connection;

  /// Creates a connection to DynamoDB Local.
  ///
  /// Returns the connection instance for use in tests.
  DynamoConnection connect() {
    if (_connection != null) {
      return _connection!;
    }

    _connection = DynamoConnection.local(port: port);
    return _connection!;
  }

  /// Disposes the connection to DynamoDB Local.
  void disconnect() {
    _connection?.dispose();
    _connection = null;
  }

  /// Gets the connection instance.
  ///
  /// Throws [StateError] if not connected.
  DynamoConnection get connection {
    if (_connection == null) {
      throw StateError('Not connected. Call connect() first.');
    }
    return _connection!;
  }

  /// Checks if connected to DynamoDB.
  bool get isConnected => _connection != null;

  /// Creates a table with the specified name.
  ///
  /// Uses the standard schema with 'id' as the partition key.
  Future<void> createTable(String tableName) async {
    if (!isConnected) {
      throw StateError('Not connected. Call connect() first.');
    }

    try {
      await _connection!.client.createTable(
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

      // Wait for table to become active
      await _waitForTableActive(tableName);
    } catch (e) {
      // Ignore if table already exists
      if (!e.toString().contains('ResourceInUseException')) {
        rethrow;
      }
    }
  }

  /// Deletes a table.
  ///
  /// Useful for cleanup after tests.
  Future<void> deleteTable(String tableName) async {
    if (!isConnected) {
      throw StateError('Not connected. Call connect() first.');
    }

    try {
      await _connection!.client.deleteTable(tableName: tableName);
      
      // Wait for table to be deleted
      await _waitForTableDeleted(tableName);
    } catch (e) {
      // Ignore if table doesn't exist
      if (!e.toString().contains('ResourceNotFoundException')) {
        rethrow;
      }
    }
  }

  /// Clears all items from a table.
  ///
  /// Scans the table and deletes all items.
  Future<void> clearTable(String tableName) async {
    if (!isConnected) {
      throw StateError('Not connected. Call connect() first.');
    }

    try {
      // Scan all items
      final result = await _connection!.client.scan(tableName: tableName);
      
      if (result.items == null || result.items!.isEmpty) {
        return;
      }

      // Delete each item
      for (final item in result.items!) {
        final id = item['id'];
        if (id != null) {
          await _connection!.client.deleteItem(
            tableName: tableName,
            key: {'id': id},
          );
        }
      }
    } catch (e) {
      // Ignore if table doesn't exist
      if (!e.toString().contains('ResourceNotFoundException')) {
        rethrow;
      }
    }
  }

  /// Lists all tables in DynamoDB Local.
  Future<List<String>> listTables() async {
    if (!isConnected) {
      throw StateError('Not connected. Call connect() first.');
    }

    final result = await _connection!.client.listTables();
    return result.tableNames ?? [];
  }

  /// Checks if a table exists.
  Future<bool> tableExists(String tableName) async {
    if (!isConnected) {
      throw StateError('Not connected. Call connect() first.');
    }

    try {
      await _connection!.client.describeTable(tableName: tableName);
      return true;
    } catch (e) {
      if (e.toString().contains('ResourceNotFoundException')) {
        return false;
      }
      rethrow;
    }
  }

  /// Counts items in a table.
  Future<int> countItems(String tableName) async {
    if (!isConnected) {
      throw StateError('Not connected. Call connect() first.');
    }

    final result = await _connection!.client.scan(
      tableName: tableName,
      select: Select.count,
    );
    
    return result.count ?? 0;
  }

  /// Gets an item by ID directly from DynamoDB.
  ///
  /// Useful for verifying test results.
  Future<Map<String, AttributeValue>?> getItemById(
    String tableName,
    String id,
  ) async {
    if (!isConnected) {
      throw StateError('Not connected. Call connect() first.');
    }

    final result = await _connection!.client.getItem(
      tableName: tableName,
      key: {
        'id': AttributeValue(s: id),
      },
    );

    return result.item;
  }

  /// Waits for a table to become active.
  Future<void> _waitForTableActive(String tableName) async {
    const maxAttempts = 30;
    const delayMs = 100;

    for (var i = 0; i < maxAttempts; i++) {
      try {
        final result = await _connection!.client.describeTable(
          tableName: tableName,
        );
        
        if (result.table?.tableStatus == TableStatus.active) {
          return;
        }
      } catch (e) {
        // Continue waiting
      }

      await Future<void>.delayed(const Duration(milliseconds: delayMs));
    }

    throw StateError('Table $tableName did not become active in time');
  }

  /// Waits for a table to be deleted.
  Future<void> _waitForTableDeleted(String tableName) async {
    const maxAttempts = 30;
    const delayMs = 100;

    for (var i = 0; i < maxAttempts; i++) {
      try {
        await _connection!.client.describeTable(tableName: tableName);
      } catch (e) {
        if (e.toString().contains('ResourceNotFoundException')) {
          return;
        }
      }

      await Future<void>.delayed(const Duration(milliseconds: delayMs));
    }

    throw StateError('Table $tableName was not deleted in time');
  }
}

/// Creates a test DynamoDB helper with default settings.
TestDynamoHelper createTestHelper() {
  return TestDynamoHelper();
}

/// Runs a test with a DynamoDB Local connection.
///
/// Automatically connects before the test and disconnects after.
/// Optionally creates and clears specified tables before running the test.
Future<void> withDynamoConnection(
  Future<void> Function(DynamoConnection connection) testFn, {
  List<String> createTables = const [],
  List<String> clearTables = const [],
}) async {
  final helper = createTestHelper();
  try {
    final connection = helper.connect();

    // Create specified tables
    for (final table in createTables) {
      await helper.createTable(table);
    }

    // Clear specified tables
    for (final table in clearTables) {
      await helper.clearTable(table);
    }

    await testFn(connection);
  } finally {
    helper.disconnect();
  }
}

/// Runs a test with table setup and cleanup.
///
/// Creates tables before the test and deletes them after.
Future<void> withTestTables(
  List<String> tableNames,
  Future<void> Function(DynamoConnection connection) testFn,
) async {
  final helper = createTestHelper();
  try {
    final connection = helper.connect();

    // Create tables
    for (final table in tableNames) {
      await helper.createTable(table);
    }

    await testFn(connection);
  } finally {
    // Clean up tables
    for (final table in tableNames) {
      try {
        await helper.deleteTable(table);
      } catch (e) {
        // Ignore cleanup errors
      }
    }
    helper.disconnect();
  }
}
