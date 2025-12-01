import 'package:dddart/dddart.dart';
import 'package:dddart_repository_sql/src/schema/table_definition.dart';

/// Abstract interface for database-specific SQL syntax.
///
/// Different SQL databases have variations in syntax, data types,
/// and features. This interface abstracts those differences.
abstract class SqlDialect {
  /// SQL type for UUID columns (e.g., BLOB, UUID).
  String get uuidColumnType;

  /// SQL type for text columns (e.g., TEXT, VARCHAR).
  String get textColumnType;

  /// SQL type for integer columns (e.g., INTEGER, BIGINT).
  String get integerColumnType;

  /// SQL type for floating point columns (e.g., REAL, DOUBLE).
  String get realColumnType;

  /// SQL type for boolean columns (e.g., INTEGER, BOOLEAN).
  String get booleanColumnType;

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
