/// Configuration management with multiple provider support.
library;

import 'config_provider.dart';
import 'config_requirement.dart';
import 'exceptions.dart';

/// Unified configuration management with layered provider support.
///
/// The [Configuration] class combines multiple [ConfigProvider] instances
/// with defined precedence rules, providing a single interface for accessing
/// configuration values from multiple sources.
///
/// Providers are checked in the order they are provided to the constructor,
/// with earlier providers taking precedence over later ones. This allows
/// environment variables to override file-based defaults, for example.
///
/// Example:
/// ```dart
/// final config = Configuration([
///   EnvironmentConfigProvider(prefix: 'MYAPP'),
///   YamlConfigProvider('config.yaml'),
/// ]);
///
/// // Environment variable MYAPP_DATABASE_HOST overrides config.yaml
/// final host = config.getString('database.host');
/// ```
///
/// The class provides basic string access through [getString] and
/// [getSection], with support for reloading configuration from all
/// providers via [reload].
class Configuration {
  /// Creates a configuration with the given providers.
  ///
  /// Providers are checked in order, with earlier providers taking
  /// precedence over later ones. This allows layering configuration
  /// sources with override semantics.
  ///
  /// Example:
  /// ```dart
  /// // Environment variables override YAML file values
  /// final config = Configuration([
  ///   EnvironmentConfigProvider(prefix: 'MYAPP'),
  ///   YamlConfigProvider('config.yaml'),
  /// ]);
  /// ```
  ///
  /// Throws [ArgumentError] if [providers] is empty.
  Configuration(List<ConfigProvider> providers)
      : _providers = List.unmodifiable(providers) {
    if (providers.isEmpty) {
      throw ArgumentError('At least one provider must be specified');
    }
  }

  final List<ConfigProvider> _providers;

  /// Retrieves a configuration value by key.
  ///
  /// Checks providers in precedence order and returns the first non-null
  /// value found. Returns null if no provider contains the key.
  ///
  /// Keys typically use dot notation for hierarchical organization:
  /// - `database.host`
  /// - `database.port`
  /// - `logging.level`
  ///
  /// Example:
  /// ```dart
  /// final host = config.getString('database.host');
  /// if (host != null) {
  ///   print('Database host: $host');
  /// }
  /// ```
  ///
  /// Returns null if the key does not exist in any provider.
  String? getString(String key) {
    for (final provider in _providers) {
      final value = provider.getString(key);
      if (value != null) {
        return value;
      }
    }
    return null;
  }

  /// Retrieves all configuration keys with a given prefix.
  ///
  /// Merges sections from all providers with precedence rules applied.
  /// Earlier providers override values from later providers for the same key.
  ///
  /// For example, if the configuration contains:
  /// - Provider 1: `database.host` = "prod.example.com"
  /// - Provider 2: `database.host` = "localhost", `database.port` = "5432"
  ///
  /// Then `getSection('database')` returns:
  /// ```dart
  /// {
  ///   'host': 'prod.example.com',  // From provider 1 (higher precedence)
  ///   'port': '5432'                // From provider 2
  /// }
  /// ```
  ///
  /// Returns an empty map if no keys match the prefix in any provider.
  Map<String, String> getSection(String prefix) {
    final result = <String, String>{};

    // Process providers in reverse order so earlier providers override later
    for (var i = _providers.length - 1; i >= 0; i--) {
      final section = _providers[i].getSection(prefix);
      result.addAll(section);
    }

    return result;
  }

  /// Retrieves a required string configuration value.
  ///
  /// Returns the string value for [key], or throws [MissingConfigException]
  /// if the key does not exist or has a null value.
  ///
  /// Example:
  /// ```dart
  /// final host = config.getRequiredString('database.host');
  /// // Throws if database.host is not configured
  /// ```
  ///
  /// Throws [MissingConfigException] if the key is not found.
  String getRequiredString(String key) {
    final value = getString(key);
    if (value == null) {
      throw MissingConfigException(key);
    }
    return value;
  }

  /// Retrieves a string configuration value with a default fallback.
  ///
  /// Returns the string value for [key], or [defaultValue] if the key
  /// does not exist or has a null value.
  ///
  /// Example:
  /// ```dart
  /// final host = config.getStringOrDefault('database.host', 'localhost');
  /// ```
  String getStringOrDefault(String key, String defaultValue) {
    return getString(key) ?? defaultValue;
  }

  /// Retrieves an integer configuration value.
  ///
  /// Converts the string value to an integer using [int.parse].
  /// Returns null if the key does not exist.
  ///
  /// Example:
  /// ```dart
  /// final port = config.getInt('database.port');
  /// if (port != null) {
  ///   print('Port: $port');
  /// }
  /// ```
  ///
  /// Throws [TypeConversionException] if the value cannot be parsed as int.
  int? getInt(String key) {
    final value = getString(key);
    if (value == null) {
      return null;
    }

    try {
      return int.parse(value);
    } on FormatException {
      throw TypeConversionException(key, 'int', value);
    }
  }

  /// Retrieves a required integer configuration value.
  ///
  /// Returns the integer value for [key], or throws an exception if the
  /// key does not exist or cannot be converted to an integer.
  ///
  /// Example:
  /// ```dart
  /// final port = config.getRequiredInt('database.port');
  /// ```
  ///
  /// Throws [MissingConfigException] if the key is not found.
  /// Throws [TypeConversionException] if the value cannot be parsed as int.
  int getRequiredInt(String key) {
    final value = getString(key);
    if (value == null) {
      throw MissingConfigException(key);
    }

    try {
      return int.parse(value);
    } on FormatException {
      throw TypeConversionException(key, 'int', value);
    }
  }

  /// Retrieves an integer configuration value with a default fallback.
  ///
  /// Returns the integer value for [key], or [defaultValue] if the key
  /// does not exist or has a null value.
  ///
  /// Example:
  /// ```dart
  /// final port = config.getIntOrDefault('database.port', 5432);
  /// ```
  ///
  /// Throws [TypeConversionException] if the value exists but cannot be
  /// parsed as int.
  int getIntOrDefault(String key, int defaultValue) {
    return getInt(key) ?? defaultValue;
  }

  /// Retrieves a double configuration value.
  ///
  /// Converts the string value to a double using [double.parse].
  /// Returns null if the key does not exist.
  ///
  /// Example:
  /// ```dart
  /// final timeout = config.getDouble('connection.timeout');
  /// if (timeout != null) {
  ///   print('Timeout: $timeout seconds');
  /// }
  /// ```
  ///
  /// Throws [TypeConversionException] if the value cannot be parsed as double.
  double? getDouble(String key) {
    final value = getString(key);
    if (value == null) {
      return null;
    }

    try {
      return double.parse(value);
    } on FormatException {
      throw TypeConversionException(key, 'double', value);
    }
  }

  /// Retrieves a required double configuration value.
  ///
  /// Returns the double value for [key], or throws an exception if the
  /// key does not exist or cannot be converted to a double.
  ///
  /// Example:
  /// ```dart
  /// final timeout = config.getRequiredDouble('connection.timeout');
  /// ```
  ///
  /// Throws [MissingConfigException] if the key is not found.
  /// Throws [TypeConversionException] if the value cannot be parsed as double.
  double getRequiredDouble(String key) {
    final value = getString(key);
    if (value == null) {
      throw MissingConfigException(key);
    }

    try {
      return double.parse(value);
    } on FormatException {
      throw TypeConversionException(key, 'double', value);
    }
  }

  /// Retrieves a double configuration value with a default fallback.
  ///
  /// Returns the double value for [key], or [defaultValue] if the key
  /// does not exist or has a null value.
  ///
  /// Example:
  /// ```dart
  /// final timeout = config.getDoubleOrDefault('connection.timeout', 30.0);
  /// ```
  ///
  /// Throws [TypeConversionException] if the value exists but cannot be
  /// parsed as double.
  double getDoubleOrDefault(String key, double defaultValue) {
    return getDouble(key) ?? defaultValue;
  }

  /// Retrieves a boolean configuration value.
  ///
  /// Accepts the following string representations (case-insensitive):
  /// - `true`, `false`
  /// - `1`, `0`
  /// - `yes`, `no`
  /// - `on`, `off`
  ///
  /// Returns null if the key does not exist.
  ///
  /// Example:
  /// ```dart
  /// final debug = config.getBool('debug');
  /// if (debug == true) {
  ///   enableDebugMode();
  /// }
  /// ```
  ///
  /// Throws [TypeConversionException] if the value is not a valid boolean
  /// representation.
  bool? getBool(String key) {
    final value = getString(key);
    if (value == null) {
      return null;
    }

    final normalized = value.toLowerCase().trim();
    switch (normalized) {
      case 'true':
      case '1':
      case 'yes':
      case 'on':
        return true;
      case 'false':
      case '0':
      case 'no':
      case 'off':
        return false;
      default:
        throw TypeConversionException(key, 'bool', value);
    }
  }

  /// Retrieves a required boolean configuration value.
  ///
  /// Returns the boolean value for [key], or throws an exception if the
  /// key does not exist or cannot be converted to a boolean.
  ///
  /// Example:
  /// ```dart
  /// final debug = config.getRequiredBool('debug');
  /// ```
  ///
  /// Throws [MissingConfigException] if the key is not found.
  /// Throws [TypeConversionException] if the value is not a valid boolean
  /// representation.
  bool getRequiredBool(String key) {
    final value = getString(key);
    if (value == null) {
      throw MissingConfigException(key);
    }

    final normalized = value.toLowerCase().trim();
    switch (normalized) {
      case 'true':
      case '1':
      case 'yes':
      case 'on':
        return true;
      case 'false':
      case '0':
      case 'no':
      case 'off':
        return false;
      default:
        throw TypeConversionException(key, 'bool', value);
    }
  }

  /// Retrieves a boolean configuration value with a default fallback.
  ///
  /// Returns the boolean value for [key], or [defaultValue] if the key
  /// does not exist or has a null value.
  ///
  /// Example:
  /// ```dart
  /// final debug = config.getBoolOrDefault('debug', false);
  /// ```
  ///
  /// Throws [TypeConversionException] if the value exists but is not a
  /// valid boolean representation.
  bool getBoolOrDefault(String key, bool defaultValue) {
    return getBool(key) ?? defaultValue;
  }

  /// Retrieves a list configuration value.
  ///
  /// Splits the string value on commas and trims whitespace from each element.
  /// Returns null if the key does not exist.
  ///
  /// Example:
  /// ```dart
  /// final hosts = config.getList('database.hosts');
  /// // "host1, host2, host3" -> ["host1", "host2", "host3"]
  /// ```
  ///
  /// Returns an empty list if the value is an empty string.
  List<String>? getList(String key) {
    final value = getString(key);
    if (value == null) {
      return null;
    }

    if (value.trim().isEmpty) {
      return [];
    }

    return value.split(',').map((e) => e.trim()).toList();
  }

  /// Retrieves a required list configuration value.
  ///
  /// Returns the list value for [key], or throws [MissingConfigException]
  /// if the key does not exist.
  ///
  /// Example:
  /// ```dart
  /// final hosts = config.getRequiredList('database.hosts');
  /// ```
  ///
  /// Throws [MissingConfigException] if the key is not found.
  List<String> getRequiredList(String key) {
    final value = getList(key);
    if (value == null) {
      throw MissingConfigException(key);
    }
    return value;
  }

  /// Retrieves a list configuration value with a default fallback.
  ///
  /// Returns the list value for [key], or [defaultValue] if the key
  /// does not exist or has a null value.
  ///
  /// Example:
  /// ```dart
  /// final hosts = config.getListOrDefault(
  ///   'database.hosts',
  ///   ['localhost'],
  /// );
  /// ```
  List<String> getListOrDefault(String key, List<String> defaultValue) {
    return getList(key) ?? defaultValue;
  }

  /// Validates configuration against a list of requirements.
  ///
  /// Checks each requirement to ensure:
  /// 1. Required keys exist
  /// 2. Values can be converted to the expected type
  /// 3. Custom validators pass (if provided)
  ///
  /// All validation failures are collected before throwing an exception,
  /// allowing the application to see all configuration issues at once.
  ///
  /// Example:
  /// ```dart
  /// config.validate([
  ///   ConfigRequirement(
  ///     key: 'database.host',
  ///     type: ConfigType.string,
  ///     required: true,
  ///   ),
  ///   ConfigRequirement(
  ///     key: 'database.port',
  ///     type: ConfigType.integer,
  ///     required: true,
  ///     validator: (value) {
  ///       if (value < 1 || value > 65535) {
  ///         throw ArgumentError('Port must be between 1 and 65535');
  ///       }
  ///       return value;
  ///     },
  ///   ),
  ///   ConfigRequirement(
  ///     key: 'logging.level',
  ///     type: ConfigType.string,
  ///     validator: (value) {
  ///       final valid = ['debug', 'info', 'warn', 'error'];
  ///       if (!valid.contains(value)) {
  ///         throw ArgumentError('Must be one of: ${valid.join(', ')}');
  ///       }
  ///       return value;
  ///     },
  ///   ),
  /// ]);
  /// ```
  ///
  /// Throws [ValidationException] with a list of all validation failures
  /// if any requirement is not met.
  void validate(List<ConfigRequirement> requirements) {
    final failures = <String>[];

    for (final requirement in requirements) {
      final key = requirement.key;
      final rawValue = getString(key);

      // Check if required key exists
      if (rawValue == null) {
        if (requirement.required) {
          failures.add('$key is required');
        }
        continue; // Skip type and validator checks if value doesn't exist
      }

      // Check type conversion
      dynamic typedValue;
      try {
        switch (requirement.type) {
          case ConfigType.string:
            typedValue = rawValue;
          case ConfigType.integer:
            typedValue = int.parse(rawValue);
          case ConfigType.double:
            typedValue = double.parse(rawValue);
          case ConfigType.boolean:
            final normalized = rawValue.toLowerCase().trim();
            switch (normalized) {
              case 'true':
              case '1':
              case 'yes':
              case 'on':
                typedValue = true;
              case 'false':
              case '0':
              case 'no':
              case 'off':
                typedValue = false;
              default:
                throw FormatException('Invalid boolean value');
            }
          case ConfigType.list:
            if (rawValue.trim().isEmpty) {
              typedValue = <String>[];
            } else {
              typedValue = rawValue.split(',').map((e) => e.trim()).toList();
            }
        }
      } on FormatException {
        failures.add('$key must be a valid ${requirement.type.name}');
        continue; // Skip validator check if type conversion failed
      }

      // Check custom validator
      if (requirement.validator != null) {
        try {
          requirement.validator!(typedValue);
        } catch (e) {
          failures.add('$key validation failed: ${e.toString()}');
        }
      }
    }

    if (failures.isNotEmpty) {
      throw ValidationException(failures);
    }
  }

  /// Reloads configuration from all providers.
  ///
  /// Calls [ConfigProvider.reload] on each provider sequentially.
  /// If any provider fails to reload, throws an exception with details
  /// about which provider failed.
  ///
  /// Example:
  /// ```dart
  /// // Configuration files have been updated
  /// await config.reload();
  /// // New values are now available
  /// final newValue = config.getString('some.key');
  /// ```
  ///
  /// Throws [ConfigException] if any provider fails to reload, with
  /// details about which provider failed and the underlying cause.
  Future<void> reload() async {
    for (var i = 0; i < _providers.length; i++) {
      try {
        await _providers[i].reload();
      } catch (e) {
        throw ConfigException(
          'Failed to reload provider at index $i: ${e.toString()}',
        );
      }
    }
  }
}
