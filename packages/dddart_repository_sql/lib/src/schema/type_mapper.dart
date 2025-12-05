import 'package:dddart_repository_sql/src/dialect/sql_dialect.dart';

/// Maps between Dart types and SQL column types.
///
/// This class provides the mapping logic for converting Dart primitive types
/// to their corresponding SQL column types. The mapping can be database-specific
/// when a SqlDialect is provided, allowing for native database types like
/// DATETIME for MySQL or TEXT for SQLite DateTime fields.
///
/// Type Mapping Table (with dialect):
/// | Dart Type | SQL Type (SQLite) | SQL Type (MySQL) |
/// |-----------|-------------------|------------------|
/// | String    | TEXT              | VARCHAR(255)     |
/// | int       | INTEGER           | BIGINT           |
/// | double    | REAL              | DOUBLE           |
/// | bool      | INTEGER           | TINYINT(1)       |
/// | DateTime  | TEXT              | DATETIME         |
/// | UuidValue | BLOB              | BINARY(16)       |
///
/// Example:
/// ```dart
/// final mapper = TypeMapper();
/// final sqlType = mapper.getSqlType('String', sqliteDialect); // 'TEXT'
/// final isNullable = mapper.isNullable('String?'); // true
/// ```
class TypeMapper {
  /// Creates a type mapper.
  const TypeMapper();

  /// Gets the SQL type for a Dart type using the specified dialect.
  ///
  /// Returns the SQL column type for primitive Dart types, using
  /// database-specific types from the provided [dialect]:
  /// - `String` → dialect.textColumnType
  /// - `int` → dialect.integerColumnType
  /// - `double` → dialect.realColumnType
  /// - `bool` → dialect.booleanColumnType
  /// - `DateTime` → dialect.dateTimeColumnType
  /// - `UuidValue` → dialect.uuidColumnType
  ///
  /// Returns `null` if [dartType] is not a primitive type.
  /// Non-primitive types (custom classes) require special handling:
  /// - Value objects are embedded with prefixed columns
  /// - Entities get foreign key columns
  ///
  /// Example:
  /// ```dart
  /// mapper.getSqlType('String', sqliteDialect); // 'TEXT'
  /// mapper.getSqlType('DateTime', mysqlDialect); // 'DATETIME'
  /// mapper.getSqlType('Order', dialect); // null (not primitive)
  /// ```
  String? getSqlType(String dartType, SqlDialect dialect) {
    switch (dartType) {
      case 'String':
        return dialect.textColumnType;
      case 'int':
        return dialect.integerColumnType;
      case 'double':
        return dialect.realColumnType;
      case 'bool':
        return dialect.booleanColumnType;
      case 'DateTime':
        return dialect.dateTimeColumnType;
      case 'UuidValue':
        return dialect.uuidColumnType;
      default:
        return null; // Not a primitive type
    }
  }

  /// Checks if a type is nullable (ends with ?).
  ///
  /// In Dart, nullable types are denoted with a `?` suffix.
  /// This method detects that suffix to determine nullability.
  ///
  /// Example:
  /// ```dart
  /// mapper.isNullable('String'); // false
  /// mapper.isNullable('String?'); // true
  /// mapper.isNullable('int?'); // true
  /// ```
  ///
  /// Returns `true` if [dartType] ends with `?`.
  bool isNullable(String dartType) {
    return dartType.endsWith('?');
  }

  /// Removes the nullable marker from a type.
  ///
  /// Strips the `?` suffix from nullable type names to get
  /// the base type name.
  ///
  /// Example:
  /// ```dart
  /// mapper.removeNullable('String?'); // 'String'
  /// mapper.removeNullable('int?'); // 'int'
  /// mapper.removeNullable('String'); // 'String' (unchanged)
  /// ```
  ///
  /// Returns the type name without the `?` suffix.
  String removeNullable(String dartType) {
    return dartType.endsWith('?')
        ? dartType.substring(0, dartType.length - 1)
        : dartType;
  }
}
