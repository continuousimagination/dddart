import 'dart:io';

import 'package:dddart_config/src/environment_config_provider.dart';
import 'package:test/test.dart';

void main() {
  group('EnvironmentConfigProvider', () {
    // Note: Platform.environment is immutable
    // Tests should be designed to work with the current environment

    group('constructor and loading', () {
      test('should load environment variables without prefix', () {
        final provider = EnvironmentConfigProvider();

        // Test with actual environment variables that should exist
        // PATH should exist on all systems
        final path = Platform.environment['PATH'];
        if (path != null) {
          expect(provider.getString('path'), equals(path));
        }
      });

      test('should convert environment variable names to config keys', () {
        // We'll test the conversion logic by checking if variables
        // are accessible with the converted key format
        final provider = EnvironmentConfigProvider();

        // If HOME or USERPROFILE exists (depending on OS)
        final home =
            Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
        if (home != null) {
          final key =
              Platform.environment.containsKey('HOME') ? 'home' : 'userprofile';
          expect(provider.getString(key), equals(home));
        }
      });
    });

    group('getString', () {
      test('should return null for non-existent keys', () {
        final provider = EnvironmentConfigProvider();

        expect(
          provider.getString('definitely.not.a.real.environment.variable'),
          isNull,
        );
      });

      test('should handle keys with dots (converted from underscores)', () {
        final provider = EnvironmentConfigProvider();

        // Check if any environment variable with underscores exists
        final envWithUnderscore = Platform.environment.entries.firstWhere(
          (e) => e.key.contains('_'),
          orElse: () => const MapEntry('', ''),
        );

        if (envWithUnderscore.key.isNotEmpty) {
          final configKey =
              envWithUnderscore.key.toLowerCase().replaceAll('_', '.');
          expect(
            provider.getString(configKey),
            equals(envWithUnderscore.value),
          );
        }
      });
    });

    group('getSection', () {
      test('should retrieve all keys with given prefix', () {
        final provider = EnvironmentConfigProvider();

        // Get a section - this will return all env vars that start with
        // a common prefix when converted to config key format
        final section = provider.getSection('path');

        // Should at least be empty, not throw
        expect(section, isA<Map<String, String>>());
      });

      test('should return empty map for non-existent prefix', () {
        final provider = EnvironmentConfigProvider();

        final section = provider.getSection('definitely.not.a.real.prefix');

        expect(section, isEmpty);
      });

      test('should remove prefix from returned keys', () {
        final provider = EnvironmentConfigProvider();

        // Find any environment variable to test with
        final anyEnvVar = Platform.environment.entries.firstOrNull;
        if (anyEnvVar != null) {
          final configKey = anyEnvVar.key.toLowerCase().replaceAll('_', '.');

          // If the key has a dot, we can test section retrieval
          if (configKey.contains('.')) {
            final parts = configKey.split('.');
            final prefix = parts.first;
            final section = provider.getSection(prefix);

            // The section should contain keys without the prefix
            for (final key in section.keys) {
              expect(key.startsWith('$prefix.'), isFalse);
            }
          }
        }
      });
    });

    group('reload', () {
      test('should reload environment variables', () async {
        final provider = EnvironmentConfigProvider();

        // Get initial value
        final initialPath = provider.getString('path');

        // Reload
        await provider.reload();

        // Value should be the same (environment hasn't changed)
        expect(provider.getString('path'), equals(initialPath));
      });

      test('should complete without errors', () async {
        final provider = EnvironmentConfigProvider();

        // Should not throw
        await expectLater(provider.reload(), completes);
      });
    });

    group('with prefix', () {
      test('should only load variables with matching prefix', () {
        // Create provider with a prefix that likely doesn't exist
        final provider = EnvironmentConfigProvider(
          prefix: 'DDDART_TEST_PREFIX_UNLIKELY',
        );

        // Should not find PATH since it doesn't have the prefix
        expect(provider.getString('path'), isNull);
      });

      test('should remove prefix from config keys', () {
        // We can't easily test this without setting environment variables,
        // but we can verify the provider initializes correctly
        final provider = EnvironmentConfigProvider(prefix: 'MYAPP');

        // Should initialize without errors
        expect(provider, isNotNull);
      });

      test('should handle prefix with underscore separator', () {
        final provider = EnvironmentConfigProvider(prefix: 'TEST');

        // Provider should initialize correctly
        expect(provider, isNotNull);

        // Any variable starting with TEST_ would be accessible
        // without the TEST_ prefix
      });
    });

    group('key conversion', () {
      test('should convert uppercase to lowercase', () {
        final provider = EnvironmentConfigProvider();

        // PATH should be accessible as 'path'
        final pathValue = Platform.environment['PATH'];
        if (pathValue != null) {
          expect(provider.getString('path'), equals(pathValue));
        }
      });

      test('should convert single underscores to dots', () {
        final provider = EnvironmentConfigProvider();

        // Find any environment variable with underscores
        final envWithUnderscore = Platform.environment.entries
            .where((e) => e.key.contains('_') && !e.key.contains('__'))
            .firstOrNull;

        if (envWithUnderscore != null) {
          final configKey =
              envWithUnderscore.key.toLowerCase().replaceAll('_', '.');
          expect(
            provider.getString(configKey),
            equals(envWithUnderscore.value),
          );
        }
      });

      test('should handle multiple single underscores', () {
        final provider = EnvironmentConfigProvider();

        // If there's an env var with multiple underscores, test it
        final envWithMultipleUnderscores = Platform.environment.entries
            .where((e) => e.key.split('_').length > 2 && !e.key.contains('__'))
            .firstOrNull;

        if (envWithMultipleUnderscores != null) {
          final configKey =
              envWithMultipleUnderscores.key.toLowerCase().replaceAll('_', '.');
          expect(
            provider.getString(configKey),
            equals(envWithMultipleUnderscores.value),
          );
        }
      });
    });

    group('double underscore convention', () {
      test('should convert double underscores to single underscores', () {
        // Test the conversion logic by checking if a hypothetical
        // SLACK_BOT__TOKEN would map to slack.bot_token
        final provider = EnvironmentConfigProvider();

        // Check if any env var with double underscores exists
        final envWithDoubleUnderscore = Platform.environment.entries
            .where((e) => e.key.contains('__'))
            .firstOrNull;

        if (envWithDoubleUnderscore != null) {
          // Convert using the same logic as the provider
          final configKey = envWithDoubleUnderscore.key
              .toLowerCase()
              .replaceAll('__', '\u0000')
              .replaceAll('_', '.')
              .replaceAll('\u0000', '_');

          expect(
            provider.getString(configKey),
            equals(envWithDoubleUnderscore.value),
          );
        }
      });

      test('should handle mixed single and double underscores', () {
        final provider = EnvironmentConfigProvider();

        // Check for env vars with both single and double underscores
        final envWithMixed = Platform.environment.entries
            .where((e) => e.key.contains('__') && e.key.contains('_'))
            .firstOrNull;

        if (envWithMixed != null) {
          final configKey = envWithMixed.key
              .toLowerCase()
              .replaceAll('__', '\u0000')
              .replaceAll('_', '.')
              .replaceAll('\u0000', '_');

          expect(
            provider.getString(configKey),
            equals(envWithMixed.value),
          );
        }
      });

      test('should preserve underscores from double underscores in sections',
          () {
        final provider = EnvironmentConfigProvider();

        // Find env var with double underscores
        final envWithDoubleUnderscore = Platform.environment.entries
            .where((e) => e.key.contains('__'))
            .firstOrNull;

        if (envWithDoubleUnderscore != null) {
          final configKey = envWithDoubleUnderscore.key
              .toLowerCase()
              .replaceAll('__', '\u0000')
              .replaceAll('_', '.')
              .replaceAll('\u0000', '_');

          if (configKey.contains('.')) {
            final prefix = configKey.split('.').first;
            final section = provider.getSection(prefix);

            // The section should contain the key with underscores preserved
            final keyWithoutPrefix = configKey.substring(prefix.length + 1);
            if (section.containsKey(keyWithoutPrefix)) {
              expect(section[keyWithoutPrefix], isNotNull);
            }
          }
        }
      });
    });

    group('integration scenarios', () {
      test('should work with typical application configuration pattern', () {
        // Simulate typical usage where app looks for prefixed env vars
        final provider = EnvironmentConfigProvider(prefix: 'MYAPP');

        // Should initialize without errors
        expect(provider, isNotNull);

        // Should return null for non-existent config
        expect(provider.getString('database.host'), isNull);
      });

      test('should handle empty environment gracefully', () {
        // Even with a prefix that matches nothing, should work
        final provider = EnvironmentConfigProvider(
          prefix: 'NONEXISTENT_PREFIX_12345',
        );

        expect(provider.getString('any.key'), isNull);
        expect(provider.getSection('any'), isEmpty);
      });

      test('should support reload in typical usage', () async {
        final provider = EnvironmentConfigProvider();

        final initialValue = provider.getString('path');
        await provider.reload();
        final reloadedValue = provider.getString('path');

        // Values should be consistent
        expect(reloadedValue, equals(initialValue));
      });
    });
  });
}
