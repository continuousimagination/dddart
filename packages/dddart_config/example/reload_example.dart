// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';

import 'package:dddart_config/dddart_config.dart';

/// Demonstrates runtime configuration reload.
///
/// This example shows how to:
/// - Reload configuration from all providers
/// - Respond to configuration changes without restarting
/// - Handle reload failures gracefully
/// - Use reload in long-running applications
void main() async {
  print('=== Configuration Reload Example ===\n');

  // Create a temporary config file for this example
  final tempConfigFile = File('example/temp_config.yaml');
  await _writeConfigFile(tempConfigFile, version: 1);

  try {
    // Create configuration
    final config = Configuration([
      EnvironmentConfigProvider(prefix: 'MYAPP'),
      YamlConfigProvider(tempConfigFile.path),
    ]);

    print('Initial configuration loaded:');
    _printCurrentConfig(config);

    print('\n=== Simulating Configuration Changes ===\n');

    // Simulate a long-running application that needs to reload config
    for (var i = 2; i <= 4; i++) {
      print('Waiting 2 seconds before reload...');
      await Future<void>.delayed(const Duration(seconds: 2));

      print('\nUpdating configuration file (version $i)...');
      await _writeConfigFile(tempConfigFile, version: i);

      print('Reloading configuration...');
      try {
        await config.reload();
        print('✓ Configuration reloaded successfully\n');
        _printCurrentConfig(config);
      } on ConfigException catch (e) {
        print('✗ Reload failed: ${e.message}');
      }
    }

    print('\n=== Reload with Invalid Configuration ===\n');

    // Test reload with invalid YAML
    print('Writing invalid YAML to config file...');
    await tempConfigFile.writeAsString('invalid: yaml: content: [');

    try {
      await config.reload();
      print('✓ Reload succeeded (unexpected)');
    } on FileAccessException catch (e) {
      print('✗ Caught expected error during reload:');
      print('   ${e.message}');
    }

    // Restore valid configuration
    print('\nRestoring valid configuration...');
    await _writeConfigFile(tempConfigFile, version: 5);
    await config.reload();
    print('✓ Configuration restored\n');
    _printCurrentConfig(config);

    print('\n=== Reload with Environment Variables ===\n');

    // Environment variables are also reloaded
    print('Note: Environment variables are re-read from Platform.environment');
    print('In a real application, you might update environment variables');
    print(
        'through a configuration management system or container orchestration.');
    print('\nCurrent database.host: ${config.getString('database.host')}');
    print('To override, set: export MYAPP_DATABASE_HOST=new-host.example.com');

    print('\n=== Use Cases for Configuration Reload ===\n');
    print('1. Feature flags that change without redeployment');
    print('2. Adjusting log levels in production');
    print('3. Updating API endpoints or timeouts');
    print('4. Responding to configuration changes from external systems');
    print('5. Hot-reloading settings in long-running services');

    print('\n=== Best Practices ===\n');
    print('1. Reload configuration periodically or on signal');
    print('2. Handle reload failures gracefully (keep old config)');
    print('3. Log configuration changes for audit trail');
    print('4. Validate configuration after reload');
    print('5. Consider thread safety in concurrent applications');
  } finally {
    // Clean up temporary file
    if (await tempConfigFile.exists()) {
      await tempConfigFile.delete();
      print('\nCleaned up temporary config file.');
    }
  }
}

/// Writes a sample configuration file with version-specific values.
Future<void> _writeConfigFile(File file, {required int version}) async {
  final content = '''
# Configuration version $version
database:
  host: db-v$version.example.com
  port: ${5432 + version}
  name: myapp_v$version

app:
  version: 1.0.$version
  debug: ${version.isEven}

logging:
  level: ${_getLogLevel(version)}

api:
  timeout: ${30 + (version * 10)}
  retry_attempts: $version
''';

  await file.writeAsString(content);
}

/// Gets a log level based on version number.
String _getLogLevel(int version) {
  final levels = ['debug', 'info', 'warn', 'error'];
  return levels[(version - 1) % levels.length];
}

/// Prints current configuration values.
void _printCurrentConfig(Configuration config) {
  print('Current configuration:');
  print('  database.host: ${config.getString('database.host')}');
  print('  database.port: ${config.getInt('database.port')}');
  print('  database.name: ${config.getString('database.name')}');
  print('  app.version: ${config.getString('app.version')}');
  print('  app.debug: ${config.getBool('app.debug')}');
  print('  logging.level: ${config.getString('logging.level')}');
  print('  api.timeout: ${config.getInt('api.timeout')}');
  print('  api.retry_attempts: ${config.getInt('api.retry_attempts')}');
}
