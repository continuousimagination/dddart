import 'dart:io';

import 'package:dddart_config/src/exceptions.dart';
import 'package:dddart_config/src/yaml_config_provider.dart';
import 'package:test/test.dart';

void main() {
  group('YamlConfigProvider', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('yaml_config_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    File createYamlFile(String filename, String content) {
      final file = File('${tempDir.path}/$filename');
      file.writeAsStringSync(content);
      return file;
    }

    group('constructor and loading', () {
      test('should load simple YAML configuration', () {
        final file = createYamlFile(
          'config.yaml',
          '''
app_name: MyApp
version: 1.0.0
debug: true
''',
        );

        final provider = YamlConfigProvider(file.path);

        expect(provider.getString('app_name'), equals('MyApp'));
        expect(provider.getString('version'), equals('1.0.0'));
        expect(provider.getString('debug'), equals('true'));
      });

      test('should load nested YAML configuration with dot notation', () {
        final file = createYamlFile(
          'config.yaml',
          '''
database:
  host: localhost
  port: 5432
  connection:
    timeout: 30
    pool_size: 10
''',
        );

        final provider = YamlConfigProvider(file.path);

        expect(provider.getString('database.host'), equals('localhost'));
        expect(provider.getString('database.port'), equals('5432'));
        expect(provider.getString('database.connection.timeout'), equals('30'));
        expect(
          provider.getString('database.connection.pool_size'),
          equals('10'),
        );
      });

      test('should convert YAML lists to comma-separated strings', () {
        final file = createYamlFile(
          'config.yaml',
          '''
features:
  - feature1
  - feature2
  - feature3
servers:
  - server1
  - server2
''',
        );

        final provider = YamlConfigProvider(file.path);

        expect(
          provider.getString('features'),
          equals('feature1,feature2,feature3'),
        );
        expect(provider.getString('servers'), equals('server1,server2'));
      });

      test('should handle empty YAML file', () {
        final file = createYamlFile('config.yaml', '');

        final provider = YamlConfigProvider(file.path);

        expect(provider.getString('any.key'), isNull);
      });

      test('should throw FileAccessException for missing file', () {
        expect(
          () => YamlConfigProvider('${tempDir.path}/nonexistent.yaml'),
          throwsA(isA<FileAccessException>()),
        );
      });

      test('should throw FileAccessException for invalid YAML', () {
        final file = createYamlFile(
          'config.yaml',
          '''
invalid: yaml: content:
  - broken
    indentation
''',
        );

        expect(
          () => YamlConfigProvider(file.path),
          throwsA(isA<FileAccessException>()),
        );
      });
    });

    group('getString', () {
      test('should return null for non-existent keys', () {
        final file = createYamlFile(
          'config.yaml',
          '''
existing_key: value
''',
        );

        final provider = YamlConfigProvider(file.path);

        expect(provider.getString('non_existent_key'), isNull);
        expect(provider.getString('nested.non.existent'), isNull);
      });

      test('should handle numeric values as strings', () {
        final file = createYamlFile(
          'config.yaml',
          '''
integer: 42
float: 3.14
scientific: 1.5e10
''',
        );

        final provider = YamlConfigProvider(file.path);

        expect(provider.getString('integer'), equals('42'));
        expect(provider.getString('float'), equals('3.14'));
        expect(provider.getString('scientific'), equals('15000000000.0'));
      });

      test('should handle boolean values as strings', () {
        final file = createYamlFile(
          'config.yaml',
          '''
enabled: true
disabled: false
''',
        );

        final provider = YamlConfigProvider(file.path);

        expect(provider.getString('enabled'), equals('true'));
        expect(provider.getString('disabled'), equals('false'));
      });

      test('should not store null values', () {
        final file = createYamlFile(
          'config.yaml',
          '''
key_with_value: value
key_with_null: null
''',
        );

        final provider = YamlConfigProvider(file.path);

        expect(provider.getString('key_with_value'), equals('value'));
        expect(provider.getString('key_with_null'), isNull);
      });
    });

    group('getSection', () {
      test('should retrieve all keys with given prefix', () {
        final file = createYamlFile(
          'config.yaml',
          '''
database:
  host: localhost
  port: 5432
  name: mydb
logging:
  level: info
''',
        );

        final provider = YamlConfigProvider(file.path);
        final section = provider.getSection('database');

        expect(section, hasLength(3));
        expect(section['host'], equals('localhost'));
        expect(section['port'], equals('5432'));
        expect(section['name'], equals('mydb'));
      });

      test('should return empty map for non-existent prefix', () {
        final file = createYamlFile(
          'config.yaml',
          '''
existing:
  key: value
''',
        );

        final provider = YamlConfigProvider(file.path);
        final section = provider.getSection('nonexistent');

        expect(section, isEmpty);
      });

      test('should handle nested sections', () {
        final file = createYamlFile(
          'config.yaml',
          '''
database:
  connection:
    timeout: 30
    pool_size: 10
    retry:
      max_attempts: 3
''',
        );

        final provider = YamlConfigProvider(file.path);
        final section = provider.getSection('database.connection');

        expect(section, hasLength(3));
        expect(section['timeout'], equals('30'));
        expect(section['pool_size'], equals('10'));
        expect(section['retry.max_attempts'], equals('3'));
      });

      test('should not include keys that only partially match prefix', () {
        final file = createYamlFile(
          'config.yaml',
          '''
database_backup: value2
database:
  host: localhost
''',
        );

        final provider = YamlConfigProvider(file.path);
        final section = provider.getSection('database');

        expect(section, hasLength(1));
        expect(section['host'], equals('localhost'));
        expect(section.containsKey('_backup'), isFalse);
      });
    });

    group('reload', () {
      test('should reload configuration from file', () async {
        final file = createYamlFile(
          'config.yaml',
          '''
value: original
''',
        );

        final provider = YamlConfigProvider(file.path);
        expect(provider.getString('value'), equals('original'));

        // Modify the file
        file.writeAsStringSync('''
value: updated
''');

        await provider.reload();
        expect(provider.getString('value'), equals('updated'));
      });

      test('should clear old values on reload', () async {
        final file = createYamlFile(
          'config.yaml',
          '''
old_key: old_value
shared_key: original
''',
        );

        final provider = YamlConfigProvider(file.path);
        expect(provider.getString('old_key'), equals('old_value'));
        expect(provider.getString('shared_key'), equals('original'));

        // Replace with new configuration
        file.writeAsStringSync('''
new_key: new_value
shared_key: updated
''');

        await provider.reload();
        expect(provider.getString('old_key'), isNull);
        expect(provider.getString('new_key'), equals('new_value'));
        expect(provider.getString('shared_key'), equals('updated'));
      });

      test('should throw FileAccessException if file deleted', () async {
        final file = createYamlFile(
          'config.yaml',
          '''
value: original
''',
        );

        final provider = YamlConfigProvider(file.path);
        expect(provider.getString('value'), equals('original'));

        // Delete the file
        file.deleteSync();

        expect(
          provider.reload,
          throwsA(isA<FileAccessException>()),
        );
      });

      test('should throw FileAccessException if file becomes invalid',
          () async {
        final file = createYamlFile(
          'config.yaml',
          '''
value: original
''',
        );

        final provider = YamlConfigProvider(file.path);
        expect(provider.getString('value'), equals('original'));

        // Write invalid YAML
        file.writeAsStringSync('invalid: yaml: syntax:');

        expect(
          provider.reload,
          throwsA(isA<FileAccessException>()),
        );
      });
    });

    group('complex scenarios', () {
      test('should handle mixed nested structures', () {
        final file = createYamlFile(
          'config.yaml',
          '''
app:
  name: MyApp
  features:
    - auth
    - logging
  database:
    primary:
      host: localhost
      port: 5432
    replicas:
      - replica1
      - replica2
''',
        );

        final provider = YamlConfigProvider(file.path);

        expect(provider.getString('app.name'), equals('MyApp'));
        expect(provider.getString('app.features'), equals('auth,logging'));
        expect(
          provider.getString('app.database.primary.host'),
          equals('localhost'),
        );
        expect(provider.getString('app.database.primary.port'), equals('5432'));
        expect(
          provider.getString('app.database.replicas'),
          equals('replica1,replica2'),
        );
      });

      test('should handle empty lists', () {
        final file = createYamlFile(
          'config.yaml',
          '''
empty_list: []
''',
        );

        final provider = YamlConfigProvider(file.path);

        expect(provider.getString('empty_list'), equals(''));
      });
    });
  });
}
