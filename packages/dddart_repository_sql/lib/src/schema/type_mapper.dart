/// Maps between Dart types and SQL column types.
///
/// This class provides the mapping logic for converting Dart primitive types
/// to their corresponding SQL column types. The mapping is database-agnostic
/// and uses common SQL types.
///
/// Type Mapping Table:
/// | Dart Type | SQL Type | Storage Format |
/// |-----------|----------|----------------|
/// | String    | TEXT     | UTF-8 text     |
/// | int       | INTEGER  | 64-bit integer |
/// | double    | REAL     | 64-bit float   |
/// | bool      | INTEGER  | 0 or 1         |
/// | DateTime  | INTEGER  | Milliseconds since epoch |
/// | UuidValue | BLOB     | 16 bytes       |
///
/// Example:
/// ```dart
/// final mapper = TypeMapper();
/// final sqlType = mapper.getSqlType('String'); // 'TEXT'
/// final isNullable = mapper.isNullable('String?'); // true
/// ```
class TypeMapper {
  /// Creates a type mapper.
  const TypeMapper();

  /// Gets the SQL type for a Dart type.
  ///
  /// Returns the SQL column type for primitive Dart types:
  /// - `String` → `TEXT`
  /// - `int` → `INTEGER`
  /// - `double` → `REAL`
  /// - `bool` → `INTEGER` (stored as 0 or 1)
  /// - `DateTime` → `INTEGER` (milliseconds since epoch)
  /// - `UuidValue` → `BLOB` (16 bytes)
  ///
  /// Returns `null` if [dartType] is not a primitive type.
  /// Non-primitive types (custom classes) require special handling:
  /// - Value objects are embedded with prefixed columns
  /// - Entities get foreign key columns
  ///
  /// Example:
  /// ```dart
  /// mapper.getSqlType('String'); // 'TEXT'
  /// mapper.getSqlType('int'); // 'INTEGER'
  /// mapper.getSqlType('Order'); // null (not primitive)
  /// ```
  String? getSqlType(String dartType) {
    switch (dartType) {
      case 'String':
        return 'TEXT';
      case 'int':
        return 'INTEGER';
      case 'double':
        return 'REAL';
      case 'bool':
        return 'INTEGER'; // 0 or 1
      case 'DateTime':
        return 'INTEGER'; // Milliseconds since epoch
      case 'UuidValue':
        return 'BLOB'; // 16 bytes
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
