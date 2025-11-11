import 'dart:io';

import 'package:yaml/yaml.dart';

import 'config_provider.dart';
import 'exceptions.dart';

/// Configuration provider that reads from YAML files.
///
/// This provider loads configuration from a YAML file and makes values
/// accessible through dot notation keys. Nested YAML structures are
/// flattened into dot-separated keys for consistent access patterns.
///
/// Example YAML file:
/// ```yaml
/// database:
///   host: localhost
///   port: 5432
///   connection:
///     timeout: 30
/// features:
///   - feature1
///   - feature2
/// ```
///
/// Accessible as:
/// - `database.host` → "localhost"
/// - `database.port` → "5432"
/// - `database.connection.timeout` → "30"
/// - `features` → "feature1,feature2"
///
/// YAML lists are converted to comma-separated strings for consistent
/// string-based access across all configuration providers.
class YamlConfigProvider implements ConfigProvider {
  /// Creates a YAML configuration provider for the given file path.
  ///
  /// The file is loaded and parsed immediately during construction.
  /// The YAML structure is flattened into dot-notation keys for access.
  ///
  /// Example:
  /// ```dart
  /// final provider = YamlConfigProvider('config.yaml');
  /// final host = provider.getString('database.host');
  /// ```
  ///
  /// Throws [FileAccessException] if the file cannot be read or if the
  /// YAML content cannot be parsed.
  YamlConfigProvider(this._filePath) {
    _load();
  }

  final String _filePath;
  final Map<String, String> _config = {};

  /// Loads and parses the YAML file, flattening the structure.
  void _load() {
    try {
      final file = File(_filePath);
      final content = file.readAsStringSync();
      final yaml = loadYaml(content);

      _config.clear();
      if (yaml != null) {
        _flatten(yaml, '');
      }
    } on FileSystemException catch (e) {
      throw FileAccessException(_filePath, e);
    } on YamlException catch (e) {
      throw FileAccessException(_filePath, e);
    } catch (e) {
      throw FileAccessException(_filePath, e);
    }
  }

  /// Flattens a nested YAML structure into dot-notation keys.
  ///
  /// Recursively processes maps and converts lists to comma-separated strings.
  /// The [prefix] accumulates the key path as we traverse the structure.
  void _flatten(dynamic value, String prefix) {
    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key.toString();
        final fullKey = prefix.isEmpty ? key : '$prefix.$key';
        _flatten(entry.value, fullKey);
      }
    } else if (value is List) {
      // Convert list to comma-separated string
      final stringValue = value.map((e) => e.toString()).join(',');
      _config[prefix] = stringValue;
    } else if (value != null) {
      _config[prefix] = value.toString();
    }
    // Null values are not stored (treated as missing keys)
  }

  @override
  String? getString(String key) {
    return _config[key];
  }

  @override
  Map<String, String> getSection(String prefix) {
    final section = <String, String>{};
    final prefixWithDot = '$prefix.';

    for (final entry in _config.entries) {
      if (entry.key.startsWith(prefixWithDot)) {
        // Remove the prefix and the dot
        final keyWithoutPrefix = entry.key.substring(prefixWithDot.length);
        section[keyWithoutPrefix] = entry.value;
      }
    }

    return section;
  }

  @override
  Future<void> reload() async {
    _load();
  }
}
