import 'dart:io';

import 'package:dddart_config/dddart_config.dart';
import 'package:test/test.dart';

class _TreeProvider extends ConfigProvider {
  _TreeProvider(Map<String, Object?> values)
      : _root = ConfigLookup.present(values);
  final ConfigLookup _root;

  @override
  ConfigLookup lookup(String path) => _root.at(path);

  @override
  Future<void> reload() async {}
}

void main() {
  late Directory directory;
  setUp(
    () => directory = Directory.systemTemp.createTempSync('structured_config_'),
  );
  tearDown(() => directory.deleteSync(recursive: true));

  Configuration yamlConfig(String source) {
    final file = File('${directory.path}/config.yaml')
      ..writeAsStringSync(source);
    return Configuration([YamlConfigProvider(file.path)]);
  }

  test('reads ordered records and native nested scalar values', () {
    final config = yamlConfig('''
projects:
  - organization: continuousimagination
    number: 12
  - organization: continuousimagination
    number: 34
nested:
  records: [[], {}, [true, null, 1.5, "a,b"]]
''');
    expect(config.getRequiredList('projects'), [
      {'organization': 'continuousimagination', 'number': 12},
      {'organization': 'continuousimagination', 'number': 34},
    ]);
    expect(
      (config.getRequiredList('projects').first! as Map)['number'],
      isA<int>(),
    );
    expect(config.getRequiredMap('nested')['records'], [
      <Object?>[],
      <String, Object?>{},
      [true, null, 1.5, 'a,b'],
    ]);
    expect(
      () => config.getString('projects'),
      throwsA(isA<TypeConversionException>()),
    );
  });

  test('distinguishes absent, null, empty string and empty collections', () {
    final config = yamlConfig('''
explicit_null: null
text: ''
list: []
map: {}
''');
    expect(config.lookup('missing').isPresent, isFalse);
    expect(config.lookup('explicit_null').isPresent, isTrue);
    expect(config.lookup('explicit_null').value, isNull);
    expect(config.getString('explicit_null'), isNull);
    expect(config.getString('text'), '');
    expect(config.getRequiredList('list'), isEmpty);
    expect(config.getRequiredMap('map'), isEmpty);
    expect(
      () => config.getRequiredInt('missing'),
      throwsA(isA<MissingConfigException>()),
    );
    expect(
      () => config.getRequiredInt('explicit_null'),
      throwsA(isA<TypeConversionException>()),
    );
  });

  test('maps merge by key and lists replace wholesale', () {
    final config = Configuration([
      _TreeProvider({
        'database': {'host': 'prod'},
        'projects': <Object?>[],
      }),
      _TreeProvider({
        'database': {'host': 'local', 'port': 5432},
        'projects': [1, 2],
      }),
    ]);
    expect(config.getRequiredMap('database'), {'host': 'prod', 'port': 5432});
    expect(config.getInt('database.port'), 5432);
    expect(config.getRequiredList('projects'), isEmpty);
  });

  for (final barrier in <Object?>[null, 'off', 42, <Object?>[]]) {
    for (final high in <Map<String, Object?>>[
      {'host': 'prod'},
      {},
    ]) {
      test(
          'three-provider barrier $barrier masks lower descendants with high $high',
          () {
        final config = Configuration([
          _TreeProvider({'database': high}),
          _TreeProvider({'database': barrier}),
          _TreeProvider({
            'database': {'port': 5432},
          }),
        ]);
        expect(config.getRequiredMap('database'), high);
        expect(config.lookup('database.port').isPresent, isFalse);
        expect(config.getInt('database.port'), isNull);
        expect(config.getRequiredMap('database').containsKey('port'), isFalse);
      });
    }
  }

  test('nested barriers and explicit null mask lower maps consistently', () {
    final config = Configuration([
      _TreeProvider({
        'app': {
          'database': {'host': 'prod'},
          'feature': null,
        },
      }),
      _TreeProvider({'app': null}),
      _TreeProvider({
        'app': {
          'database': {'port': 5432},
          'feature': true,
        },
      }),
    ]);
    expect(config.getRequiredMap('app'), {
      'database': {'host': 'prod'},
      'feature': null,
    });
    expect(config.contains('app.database.port'), isFalse);
    expect(config.contains('app.feature'), isTrue);
    expect(config.getBool('app.feature'), isNull);
  });

  test('empty maps merge but explicit null masks a subtree', () {
    final config = Configuration([
      _TreeProvider({'database': <String, Object?>{}, 'masked': null}),
      _TreeProvider({
        'database': {'port': 5432},
        'masked': {'secret': 'hidden'},
      }),
    ]);
    expect(config.getRequiredMap('database'), {'port': 5432});
    expect(config.contains('masked'), isTrue);
    expect(config.contains('masked.secret'), isFalse);
  });

  test('structured values are snapshots and deeply immutable', () {
    final source = <String, Object?>{
      'nested': <Object?>[
        <String, Object?>{'n': 1},
      ],
    };
    final provider = _TreeProvider(source);
    (source['nested']! as List).clear();
    final config = Configuration([provider]);
    final nested = config.getRequiredList('nested');
    expect(nested, [
      {'n': 1},
    ]);
    expect(() => nested.add(2), throwsUnsupportedError);
    expect(() => (nested.first! as Map)['n'] = 2, throwsUnsupportedError);
    expect(
      () => config.getRequiredMap('')['other'] = 1,
      throwsUnsupportedError,
    );
  });

  test('environment overrides keep strings and preserve map siblings', () {
    final environment = <String, String>{
      'APP_DATABASE_HOST': 'prod',
      'APP_LABEL': 'one,two',
      'APP_PORT': '5432',
      'APP_SLACK_BOT__TOKEN': 'token',
    };
    final config = Configuration([
      EnvironmentConfigProvider(prefix: 'APP', environment: environment),
      _TreeProvider({
        'database': {'port': 1000},
      }),
    ]);
    expect(config.getRequiredMap('database'), {'host': 'prod', 'port': 1000});
    expect(config.getString('label'), 'one,two');
    expect(config.getInt('port'), 5432);
    expect(config.getValue('port'), '5432');
    expect(config.getString('slack.bot_token'), 'token');
    expect(
      () => config.getList('label'),
      throwsA(isA<TypeConversionException>()),
    );
  });

  test('environment collisions are rejected regardless of source order', () {
    for (final values in [
      {'APP_DATABASE': 'secret-value', 'APP_DATABASE_PORT': '5432'},
      {'APP_DATABASE_PORT': '5432', 'APP_DATABASE': 'secret-value'},
    ]) {
      expect(
        () => EnvironmentConfigProvider(prefix: 'APP', environment: values),
        throwsA(
          isA<ConfigException>().having(
            (error) => error.toString(),
            'message',
            isNot(contains('secret-value')),
          ),
        ),
      );
    }
  });

  test('reload reads the current source without corrupting prior valid YAML',
      () async {
    final file = File('${directory.path}/reload.yaml')
      ..writeAsStringSync('number: 1');
    final provider = YamlConfigProvider(file.path);
    file.writeAsStringSync('number: 2');
    await provider.reload();
    expect(provider.lookup('number').value, 2);
    file.writeAsStringSync('secret: [invalid');
    await expectLater(provider.reload(), throwsA(isA<FileAccessException>()));
    expect(provider.lookup('number').value, 2);
  });

  test('type and validation failures identify paths without exposing secrets',
      () {
    final config = Configuration([
      _TreeProvider({'token': 'private-token', 'null': null}),
    ]);
    expect(
      () => config.getInt('token'),
      throwsA(
        isA<TypeConversionException>()
            .having((error) => error.key, 'key', 'token')
            .having(
              (error) => error.toString(),
              'message',
              isNot(contains('private-token')),
            ),
      ),
    );
    expect(
      () => config.validate([
        ConfigRequirement(
          key: 'token',
          type: ConfigType.string,
          validator: (value) => throw ArgumentError('invalid private-token'),
        ),
      ]),
      throwsA(
        isA<ValidationException>().having(
          (error) => error.toString(),
          'message',
          isNot(contains('private-token')),
        ),
      ),
    );
    expect(
      () => config.validate([
        ConfigRequirement(
          key: 'null',
          type: ConfigType.integer,
          required: false,
        ),
      ]),
      throwsA(isA<ValidationException>()),
    );
  });

  test('rejects unsupported YAML keys, values and cycles with path context',
      () {
    expect(() => yamlConfig('1: secret'), throwsA(isA<ConfigException>()));
    expect(
      () => ConfigLookup.present({'nested': DateTime(2026)}),
      throwsA(
        isA<TypeConversionException>()
            .having((error) => error.key, 'key', 'nested'),
      ),
    );
    final cycle = <Object?>[];
    cycle.add(cycle);
    expect(
      () => ConfigLookup.present({'cycle': cycle}),
      throwsA(isA<ConfigException>()),
    );
  });
}
