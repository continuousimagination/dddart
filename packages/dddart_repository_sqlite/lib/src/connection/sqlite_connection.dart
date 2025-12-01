/// SQLite database connection management.
library;

import 'package:dddart_repository_sql/dddart_repository_sql.dart';
import 'package:sqlite3/sqlite3.dart';

/// SQLite database connection implementation.
///
/// Manages the lifecycle of a SQLite database connection and provides
/// methods for executing queries and transactions.
///
/// Example:
/// ```dart
/// final connection = SqliteConnection.file('database.db');
/// await connection.open();
/// // Use connection
/// await connection.close();
/// ```
class SqliteConnection implements SqlConnection {
  /// Creates a file-based SQLite connection.
  SqliteConnection.file(String path) : _path = path;

  /// Creates an in-memory SQLite connection.
  SqliteConnection.memory() : _path = ':memory:';

  final String _path;
  Database? _database;
  int _transactionDepth = 0;

  @override
  Future<void> open() async {
    if (_database != null) {
      return; // Already open
    }

    _database = sqlite3.open(_path);

    // CRITICAL: Enable foreign key constraints
    // Without this, CASCADE DELETE will not work!
    _database!.execute('PRAGMA foreign_keys = ON');
  }

  @override
  Future<void> close() async {
    if (_database == null) {
      return; // Already closed
    }

    _database!.dispose();
    _database = null;
    _transactionDepth = 0;
  }

  @override
  bool get isOpen => _database != null;

  @override
  Future<void> execute(String sql, [List<Object?>? parameters]) async {
    if (_database == null) {
      throw StateError('Connection is not open. Call open() first.');
    }

    if (parameters == null || parameters.isEmpty) {
      _database!.execute(sql);
    } else {
      final stmt = _database!.prepare(sql);
      try {
        stmt.execute(parameters);
      } finally {
        stmt.dispose();
      }
    }
  }

  @override
  Future<List<Map<String, Object?>>> query(
    String sql, [
    List<Object?>? parameters,
  ]) async {
    if (_database == null) {
      throw StateError('Connection is not open. Call open() first.');
    }

    final stmt = _database!.prepare(sql);
    try {
      final resultSet = parameters == null || parameters.isEmpty
          ? stmt.select()
          : stmt.select(parameters);

      // Convert ResultSet to List<Map<String, Object?>>
      final results = <Map<String, Object?>>[];
      for (final row in resultSet) {
        results.add(row);
      }
      return results;
    } finally {
      stmt.dispose();
    }
  }

  @override
  Future<T> transaction<T>(Future<T> Function() action) async {
    if (_database == null) {
      throw StateError('Connection is not open. Call open() first.');
    }

    // Support nested transactions by tracking depth
    final isOuterTransaction = _transactionDepth == 0;

    if (isOuterTransaction) {
      _database!.execute('BEGIN');
    }

    _transactionDepth++;

    try {
      final result = await action();

      _transactionDepth--;

      if (isOuterTransaction) {
        _database!.execute('COMMIT');
      }

      return result;
    } catch (e) {
      _transactionDepth--;

      if (isOuterTransaction) {
        _database!.execute('ROLLBACK');
      }

      rethrow;
    }
  }
}
