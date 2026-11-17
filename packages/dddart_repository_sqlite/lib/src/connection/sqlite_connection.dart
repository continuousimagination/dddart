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
  final _coordinator = SqlConnectionCoordinator();

  @override
  Future<void> open() async {
    _coordinator.requireOutsideTransaction();
    await _coordinator.run(_open);
  }

  Future<void> _open() async {
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
    _coordinator.requireOutsideTransaction();
    await _coordinator.run(_close);
  }

  Future<void> _close() async {
    if (_database == null) {
      return; // Already closed
    }

    final database = _database!;
    _database = null;
    database.dispose();
  }

  @override
  bool get isOpen => _database != null;

  @override
  Future<void> execute(String sql, [List<Object?>? parameters]) =>
      _coordinator.run(() => _execute(sql, parameters));

  Future<void> _execute(String sql, [List<Object?>? parameters]) async {
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
  ]) =>
      _coordinator.run(() => _query(sql, parameters));

  Future<List<Map<String, Object?>>> _query(
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

  Future<void> _begin() async {
    // Never block the Dart isolate while another connection needs to commit.
    // Only lock acquisition is retried; user work and COMMIT are never replayed.
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (true) {
      try {
        await _execute('BEGIN IMMEDIATE');
        return;
      } on SqliteException catch (error) {
        if (error.resultCode != 5 || DateTime.now().isAfter(deadline)) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    }
  }

  /// Runs publication after the outer commit, discarding it on rollback.
  Future<void> afterCommit(Future<void> Function() action) =>
      _coordinator.afterCommit(action);

  /// Conditional writes must own their commit to report a confirmed revision.
  void requireStandaloneTransaction() =>
      _coordinator.requireOutsideTransaction();

  @override
  Future<T> transaction<T>(Future<T> Function() action) =>
      _coordinator.transaction(
        action: action,
        begin: _begin,
        commit: () => _execute('COMMIT'),
        rollback: () => _execute('ROLLBACK'),
        invalidate: _close,
      );
}
