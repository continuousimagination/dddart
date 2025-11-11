/// Configuration management package for DDDart framework.
///
/// Provides a unified interface for accessing configuration values from
/// multiple sources (YAML files, environment variables, cloud services)
/// with support for layering, type safety, and validation.
///
/// Example usage:
/// ```dart
/// import 'package:dddart_config/dddart_config.dart';
///
/// void main() {
///   final config = Configuration([
///     EnvironmentConfigProvider(prefix: 'MYAPP'),
///     YamlConfigProvider('config.yaml'),
///   ]);
///
///   final host = config.getRequiredString('database.host');
///   final port = config.getIntOrDefault('database.port', 5432);
/// }
/// ```
library dddart_config;

export 'src/config_provider.dart';
export 'src/config_requirement.dart';
export 'src/configuration.dart';
export 'src/environment_config_provider.dart';
export 'src/exceptions.dart';
export 'src/yaml_config_provider.dart';
