import 'package:dddart_config/dddart_config.dart';
import 'package:test/test.dart';

void main() {
  test('unprefixed shell metadata does not block construction or reload',
      () async {
    for (final ambientName in ['_', '_UNADDRESSABLE', 'TRAILING_']) {
      final source = <String, String>{
        ambientName: 'metadata',
        'DATABASE_HOST': 'before',
      };
      final provider = EnvironmentConfigProvider(environment: source);
      expect(provider.getString('database.host'), 'before');
      expect(provider.lookup('').value, {
        'database': {'host': 'before'},
      });
      source
        ..[ambientName] = 'updated metadata'
        ..['DATABASE_HOST'] = 'after';
      await provider.reload();
      expect(provider.getString('database.host'), 'after');
      expect(provider.lookup('database').value, {'host': 'after'});
    }
  });

  test('unprefixed configured path collisions remain errors', () {
    for (final source in [
      {'_': 'metadata', 'DATABASE': 'scalar', 'DATABASE_HOST': 'child'},
      {'_': 'metadata', 'DATABASE_HOST': 'one', 'database_host': 'two'},
    ]) {
      expect(
        () => EnvironmentConfigProvider(environment: source),
        throwsA(
          isA<ConfigException>().having(
            (error) => error.message,
            'message',
            contains('Conflicting environment paths'),
          ),
        ),
      );
    }
  });

  test('loads unprefixed environment strings as a structural map', () {
    final provider = EnvironmentConfigProvider(
      environment: {
        'PATH': '/bin:/usr/bin',
        'DATABASE_HOST': 'local',
        'DATABASE_PORT': '5432',
      },
    );
    expect(provider.getString('path'), '/bin:/usr/bin');
    expect(
      provider.lookup('database').value,
      {'host': 'local', 'port': '5432'},
    );
    expect(provider.getSection('database'), {'host': 'local', 'port': '5432'});
    expect(provider.lookup('missing').isPresent, isFalse);
    expect(provider.getSection('missing'), isEmpty);
  });

  test('matches the complete case-sensitive prefix boundary', () {
    final provider = EnvironmentConfigProvider(
      prefix: 'APP',
      environment: {
        'APP_DATABASE_HOST': 'prod',
        'APP2_DATABASE_HOST': 'other',
        'app_DATABASE_PORT': '1234',
        'UNRELATED': 'ignored',
      },
    );
    expect(provider.lookup('').value, {
      'database': {'host': 'prod'},
    });
    expect(provider.prefix, 'APP');
  });

  test('reload refreshes the source and removes old values', () async {
    final source = <String, String>{'APP_HOST': 'old'};
    final provider =
        EnvironmentConfigProvider(prefix: 'APP', environment: source);
    source
      ..clear()
      ..['APP_PORT'] = '5432';
    expect(provider.getString('host'), 'old');
    await provider.reload();
    expect(provider.getString('host'), isNull);
    expect(provider.getString('port'), '5432');
  });

  test('failed reload retains the last valid snapshot', () async {
    final source = <String, String>{'APP_DATABASE_HOST': 'prod'};
    final provider =
        EnvironmentConfigProvider(prefix: 'APP', environment: source);
    source['APP_DATABASE'] = 'invalid ancestor';
    await expectLater(provider.reload(), throwsA(isA<ConfigException>()));
    expect(provider.getString('database.host'), 'prod');
  });

  test('case-normalized duplicate and malformed paths fail clearly', () {
    for (final source in [
      {'APP_HOST': 'one', 'APP_host': 'two'},
      {'APP__HOST': 'one'},
      {'APP_': 'one'},
    ]) {
      expect(
        () => EnvironmentConfigProvider(prefix: 'APP', environment: source),
        throwsA(isA<ConfigException>()),
      );
    }
  });
}
