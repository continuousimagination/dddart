# Design Document

## Overview

`dddart_config` is a configuration management package that provides a unified interface for accessing configuration values from multiple sources. The package follows the DDDart framework's design philosophy of minimal boilerplate, clear abstractions, and extensibility.

The design uses a provider pattern where different configuration sources (YAML files, environment variables, future cloud services) implement a common interface. A layered configuration system combines multiple providers with defined precedence rules, allowing environment-specific overrides of default values.

### Key Design Principles

1. **Single Responsibility**: Each provider handles one configuration source
2. **Open/Closed**: Easy to add new providers without modifying core code
3. **Type Safety**: Strong typing with explicit conversion and validation
4. **Fail Fast**: Clear errors at startup for missing required configuration
5. **No Reflection**: Uses explicit parsing and type conversion
6. **Platform Independent**: Works on all Dart platforms (server, web, mobile, desktop)

## Architecture

### Component Diagram

```
┌─────────────────────────────────────────────────────────┐
│                    Application Code                      │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│                   Configuration                          │
│  - Unified access interface                              │
│  - Provider layering and precedence                      │
│  - Type conversion and validation                        │
└────────┬────────────────────┬───────────────────────────┘
         │                    │
         ▼                    ▼
┌──────────────────┐  ┌──────────────────┐
│ ConfigProvider   │  │ ConfigProvider   │  ... (extensible)
│   (abstract)     │  │   (abstract)     │
└────────┬─────────┘  └────────┬─────────┘
         │                     │
    ┌────┴────┐           ┌────┴────┐
    ▼         ▼           ▼         ▼
┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐
│ YAML   │ │ Env    │ │ Future │ │ Custom │
│Provider│ │Provider│ │ Cloud  │ │Provider│
└────────┘ └────────┘ └────────┘ └────────┘
```

### Class Hierarchy

```
ConfigProvider (abstract interface)
├── YamlConfigProvider
├── EnvironmentConfigProvider
└── [Future cloud providers]

Configuration (concrete class)
├── Uses List<ConfigProvider>
├── Implements layering logic
└── Provides typed access methods

ConfigException (exception hierarchy)
├── MissingConfigException
├── TypeConversionException
├── ValidationException
└── FileAccessException
```

## Components and Interfaces

### ConfigProvider Interface

The abstract interface that all configuration sources must implement:

```dart
/// Abstract interface for configuration providers.
///
/// Providers read configuration from a specific source (file, environment,
/// cloud service) and make values available through a common interface.
abstract interface class ConfigProvider {
  /// Retrieves a configuration value by key.
  ///
  /// Returns the string value associated with [key], or null if the key
  /// does not exist or has an explicit null value.
  String? getString(String key);
  
  /// Retrieves all configuration keys with a given prefix.
  ///
  /// Returns a map of all keys starting with [prefix], with the prefix
  /// removed from the keys. Useful for retrieving configuration sections.
  ///
  /// Example: getSection('database') might return:
  /// {'host': 'localhost', 'port': '5432', 'name': 'mydb'}
  Map<String, String> getSection(String prefix);
  
  /// Reloads configuration from the source.
  ///
  /// Re-reads all configuration values from the underlying source.
  /// Throws an exception if the reload fails.
  Future<void> reload();
}
```

### Configuration Class

The main class that applications interact with:

```dart
/// Unified configuration management with multiple provider support.
///
/// Combines multiple configuration providers with defined precedence,
/// providing type-safe access to configuration values.
class Configuration {
  /// Creates a configuration with the given providers.
  ///
  /// Providers are checked in order, with earlier providers taking
  /// precedence over later ones. This allows environment variables
  /// to override file-based defaults.
  ///
  /// Example:
  /// ```dart
  /// final config = Configuration([
  ///   EnvironmentConfigProvider(prefix: 'MYAPP'),
  ///   YamlConfigProvider('config.yaml'),
  /// ]);
  /// ```
  Configuration(List<ConfigProvider> providers);
  
  // String access
  String? getString(String key);
  String getRequiredString(String key);
  String getStringOrDefault(String key, String defaultValue);
  
  // Integer access
  int? getInt(String key);
  int getRequiredInt(String key);
  int getIntOrDefault(String key, int defaultValue);
  
  // Double access
  double? getDouble(String key);
  double getRequiredDouble(String key);
  double getDoubleOrDefault(String key, double defaultValue);
  
  // Boolean access
  bool? getBool(String key);
  bool getRequiredBool(String key);
  bool getBoolOrDefault(String key, bool defaultValue);
  
  // List access (comma-separated values)
  List<String>? getList(String key);
  List<String> getRequiredList(String key);
  List<String> getListOrDefault(String key, List<String> defaultValue);
  
  // Section access
  Map<String, String> getSection(String prefix);
  
  // Validation
  void validate(List<ConfigRequirement> requirements);
  
  // Reload
  Future<void> reload();
}
```

### YamlConfigProvider

Reads configuration from YAML files:

```dart
/// Configuration provider that reads from YAML files.
class YamlConfigProvider implements ConfigProvider {
  /// Creates a YAML provider for the given file path.
  ///
  /// The file is loaded immediately during construction.
  /// Throws [FileAccessException] if the file cannot be read or parsed.
  YamlConfigProvider(String filePath);
  
  @override
  String? getString(String key);
  
  @override
  Map<String, String> getSection(String prefix);
  
  @override
  Future<void> reload();
}
```

**Key Implementation Details:**
- Uses `package:yaml` for parsing
- Supports nested structures with dot notation (e.g., `database.host`)
- Flattens YAML structure into key-value pairs internally
- Handles YAML lists by converting to comma-separated strings
- Throws descriptive exceptions for parse errors

### EnvironmentConfigProvider

Reads configuration from environment variables:

```dart
/// Configuration provider that reads from environment variables.
class EnvironmentConfigProvider implements ConfigProvider {
  /// Creates an environment provider with optional prefix.
  ///
  /// If [prefix] is provided, only environment variables starting with
  /// the prefix are considered. The prefix is removed when converting
  /// to configuration keys.
  ///
  /// Example:
  /// ```dart
  /// // With prefix 'MYAPP_'
  /// // Environment: MYAPP_DATABASE_HOST=localhost
  /// // Key: database.host
  /// final provider = EnvironmentConfigProvider(prefix: 'MYAPP');
  /// ```
  EnvironmentConfigProvider({String? prefix});
  
  @override
  String? getString(String key);
  
  @override
  Map<String, String> getSection(String prefix);
  
  @override
  Future<void> reload();
}
```

**Key Implementation Details:**
- Accesses `Platform.environment` for environment variables
- Converts environment variable names to configuration keys:
  - `MYAPP_DATABASE_HOST` → `database.host`
  - Removes prefix if configured
  - Converts underscores to dots
  - Converts to lowercase
- Reload re-reads from `Platform.environment` (useful if env changes at runtime)

## Data Models

### Configuration Key Format

Configuration keys use dot notation for hierarchical organization:

```
database.host
database.port
database.connection.timeout
logging.level
logging.file.path
```

### Type Conversion Rules

**String to Int:**
- Uses `int.parse()`
- Throws `TypeConversionException` if not a valid integer

**String to Double:**
- Uses `double.parse()`
- Throws `TypeConversionException` if not a valid number

**String to Bool:**
- Accepts: `true`, `false`, `1`, `0`, `yes`, `no`, `on`, `off` (case-insensitive)
- Throws `TypeConversionException` for other values

**String to List:**
- Splits on comma: `"a,b,c"` → `["a", "b", "c"]`
- Trims whitespace from each element
- Empty string returns empty list

### ConfigRequirement

Used for validation:

```dart
/// Defines a required configuration value with validation rules.
class ConfigRequirement {
  final String key;
  final ConfigType type;
  final bool required;
  final dynamic Function(dynamic)? validator;
  
  ConfigRequirement({
    required this.key,
    required this.type,
    this.required = true,
    this.validator,
  });
}

enum ConfigType {
  string,
  integer,
  double,
  boolean,
  list,
}
```

## Error Handling

### Exception Hierarchy

```dart
/// Base exception for configuration errors.
class ConfigException implements Exception {
  final String message;
  final String? key;
  
  ConfigException(this.message, {this.key});
  
  @override
  String toString() => 'ConfigException: $message${key != null ? ' (key: $key)' : ''}';
}

/// Thrown when a required configuration key is missing.
class MissingConfigException extends ConfigException {
  MissingConfigException(String key)
      : super('Required configuration key not found', key: key);
}

/// Thrown when type conversion fails.
class TypeConversionException extends ConfigException {
  final String expectedType;
  final String actualValue;
  
  TypeConversionException(String key, this.expectedType, this.actualValue)
      : super(
          'Cannot convert "$actualValue" to $expectedType',
          key: key,
        );
}

/// Thrown when validation fails.
class ValidationException extends ConfigException {
  final List<String> failures;
  
  ValidationException(this.failures)
      : super('Configuration validation failed: ${failures.join(', ')}');
}

/// Thrown when file access fails.
class FileAccessException extends ConfigException {
  final String filePath;
  final Object cause;
  
  FileAccessException(this.filePath, this.cause)
      : super('Cannot access configuration file: $filePath (${cause.toString()})');
}
```

### Error Messages

All exceptions provide clear, actionable error messages:

```dart
// Missing key
"Required configuration key not found (key: database.host)"

// Type conversion
"Cannot convert "abc" to int (key: database.port)"

// Validation
"Configuration validation failed: database.host is required, logging.level must be one of [debug, info, warn, error]"

// File access
"Cannot access configuration file: config.yaml (FileSystemException: No such file or directory)"
```

## Testing Strategy

### Unit Tests

**ConfigProvider Implementations:**
- Test each provider in isolation
- Mock file system for YAML provider
- Mock environment for environment provider
- Test key lookup, section retrieval, reload

**Configuration Class:**
- Test provider precedence (first provider wins)
- Test type conversion for all supported types
- Test error handling for missing keys and invalid types
- Test validation logic

**Type Conversion:**
- Test all valid boolean representations
- Test numeric parsing edge cases
- Test list parsing with various delimiters and whitespace

### Integration Tests

**Multi-Provider Scenarios:**
- Environment variables override YAML values
- YAML provides defaults, environment overrides specific keys
- Section retrieval across multiple providers

**Reload Behavior:**
- Modify YAML file and reload
- Change environment and reload
- Verify updated values are accessible

**Validation:**
- Define requirements and validate complete configuration
- Test validation failure messages
- Test custom validators

### Example Test Structure

```dart
group('YamlConfigProvider', () {
  test('should load configuration from YAML file', () {
    // Test implementation
  });
  
  test('should support nested keys with dot notation', () {
    // Test implementation
  });
  
  test('should throw FileAccessException for missing file', () {
    // Test implementation
  });
});

group('Configuration', () {
  test('should return value from first provider with key', () {
    // Test implementation
  });
  
  test('should convert string to int correctly', () {
    // Test implementation
  });
  
  test('should throw MissingConfigException for required key', () {
    // Test implementation
  });
});
```

## Usage Examples

### Basic Usage

```dart
import 'package:dddart_config/dddart_config.dart';

void main() {
  // Create configuration with environment override
  final config = Configuration([
    EnvironmentConfigProvider(prefix: 'MYAPP'),
    YamlConfigProvider('config.yaml'),
  ]);
  
  // Access values with type safety
  final host = config.getRequiredString('database.host');
  final port = config.getIntOrDefault('database.port', 5432);
  final debug = config.getBoolOrDefault('debug', false);
  
  print('Connecting to $host:$port (debug: $debug)');
}
```

### Validation at Startup

```dart
void main() {
  final config = Configuration([
    EnvironmentConfigProvider(prefix: 'MYAPP'),
    YamlConfigProvider('config.yaml'),
  ]);
  
  // Validate required configuration
  try {
    config.validate([
      ConfigRequirement(key: 'database.host', type: ConfigType.string),
      ConfigRequirement(key: 'database.port', type: ConfigType.integer),
      ConfigRequirement(
        key: 'logging.level',
        type: ConfigType.string,
        validator: (value) {
          final valid = ['debug', 'info', 'warn', 'error'];
          if (!valid.contains(value)) {
            throw ArgumentError('Must be one of: ${valid.join(', ')}');
          }
          return value;
        },
      ),
    ]);
  } on ValidationException catch (e) {
    print('Configuration error: ${e.message}');
    exit(1);
  }
  
  // Configuration is valid, start application
  startApplication(config);
}
```

### Section Access

```dart
// Get all database configuration
final dbConfig = config.getSection('database');
// Returns: {'host': 'localhost', 'port': '5432', 'name': 'mydb'}

// Use with connection string builder
final connectionString = buildConnectionString(dbConfig);
```

### Runtime Reload

```dart
// Reload configuration from all providers
await config.reload();

// Updated values are now available
final newHost = config.getString('database.host');
```

## Dependencies

### Required Dependencies

```yaml
dependencies:
  yaml: ^3.1.0  # YAML parsing
```

### Development Dependencies

```yaml
dev_dependencies:
  test: ^1.24.0
  very_good_analysis: ^6.0.0
```

## Future Extensibility

The provider pattern makes it easy to add new configuration sources:

### Cloud Provider Example

```dart
class AWSParameterStoreProvider implements ConfigProvider {
  final SSMClient client;
  final String prefix;
  
  AWSParameterStoreProvider(this.client, {required this.prefix});
  
  @override
  String? getString(String key) {
    // Fetch from AWS Parameter Store
  }
  
  @override
  Future<void> reload() async {
    // Refresh from AWS
  }
}

// Usage
final config = Configuration([
  EnvironmentConfigProvider(prefix: 'MYAPP'),
  AWSParameterStoreProvider(ssmClient, prefix: '/myapp/'),
  YamlConfigProvider('defaults.yaml'),
]);
```

### Custom Provider Example

```dart
class DatabaseConfigProvider implements ConfigProvider {
  final Database db;
  
  DatabaseConfigProvider(this.db);
  
  @override
  String? getString(String key) {
    // Read from database config table
  }
  
  @override
  Future<void> reload() async {
    // Refresh from database
  }
}
```

## Package Structure

```
packages/dddart_config/
├── lib/
│   ├── dddart_config.dart              # Main library export
│   └── src/
│       ├── config_provider.dart         # Abstract interface
│       ├── configuration.dart           # Main configuration class
│       ├── yaml_config_provider.dart    # YAML implementation
│       ├── environment_config_provider.dart  # Environment implementation
│       ├── config_requirement.dart      # Validation model
│       └── exceptions.dart              # Exception hierarchy
├── test/
│   ├── yaml_config_provider_test.dart
│   ├── environment_config_provider_test.dart
│   ├── configuration_test.dart
│   └── integration_test.dart
├── example/
│   ├── basic_usage.dart
│   ├── validation_example.dart
│   └── config.yaml
├── pubspec.yaml
├── README.md
├── CHANGELOG.md
└── LICENSE
```

## Performance Considerations

- **Lazy Loading**: Providers load configuration on first access or explicit reload
- **Caching**: Configuration values are cached after first retrieval
- **No Reflection**: All type conversion is explicit, avoiding reflection overhead
- **Minimal Dependencies**: Only `yaml` package required, keeping bundle size small

## Security Considerations

- **Sensitive Values**: Environment variables are preferred for secrets (passwords, API keys)
- **File Permissions**: YAML files should have appropriate read permissions
- **No Logging**: Configuration values are never logged by the framework
- **Validation**: Custom validators can enforce security policies (e.g., password complexity)
