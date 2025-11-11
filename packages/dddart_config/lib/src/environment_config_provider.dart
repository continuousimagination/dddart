import 'dart:io';

import 'config_provider.dart';

/// Configuration provider that reads from environment variables.
///
/// This provider reads configuration values from the system environment,
/// making it ideal for containerized deployments and following 12-factor
/// app principles.
///
/// Environment variable names are converted to configuration keys by:
/// 1. Removing the optional prefix
/// 2. Converting to lowercase
/// 3. Replacing underscores with dots
///
/// For example, with prefix 'MYAPP':
/// - `MYAPP_DATABASE_HOST` → `database.host`
/// - `MYAPP_DATABASE_PORT` → `database.port`
///
/// Example usage:
/// ```dart
/// // With prefix
/// final provider = EnvironmentConfigProvider(prefix: 'MYAPP');
/// final host = provider.getString('database.host');
/// // Reads from MYAPP_DATABASE_HOST environment variable
///
/// // Without prefix
/// final provider = EnvironmentConfigProvider();
/// final host = provider.getString('database.host');
/// // Reads from DATABASE_HOST environment variable
/// ```
class EnvironmentConfigProvider implements ConfigProvider {
  /// Optional prefix for environment variable names.
  ///
  /// If provided, only environment variables starting with this prefix
  /// (followed by an underscore) are considered. The prefix and underscore
  /// are removed when converting to configuration keys.
  final String? prefix;

  /// Cache of environment variables converted to configuration keys.
  Map<String, String> _cache = {};

  /// Creates an environment provider with optional prefix.
  ///
  /// If [prefix] is provided, only environment variables starting with
  /// `{prefix}_` are considered. The prefix is removed when converting
  /// to configuration keys.
  ///
  /// Example:
  /// ```dart
  /// // Only reads MYAPP_* environment variables
  /// final provider = EnvironmentConfigProvider(prefix: 'MYAPP');
  ///
  /// // Reads all environment variables
  /// final provider = EnvironmentConfigProvider();
  /// ```
  EnvironmentConfigProvider({this.prefix}) {
    _loadEnvironment();
  }

  /// Loads environment variables into the cache.
  void _loadEnvironment() {
    _cache = {};
    final env = Platform.environment;

    for (final entry in env.entries) {
      final envKey = entry.key;
      final envValue = entry.value;

      // Check if we should process this environment variable
      if (prefix != null) {
        // With prefix: must start with PREFIX_
        final expectedPrefix = '${prefix}_';
        if (!envKey.startsWith(expectedPrefix)) {
          continue;
        }
        // Remove prefix and convert to config key
        final withoutPrefix = envKey.substring(expectedPrefix.length);
        final configKey = _envKeyToConfigKey(withoutPrefix);
        _cache[configKey] = envValue;
      } else {
        // Without prefix: convert all environment variables
        final configKey = _envKeyToConfigKey(envKey);
        _cache[configKey] = envValue;
      }
    }
  }

  /// Converts an environment variable name to a configuration key.
  ///
  /// Conversion rules:
  /// 1. Convert to lowercase
  /// 2. Replace underscores with dots
  ///
  /// Examples:
  /// - `DATABASE_HOST` → `database.host`
  /// - `DATABASE_CONNECTION_TIMEOUT` → `database.connection.timeout`
  String _envKeyToConfigKey(String envKey) {
    return envKey.toLowerCase().replaceAll('_', '.');
  }

  /// Converts a configuration key to an environment variable name.
  ///
  /// This is the reverse of [_envKeyToConfigKey] and is used for lookups.
  ///
  /// Conversion rules:
  /// 1. Convert to uppercase
  /// 2. Replace dots with underscores
  /// 3. Add prefix if configured
  ///
  /// Examples:
  /// - `database.host` → `DATABASE_HOST` (no prefix)
  /// - `database.host` → `MYAPP_DATABASE_HOST` (with prefix 'MYAPP')
  String _configKeyToEnvKey(String configKey) {
    final envKey = configKey.toUpperCase().replaceAll('.', '_');
    return prefix != null ? '${prefix}_$envKey' : envKey;
  }

  @override
  String? getString(String key) {
    return _cache[key];
  }

  @override
  Map<String, String> getSection(String prefix) {
    final result = <String, String>{};
    final prefixWithDot = prefix.endsWith('.') ? prefix : '$prefix.';

    for (final entry in _cache.entries) {
      if (entry.key.startsWith(prefixWithDot)) {
        // Remove prefix from key
        final keyWithoutPrefix = entry.key.substring(prefixWithDot.length);
        result[keyWithoutPrefix] = entry.value;
      }
    }

    return result;
  }

  @override
  Future<void> reload() async {
    _loadEnvironment();
  }
}
