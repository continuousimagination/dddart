/// Test helpers and utilities for SQLite repository testing.
library;

import 'package:dddart_repository_sqlite/dddart_repository_sqlite.dart';

/// Helper class for managing test SQLite connections.
class TestSqliteHelper {
  /// Creates a test SQLite helper with in-memory database.
  TestSqliteHelper({this.path = ':memory:'});

  /// Database file path (defaults to in-memory).
  final String path;

  SqliteConnection? _connection;

  /// Opens a connection to the test database.
  SqliteConnection connect() {
    if (_connection != null && _connection!.isOpen) {
      return _connection!;
    }

    _connection = path == ':memory:'
        ? SqliteConnection.memory()
        : SqliteConnection.file(path);
    _connection!.open();
    return _connection!;
  }

  /// Closes the connection to the test database.
  void disconnect() {
    _connection?.close();
    _connection = null;
  }

  /// Gets the connection instance.
  SqliteConnection get connection {
    if (_connection == null || !_connection!.isOpen) {
      throw StateError('Not connected. Call connect() first.');
    }
    return _connection!;
  }

  /// Checks if connected to the database.
  bool get isConnected => _connection != null && _connection!.isOpen;

  /// Clears all rows from a table.
  Future<void> clearTable(String tableName) async {
    if (!isConnected) {
      throw StateError('Not connected. Call connect() first.');
    }
    await _connection!.execute('DELETE FROM $tableName');
  }

  /// Drops a table entirely.
  Future<void> dropTable(String tableName) async {
    if (!isConnected) {
      throw StateError('Not connected. Call connect() first.');
    }
    await _connection!.execute('DROP TABLE IF EXISTS $tableName');
  }

  /// Counts rows in a table.
  Future<int> countRows(String tableName) async {
    if (!isConnected) {
      throw StateError('Not connected. Call connect() first.');
    }
    final result =
        await _connection!.query('SELECT COUNT(*) as count FROM $tableName');
    return result.first['count']! as int;
  }

  /// Checks if a table exists.
  Future<bool> tableExists(String tableName) async {
    if (!isConnected) {
      throw StateError('Not connected. Call connect() first.');
    }
    final result = await _connection!.query(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [tableName],
    );
    return result.isNotEmpty;
  }

  /// Verifies foreign keys are enabled.
  Future<bool> foreignKeysEnabled() async {
    if (!isConnected) {
      throw StateError('Not connected. Call connect() first.');
    }
    final result = await _connection!.query('PRAGMA foreign_keys');
    return result.first['foreign_keys'] == 1;
  }
}

/// Creates a test SQLite helper with default settings (in-memory).
TestSqliteHelper createTestHelper() {
  return TestSqliteHelper();
}
