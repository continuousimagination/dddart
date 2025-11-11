// ignore_for_file: avoid_print

import 'dart:io';

import 'package:dddart_config/dddart_config.dart';

/// Demonstrates configuration validation at application startup.
///
/// This example shows how to:
/// - Define configuration requirements with types
/// - Validate configuration before starting the application
/// - Use custom validators for business rules
/// - Handle validation failures gracefully
void main() {
  print('=== Configuration Validation Example ===\n');

  // Create configuration
  final config = Configuration([
    EnvironmentConfigProvider(prefix: 'MYAPP'),
    YamlConfigProvider('example/config.yaml'),
  ]);

  print('Validating configuration...\n');

  try {
    // Define configuration requirements
    config.validate([
      // Required string values
      ConfigRequirement(
        key: 'database.host',
        type: ConfigType.string,
        required: true,
      ),
      ConfigRequirement(
        key: 'database.name',
        type: ConfigType.string,
        required: true,
      ),

      // Required integer values
      ConfigRequirement(
        key: 'database.port',
        type: ConfigType.integer,
        required: true,
      ),
      ConfigRequirement(
        key: 'database.connection.timeout',
        type: ConfigType.integer,
        required: true,
      ),

      // Required boolean values
      ConfigRequirement(
        key: 'database.connection.ssl_enabled',
        type: ConfigType.boolean,
        required: true,
      ),

      // Custom validator for logging level
      ConfigRequirement(
        key: 'logging.level',
        type: ConfigType.string,
        required: true,
        validator: (value) {
          final validLevels = ['debug', 'info', 'warn', 'error'];
          if (!validLevels.contains(value)) {
            throw ArgumentError(
              'logging.level must be one of: ${validLevels.join(', ')}',
            );
          }
          return value;
        },
      ),

      // Custom validator for port range
      ConfigRequirement(
        key: 'database.port',
        type: ConfigType.integer,
        required: true,
        validator: (value) {
          final port = value as int;
          if (port < 1 || port > 65535) {
            throw ArgumentError('database.port must be between 1 and 65535');
          }
          return value;
        },
      ),

      // Custom validator for timeout
      ConfigRequirement(
        key: 'database.connection.timeout',
        type: ConfigType.integer,
        required: true,
        validator: (value) {
          final timeout = value as int;
          if (timeout < 1) {
            throw ArgumentError(
              'database.connection.timeout must be positive',
            );
          }
          return value;
        },
      ),

      // Optional values (required: false)
      ConfigRequirement(
        key: 'cache.enabled',
        type: ConfigType.boolean,
        required: false,
      ),
      ConfigRequirement(
        key: 'app.features',
        type: ConfigType.list,
        required: false,
      ),
    ]);

    print('✓ Configuration validation passed!\n');
    print('All required configuration values are present and valid.');
    print('Application can start safely.\n');

    // Show validated configuration
    print('=== Validated Configuration ===\n');
    print('Database: ${config.getString('database.host')}:'
        '${config.getInt('database.port')}');
    print('Logging level: ${config.getString('logging.level')}');
    print('SSL enabled: ${config.getBool('database.connection.ssl_enabled')}');
    print('Connection timeout: '
        '${config.getInt('database.connection.timeout')}s');
  } on ValidationException catch (e) {
    // Validation failed - collect all errors
    print('✗ Configuration validation failed!\n');
    print('Errors:');
    for (final failure in e.failures) {
      print('  - $failure');
    }
    print('\nPlease fix the configuration errors and try again.');
    exit(1);
  } on ConfigException catch (e) {
    // Other configuration errors
    print('✗ Configuration error: ${e.message}');
    exit(1);
  }

  print('\n=== Testing Validation Failure ===\n');

  // Demonstrate validation failure with missing required key
  print('Creating configuration with missing required values...');

  try {
    // Create a minimal config that will fail validation
    final minimalConfig = Configuration([
      EnvironmentConfigProvider(prefix: 'MINIMAL'),
    ]);

    minimalConfig.validate([
      ConfigRequirement(
        key: 'required.missing.key',
        type: ConfigType.string,
        required: true,
      ),
      ConfigRequirement(
        key: 'another.missing.key',
        type: ConfigType.integer,
        required: true,
      ),
    ]);
  } on ValidationException catch (e) {
    print('Caught expected validation failure:');
    print('  ${e.message}');
    print('\nValidation collected ${e.failures.length} error(s):');
    for (final failure in e.failures) {
      print('  - $failure');
    }
  }

  print('\n=== Best Practices ===\n');
  print('1. Validate configuration at application startup');
  print('2. Define all required keys with expected types');
  print('3. Use custom validators for business rules');
  print('4. Fail fast with clear error messages');
  print('5. Collect all validation errors before failing');
}
