import 'dart:convert';
import 'dart:typed_data';

import 'package:dddart/dddart.dart';
import 'package:dddart_repository_sql/src/schema/table_definition.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

/// Abstract interface for database-specific SQL syntax.
///
/// Different SQL databases have variations in syntax, data types,
/// and features. This interface abstracts those differences.
abstract class SqlDialect {
  /// Creates a stateless SQL dialect.
  const SqlDialect();

  /// Exact key storage for supplied UUID identities (e.g., BLOB, VARBINARY).
  String get uuidColumnType;

  /// Exact, variable-length binary storage for canonical identity key bytes.
  String get identityColumnType => uuidColumnType;

  /// Adapter key budget, checked before the server can truncate a value.
  int? get maxIdentityKeyBytes => null;

  /// Encodes a canonical identity key without case folding or Unicode loss.
  Uint8List encodeIdentityKey(String key) {
    final bytes = utf8.encode(key);
    if (utf8.decode(bytes) != key ||
        (maxIdentityKeyBytes != null && bytes.length > maxIdentityKeyBytes!)) {
      throw const RepositoryException(
        'Identity key exceeds the SQL adapter limit or contains malformed Unicode',
        type: RepositoryExceptionType.constraint,
      );
    }
    return Uint8List.fromList(bytes);
  }

  /// Decodes binary keys, or the UTF-8 string projection of the MySQL driver.
  String decodeIdentityKey(Object? value) {
    try {
      final String key;
      if (value is String) {
        key = value;
      } else if (value is List<int> &&
          value.every((byte) => byte >= 0 && byte <= 255)) {
        key = utf8.decode(value);
      } else {
        throw const FormatException('Expected canonical SQL identity bytes');
      }
      encodeIdentityKey(key);
      return key;
    } catch (_) {
      throw const DeserializationException('Invalid stored SQL identity key');
    }
  }

  /// SQL type for text columns (e.g., TEXT, VARCHAR).
  String get textColumnType;

  /// SQL type for integer columns (e.g., INTEGER, BIGINT).
  String get integerColumnType;

  /// SQL type for floating point columns (e.g., REAL, DOUBLE).
  String get realColumnType;

  /// SQL type for boolean columns (e.g., INTEGER, BOOLEAN).
  String get booleanColumnType;

  /// SQL type for DateTime columns (e.g., TEXT, DATETIME).
  ///
  /// Different databases use different native types for datetime:
  /// - SQLite: TEXT (ISO8601 format)
  /// - MySQL: DATETIME (native datetime type)
  /// - PostgreSQL: TIMESTAMP (native timestamp type)
  String get dateTimeColumnType;

  /// Encodes a [UuidValue] to database format.
  Object? encodeUuid(UuidValue uuid);

  /// Decodes a database value to [UuidValue].
  UuidValue decodeUuid(Object? value);

  /// Encodes a [DateTime] to database format.
  Object? encodeDateTime(DateTime dateTime);

  /// Decodes a database value to [DateTime].
  DateTime decodeDateTime(Object? value);

  /// Generates CREATE TABLE IF NOT EXISTS statement.
  String createTableIfNotExists(TableDefinition table);

  /// Generates INSERT OR REPLACE statement.
  String insertOrReplace(String tableName, List<String> columns);

  /// Generates SELECT with JOINs statement.
  String selectWithJoins(
    TableDefinition rootTable,
    List<JoinClause> joins,
  );

  /// Generates DELETE statement.
  String delete(String tableName);
}

/// Represents a JOIN clause in a SQL query.
class JoinClause {
  /// Creates a JOIN clause.
  const JoinClause({
    required this.type,
    required this.table,
    required this.onCondition,
  });

  /// The type of JOIN (INNER, LEFT, RIGHT, etc.).
  final JoinType type;

  /// The table to join.
  final String table;

  /// The ON condition for the join.
  final String onCondition;
}

/// Types of SQL JOINs.
enum JoinType {
  /// INNER JOIN
  inner,

  /// LEFT JOIN
  left,

  /// RIGHT JOIN
  right,

  /// FULL OUTER JOIN
  fullOuter,
}
