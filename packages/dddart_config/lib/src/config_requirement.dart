/// Configuration validation requirements.
library;

/// Defines the expected type of a configuration value.
///
/// Used by [ConfigRequirement] to specify what type a configuration
/// value should be convertible to.
enum ConfigType {
  /// String type - no conversion required.
  string,

  /// Integer type - must be parseable as int.
  integer,

  /// Double type - must be parseable as double.
  double,

  /// Boolean type - must be a valid boolean representation.
  boolean,

  /// List type - comma-separated string values.
  list,
}

/// Defines a configuration requirement for validation.
///
/// A requirement specifies a configuration key, its expected type,
/// whether it is required, and an optional custom validator function.
///
/// Example:
/// ```dart
/// final requirement = ConfigRequirement(
///   key: 'database.host',
///   type: ConfigType.string,
///   required: true,
/// );
///
/// // With custom validator
/// final portRequirement = ConfigRequirement(
///   key: 'database.port',
///   type: ConfigType.integer,
///   required: true,
///   validator: (value) {
///     if (value < 1 || value > 65535) {
///       throw ArgumentError('Port must be between 1 and 65535');
///     }
///     return value;
///   },
/// );
/// ```
class ConfigRequirement {
  /// Creates a configuration requirement.
  ///
  /// The [key] identifies the configuration value to validate.
  /// The [type] specifies the expected type of the value.
  /// The [required] flag indicates whether the key must exist (defaults to true).
  /// The optional [validator] function performs custom validation on the value.
  ///
  /// The validator function receives the typed value (after type conversion)
  /// and should throw an exception if validation fails. It should return
  /// the value if validation succeeds.
  ConfigRequirement({
    required this.key,
    required this.type,
    this.required = true,
    this.validator,
  });

  /// The configuration key to validate.
  final String key;

  /// The expected type of the configuration value.
  final ConfigType type;

  /// Whether the configuration key is required.
  ///
  /// If true, validation fails if the key does not exist.
  /// If false, validation only checks type and custom validator if the key exists.
  final bool required;

  /// Optional custom validator function.
  ///
  /// The validator receives the typed value (after type conversion) and
  /// should throw an exception if validation fails. The exception message
  /// will be included in the validation failure report.
  ///
  /// Example:
  /// ```dart
  /// validator: (value) {
  ///   if (value < 0) {
  ///     throw ArgumentError('Value must be non-negative');
  ///   }
  ///   return value;
  /// }
  /// ```
  final dynamic Function(dynamic)? validator;
}
