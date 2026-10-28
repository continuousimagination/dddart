import 'dart:io';

import 'package:dddart_config/src/config_lookup.dart';
import 'package:dddart_config/src/config_provider.dart';
import 'package:dddart_config/src/exceptions.dart';

/// Hierarchical configuration backed by environment strings.
///
/// A single underscore separates path segments; a double underscore represents
/// a literal underscore. Values remain strings, including commas and JSON text.
/// Without a prefix, names mapping to empty path segments (such as shell `_`)
/// are ignored. Names selected by an explicit prefix remain strictly validated.
class EnvironmentConfigProvider extends ConfigProvider {
  /// Loads the process environment, optionally restricting names to [prefix].
  ///
  /// [environment] supplies an explicit environment for tests or embedding.
  /// Reload reads its current entries, or Platform.environment when omitted.
  EnvironmentConfigProvider({this.prefix, Map<String, String>? environment})
      : _environment = environment {
    _load();
  }

  /// Environment variable prefix, before the separating underscore.
  final String? prefix;
  final Map<String, String>? _environment;
  ConfigLookup _root = ConfigLookup.present(<String, Object?>{});

  void _load() {
    final root = <String, Object?>{};
    final entries = (_environment ?? Platform.environment).entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    for (final entry in entries) {
      var name = entry.key;
      if (prefix != null) {
        if (!name.startsWith('${prefix}_')) continue;
        name = name.substring(prefix!.length + 1);
      }
      final path = name
          .toLowerCase()
          .replaceAll('__', '\u0000')
          .replaceAll('_', '.')
          .replaceAll('\u0000', '_');
      final segments = path.split('.');
      if (segments.any((segment) => segment.isEmpty)) {
        if (prefix == null) continue;
        throw ConfigException('Empty environment path segment', key: path);
      }
      var map = root;
      for (var i = 0; i < segments.length - 1; i++) {
        final segment = segments[i];
        if (!map.containsKey(segment)) map[segment] = <String, Object?>{};
        final child = map[segment];
        if (child is! Map<String, Object?>) {
          throw ConfigException('Conflicting environment paths', key: path);
        }
        map = child;
      }
      final leaf = segments.last;
      if (map.containsKey(leaf)) {
        throw ConfigException('Conflicting environment paths', key: path);
      }
      map[leaf] = entry.value;
    }
    _root = ConfigLookup.present(root);
  }

  @override
  ConfigLookup lookup(String path) => _root.at(path);

  @override
  Future<void> reload() async => _load();
}
