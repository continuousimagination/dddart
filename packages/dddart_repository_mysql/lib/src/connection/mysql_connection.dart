/// MySQL database connection management.
library;

import 'package:dddart/dddart.dart';
import 'package:dddart_repository_sql/dddart_repository_sql.dart';
import 'package:mysql1/mysql1.dart';

/// MySQL database connection implementation.
///
/// Manages the lifecycle of a MySQL database connection pool and provides
/// methods for executing queries and transactions.
///
/// Example:
/// ```dart
/// final connection = MysqlConnection(
///   host: 'localhost',
///   port: 3306,
///   database: 'myapp',
///   user: 'root',
///   password: 'password',
/// );
/// await connection.open();
/// // Use connection
/// await connection.close();
/// ```
class MysqlConnection implements SqlConnection {
  /// Creates a MySQL connection with the specified configuration.
  MysqlConnection({
    required this.host,
    required this.port,
    required this.database,
    required this.user,
    required this.password,
    this.maxConnections = 5,
    this.timeout = const Duration(seconds: 30),
  });

  /// MySQL server host.
  final String host;

  /// MySQL server port.
  final int port;

  /// Database name.
  final String database;

  /// Database user.
  final String user;

  /// Database password.
  final String password;

  /// Maximum number of connections in the pool.
  final int maxConnections;

  /// Connection timeout duration.
  final Duration timeout;

  MySqlConnection? _pool;
  int _transactionDepth = 0;

  @override
  Future<void> open() async {
    if (_pool != null) {
      return; // Already open
    }

    try {
      final settings = ConnectionSettings(
        host: host,
        port: port,
        user: user,
        password: password,
        db: database,
        timeout: timeout,
      );

      _pool = await MySqlConnection.connect(settings);
    } catch (e) {
      throw _mapMysqlException(e, 'open connection');
    }
  }

  @override
  Future<void> close() async {
    if (_pool == null) {
      return; // Already closed
    }

    await _pool!.close();
    _pool = null;
    _transactionDepth = 0;
  }

  @override
  bool get isOpen => _pool != null;

  @override
  Future<void> execute(String sql, [List<Object?>? parameters]) async {
    if (_pool == null) {
      throw StateError('Connection is not open. Call open() first.');
    }

    try {
      if (parameters == null || parameters.isEmpty) {
        await _pool!.query(sql);
      } else {
        await _pool!.query(sql, parameters);
      }
    } catch (e) {
      throw _mapMysqlException(e, 'execute');
    }
  }

  @override
  Future<List<Map<String, Object?>>> query(
    String sql, [
    List<Object?>? parameters,
  ]) async {
    if (_pool == null) {
      throw StateError('Connection is not open. Call open() first.');
    }

    try {
      final Results results;
      if (parameters == null || parameters.isEmpty) {
        results = await _pool!.query(sql);
      } else {
        results = await _pool!.query(sql, parameters);
      }

      // Convert Results to List<Map<String, Object?>>
      final resultList = <Map<String, Object?>>[];
      for (final row in results) {
        final rowMap = <String, Object?>{};
        for (var i = 0; i < results.fields.length; i++) {
          final fieldName = results.fields[i].name;
          if (fieldName != null) {
            rowMap[fieldName] = row[i];
          }
        }
        resultList.add(rowMap);
      }
      return resultList;
    } catch (e) {
      throw _mapMysqlException(e, 'query');
    }
  }

  @override
  Future<T> transaction<T>(Future<T> Function() action) async {
    if (_pool == null) {
      throw StateError('Connection is not open. Call open() first.');
    }

    // Support nested transactions by tracking depth
    final isOuterTransaction = _transactionDepth == 0;

    if (isOuterTransaction) {
      await _pool!.query('START TRANSACTION');
    }

    _transactionDepth++;

    try {
      final result = await action();

      _transactionDepth--;

      if (isOuterTransaction) {
        await _pool!.query('COMMIT');
      }

      return result;
    } catch (e) {
      _transactionDepth--;

      if (isOuterTransaction) {
        await _pool!.query('ROLLBACK');
      }

      rethrow;
    }
  }

  /// Maps MySQL exceptions to RepositoryException with appropriate types.
  RepositoryException _mapMysqlException(Object error, String operation) {
    if (error is MySqlException) {
      // Check error number for specific error types
      switch (error.errorNumber) {
        case 1062: // Duplicate entry
          return RepositoryException(
            'Duplicate key error during $operation',
            type: RepositoryExceptionType.duplicate,
            cause: error,
          );
        case 2003: // Connection refused
        case 1045: // Access denied
        case 1049: // Unknown database
          return RepositoryException(
            'Connection error during $operation: ${error.message}',
            type: RepositoryExceptionType.connection,
            cause: error,
          );
        case 1205: // Lock wait timeout
        case 3024: // Query timeout
          return RepositoryException(
            'Timeout during $operation',
            type: RepositoryExceptionType.timeout,
            cause: error,
          );
        default:
          return RepositoryException(
            'MySQL error during $operation: ${error.message}',
            cause: error,
          );
      }
    }

    // Handle connection-related errors
    // (SocketException, TimeoutException, etc.)
    final errorString = error.toString().toLowerCase();
    if (errorString.contains('socket') ||
        errorString.contains('connection') ||
        errorString.contains('host lookup') ||
        errorString.contains('refused') ||
        errorString.contains('access denied')) {
      return RepositoryException(
        'Connection error during $operation: $error',
        type: RepositoryExceptionType.connection,
        cause: error,
      );
    }

    if (errorString.contains('timeout')) {
      return RepositoryException(
        'Timeout during $operation: $error',
        type: RepositoryExceptionType.timeout,
        cause: error,
      );
    }

    return RepositoryException(
      'Unknown error during $operation: $error',
      cause: error,
    );
  }
}
