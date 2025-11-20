/// Exception hierarchy for configuration errors.
library;

/// Base exception for all configuration-related errors.
///
/// All configuration exceptions extend this base class to provide
/// consistent error handling across the configuration system.
class ConfigException implements Exception {
  /// Creates a configuration exception with a descriptive message.
  ///
  /// The [message] describes what went wrong.
  /// The optional [key] identifies which configuration key caused the error.
  ConfigException(this.message, {this.key});

  /// Descriptive error message.
  final String message;

  /// The configuration key that caused the error, if applicable.
  final String? key;

  @override
  String toString() {
    if (key != null) {
      return 'ConfigException: $message (key: $key)';
    }
    return 'ConfigException: $message';
  }
}

/// Thrown when a required configuration key is missing or null.
///
/// This exception indicates that the application attempted to access
/// a required configuration value that does not exist or is explicitly null.
///
/// Example:
/// ```dart
/// throw MissingConfigException('database.host');
/// // Output: Required configuration key not found (key: database.host)
/// ```
class MissingConfigException extends ConfigException {
  /// Creates an exception for a missing required configuration key.
  ///
  /// The [key] parameter identifies which configuration key was not found.
  MissingConfigException(String key)
      : super('Required configuration key not found', key: key);
}

/// Thrown when a configuration value cannot be converted to the requested type.
///
/// This exception occurs when type conversion fails, such as attempting
/// to parse a non-numeric string as an integer.
///
/// Example:
/// ```dart
/// throw TypeConversionException('database.port', 'int', 'abc');
/// // Output: Cannot convert "abc" to int (key: database.port)
/// ```
class TypeConversionException extends ConfigException {
  /// Creates an exception for a type conversion failure.
  ///
  /// The [key] identifies the configuration key.
  /// The [expectedType] describes the type that was expected.
  /// The [actualValue] is the value that could not be converted.
  TypeConversionException(String key, this.expectedType, this.actualValue)
      : super(
          'Cannot convert "$actualValue" to $expectedType',
          key: key,
        );

  /// The type that was expected (e.g., 'int', 'bool', 'double').
  final String expectedType;

  /// The actual value that could not be converted.
  final String actualValue;
}

/// Thrown when configuration validation fails.
///
/// This exception collects all validation failures that occurred during
/// configuration validation, allowing the application to report all
/// issues at once rather than failing on the first error.
///
/// Example:
/// ```dart
/// throw ValidationException([
///   'database.host is required',
///   'logging.level must be one of [debug, info, warn, error]',
/// ]);
/// ```
class ValidationException extends ConfigException {
  /// Creates an exception with a list of validation failures.
  ///
  /// The [failures] list contains descriptive messages for each
  /// validation error that was detected.
  ValidationException(this.failures)
      : super('Configuration validation failed: ${failures.join(', ')}');

  /// List of all validation failure messages.
  final List<String> failures;
}

/// Thrown when a configuration file cannot be accessed or parsed.
///
/// This exception indicates file system errors (file not found, permission
/// denied) or parsing errors (invalid YAML syntax).
///
/// Example:
/// ```dart
/// throw FileAccessException(
///   'config.yaml',
///   FileSystemException('No such file or directory'),
/// );
/// // Output: Cannot access configuration file: config.yaml
/// //         (FileSystemException: No such file or directory)
/// ```
class FileAccessException extends ConfigException {
  /// Creates an exception for file access or parsing errors.
  ///
  /// The [filePath] identifies which file could not be accessed.
  /// The [cause] is the underlying exception that caused the failure.
  FileAccessException(this.filePath, this.cause)
      : super(
          'Cannot access configuration file: $filePath ($cause)',
        );

  /// The path to the file that could not be accessed.
  final String filePath;

  /// The underlying exception that caused the file access failure.
  final Object cause;
}
