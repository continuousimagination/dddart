# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- **BREAKING**: `EnvironmentConfigProvider` now uses double underscore (`__`) convention for keys containing underscores
  - Single underscore (`_`) → dot (`.`) for hierarchical keys (unchanged)
  - Double underscore (`__`) → single underscore (`_`) in the configuration key (new)
  - Example: `MYAPP_SLACK_BOT__TOKEN` → `slack.bot_token`
  - This allows representing configuration keys that contain underscores (e.g., `bot_token`, `client_id`, `max_connections`)
  - Migration: If you have environment variables with double underscores that you expect to become dots, replace `__` with `_`

### Added

- Comprehensive test coverage for double underscore convention
- New example demonstrating underscore conversion (`example/underscore_demo.dart`)
- Documentation for underscore naming convention in README

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
