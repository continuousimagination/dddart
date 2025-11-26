// ignore_for_file: avoid_print

import 'package:dddart_config/dddart_config.dart';

/// Demonstrates basic configuration usage with multiple providers.
///
/// This example shows how to:
/// - Create a Configuration with multiple providers
/// - Access configuration values with type safety
/// - Use default values for optional settings
/// - Handle missing configuration gracefully
void main() {
  // Create configuration with layered providers
  // Environment variables take precedence over YAML file values
  final config = Configuration([
    EnvironmentConfigProvider(prefix: 'MYAPP'),
    YamlConfigProvider('example/config.yaml'),
  ]);

  print('=== Basic Configuration Access ===\n');

  // Access string values
  final dbHost = config.getRequiredString('database.host');
  print('Database host: $dbHost');

  // Access integer values with type conversion
  final dbPort = config.getIntOrDefault('database.port', 5432);
  print('Database port: $dbPort');

  // Access boolean values
  final debugMode = config.getBoolOrDefault('app.debug', false);
  print('Debug mode: $debugMode');

  // Access nested values using dot notation
  final connectionTimeout = config.getInt('database.connection.timeout');
  print('Connection timeout: ${connectionTimeout}s');

  // Access list values (comma-separated in config)
  final features = config.getList('app.features');
  print('Enabled features: ${features?.join(', ')}');

  print('\n=== Optional Values with Defaults ===\n');

  // Use defaults for values that might not exist
  final maxRetries = config.getIntOrDefault('api.max_retries', 3);
  print('Max retries: $maxRetries');

  final cacheEnabled = config.getBoolOrDefault('cache.enabled', true);
  print('Cache enabled: $cacheEnabled');

  print('\n=== Handling Missing Values ===\n');

  // Nullable access returns null for missing keys
  final missingValue = config.getString('nonexistent.key');
  print('Missing value: $missingValue');

  // Required access throws exception for missing keys
  try {
    config.getRequiredString('nonexistent.required');
  } on MissingConfigException catch (e) {
    print('Caught expected exception: $e');
  }

  print('\n=== Type Conversion ===\n');

  // Automatic type conversion from string values
  final poolSize = config.getInt('database.connection.pool_size');
  print('Pool size (int): $poolSize');

  final sslEnabled = config.getBool('database.connection.ssl_enabled');
  print('SSL enabled (bool): $sslEnabled');

  // Type conversion errors are caught
  try {
    // This would fail if the value isn't a valid number
    config.getInt('app.name'); // "MyApplication" is not a number
  } on TypeConversionException catch (e) {
    print('Type conversion error: ${e.message}');
  }

  print('\n=== Environment Variable Override ===\n');

  // Environment variables can override YAML values
  // Set MYAPP_DATABASE_HOST=production.db.example.com to override
  print('To override database.host, set environment variable:');
  print('  export MYAPP_DATABASE_HOST=production.db.example.com');
  print('Current value: ${config.getString('database.host')}');

  print('\n=== Underscore Convention ===\n');

  // Single underscores in env vars become dots (hierarchy)
  print('Single underscore: MYAPP_DATABASE_HOST → database.host');

  // Double underscores in env vars become single underscores (in key name)
  print('Double underscore: MYAPP_SLACK_BOT__TOKEN → slack.bot_token');

  // Try accessing a key with underscore (if set in environment)
  final botToken = config.getString('slack.bot_token');
  if (botToken != null) {
    print('Slack bot token found: ${botToken.substring(0, 10)}...');
  } else {
    print('To set a key with underscore, use double underscore:');
    print('  export MYAPP_SLACK_BOT__TOKEN=xoxb-your-token');
  }

  // Mixed example
  print('\nMixed: MYAPP_DATABASE_MAX__CONNECTIONS → database.max_connections');
  final maxConnections = config.getInt('database.max_connections');
  if (maxConnections != null) {
    print('Max connections: $maxConnections');
  }
}
