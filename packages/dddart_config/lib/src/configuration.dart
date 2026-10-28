import 'package:dddart_config/src/config_lookup.dart';
import 'package:dddart_config/src/config_provider.dart';
import 'package:dddart_config/src/config_requirement.dart';
import 'package:dddart_config/src/exceptions.dart';

/// Layered structured configuration; earlier providers have higher precedence.
///
/// Maps merge recursively. Other shapes, including lists and explicit null,
/// replace the lower subtree. Resolve a complete effective tree before lookup
/// so a child cannot bypass a null/scalar barrier in an intermediate provider.
class Configuration extends ConfigProvider {
  /// Creates a configuration from at least one provider.
  Configuration(List<ConfigProvider> providers)
      : _providers = List.unmodifiable(providers) {
    if (providers.isEmpty) {
      throw ArgumentError('At least one provider is required');
    }
  }

  final List<ConfigProvider> _providers;

  @override
  ConfigLookup lookup(String path) {
    var root = <String, Object?>{};
    for (final provider in _providers.reversed) {
      final result = provider.lookup('');
      if (!result.isPresent) continue;
      final value = result.value;
      if (value is! Map<String, Object?>) {
        throw TypeConversionException('', 'root map', value);
      }
      root = _merge(root, value);
    }
    return ConfigLookup.present(root).at(path);
  }

  static Map<String, Object?> _merge(
    Map<String, Object?> low,
    Map<String, Object?> high,
  ) {
    final result = Map<String, Object?>.of(low);
    for (final entry in high.entries) {
      final previous = result[entry.key];
      final next = entry.value;
      result[entry.key] =
          previous is Map<String, Object?> && next is Map<String, Object?>
              ? _merge(previous, next)
              : next;
    }
    return result;
  }

  /// Whether a path is present, including explicit null.
  bool contains(String key) => lookup(key).isPresent;

  /// Reads the structural value; use [lookup] to distinguish absent/null.
  Object? getValue(String key) => lookup(key).value;

  /// Reads a required scalar as text.
  String getRequiredString(String key) {
    final value = _required(key, 'scalar');
    if (value is String || value is num || value is bool) {
      return value.toString();
    }
    throw TypeConversionException(key, 'scalar', value);
  }

  /// Reads a scalar with a fallback for missing/null values.
  String getStringOrDefault(String key, String defaultValue) =>
      getString(key) ?? defaultValue;

  /// Reads an integer, parsing environment-backed strings when necessary.
  int? getInt(String key) => _optional(key, _integer);

  /// Reads a required integer.
  int getRequiredInt(String key) => _integer(key, _required(key, 'int'));

  /// Reads an integer with a fallback for missing/null.
  int getIntOrDefault(String key, int defaultValue) =>
      getInt(key) ?? defaultValue;

  /// Reads a number as double, or parses a numeric string.
  double? getDouble(String key) => _optional(key, _double);

  /// Reads a required double.
  double getRequiredDouble(String key) =>
      _double(key, _required(key, 'double'));

  /// Reads a double with a fallback for missing/null.
  double getDoubleOrDefault(String key, double defaultValue) =>
      getDouble(key) ?? defaultValue;

  /// Reads a boolean or a documented true/false string representation.
  bool? getBool(String key) => _optional(key, _boolean);

  /// Reads a required boolean.
  bool getRequiredBool(String key) => _boolean(key, _required(key, 'bool'));

  /// Reads a boolean with a fallback for missing/null.
  bool getBoolOrDefault(String key, bool defaultValue) =>
      getBool(key) ?? defaultValue;

  /// Reads an ordered immutable list, without comma splitting.
  List<Object?>? getList(String key) => _optional(key, _list);

  /// Reads a required structured list.
  List<Object?> getRequiredList(String key) =>
      _list(key, _required(key, 'list'));

  /// Reads a list, copying fallback values into an immutable tree.
  List<Object?> getListOrDefault(String key, List<Object?> defaultValue) =>
      getList(key) ??
      ConfigLookup.present(defaultValue).value! as List<Object?>;

  /// Reads an immutable map subtree.
  Map<String, Object?>? getMap(String key) => _optional(key, _map);

  /// Reads a required map subtree.
  Map<String, Object?> getRequiredMap(String key) =>
      _map(key, _required(key, 'map'));

  Object _required(String key, String expected) {
    final result = lookup(key);
    if (!result.isPresent) throw MissingConfigException(key);
    final value = result.value;
    if (value == null) throw TypeConversionException(key, expected, null);
    return value;
  }

  T? _optional<T>(String key, T Function(String, Object) convert) {
    final value = lookup(key).value;
    return value == null ? null : convert(key, value);
  }

  static int _integer(String key, Object value) {
    if (value is int) return value;
    final parsed = value is String ? int.tryParse(value) : null;
    if (parsed != null) return parsed;
    throw TypeConversionException(key, 'int', value);
  }

  static double _double(String key, Object value) {
    if (value is num) return value.toDouble();
    final parsed = value is String ? double.tryParse(value) : null;
    if (parsed != null) return parsed;
    throw TypeConversionException(key, 'double', value);
  }

  static bool _boolean(String key, Object value) {
    if (value is bool) return value;
    if (value is String) {
      switch (value.toLowerCase().trim()) {
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
      }
    }
    throw TypeConversionException(key, 'bool', value);
  }

  static List<Object?> _list(String key, Object value) {
    if (value is List<Object?>) return value;
    throw TypeConversionException(key, 'list', value);
  }

  static Map<String, Object?> _map(String key, Object value) {
    if (value is Map<String, Object?>) return value;
    throw TypeConversionException(key, 'map', value);
  }

  /// Validates required values, types and optional application validators.
  ///
  /// Failure reports omit actual configuration values and validator exception
  /// text, which may contain secrets.
  void validate(List<ConfigRequirement> requirements) {
    final failures = <String>[];
    for (final requirement in requirements) {
      final key = requirement.key;
      if (!contains(key)) {
        if (requirement.required) failures.add('$key is required');
        continue;
      }
      final Object value;
      try {
        value = switch (requirement.type) {
          ConfigType.string => getRequiredString(key),
          ConfigType.integer => getRequiredInt(key),
          ConfigType.double => getRequiredDouble(key),
          ConfigType.boolean => getRequiredBool(key),
          ConfigType.list => getRequiredList(key),
          ConfigType.map => getRequiredMap(key),
        };
      } on TypeConversionException {
        failures.add('$key must be a valid ${requirement.type.name}');
        continue;
      }
      try {
        requirement.validator?.call(value);
      } catch (_) {
        failures.add('$key validation failed');
      }
    }
    if (failures.isNotEmpty) throw ValidationException(failures);
  }

  @override
  Future<void> reload() async {
    for (var i = 0; i < _providers.length; i++) {
      try {
        await _providers[i].reload();
      } catch (_) {
        throw ConfigException('Failed to reload provider at index $i');
      }
    }
  }
}
