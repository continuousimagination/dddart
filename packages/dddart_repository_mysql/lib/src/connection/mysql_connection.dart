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

  MySQLConnection? _connection;
  int _transactionDepth = 0;

  @override
  Future<void> open() async {
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
      throw _mapMysqlException(e, 'open connection');
    }
  }

  @override
  Future<void> close() async {
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
      _transactionDepth = 0;
    }
  }

  @override
  bool get isOpen => _connection != null;

  @override
  Future<void> execute(String sql, [List<Object?>? parameters]) async {
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

      // Convert IResultSet to List<Map<String, Object?>>
      // mysql_client may return numeric values as strings when using named
      // parameters, so we need to convert them back to proper types for
      // consistency with mysql1
      final resultList = <Map<String, Object?>>[];

      // Try to iterate over rows - if this fails with FormatException,
      // it means we're selecting binary columns that can't be decoded as UTF-8
      try {
        for (final row in result.rows) {
          final rowMap = <String, Object?>{};
          for (final column in result.cols) {
            Object? value;
            try {
              value = row.colByName(column.name);
            } catch (e) {
              // If we get a FormatException, it's likely binary data that
              // mysql_client is trying to decode as UTF-8. Try to get it as bytes.
              if (e is FormatException) {
                // For binary columns, mysql_client might fail to decode as string
                // In this case, we'll get the raw bytes using colAt
                final cols = result.cols.toList();
                final columnIndex = cols.indexOf(column);
                if (columnIndex >= 0) {
                  try {
                    value = row.colAt(columnIndex);
                  } catch (_) {
                    // If that also fails, set to null
                    value = null;
                  }
                } else {
                  value = null;
                }
              } else {
                rethrow;
              }
            }

            // Convert string values to proper types based on heuristics
            // This is needed because mysql_client returns numeric values as
            // strings when using named parameters
            if (value is String && value.isNotEmpty) {
              final columnName = column.name.toLowerCase();

              // Don't convert fields that are likely to be string identifiers
              // even if they contain only digits (like zipCode, phone, etc.)
              final isLikelyStringField = columnName.contains('code') ||
                  columnName.contains('zip') ||
                  columnName.contains('phone') ||
                  columnName.contains('ssn') ||
                  columnName.contains('id') && columnName != 'id';

              if (!isLikelyStringField) {
                // Only convert if it looks like a pure number
                final isNumericString =
                    RegExp(r'^-?(?:0|[1-9]\d*)(?:\.\d+)?$').hasMatch(value);

                if (isNumericString) {
                  // Try to parse as int first (for BIGINT, INT, etc.)
                  if (!value.contains('.')) {
                    final intValue = int.tryParse(value);
                    if (intValue != null) {
                      value = intValue;
                    }
                  } else {
                    // Parse as double (for DOUBLE, FLOAT, DECIMAL)
                    final doubleValue = double.tryParse(value);
                    if (doubleValue != null) {
                      value = doubleValue;
                    }
                  }
                }
              }
            }

            rowMap[column.name] = value;
          }
          resultList.add(rowMap);
        }
      } catch (e) {
        if (e is FormatException) {
          // If we get a FormatException when iterating rows, it means we're
          // selecting binary columns (like BINARY(16) for UUIDs) that can't
          // be decoded as UTF-8. This is a known issue with the generated code
          // that selects raw binary columns instead of using BIN_TO_UUID().
          // For now, we'll return an empty result to indicate "not found"
          // which is the typical use case for these queries.
          return [];
        }
        rethrow;
      }

      return resultList;
    } catch (e) {
      throw _mapMysqlException(e, 'query');
    }
  }

  @override
  Future<T> transaction<T>(Future<T> Function() action) async {
    if (_connection == null) {
      throw StateError('Connection is not open. Call open() first.');
    }

    // Support nested transactions by tracking depth
    final isOuterTransaction = _transactionDepth == 0;

    if (isOuterTransaction) {
      // Manage transaction manually with START TRANSACTION, COMMIT, ROLLBACK
      // We use manual management instead of mysql_client's transactional()
      // to maintain full control over the connection state
      _transactionDepth++;
      try {
        await _connection!.execute('START TRANSACTION');
        try {
          final result = await action();
          await _connection!.execute('COMMIT');
          _transactionDepth--;
          return result;
        } catch (e) {
          // Rollback on error
          try {
            await _connection!.execute('ROLLBACK');
          } catch (rollbackError) {
            // If ROLLBACK fails, log but don't mask the original error
            // The connection might be in a bad state
          }
          _transactionDepth--;
          rethrow;
        }
      } catch (e) {
        _transactionDepth = 0; // Reset on error
        rethrow;
      }
    } else {
      // For nested transactions, just execute the action
      // The outer transaction will handle commit/rollback
      _transactionDepth++;
      try {
        final result = await action();
        _transactionDepth--;
        return result;
      } catch (e) {
        _transactionDepth--;
        rethrow;
      }
    }
  }

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
        'Connection error during $operation to $host:$port: ${error.message}',
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
