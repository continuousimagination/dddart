import 'package:dddart_config/src/exceptions.dart';

/// A structural configuration value, distinguishing absence from explicit null.
class ConfigLookup {
  /// A lookup for a key that is not present.
  const ConfigLookup.missing()
      : isPresent = false,
        value = null;

  const ConfigLookup._(this.value) : isPresent = true;

  /// Copies a supported value into a deeply immutable plain Dart tree.
  factory ConfigLookup.present(Object? value) => ConfigLookup._(
        _freeze(value, '', Set<Object>.identity()),
      );

  /// Whether this value exists, even when [value] is null.
  final bool isPresent;

  /// A scalar, immutable map/list, or explicit null.
  final Object? value;

  /// Looks up a dotted map path; an empty path selects this entire value.
  ///
  /// List elements and literal dotted keys can be accessed from a subtree.
  ConfigLookup at(String path) {
    if (!isPresent || path.isEmpty) return this;
    final segments = path.split('.');
    if (segments.any((segment) => segment.isEmpty)) {
      throw ArgumentError.value(path, 'path', 'Empty path segment');
    }
    var current = value;
    for (final segment in segments) {
      if (current is! Map<String, Object?> || !current.containsKey(segment)) {
        return const ConfigLookup.missing();
      }
      current = current[segment];
    }
    return ConfigLookup._(current);
  }

  static Object? _freeze(Object? value, String path, Set<Object> active) {
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }
    if (value is! Map && value is! List) {
      throw TypeConversionException(path, 'configuration value', value);
    }
    if (!active.add(value)) {
      throw ConfigException('Cyclic configuration collection', key: path);
    }
    try {
      if (value is List) {
        return List<Object?>.unmodifiable([
          for (var i = 0; i < value.length; i++)
            _freeze(value[i], '$path[$i]', active),
        ]);
      }
      final result = <String, Object?>{};
      for (final entry in (value as Map).entries) {
        final key = entry.key;
        if (key is! String) {
          throw ConfigException(
            'Configuration map keys must be strings',
            key: path,
          );
        }
        result[key] =
            _freeze(entry.value, path.isEmpty ? key : '$path.$key', active);
      }
      return Map<String, Object?>.unmodifiable(result);
    } finally {
      active.remove(value);
    }
  }
}
