// ignore_for_file: avoid_print

import 'package:dddart_config/dddart_config.dart';

/// Demonstrates accessing configuration sections.
///
/// This example shows how to:
/// - Retrieve entire configuration sections as maps
/// - Work with hierarchical configuration structures
/// - Build connection strings from configuration sections
/// - Iterate over related configuration values
void main() {
  // Create configuration
  final config = Configuration([
    EnvironmentConfigProvider(prefix: 'MYAPP'),
    YamlConfigProvider('example/config.yaml'),
  ]);

  print('=== Configuration Section Access ===\n');

  // Get entire database configuration section
  print('1. Database Configuration Section:');
  final dbConfig = config.getSection('database');
  print('   Keys in database section:');
  for (final entry in dbConfig.entries) {
    print('   - ${entry.key}: ${entry.value}');
  }

  // Get nested section
  print('\n2. Database Connection Section:');
  final connectionConfig = config.getSection('database.connection');
  print('   Keys in database.connection section:');
  for (final entry in connectionConfig.entries) {
    print('   - ${entry.key}: ${entry.value}');
  }

  // Get logging configuration section
  print('\n3. Logging Configuration Section:');
  final loggingConfig = config.getSection('logging');
  print('   Keys in logging section:');
  for (final entry in loggingConfig.entries) {
    print('   - ${entry.key}: ${entry.value}');
  }

  // Get API endpoints section
  print('\n4. API Endpoints Section:');
  final apiEndpoints = config.getSection('api.endpoints');
  print('   Available endpoints:');
  for (final entry in apiEndpoints.entries) {
    print('   - ${entry.key}: ${entry.value}');
  }

  print('\n=== Building Connection Strings ===\n');

  // Use section data to build a database connection string
  final host = dbConfig['host'] ?? 'localhost';
  final port = dbConfig['port'] ?? '5432';
  final name = dbConfig['name'] ?? 'mydb';
  final connectionString = 'postgresql://$host:$port/$name';
  print('Database connection string: $connectionString');

  // Build API URLs from section data
  print('\nAPI URLs:');
  final baseUrl = config.getString('api.base_url') ?? 'https://api.example.com';
  for (final entry in apiEndpoints.entries) {
    final fullUrl = '$baseUrl${entry.value}';
    print('  ${entry.key}: $fullUrl');
  }

  print('\n=== Section-Based Configuration Objects ===\n');

  // Create configuration objects from sections
  final dbSettings = DatabaseSettings.fromSection(dbConfig);
  print('Database Settings:');
  print('  Host: ${dbSettings.host}');
  print('  Port: ${dbSettings.port}');
  print('  Name: ${dbSettings.name}');

  final logSettings = LoggingSettings.fromSection(loggingConfig);
  print('\nLogging Settings:');
  print('  Level: ${logSettings.level}');
  print('  Console enabled: ${logSettings.consoleEnabled}');

  print('\n=== Merging Sections from Multiple Providers ===\n');

  // When multiple providers have the same section,
  // values are merged with precedence
  print('Section merging example:');
  print('  YAML provides: database.host = localhost');
  print('  Environment can override: MYAPP_DATABASE_HOST=production.db');
  print('  getSection("database") returns merged result');
  print('  Current database.host: ${dbConfig['host']}');

  print('\n=== Empty Sections ===\n');

  // Accessing non-existent sections returns empty map
  final emptySection = config.getSection('nonexistent.section');
  print('Non-existent section returns empty map: ${emptySection.isEmpty}');

  print('\n=== Use Cases for Section Access ===\n');
  print('1. Building connection strings from related values');
  print('2. Creating configuration objects for subsystems');
  print('3. Iterating over dynamic configuration (e.g., endpoints)');
  print('4. Passing configuration groups to components');
  print('5. Validating related configuration values together');
}

/// Example configuration object built from a section.
class DatabaseSettings {
  final String host;
  final int port;
  final String name;

  DatabaseSettings({
    required this.host,
    required this.port,
    required this.name,
  });

  /// Creates database settings from a configuration section.
  factory DatabaseSettings.fromSection(Map<String, String> section) {
    return DatabaseSettings(
      host: section['host'] ?? 'localhost',
      port: int.parse(section['port'] ?? '5432'),
      name: section['name'] ?? 'mydb',
    );
  }
}

/// Example logging configuration object.
class LoggingSettings {
  final String level;
  final bool consoleEnabled;

  LoggingSettings({
    required this.level,
    required this.consoleEnabled,
  });

  /// Creates logging settings from a configuration section.
  factory LoggingSettings.fromSection(Map<String, String> section) {
    return LoggingSettings(
      level: section['level'] ?? 'info',
      consoleEnabled: section['console.enabled']?.toLowerCase() == 'true',
    );
  }
}
