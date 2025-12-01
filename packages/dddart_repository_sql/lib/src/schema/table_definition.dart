import 'package:dddart_repository_sql/src/dialect/sql_dialect.dart';

/// Represents a SQL table definition for a class.
class TableDefinition {
  /// Creates a table definition.
  const TableDefinition({
    required this.tableName,
    required this.className,
    required this.columns,
    required this.foreignKeys,
    required this.isAggregateRoot,
  });

  /// The SQL table name.
  final String tableName;

  /// The Dart class name.
  final String className;

  /// The columns in the table.
  final List<ColumnDefinition> columns;

  /// The foreign key constraints.
  final List<ForeignKeyDefinition> foreignKeys;

  /// Whether this table represents an aggregate root.
  final bool isAggregateRoot;

  /// Generates CREATE TABLE SQL statement.
  String toCreateTableSql(SqlDialect dialect) {
    return dialect.createTableIfNotExists(this);
  }
}

/// Represents a column definition in a SQL table.
class ColumnDefinition {
  /// Creates a column definition.
  const ColumnDefinition({
    required this.name,
    required this.sqlType,
    required this.dartType,
    required this.isNullable,
    required this.isPrimaryKey,
    required this.isForeignKey,
  });

  /// The column name.
  final String name;

  /// The SQL type (e.g., TEXT, INTEGER, BLOB).
  final String sqlType;

  /// The Dart type (e.g., String, int, UuidValue).
  final String dartType;

  /// Whether the column allows NULL values.
  final bool isNullable;

  /// Whether this is a primary key column.
  final bool isPrimaryKey;

  /// Whether this is a foreign key column.
  final bool isForeignKey;
}

/// Represents a foreign key constraint.
class ForeignKeyDefinition {
  /// Creates a foreign key definition.
  const ForeignKeyDefinition({
    required this.columnName,
    required this.referencedTable,
    required this.referencedColumn,
    required this.onDelete,
  });

  /// The column name in this table.
  final String columnName;

  /// The referenced table name.
  final String referencedTable;

  /// The referenced column name.
  final String referencedColumn;

  /// The cascade action on delete.
  final CascadeAction onDelete;
}

/// Cascade actions for foreign key constraints.
enum CascadeAction {
  /// DELETE CASCADE - delete child rows when parent is deleted.
  cascade,

  /// SET NULL - set child foreign key to NULL when parent is deleted.
  setNull,

  /// RESTRICT - prevent deletion of parent if children exist.
  restrict,
}
