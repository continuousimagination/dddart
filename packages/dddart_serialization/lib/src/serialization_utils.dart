import 'package:dddart_serialization/dddart_serialization.dart';

/// Utility functions for serialization.
class SerializationUtils {
  /// Applies field renaming strategy to a field name.
  static String applyFieldRename(String fieldName, FieldRename strategy) {
    switch (strategy) {
      case FieldRename.none:
        return fieldName;
      case FieldRename.snake:
        return _toSnakeCase(fieldName);
      case FieldRename.kebab:
        return _toKebabCase(fieldName);
    }
  }

  /// Converts a camelCase string to snake_case.
  static String _toSnakeCase(String input) {
    if (input.isEmpty) return input;

    return input
        .replaceAllMapped(
          RegExp('[A-Z]'),
          (match) => '_${match.group(0)!.toLowerCase()}',
        )
        .replaceFirst(RegExp('^_'), ''); // Remove leading underscore if present
  }

  /// Converts a camelCase string to kebab-case.
  static String _toKebabCase(String input) {
    if (input.isEmpty) return input;

    return input
        .replaceAllMapped(
          RegExp('[A-Z]'),
          (match) => '-${match.group(0)!.toLowerCase()}',
        )
        .replaceFirst(RegExp('^-'), ''); // Remove leading dash if present
  }

  /// Validates that a value is not null.
  static T validateNotNull<T>(T? value, String fieldName, String typeName) {
    if (value == null) {
      throw DeserializationException(
        'Required field "$fieldName" is null',
        expectedType: typeName,
        field: fieldName,
      );
    }
    return value;
  }

  /// Validates that a value is of the expected type.
  static T validateType<T>(dynamic value, String fieldName, String typeName) {
    if (value is! T) {
      throw DeserializationException(
        'Field "$fieldName" expected type $T but got ${value.runtimeType}',
        expectedType: typeName,
        field: fieldName,
      );
    }
    return value;
  }
}
