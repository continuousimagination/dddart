# dddart_config

A unified configuration management package for the DDDart framework. Provides a consistent interface for accessing configuration values from multiple sources (environment variables, YAML files) with support for layering, type safety, and validation.

## Features

- **Multiple Configuration Sources**: Load configuration from YAML files, environment variables, or custom providers
- **Provider Layering**: Combine multiple sources with defined precedence (e.g., environment overrides YAML)
- **Type Safety**: Type-safe access methods for String, int, double, bool, and List types
- **Validation**: Validate required configuration at startup with descriptive error messages
- **Nested Configuration**: Support for hierarchical configuration using dot notation
- **Runtime Reload**: Reload configuration from sources without restarting the application
- **Extensible**: Easy to add custom configuration providers
- **Platform Independent**: Works on all Dart platforms (server, web, mobile, desktop)

## Installation

Add `dddart_config` to your `pubspec.yaml`:

```yaml
dependencies:
  dddart_config: ^1.0.0
```

Then run:

```bash
dart pub get
```

## Quick Start

### Basic Usage

Create a configuration with multiple providers:

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

### YAML Configuration

Create a `config.yaml` file:

```yaml
database:
  host: localhost
  port: 5432
  name: myapp_db
  connection:
    timeout: 30
    pool_size: 10

logging:
  level: info
  file:
    path: /var/log/myapp.log
    max_size: 10485760

features:
  new_ui: true
  beta_features: false
```

Access nested values using dot notation:

```dart
final timeout = config.getInt('database.connection.timeout');
final logLevel = config.getString('logging.level');
```

### Environment Variables

Set environment variables with a prefix:

```bash
export MYAPP_DATABASE_HOST=prod-db.example.com
export MYAPP_DATABASE_PORT=5432
export MYAPP_LOGGING_LEVEL=warn
export MYAPP_SLACK_BOT__TOKEN=xoxb-your-token-here
```

The provider converts environment variable names to configuration keys:
- `MYAPP_DATABASE_HOST` → `database.host`
- `MYAPP_LOGGING_LEVEL` → `logging.level`
- `MYAPP_SLACK_BOT__TOKEN` → `slack.bot_token`

**Underscore Convention:**
- Single underscore (`_`) → dot (`.`) for hierarchical keys
- Double underscore (`__`) → single underscore (`_`) for keys containing underscores

This allows you to represent configuration keys that contain underscores, such as `bot_token`, `client_id`, or `max_connections`.

## Usage Examples

### Provider Precedence

Providers are checked in order, with earlier providers taking precedence. This allows environment variables to override file-based defaults:

```dart
final config = Configuration([
  EnvironmentConfigProvider(prefix: 'MYAPP'),  // Highest precedence
  YamlConfigProvider('config.yaml'),            // Fallback defaults
]);

// If MYAPP_DATABASE_HOST is set, it overrides config.yaml
final host = config.getString('database.host');
```

### Validation at Startup

Validate required configuration before starting your application:

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

Retrieve entire configuration sections as maps:

```dart
// Get all database configuration
final dbConfig = config.getSection('database');
// Returns: {'host': 'localhost', 'port': '5432', 'name': 'myapp_db', ...}

// Get nested section
final connectionConfig = config.getSection('database.connection');
// Returns: {'timeout': '30', 'pool_size': '10'}
```

### Type-Safe Access

Use typed methods to ensure correct value types:

```dart
// String access
final host = config.getRequiredString('database.host');
final name = config.getStringOrDefault('database.name', 'default_db');

// Integer access
final port = config.getRequiredInt('database.port');
final timeout = config.getIntOrDefault('database.timeout', 30);

// Boolean access
final debug = config.getBoolOrDefault('debug', false);
final enabled = config.getRequiredBool('features.new_ui');

// List access (comma-separated values)
final tags = config.getListOrDefault('tags', ['default']);
```

### Runtime Reload

Reload configuration from all providers without restarting:

```dart
// Reload configuration
await config.reload();

// Updated values are now available
final newHost = config.getString('database.host');
```

## API Reference

### Core Classes

- **[Configuration](lib/src/configuration.dart)**: Main configuration class with provider layering and typed access
- **[ConfigProvider](lib/src/config_provider.dart)**: Abstract interface for configuration sources
- **[YamlConfigProvider](lib/src/yaml_config_provider.dart)**: Reads configuration from YAML files
- **[EnvironmentConfigProvider](lib/src/environment_config_provider.dart)**: Reads configuration from environment variables

### Validation

- **[ConfigRequirement](lib/src/config_requirement.dart)**: Defines required configuration with validation rules
- **[ConfigType](lib/src/config_requirement.dart)**: Enum for configuration value types

### Exceptions

- **[ConfigException](lib/src/exceptions.dart)**: Base exception for configuration errors
- **[MissingConfigException](lib/src/exceptions.dart)**: Thrown when required keys are missing
- **[TypeConversionException](lib/src/exceptions.dart)**: Thrown when type conversion fails
- **[ValidationException](lib/src/exceptions.dart)**: Thrown when validation fails
- **[FileAccessException](lib/src/exceptions.dart)**: Thrown when file access fails

## Environment Variable Naming Convention

### Underscore Handling

Environment variables use a special convention to represent both hierarchical structure (dots) and keys containing underscores:

**Single Underscore (`_`)** - Represents hierarchy (converted to `.`)
```bash
export MYAPP_DATABASE_HOST=localhost
# Accessible as: config.getString('database.host')

export MYAPP_DATABASE_CONNECTION_TIMEOUT=30
# Accessible as: config.getString('database.connection.timeout')
```

**Double Underscore (`__`)** - Represents an underscore in the key name (converted to `_`)
```bash
export MYAPP_SLACK_BOT__TOKEN=xoxb-token
# Accessible as: config.getString('slack.bot_token')

export MYAPP_OAUTH_CLIENT__ID=abc123
# Accessible as: config.getString('oauth.client_id')
```

**Mixed Usage** - Combine both for complex keys
```bash
export MYAPP_DATABASE_MAX__CONNECTIONS=100
# Accessible as: config.getString('database.max_connections')

export MYAPP_API_V2__ENDPOINT_URL=https://api.example.com
# Accessible as: config.getString('api.v2_endpoint.url')
```

### Common Patterns

This convention is particularly useful for common configuration patterns:

```bash
# OAuth credentials
export MYAPP_OAUTH_CLIENT__ID=your-client-id
export MYAPP_OAUTH_CLIENT__SECRET=your-client-secret

# Slack integration
export MYAPP_SLACK_BOT__TOKEN=xoxb-your-bot-token
export MYAPP_SLACK_WEBHOOK__URL=https://hooks.slack.com/...

# Database settings
export MYAPP_DATABASE_MAX__CONNECTIONS=50
export MYAPP_DATABASE_IDLE__TIMEOUT=300

# JWT configuration
export MYAPP_JWT_ACCESS__TOKEN_EXPIRY=3600
export MYAPP_JWT_REFRESH__TOKEN_EXPIRY=86400
```

## Type Conversion

### Boolean Values

The following string values are recognized as boolean (case-insensitive):
- `true`, `false`
- `1`, `0`
- `yes`, `no`
- `on`, `off`

### List Values

Lists are represented as comma-separated strings:
- `"a,b,c"` → `["a", "b", "c"]`
- Whitespace is trimmed from each element
- Empty string returns empty list

### Numeric Values

- Integers: Parsed with `int.parse()`
- Doubles: Parsed with `double.parse()`
- Throws `TypeConversionException` for invalid formats

## Extending with Custom Providers

Create custom providers by implementing the `ConfigProvider` interface:

```dart
class DatabaseConfigProvider implements ConfigProvider {
  final Database db;
  
  DatabaseConfigProvider(this.db);
  
  @override
  String? getString(String key) {
    // Read from database config table
    return db.query('SELECT value FROM config WHERE key = ?', [key]);
  }
  
  @override
  Map<String, String> getSection(String prefix) {
    // Read all keys with prefix
    final results = db.query(
      'SELECT key, value FROM config WHERE key LIKE ?',
      ['$prefix.%'],
    );
    return Map.fromEntries(
      results.map((r) => MapEntry(r['key'], r['value'])),
    );
  }
  
  @override
  Future<void> reload() async {
    // Refresh cache if needed
  }
}

// Use custom provider
final config = Configuration([
  EnvironmentConfigProvider(prefix: 'MYAPP'),
  DatabaseConfigProvider(database),
  YamlConfigProvider('defaults.yaml'),
]);
```

## Error Handling

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

## Best Practices

1. **Use Environment Variables for Secrets**: Never commit passwords or API keys to YAML files
2. **Validate at Startup**: Use `validate()` to fail fast when configuration is invalid
3. **Provider Order Matters**: Place higher-precedence providers first in the list
4. **Use Typed Methods**: Prefer `getRequiredInt()` over `getString()` + manual parsing
5. **Organize with Sections**: Use dot notation to group related configuration
6. **Document Requirements**: Clearly document what configuration your application needs

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Contributing

This package is part of the DDDart framework. For issues, feature requests, or contributions, please visit the main repository.
