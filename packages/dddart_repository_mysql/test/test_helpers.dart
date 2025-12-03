/// Test helpers and utilities for MySQL repository testing.
library;

import 'package:dddart_repository_mysql/dddart_repository_mysql.dart';

/// Helper class for managing test MySQL connections and database cleanup.
///
/// Provides utilities for setting up and tearing down test database
/// connections and tables.
class TestMysqlHelper {
  /// Creates a test MySQL helper.
  TestMysqlHelper({
    this.host = 'localhost',
    this.port = 3307,
    this.database = 'test_db',
    this.user = 'root',
    this.password = 'test_password',
  });

  /// MySQL host.
  final String host;

  /// MySQL port.
  final int port;

  /// Test database name.
  final String database;

  /// MySQL user.
  final String user;

  /// MySQL password.
  final String password;

  MysqlConnection? _connection;

  /// Opens a connection to the test database.
  ///
  /// Returns the connection instance for use in tests.
  /// Retries up to 3 times to handle transient connection issues.
  Future<MysqlConnection> connect() async {
    if (_connection != null && _connection!.isOpen) {
      return _connection!;
    }

    _connection = MysqlConnection(
      host: host,
      port: port,
      database: database,
      user: user,
      password: password,
    );

    // Retry connection up to 3 times to handle transient issues
    Object? lastError;
    StackTrace? lastStackTrace;
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        await _connection!.open();
        return _connection!;
      } catch (e, stackTrace) {
        lastError = e;
        lastStackTrace = stackTrace;
        if (attempt < 3) {
          // Wait a bit before retrying
          await Future<void>.delayed(Duration(milliseconds: 100 * attempt));
        }
      }
    }

    // If all retries failed, rethrow the last error with its stack trace
    Error.throwWithStackTrace(lastError!, lastStackTrace!);
  }

  /// Closes the connection to the test database.
  Future<void> disconnect() async {
    await _connection?.close();
    _connection = null;
  }

  /// Gets the connection instance.
  ///
  /// Throws [StateError] if not connected.
  MysqlConnection get connection {
    if (_connection == null || !_connection!.isOpen) {
      throw StateError('Not connected. Call connect() first.');
    }
    return _connection!;
  }

  /// Checks if connected to the database.
  bool get isConnected => _connection != null && _connection!.isOpen;

  /// Drops all tables in the test database.
  ///
  /// Useful for cleaning up between tests.
  Future<void> dropAllTables() async {
    // Check if connection is still valid, reconnect if needed
    if (_connection == null || !_connection!.isOpen) {
      try {
        await connect();
      } catch (e) {
        // If we can't reconnect, silently return - database might be gone
        return;
      }
    }

    try {
      // Disable foreign key checks temporarily
      await _connection!.execute('SET FOREIGN_KEY_CHECKS = 0');

      try {
        // Get all tables - use uppercase TABLE_NAME as that's what MySQL returns
        final tables = await _connection!.query(
          'SELECT TABLE_NAME FROM information_schema.tables '
          "WHERE table_schema = '$database'",
        );

        // Drop each table
        for (final row in tables) {
          final tableName = row['TABLE_NAME'];
          if (tableName != null) {
            await _connection!.execute('DROP TABLE IF EXISTS `$tableName`');
          }
        }
      } finally {
        // Re-enable foreign key checks
        await _connection!.execute('SET FOREIGN_KEY_CHECKS = 1');
      }
    } catch (e) {
      // Ignore errors during cleanup - connection might be closed
      // This is acceptable in test teardown
    }
  }

  /// Clears all data from a specific table.
  ///
  /// Useful for cleaning up between tests without dropping the schema.
  Future<void> clearTable(String tableName) async {
    if (!isConnected) {
      throw StateError('Not connected. Call connect() first.');
    }

    await _connection!.execute('DELETE FROM `$tableName`');
  }

  /// Checks if a table exists in the database.
  Future<bool> tableExists(String tableName) async {
    if (!isConnected) {
      throw StateError('Not connected. Call connect() first.');
    }

    final result = await _connection!.query(
      'SELECT COUNT(*) as count FROM information_schema.tables '
      "WHERE table_schema = '$database' AND TABLE_NAME = ?",
      [tableName],
    );

    final count = result.first['count']! as int;
    return count > 0;
  }

  /// Counts rows in a table.
  Future<int> countRows(String tableName) async {
    if (!isConnected) {
      throw StateError('Not connected. Call connect() first.');
    }

    final result = await _connection!.query(
      'SELECT COUNT(*) as count FROM `$tableName`',
    );

    return result.first['count']! as int;
  }

  /// Lists all tables in the test database.
  Future<List<String>> listTables() async {
    if (!isConnected) {
      throw StateError('Not connected. Call connect() first.');
    }

    final result = await _connection!.query(
      'SELECT TABLE_NAME FROM information_schema.tables '
      "WHERE table_schema = '$database'",
    );

    return result
        .map((row) => row['TABLE_NAME'])
        .where((name) => name != null)
        .cast<String>()
        .toList();
  }
}

/// Creates a test MySQL helper with default settings.
TestMysqlHelper createTestHelper() {
  return TestMysqlHelper();
}

/// Runs a test with a MySQL connection.
///
/// Automatically connects before the test and disconnects after.
/// Optionally clears specified tables before running the test.
Future<void> withMysqlConnection(
  Future<void> Function(MysqlConnection connection) testFn, {
  List<String> clearTables = const [],
}) async {
  final helper = createTestHelper();
  try {
    final connection = await helper.connect();

    // Clear specified tables
    for (final table in clearTables) {
      try {
        await helper.clearTable(table);
      } catch (e) {
        // Ignore if table doesn't exist
      }
    }

    await testFn(connection);
  } finally {
    // Clean up all tables - ignore any errors during cleanup
    try {
      await helper.dropAllTables();
    } catch (e) {
      // Silently ignore cleanup errors - connection might be closed
    }

    // Disconnect - ignore any errors
    try {
      await helper.disconnect();
    } catch (e) {
      // Silently ignore disconnect errors
    }
  }
}
