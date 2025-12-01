import 'package:dddart_repository_sql/src/dialect/sql_dialect.dart';
import 'package:dddart_repository_sql/src/schema/table_definition.dart';

/// Generates SQL schema (DDL) from table definitions.
///
/// This class is responsible for converting [TableDefinition] objects
/// into SQL CREATE TABLE statements using a specific [SqlDialect].
///
/// Example:
/// ```dart
/// final generator = SchemaGenerator(SqliteDialect());
/// final sql = generator.generateCreateTable(tableDefinition);
/// // CREATE TABLE IF NOT EXISTS orders (
/// //   id BLOB PRIMARY KEY NOT NULL,
/// //   ...
/// // )
/// ```
class SchemaGenerator {
  /// Creates a schema generator with the specified dialect.
  ///
  /// The [dialect] determines the SQL syntax and data types used
  /// in the generated DDL statements.
  const SchemaGenerator(this.dialect);

  /// The SQL dialect to use for generation.
  final SqlDialect dialect;

  /// Generates CREATE TABLE statement for a table definition.
  ///
  /// The generated statement includes:
  /// - All column definitions with types and constraints
  /// - Primary key constraints
  /// - Foreign key constraints with cascade actions
  /// - Uses CREATE TABLE IF NOT EXISTS for idempotency
  ///
  /// Example:
  /// ```dart
  /// final sql = generator.generateCreateTable(orderTable);
  /// await connection.execute(sql);
  /// ```
  String generateCreateTable(TableDefinition table) {
    return dialect.createTableIfNotExists(table);
  }

  /// Generates column definition SQL.
  ///
  /// Produces a column definition string like:
  /// - `id BLOB PRIMARY KEY NOT NULL`
  /// - `name TEXT NOT NULL`
  /// - `description TEXT` (nullable)
  ///
  /// The format includes:
  /// - Column name
  /// - SQL type
  /// - PRIMARY KEY constraint (if applicable)
  /// - NOT NULL constraint (if not nullable)
  String generateColumnDefinition(ColumnDefinition column) {
    final buffer = StringBuffer();
    buffer.write(column.name);
    buffer.write(' ');
    buffer.write(column.sqlType);

    if (column.isPrimaryKey) {
      buffer.write(' PRIMARY KEY');
    }

    if (!column.isNullable) {
      buffer.write(' NOT NULL');
    }

    return buffer.toString();
  }

  /// Checks if a Dart type is a primitive type.
  ///
  /// Primitive types are mapped directly to SQL column types:
  /// - `String` → TEXT
  /// - `int` → INTEGER
  /// - `double` → REAL
  /// - `bool` → INTEGER (0/1)
  /// - `DateTime` → INTEGER (milliseconds)
  /// - `UuidValue` → BLOB
  ///
  /// Non-primitive types (custom classes) require foreign keys
  /// or embedding (for value objects).
  ///
  /// Returns `true` if [dartType] is a primitive type.
  bool isPrimitiveType(String dartType) {
    const primitiveTypes = {
      'String',
      'int',
      'double',
      'bool',
      'DateTime',
      'UuidValue',
    };
    return primitiveTypes.contains(dartType);
  }
}
