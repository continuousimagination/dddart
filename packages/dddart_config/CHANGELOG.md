# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-11-11

### Added

- Initial release of dddart_config
- `Configuration` class for unified configuration management
- `ConfigProvider` abstract interface for extensible configuration sources
- `YamlConfigProvider` for loading configuration from YAML files
- `EnvironmentConfigProvider` for loading configuration from environment variables
- Provider layering with configurable precedence
- Type-safe access methods for String, int, double, bool, and List types
- Configuration validation with `ConfigRequirement` and custom validators
- Support for nested configuration using dot notation
- Section access for retrieving configuration groups
- Runtime configuration reload capability
- Comprehensive exception hierarchy:
  - `ConfigException` base class
  - `MissingConfigException` for missing required keys
  - `TypeConversionException` for type conversion failures
  - `ValidationException` for validation failures
  - `FileAccessException` for file access errors
- Complete documentation with usage examples
- Example code demonstrating common scenarios

### Features

- Platform-independent (works on server, web, mobile, desktop)
- No reflection or runtime type discovery
- Descriptive error messages for troubleshooting
- Support for custom configuration providers
- Follows 12-factor app principles for configuration management

[1.0.0]: https://github.com/example/dddart_config/releases/tag/v1.0.0
