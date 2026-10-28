# dddart_config

A unified configuration management package for the DDDart framework. Provides a consistent interface for accessing configuration values from multiple sources (environment variables, YAML files) with support for layering, type safety, and validation.

## Features

- **Multiple Configuration Sources**: Load configuration from YAML files, environment variables, or custom providers
- **Provider Layering**: Combine multiple sources with defined precedence (e.g., environment overrides YAML)
- **Structured Values**: Ordered lists, maps, native scalar types, and explicit null
- **Type Safety**: Typed scalar, list, and map access with path-specific errors
- **Validation**: Validate required configuration at startup with descriptive error messages
- **Nested Configuration**: Support for hierarchical configuration using dot notation
- **Runtime Reload**: Reload configuration from sources without restarting the application
- **Extensible**: Easy to add custom configuration providers
- **Platform Independent**: Works on all Dart platforms (server, web, mobile, desktop)

## Installation

Add `dddart_config` to your `pubspec.yaml`:

```yaml
dependencies:
  dddart_config:
    git:
      url: https://github.com/continuousimagination/dddart.git
      path: packages/dddart_config
      ref: <approved-immutable-candidate-revision>
```

Replace the revision placeholder with the reviewed candidate commit, then run:

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

Values remain strings: an environment value containing commas or JSON is not
implicitly decoded as a collection. Use YAML for structural lists/maps. Names
that collide after normalization, or define both an ancestor scalar and its
descendant (such as `APP_DATABASE` and `APP_DATABASE_PORT`), produce a path error.
Without a prefix, ambient names that map to empty path segments (for example
shell `_`, `_NAME` or `NAME_`) are ignored, so unrelated shell metadata cannot
disable legitimate settings. With an explicit prefix, malformed selected names
still produce a path error. Normalized duplicates and ancestor/descendant
conflicts remain errors in both modes. Prefer a prefix to avoid unrelated
addressable names colliding in the process environment.

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

Maps merge recursively by key; overriding `database.host` preserves a lower
`database.port`. Lists replace wholesale, including empty lists. An explicit
null masks lower values; an absent key permits fallback. An empty map contributes
no overriding entries when merged with a lower map.

A scalar/null/list is also a barrier in an intermediate provider. With high
`database: {host: prod}`, middle `database: null`, and low
`database: {port: 5432}`, the effective subtree is `{host: prod}`. Both subtree
and child lookup report `database.port` absent. High-priority maps cannot bring
back descendants hidden by an intermediate replacement.

### Ordered structured configuration

```yaml
projects:
  - organization: continuousimagination
    number: 12
  - organization: continuousimagination
    number: 34
```

```dart
final projects = config.getRequiredList('projects');
final first = projects.first! as Map<String, Object?>;
assert(first['number'] is int);
final subtree = config.getRequiredMap(''); // Complete effective root.
final result = config.lookup('optional.value');
if (result.isPresent) {
  // result.value can be an explicit null.
}
```

Returned maps and lists are deeply immutable plain Dart values. YAML wrapper
types are removed; sequence order, nested collections, empty values, native
string/bool/int/double values and explicit null are retained. Non-string map
keys, unsupported values and cyclic collections fail with path context.
Dot paths traverse maps; inspect a subtree directly for literal dotted keys or
list elements. Application record validation and ordering policy remain outside
the configuration library.

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

// Structural list access; a scalar "a,b" stays a string.
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
- **[ConfigLookup](lib/src/config_lookup.dart)**: Structural value with explicit presence information
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

List access requires an actual YAML list (or a list supplied by a structural
provider). Strings containing commas remain single strings. List elements are
not trimmed or converted. Use `getMap`/`getRequiredMap` for map subtrees.

Nullable getters return null for missing or explicit-null values. Use `lookup`
or `contains` to distinguish them. Required getters throw `MissingConfigException`
for absence and `TypeConversionException` for explicit null or the wrong type.
Error messages report paths and types without embedding configuration values.
Custom validation failures omit the callback's exception text for the same reason.

### Numeric Values

- Integers: Parsed with `int.parse()`
- Doubles: Parsed with `double.parse()`
- Throws `TypeConversionException` for invalid formats

## Extending with Custom Providers

Extend `ConfigProvider` and implement structural `lookup` and `reload`. The empty
lookup path must expose the complete root map. The base supplies scalar string
access and the legacy scalar-only `getSection` projection:

```dart
class ApplicationConfigProvider extends ConfigProvider {
  ApplicationConfigProvider(Map<String, Object?> values)
      : _root = ConfigLookup.present(values);

  final ConfigLookup _root;

  @override
  ConfigLookup lookup(String path) => _root.at(path);

  @override
  Future<void> reload() async {}
}

// Use custom provider
final config = Configuration([
  EnvironmentConfigProvider(prefix: 'MYAPP'),
  ApplicationConfigProvider({'database': {'port': 5432}}),
  YamlConfigProvider('defaults.yaml'),
]);
```

## Migration from flat/string configuration

- Custom providers now expose a root tree through `lookup('')`; keeping only a
  flat string cache cannot implement ancestor masking correctly.
- Replace comma-separated YAML/env list strings with actual YAML sequences.
  `getList` now returns `List<Object?>`; cast/validate application records at the
  consumer boundary. Commas and whitespace inside elements remain unchanged.
- Existing scalar getters still work for simple configuration and parse numeric
  or boolean environment strings. Collections are never stringified by `getString`.
- `getSection` remains a legacy dotted scalar projection, omits null and rejects
  lists. Prefer `getMap` for structural data and native types.
- An explicit null now masks fallback instead of disappearing. Required null is
  a type error, while an absent required key is a missing-value error.
- Environment shape collisions are errors. Use a dedicated prefix and avoid
  defining both an ancestor value and its descendants in the same provider.

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
