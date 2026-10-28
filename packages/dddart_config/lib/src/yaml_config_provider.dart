import 'dart:io';

import 'package:dddart_config/src/config_lookup.dart';
import 'package:dddart_config/src/config_provider.dart';
import 'package:dddart_config/src/exceptions.dart';
import 'package:yaml/yaml.dart';

/// Reads YAML maps without discarding collection types or explicit null.
class YamlConfigProvider extends ConfigProvider {
  /// Loads a YAML mapping from [filePath].
  YamlConfigProvider(String filePath) : _filePath = filePath {
    _load();
  }

  final String _filePath;
  ConfigLookup _root = ConfigLookup.present(<String, Object?>{});

  void _load() {
    final Object? yaml;
    try {
      yaml = loadYaml(File(_filePath).readAsStringSync());
    } on FileSystemException catch (error) {
      throw FileAccessException(_filePath, error);
    } on YamlException catch (error) {
      throw FileAccessException(_filePath, error);
    }
    if (yaml != null && yaml is! Map) {
      throw TypeConversionException('', 'root map', yaml);
    }
    _root = ConfigLookup.present(yaml ?? <String, Object?>{});
  }

  @override
  ConfigLookup lookup(String path) => _root.at(path);

  @override
  Future<void> reload() async => _load();
}
