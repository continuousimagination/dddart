import 'package:dddart_config/src/config_lookup.dart';
import 'package:dddart_config/src/exceptions.dart';

/// A structural configuration source.
///
/// Implement [lookup] and [reload]. The empty lookup path must return the
/// provider's complete root map, or an absent result for an empty source.
/// This lets Configuration resolve ancestors and descendants consistently.
abstract class ConfigProvider {
  /// Selects a dotted map path, preserving explicit null and collection types.
  ConfigLookup lookup(String path);

  /// Reloads the underlying source.
  Future<void> reload();

  /// Reads a scalar as text; missing/null return null and collections fail.
  String? getString(String key) {
    final value = lookup(key).value;
    if (value == null) return null;
    if (value is String || value is num || value is bool) {
      return value.toString();
    }
    throw TypeConversionException(key, 'scalar', value);
  }

  /// Projects a map onto legacy dotted scalar strings.
  ///
  /// Use structural lookup or Configuration.getMap to preserve collections.
  /// Null entries are omitted; lists are rejected rather than stringified.
  Map<String, String> getSection(String prefix) {
    final value = lookup(prefix).value;
    if (value is! Map<String, Object?>) return const {};
    final result = <String, String>{};
    void visit(Map<String, Object?> map, String relative) {
      for (final entry in map.entries) {
        final key = relative.isEmpty ? entry.key : '$relative.${entry.key}';
        final child = entry.value;
        if (child is Map<String, Object?>) {
          visit(child, key);
        } else if (child != null) {
          if (child is! String && child is! num && child is! bool) {
            throw TypeConversionException(
              prefix.isEmpty ? key : '$prefix.$key',
              'scalar',
              child,
            );
          }
          result[key] = child.toString();
        }
      }
    }

    visit(value, '');
    return Map.unmodifiable(result);
  }
}
