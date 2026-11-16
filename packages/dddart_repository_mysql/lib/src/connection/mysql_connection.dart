/// MySQL database connection management.
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dddart/dddart.dart';
import 'package:dddart_repository_sql/dddart_repository_sql.dart';
import 'package:mysql_client/exception.dart';
import 'package:mysql_client/mysql_client.dart';

/// MySQL database connection implementation.
///
/// Manages the lifecycle of one MySQL database connection and provides methods
/// for executing queries and transactions.
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
    @Deprecated(
      'maxConnections is ignored because MysqlConnection uses one connection. '
      'It will be removed in the next breaking release.',
    )
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

  /// Legacy no-op retained for source compatibility.
  ///
  /// [MysqlConnection] always opens one connection. Pooling, if added in the
  /// future, will use a separate abstraction with explicit lifecycle rules.
  @Deprecated(
    'maxConnections is ignored because MysqlConnection uses one connection. '
    'It will be removed in the next breaking release.',
  )
  final int maxConnections;

  /// Connection timeout duration.
  final Duration timeout;

  MySQLConnection? _connection;
  final _coordinator = SqlConnectionCoordinator();

  @override
  Future<void> open() async {
    _coordinator.requireOutsideTransaction();
    await _coordinator.run(_open);
  }

  Future<void> _open() async {
    if (_connection != null) {
      return; // Already open
    }

    try {
      _connection = await MySQLConnection.createConnection(
        host: host,
        port: port,
        userName: user,
        password: password,
        databaseName: database,
      );

      await _connection!.connect(timeoutMs: timeout.inMilliseconds);
    } catch (e) {
      await _close();
      throw _mapMysqlException(e, 'open connection');
    }
  }

  @override
  Future<void> close() async {
    _coordinator.requireOutsideTransaction();
    await _coordinator.run(_close);
  }

  Future<void> _close() async {
    if (_connection == null) {
      return; // Already closed
    }

    try {
      await _connection!.close();
    } catch (e) {
      // Ignore errors when closing - connection might already be closed
      // This can happen if the connection was closed due to an error
    } finally {
      _connection = null;
    }
  }

  @override
  bool get isOpen => _connection != null;

  @override
  Future<void> execute(String sql, [List<Object?>? parameters]) =>
      _coordinator.run(() => _execute(sql, parameters));

  Future<void> _execute(String sql, [List<Object?>? parameters]) async {
    if (_connection == null) {
      throw StateError('Connection is not open. Call open() first.');
    }

    try {
      if (parameters == null || parameters.isEmpty) {
        await _connection!.execute(sql);
      } else {
        // Convert List parameters to Map for mysql_client
        final (convertedSql, params) = _convertParametersToMap(sql, parameters);
        await _connection!.execute(convertedSql, params);
      }
    } catch (e) {
      throw _mapMysqlException(e, 'execute');
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
    if (_connection == null) {
      throw StateError('Connection is not open. Call open() first.');
    }

    try {
      final IResultSet result;
      if (parameters == null || parameters.isEmpty) {
        result = await _connection!.execute(sql);
      } else {
        // Convert List parameters to Map for mysql_client
        final (convertedSql, params) = _convertParametersToMap(sql, parameters);
        result = await _connection!.execute(convertedSql, params);
      }

      // The driver exposes values as strings. Convert only columns whose
      // database metadata is numeric; native string/binary IDs stay exact.
      final resultList = <Map<String, Object?>>[];

      for (final row in result.rows) {
        final rowMap = <String, Object?>{};
        for (final column in result.cols) {
          Object? value = row.colByName(column.name);

          if (value is String) {
            final type = column.type.getBestMatchDartType(column.length);
            if (type == int || type == bool) {
              value = int.parse(value);
            } else if (type == double) {
              value = double.parse(value);
            }
          }

          rowMap[column.name] = value;
        }
        resultList.add(rowMap);
      }

      return resultList;
    } catch (e) {
      throw _mapMysqlException(e, 'query');
    }
  }

  @override
  Future<T> transaction<T>(Future<T> Function() action) =>
      _coordinator.transaction(
        action: action,
        begin: () => _execute('START TRANSACTION'),
        commit: () => _execute('COMMIT'),
        rollback: () => _execute('ROLLBACK'),
        invalidate: _close,
      );

  /// Converts List-based parameters to Map-based parameters for mysql_client.
  ///
  /// mysql_client uses named parameters with :name syntax, but we need to
  /// support positional parameters with ? syntax for backward compatibility.
  /// This method replaces ? placeholders with :p0, :p1, etc. and creates
  /// a corresponding parameter map.
  ///
  /// Special handling for binary data: mysql_client doesn't handle Uint8List
  /// correctly in named parameters, so we inline binary data using UNHEX().
  (String, Map<String, dynamic>) _convertParametersToMap(
    String sql,
    List<Object?> parameters,
  ) {
    final params = <String, dynamic>{};
    var paramIndex = 0;
    final convertedSql = sql.replaceAllMapped(RegExp(r'\?'), (match) {
      final paramValue = parameters[paramIndex];
      paramIndex++;

      // mysql_client doesn't handle binary data (Uint8List/List<int>) correctly
      // in named parameters. Inline binary data using UNHEX() function.
      if (paramValue is Uint8List || paramValue is List<int>) {
        final bytes = paramValue is Uint8List
            ? paramValue
            : Uint8List.fromList(paramValue! as List<int>);
        // Inline as UNHEX('hexstring') instead of using a parameter
        final hexString =
            bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
        return "UNHEX('$hexString')";
      }

      // For non-binary data, use named parameter
      final paramName = 'p${params.length}';
      params[paramName] = paramValue;
      return ':$paramName';
    });
    return (convertedSql, params);
  }

  /// Maps MySQL exceptions to RepositoryException with appropriate types.
  RepositoryException _mapMysqlException(Object error, String operation) {
    if (error is MySQLServerException) {
      // Check error number for specific error types
      final errorCode = error.errorCode;
      switch (errorCode) {
        case 1062: // Duplicate entry
          return RepositoryException(
            'Duplicate key error during $operation: ${error.message}',
            type: RepositoryExceptionType.duplicate,
            cause: error,
          );
        case 2003: // Connection refused
        case 1045: // Access denied
        case 1049: // Unknown database
          return RepositoryException(
            'Connection error during $operation to '
            '$host:$port/$database: ${error.message}',
            type: RepositoryExceptionType.connection,
            cause: error,
          );
        case 1205: // Lock wait timeout
        case 3024: // Query timeout
          return RepositoryException(
            'Timeout during $operation: ${error.message}',
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

    // Handle MySQLClientException
    if (error is MySQLClientException) {
      return RepositoryException(
        'Connection error during $operation to '
        '$host:$port/$database: ${error.message}',
        type: RepositoryExceptionType.connection,
        cause: error,
      );
    }

    // Handle SocketException
    if (error is SocketException) {
      return RepositoryException(
        'Connection error during $operation to $host:$port/$database: ${error.message}',
        type: RepositoryExceptionType.connection,
        cause: error,
      );
    }

    // Handle TimeoutException from dart:async
    if (error.runtimeType.toString() == 'TimeoutException') {
      return RepositoryException(
        'Timeout during $operation after ${timeout.inSeconds}s',
        type: RepositoryExceptionType.timeout,
        cause: error,
      );
    }

    // Handle StateError
    if (error is StateError) {
      return RepositoryException(
        'Invalid connection state during $operation: ${error.message}',
        type: RepositoryExceptionType.connection,
        cause: error,
      );
    }

    // Handle other connection-related errors by string matching
    final errorString = error.toString().toLowerCase();
    if (errorString.contains('socket') ||
        errorString.contains('connection') ||
        errorString.contains('host lookup') ||
        errorString.contains('refused') ||
        errorString.contains('access denied')) {
      return RepositoryException(
        'Connection error during $operation to $host:$port/$database: $error',
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
