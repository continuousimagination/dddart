import 'package:dddart_config/dddart_config.dart';
import 'package:test/test.dart';

/// Mock provider for testing
class MockConfigProvider implements ConfigProvider {
  MockConfigProvider(this._data);

  final Map<String, String> _data;
  bool reloadCalled = false;
  bool shouldFailReload = false;

  @override
  String? getString(String key) => _data[key];

  @override
  Map<String, String> getSection(String prefix) {
    final result = <String, String>{};
    final prefixWithDot = prefix.endsWith('.') ? prefix : '$prefix.';

    for (final entry in _data.entries) {
      if (entry.key.startsWith(prefixWithDot)) {
        final keyWithoutPrefix = entry.key.substring(prefixWithDot.length);
        result[keyWithoutPrefix] = entry.value;
      }
    }

    return result;
  }

  @override
  Future<void> reload() async {
    reloadCalled = true;
    if (shouldFailReload) {
      throw Exception('Reload failed');
    }
  }
}

void main() {
  group('Configuration', () {
    group('constructor', () {
      test('should create configuration with single provider', () {
        final provider = MockConfigProvider({'key': 'value'});
        final config = Configuration([provider]);

        expect(config.getString('key'), equals('value'));
      });

      test('should create configuration with multiple providers', () {
        final provider1 = MockConfigProvider({'key1': 'value1'});
        final provider2 = MockConfigProvider({'key2': 'value2'});
        final config = Configuration([provider1, provider2]);

        expect(config.getString('key1'), equals('value1'));
        expect(config.getString('key2'), equals('value2'));
      });

      test('should throw ArgumentError when providers list is empty', () {
        expect(
          () => Configuration([]),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('getString', () {
      test('should return value from first provider with key', () {
        final provider1 = MockConfigProvider({'key': 'value1'});
        final provider2 = MockConfigProvider({'key': 'value2'});
        final config = Configuration([provider1, provider2]);

        expect(config.getString('key'), equals('value1'));
      });

      test('should return value from second provider if first has no value',
          () {
        final provider1 = MockConfigProvider({'other': 'value'});
        final provider2 = MockConfigProvider({'key': 'value2'});
        final config = Configuration([provider1, provider2]);

        expect(config.getString('key'), equals('value2'));
      });

      test('should return null if no provider has the key', () {
        final provider1 = MockConfigProvider({'key1': 'value1'});
        final provider2 = MockConfigProvider({'key2': 'value2'});
        final config = Configuration([provider1, provider2]);

        expect(config.getString('nonexistent'), isNull);
      });

      test('should support dot notation keys', () {
        final provider = MockConfigProvider({
          'database.host': 'localhost',
          'database.port': '5432',
        });
        final config = Configuration([provider]);

        expect(config.getString('database.host'), equals('localhost'));
        expect(config.getString('database.port'), equals('5432'));
      });
    });

    group('getSection', () {
      test('should return section from single provider', () {
        final provider = MockConfigProvider({
          'database.host': 'localhost',
          'database.port': '5432',
          'database.name': 'mydb',
        });
        final config = Configuration([provider]);

        final section = config.getSection('database');

        expect(
          section,
          equals({
            'host': 'localhost',
            'port': '5432',
            'name': 'mydb',
          }),
        );
      });

      test('should merge sections from multiple providers', () {
        final provider1 = MockConfigProvider({
          'database.host': 'prod.example.com',
        });
        final provider2 = MockConfigProvider({
          'database.host': 'localhost',
          'database.port': '5432',
        });
        final config = Configuration([provider1, provider2]);

        final section = config.getSection('database');

        expect(
          section,
          equals({
            'host': 'prod.example.com', // From provider1 (higher precedence)
            'port': '5432', // From provider2
          }),
        );
      });

      test('should return empty map if no keys match prefix', () {
        final provider = MockConfigProvider({
          'database.host': 'localhost',
        });
        final config = Configuration([provider]);

        final section = config.getSection('logging');

        expect(section, isEmpty);
      });

      test('should handle multiple levels of nesting', () {
        final provider = MockConfigProvider({
          'database.connection.host': 'localhost',
          'database.connection.port': '5432',
          'database.pool.size': '10',
        });
        final config = Configuration([provider]);

        final section = config.getSection('database.connection');

        expect(
          section,
          equals({
            'host': 'localhost',
            'port': '5432',
          }),
        );
      });
    });

    group('reload', () {
      test('should call reload on all providers', () async {
        final provider1 = MockConfigProvider({'key1': 'value1'});
        final provider2 = MockConfigProvider({'key2': 'value2'});
        final config = Configuration([provider1, provider2]);

        await config.reload();

        expect(provider1.reloadCalled, isTrue);
        expect(provider2.reloadCalled, isTrue);
      });

      test('should throw ConfigException if provider reload fails', () async {
        final provider1 = MockConfigProvider({'key1': 'value1'});
        final provider2 = MockConfigProvider({'key2': 'value2'})
          ..shouldFailReload = true;
        final config = Configuration([provider1, provider2]);

        expect(
          config.reload,
          throwsA(isA<ConfigException>()),
        );
      });

      test('should include provider index in error message', () async {
        final provider1 = MockConfigProvider({'key1': 'value1'});
        final provider2 = MockConfigProvider({'key2': 'value2'})
          ..shouldFailReload = true;
        final config = Configuration([provider1, provider2]);

        try {
          await config.reload();
          fail('Should have thrown ConfigException');
        } on ConfigException catch (e) {
          expect(e.message, contains('index 1'));
        }
      });
    });

    group('provider precedence', () {
      test('should respect provider order for getString', () {
        final envProvider = MockConfigProvider({
          'database.host': 'env-host',
          'database.port': '3000',
        });
        final yamlProvider = MockConfigProvider({
          'database.host': 'yaml-host',
          'database.port': '5432',
          'database.name': 'mydb',
        });
        final config = Configuration([envProvider, yamlProvider]);

        expect(config.getString('database.host'), equals('env-host'));
        expect(config.getString('database.port'), equals('3000'));
        expect(config.getString('database.name'), equals('mydb'));
      });

      test('should respect provider order for getSection', () {
        final envProvider = MockConfigProvider({
          'database.host': 'env-host',
        });
        final yamlProvider = MockConfigProvider({
          'database.host': 'yaml-host',
          'database.port': '5432',
        });
        final config = Configuration([envProvider, yamlProvider]);

        final section = config.getSection('database');

        expect(section['host'], equals('env-host'));
        expect(section['port'], equals('5432'));
      });
    });

    group('getRequiredString', () {
      test('should return value when key exists', () {
        final provider = MockConfigProvider({'key': 'value'});
        final config = Configuration([provider]);

        expect(config.getRequiredString('key'), equals('value'));
      });

      test('should throw MissingConfigException when key does not exist', () {
        final provider = MockConfigProvider({});
        final config = Configuration([provider]);

        expect(
          () => config.getRequiredString('missing'),
          throwsA(isA<MissingConfigException>()),
        );
      });
    });

    group('getStringOrDefault', () {
      test('should return value when key exists', () {
        final provider = MockConfigProvider({'key': 'value'});
        final config = Configuration([provider]);

        expect(config.getStringOrDefault('key', 'default'), equals('value'));
      });

      test('should return default when key does not exist', () {
        final provider = MockConfigProvider({});
        final config = Configuration([provider]);

        expect(
          config.getStringOrDefault('missing', 'default'),
          equals('default'),
        );
      });
    });

    group('getInt', () {
      test('should convert valid integer string', () {
        final provider = MockConfigProvider({'port': '5432'});
        final config = Configuration([provider]);

        expect(config.getInt('port'), equals(5432));
      });

      test('should return null when key does not exist', () {
        final provider = MockConfigProvider({});
        final config = Configuration([provider]);

        expect(config.getInt('missing'), isNull);
      });

      test('should throw TypeConversionException for invalid integer', () {
        final provider = MockConfigProvider({'port': 'abc'});
        final config = Configuration([provider]);

        expect(
          () => config.getInt('port'),
          throwsA(isA<TypeConversionException>()),
        );
      });
    });

    group('getRequiredInt', () {
      test('should convert valid integer string', () {
        final provider = MockConfigProvider({'port': '5432'});
        final config = Configuration([provider]);

        expect(config.getRequiredInt('port'), equals(5432));
      });

      test('should throw MissingConfigException when key does not exist', () {
        final provider = MockConfigProvider({});
        final config = Configuration([provider]);

        expect(
          () => config.getRequiredInt('missing'),
          throwsA(isA<MissingConfigException>()),
        );
      });

      test('should throw TypeConversionException for invalid integer', () {
        final provider = MockConfigProvider({'port': 'abc'});
        final config = Configuration([provider]);

        expect(
          () => config.getRequiredInt('port'),
          throwsA(isA<TypeConversionException>()),
        );
      });
    });

    group('getIntOrDefault', () {
      test('should convert valid integer string', () {
        final provider = MockConfigProvider({'port': '5432'});
        final config = Configuration([provider]);

        expect(config.getIntOrDefault('port', 3000), equals(5432));
      });

      test('should return default when key does not exist', () {
        final provider = MockConfigProvider({});
        final config = Configuration([provider]);

        expect(config.getIntOrDefault('missing', 3000), equals(3000));
      });

      test('should throw TypeConversionException for invalid integer', () {
        final provider = MockConfigProvider({'port': 'abc'});
        final config = Configuration([provider]);

        expect(
          () => config.getIntOrDefault('port', 3000),
          throwsA(isA<TypeConversionException>()),
        );
      });
    });

    group('getDouble', () {
      test('should convert valid double string', () {
        final provider = MockConfigProvider({'timeout': '30.5'});
        final config = Configuration([provider]);

        expect(config.getDouble('timeout'), equals(30.5));
      });

      test('should return null when key does not exist', () {
        final provider = MockConfigProvider({});
        final config = Configuration([provider]);

        expect(config.getDouble('missing'), isNull);
      });

      test('should throw TypeConversionException for invalid double', () {
        final provider = MockConfigProvider({'timeout': 'abc'});
        final config = Configuration([provider]);

        expect(
          () => config.getDouble('timeout'),
          throwsA(isA<TypeConversionException>()),
        );
      });
    });

    group('getRequiredDouble', () {
      test('should convert valid double string', () {
        final provider = MockConfigProvider({'timeout': '30.5'});
        final config = Configuration([provider]);

        expect(config.getRequiredDouble('timeout'), equals(30.5));
      });

      test('should throw MissingConfigException when key does not exist', () {
        final provider = MockConfigProvider({});
        final config = Configuration([provider]);

        expect(
          () => config.getRequiredDouble('missing'),
          throwsA(isA<MissingConfigException>()),
        );
      });

      test('should throw TypeConversionException for invalid double', () {
        final provider = MockConfigProvider({'timeout': 'abc'});
        final config = Configuration([provider]);

        expect(
          () => config.getRequiredDouble('timeout'),
          throwsA(isA<TypeConversionException>()),
        );
      });
    });

    group('getDoubleOrDefault', () {
      test('should convert valid double string', () {
        final provider = MockConfigProvider({'timeout': '30.5'});
        final config = Configuration([provider]);

        expect(config.getDoubleOrDefault('timeout', 10), equals(30.5));
      });

      test('should return default when key does not exist', () {
        final provider = MockConfigProvider({});
        final config = Configuration([provider]);

        expect(config.getDoubleOrDefault('missing', 10), equals(10.0));
      });

      test('should throw TypeConversionException for invalid double', () {
        final provider = MockConfigProvider({'timeout': 'abc'});
        final config = Configuration([provider]);

        expect(
          () => config.getDoubleOrDefault('timeout', 10),
          throwsA(isA<TypeConversionException>()),
        );
      });
    });

    group('getBool', () {
      test('should convert "true" to true', () {
        final provider = MockConfigProvider({'debug': 'true'});
        final config = Configuration([provider]);

        expect(config.getBool('debug'), isTrue);
      });

      test('should convert "false" to false', () {
        final provider = MockConfigProvider({'debug': 'false'});
        final config = Configuration([provider]);

        expect(config.getBool('debug'), isFalse);
      });

      test('should convert "1" to true', () {
        final provider = MockConfigProvider({'debug': '1'});
        final config = Configuration([provider]);

        expect(config.getBool('debug'), isTrue);
      });

      test('should convert "0" to false', () {
        final provider = MockConfigProvider({'debug': '0'});
        final config = Configuration([provider]);

        expect(config.getBool('debug'), isFalse);
      });

      test('should convert "yes" to true', () {
        final provider = MockConfigProvider({'debug': 'yes'});
        final config = Configuration([provider]);

        expect(config.getBool('debug'), isTrue);
      });

      test('should convert "no" to false', () {
        final provider = MockConfigProvider({'debug': 'no'});
        final config = Configuration([provider]);

        expect(config.getBool('debug'), isFalse);
      });

      test('should convert "on" to true', () {
        final provider = MockConfigProvider({'debug': 'on'});
        final config = Configuration([provider]);

        expect(config.getBool('debug'), isTrue);
      });

      test('should convert "off" to false', () {
        final provider = MockConfigProvider({'debug': 'off'});
        final config = Configuration([provider]);

        expect(config.getBool('debug'), isFalse);
      });

      test('should be case-insensitive', () {
        final provider = MockConfigProvider({
          'debug1': 'TRUE',
          'debug2': 'False',
          'debug3': 'YES',
          'debug4': 'No',
        });
        final config = Configuration([provider]);

        expect(config.getBool('debug1'), isTrue);
        expect(config.getBool('debug2'), isFalse);
        expect(config.getBool('debug3'), isTrue);
        expect(config.getBool('debug4'), isFalse);
      });

      test('should return null when key does not exist', () {
        final provider = MockConfigProvider({});
        final config = Configuration([provider]);

        expect(config.getBool('missing'), isNull);
      });

      test('should throw TypeConversionException for invalid boolean', () {
        final provider = MockConfigProvider({'debug': 'maybe'});
        final config = Configuration([provider]);

        expect(
          () => config.getBool('debug'),
          throwsA(isA<TypeConversionException>()),
        );
      });
    });

    group('getRequiredBool', () {
      test('should convert valid boolean string', () {
        final provider = MockConfigProvider({'debug': 'true'});
        final config = Configuration([provider]);

        expect(config.getRequiredBool('debug'), isTrue);
      });

      test('should throw MissingConfigException when key does not exist', () {
        final provider = MockConfigProvider({});
        final config = Configuration([provider]);

        expect(
          () => config.getRequiredBool('missing'),
          throwsA(isA<MissingConfigException>()),
        );
      });

      test('should throw TypeConversionException for invalid boolean', () {
        final provider = MockConfigProvider({'debug': 'maybe'});
        final config = Configuration([provider]);

        expect(
          () => config.getRequiredBool('debug'),
          throwsA(isA<TypeConversionException>()),
        );
      });
    });

    group('getBoolOrDefault', () {
      test('should convert valid boolean string', () {
        final provider = MockConfigProvider({'debug': 'true'});
        final config = Configuration([provider]);

        expect(config.getBoolOrDefault('debug', false), isTrue);
      });

      test('should return default when key does not exist', () {
        final provider = MockConfigProvider({});
        final config = Configuration([provider]);

        expect(config.getBoolOrDefault('missing', true), isTrue);
      });

      test('should throw TypeConversionException for invalid boolean', () {
        final provider = MockConfigProvider({'debug': 'maybe'});
        final config = Configuration([provider]);

        expect(
          () => config.getBoolOrDefault('debug', false),
          throwsA(isA<TypeConversionException>()),
        );
      });
    });

    group('getList', () {
      test('should split comma-separated values', () {
        final provider = MockConfigProvider({'hosts': 'host1,host2,host3'});
        final config = Configuration([provider]);

        expect(config.getList('hosts'), equals(['host1', 'host2', 'host3']));
      });

      test('should trim whitespace from elements', () {
        final provider = MockConfigProvider({'hosts': 'host1, host2 , host3'});
        final config = Configuration([provider]);

        expect(config.getList('hosts'), equals(['host1', 'host2', 'host3']));
      });

      test('should return empty list for empty string', () {
        final provider = MockConfigProvider({'hosts': ''});
        final config = Configuration([provider]);

        expect(config.getList('hosts'), isEmpty);
      });

      test('should return null when key does not exist', () {
        final provider = MockConfigProvider({});
        final config = Configuration([provider]);

        expect(config.getList('missing'), isNull);
      });

      test('should handle single value', () {
        final provider = MockConfigProvider({'hosts': 'host1'});
        final config = Configuration([provider]);

        expect(config.getList('hosts'), equals(['host1']));
      });
    });

    group('getRequiredList', () {
      test('should split comma-separated values', () {
        final provider = MockConfigProvider({'hosts': 'host1,host2,host3'});
        final config = Configuration([provider]);

        expect(
          config.getRequiredList('hosts'),
          equals(['host1', 'host2', 'host3']),
        );
      });

      test('should throw MissingConfigException when key does not exist', () {
        final provider = MockConfigProvider({});
        final config = Configuration([provider]);

        expect(
          () => config.getRequiredList('missing'),
          throwsA(isA<MissingConfigException>()),
        );
      });
    });

    group('getListOrDefault', () {
      test('should split comma-separated values', () {
        final provider = MockConfigProvider({'hosts': 'host1,host2,host3'});
        final config = Configuration([provider]);

        expect(
          config.getListOrDefault('hosts', ['default']),
          equals(['host1', 'host2', 'host3']),
        );
      });

      test('should return default when key does not exist', () {
        final provider = MockConfigProvider({});
        final config = Configuration([provider]);

        expect(
          config.getListOrDefault('missing', ['default1', 'default2']),
          equals(['default1', 'default2']),
        );
      });
    });

    group('validate', () {
      test('should pass validation when all requirements are met', () {
        final provider = MockConfigProvider({
          'database.host': 'localhost',
          'database.port': '5432',
          'debug': 'true',
        });
        final config = Configuration([provider]);

        expect(
          () => config.validate([
            ConfigRequirement(
              key: 'database.host',
              type: ConfigType.string,
            ),
            ConfigRequirement(
              key: 'database.port',
              type: ConfigType.integer,
            ),
            ConfigRequirement(
              key: 'debug',
              type: ConfigType.boolean,
            ),
          ]),
          returnsNormally,
        );
      });

      test('should throw ValidationException when required key is missing', () {
        final provider = MockConfigProvider({});
        final config = Configuration([provider]);

        expect(
          () => config.validate([
            ConfigRequirement(
              key: 'database.host',
              type: ConfigType.string,
            ),
          ]),
          throwsA(isA<ValidationException>()),
        );
      });

      test('should collect all missing required keys', () {
        final provider = MockConfigProvider({});
        final config = Configuration([provider]);

        try {
          config.validate([
            ConfigRequirement(
              key: 'database.host',
              type: ConfigType.string,
            ),
            ConfigRequirement(
              key: 'database.port',
              type: ConfigType.integer,
            ),
          ]);
          fail('Should have thrown ValidationException');
        } on ValidationException catch (e) {
          expect(e.failures, hasLength(2));
          expect(e.failures, contains('database.host is required'));
          expect(e.failures, contains('database.port is required'));
        }
      });

      test('should not fail for missing optional keys', () {
        final provider = MockConfigProvider({
          'database.host': 'localhost',
        });
        final config = Configuration([provider]);

        expect(
          () => config.validate([
            ConfigRequirement(
              key: 'database.host',
              type: ConfigType.string,
            ),
            ConfigRequirement(
              key: 'database.port',
              type: ConfigType.integer,
              required: false,
            ),
          ]),
          returnsNormally,
        );
      });

      test('should validate type conversion for integer', () {
        final provider = MockConfigProvider({
          'database.port': 'not-a-number',
        });
        final config = Configuration([provider]);

        try {
          config.validate([
            ConfigRequirement(
              key: 'database.port',
              type: ConfigType.integer,
            ),
          ]);
          fail('Should have thrown ValidationException');
        } on ValidationException catch (e) {
          expect(e.failures, hasLength(1));
          expect(
            e.failures.first,
            contains('database.port must be a valid integer'),
          );
        }
      });

      test('should validate type conversion for double', () {
        final provider = MockConfigProvider({
          'timeout': 'not-a-number',
        });
        final config = Configuration([provider]);

        try {
          config.validate([
            ConfigRequirement(
              key: 'timeout',
              type: ConfigType.double,
            ),
          ]);
          fail('Should have thrown ValidationException');
        } on ValidationException catch (e) {
          expect(e.failures, hasLength(1));
          expect(e.failures.first, contains('timeout must be a valid double'));
        }
      });

      test('should validate type conversion for boolean', () {
        final provider = MockConfigProvider({
          'debug': 'maybe',
        });
        final config = Configuration([provider]);

        try {
          config.validate([
            ConfigRequirement(
              key: 'debug',
              type: ConfigType.boolean,
            ),
          ]);
          fail('Should have thrown ValidationException');
        } on ValidationException catch (e) {
          expect(e.failures, hasLength(1));
          expect(e.failures.first, contains('debug must be a valid boolean'));
        }
      });

      test('should validate list type', () {
        final provider = MockConfigProvider({
          'hosts': 'host1,host2,host3',
        });
        final config = Configuration([provider]);

        expect(
          () => config.validate([
            ConfigRequirement(
              key: 'hosts',
              type: ConfigType.list,
            ),
          ]),
          returnsNormally,
        );
      });

      test('should validate string type', () {
        final provider = MockConfigProvider({
          'name': 'myapp',
        });
        final config = Configuration([provider]);

        expect(
          () => config.validate([
            ConfigRequirement(
              key: 'name',
              type: ConfigType.string,
            ),
          ]),
          returnsNormally,
        );
      });

      test('should execute custom validator when provided', () {
        final provider = MockConfigProvider({
          'database.port': '5432',
        });
        final config = Configuration([provider]);

        var validatorCalled = false;

        expect(
          () => config.validate([
            ConfigRequirement(
              key: 'database.port',
              type: ConfigType.integer,
              validator: (value) {
                validatorCalled = true;
                expect(value, equals(5432));
                return value;
              },
            ),
          ]),
          returnsNormally,
        );

        expect(validatorCalled, isTrue);
      });

      test('should fail validation when custom validator throws', () {
        final provider = MockConfigProvider({
          'database.port': '99999',
        });
        final config = Configuration([provider]);

        try {
          config.validate([
            ConfigRequirement(
              key: 'database.port',
              type: ConfigType.integer,
              validator: (value) {
                final port = value as int;
                if (port < 1 || port > 65535) {
                  throw ArgumentError('Port must be between 1 and 65535');
                }
                return value;
              },
            ),
          ]);
          fail('Should have thrown ValidationException');
        } on ValidationException catch (e) {
          expect(e.failures, hasLength(1));
          expect(e.failures.first, contains('database.port validation failed'));
          expect(
            e.failures.first,
            contains('Port must be between 1 and 65535'),
          );
        }
      });

      test('should collect all validation failures', () {
        final provider = MockConfigProvider({
          'database.port': 'not-a-number',
          'timeout': 'invalid',
          'debug': 'maybe',
        });
        final config = Configuration([provider]);

        try {
          config.validate([
            ConfigRequirement(
              key: 'database.host',
              type: ConfigType.string,
            ),
            ConfigRequirement(
              key: 'database.port',
              type: ConfigType.integer,
            ),
            ConfigRequirement(
              key: 'timeout',
              type: ConfigType.double,
            ),
            ConfigRequirement(
              key: 'debug',
              type: ConfigType.boolean,
            ),
          ]);
          fail('Should have thrown ValidationException');
        } on ValidationException catch (e) {
          expect(e.failures, hasLength(4));
          expect(e.failures, contains('database.host is required'));
          expect(e.failures, contains('database.port must be a valid integer'));
          expect(e.failures, contains('timeout must be a valid double'));
          expect(e.failures, contains('debug must be a valid boolean'));
        }
      });

      test('should validate with custom validator for string values', () {
        final provider = MockConfigProvider({
          'logging.level': 'invalid',
        });
        final config = Configuration([provider]);

        try {
          config.validate([
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
          fail('Should have thrown ValidationException');
        } on ValidationException catch (e) {
          expect(e.failures, hasLength(1));
          expect(e.failures.first, contains('logging.level validation failed'));
          expect(e.failures.first, contains('Must be one of'));
        }
      });

      test('should not run validator if type conversion fails', () {
        final provider = MockConfigProvider({
          'database.port': 'not-a-number',
        });
        final config = Configuration([provider]);

        var validatorCalled = false;

        try {
          config.validate([
            ConfigRequirement(
              key: 'database.port',
              type: ConfigType.integer,
              validator: (value) {
                validatorCalled = true;
                return value;
              },
            ),
          ]);
          fail('Should have thrown ValidationException');
        } on ValidationException catch (e) {
          expect(validatorCalled, isFalse);
          expect(e.failures, hasLength(1));
          expect(e.failures.first, contains('must be a valid integer'));
        }
      });

      test('should handle empty list validation', () {
        final provider = MockConfigProvider({
          'hosts': '',
        });
        final config = Configuration([provider]);

        expect(
          () => config.validate([
            ConfigRequirement(
              key: 'hosts',
              type: ConfigType.list,
            ),
          ]),
          returnsNormally,
        );
      });
    });
  });
}
