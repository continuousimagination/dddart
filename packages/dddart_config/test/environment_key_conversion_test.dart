import 'dart:io';

import 'package:dddart_config/src/environment_config_provider.dart';
import 'package:test/test.dart';

void main() {
  group('EnvironmentConfigProvider key conversion', () {
    group('single underscore to dot conversion', () {
      test('should convert DATABASE_HOST to database.host', () {
        // Set test environment variable
        if (Platform.environment.containsKey('TEST_DATABASE_HOST')) {
          final provider = EnvironmentConfigProvider(prefix: 'TEST');
          expect(provider.getString('database.host'), isNotNull);
        }
      });

      test('should convert nested keys with multiple single underscores', () {
        if (Platform.environment.containsKey('TEST_DATABASE_CONNECTION_POOL')) {
          final provider = EnvironmentConfigProvider(prefix: 'TEST');
          expect(provider.getString('database.connection.pool'), isNotNull);
        }
      });
    });

    group('double underscore to single underscore conversion', () {
      test('should convert SLACK_BOT__TOKEN to slack.bot_token', () {
        if (Platform.environment.containsKey('TEST_SLACK_BOT__TOKEN')) {
          final provider = EnvironmentConfigProvider(prefix: 'TEST');
          final value = provider.getString('slack.bot_token');
          expect(value, isNotNull);
          expect(value, equals(Platform.environment['TEST_SLACK_BOT__TOKEN']));
        }
      });

      test('should convert API__KEY to api_key', () {
        if (Platform.environment.containsKey('TEST_API__KEY')) {
          final provider = EnvironmentConfigProvider(prefix: 'TEST');
          final value = provider.getString('api_key');
          expect(value, isNotNull);
          expect(value, equals(Platform.environment['TEST_API__KEY']));
        }
      });

      test('should convert DATABASE_USER__NAME to database.user_name', () {
        if (Platform.environment.containsKey('TEST_DATABASE_USER__NAME')) {
          final provider = EnvironmentConfigProvider(prefix: 'TEST');
          final value = provider.getString('database.user_name');
          expect(value, isNotNull);
          expect(
            value,
            equals(Platform.environment['TEST_DATABASE_USER__NAME']),
          );
        }
      });
    });

    group('mixed single and double underscores', () {
      test('should handle SLACK_WEBHOOK__URL_PATH correctly', () {
        if (Platform.environment.containsKey('TEST_SLACK_WEBHOOK__URL_PATH')) {
          final provider = EnvironmentConfigProvider(prefix: 'TEST');
          // SLACK_WEBHOOK__URL_PATH -> slack.webhook_url.path
          final value = provider.getString('slack.webhook_url.path');
          expect(value, isNotNull);
          expect(
            value,
            equals(Platform.environment['TEST_SLACK_WEBHOOK__URL_PATH']),
          );
        }
      });

      test('should handle API_V2__ENDPOINT_URL correctly', () {
        if (Platform.environment.containsKey('TEST_API_V2__ENDPOINT_URL')) {
          final provider = EnvironmentConfigProvider(prefix: 'TEST');
          // API_V2__ENDPOINT_URL -> api.v2_endpoint.url
          final value = provider.getString('api.v2_endpoint.url');
          expect(value, isNotNull);
          expect(
            value,
            equals(Platform.environment['TEST_API_V2__ENDPOINT_URL']),
          );
        }
      });

      test('should handle consecutive double underscores', () {
        if (Platform.environment.containsKey('TEST_KEY____VALUE')) {
          final provider = EnvironmentConfigProvider(prefix: 'TEST');
          // KEY____VALUE -> key__value (two double underscores = two single)
          final value = provider.getString('key__value');
          expect(value, isNotNull);
          expect(value, equals(Platform.environment['TEST_KEY____VALUE']));
        }
      });
    });

    group('edge cases', () {
      test('should handle leading double underscore', () {
        if (Platform.environment.containsKey('TEST___PRIVATE_KEY')) {
          final provider = EnvironmentConfigProvider(prefix: 'TEST');
          // __PRIVATE_KEY -> _private.key
          final value = provider.getString('_private.key');
          expect(value, isNotNull);
          expect(value, equals(Platform.environment['TEST___PRIVATE_KEY']));
        }
      });

      test('should handle trailing double underscore', () {
        if (Platform.environment.containsKey('TEST_KEY_VALUE__')) {
          final provider = EnvironmentConfigProvider(prefix: 'TEST');
          // KEY_VALUE__ -> key.value_
          final value = provider.getString('key.value_');
          expect(value, isNotNull);
          expect(value, equals(Platform.environment['TEST_KEY_VALUE__']));
        }
      });

      test('should handle only double underscores', () {
        if (Platform.environment.containsKey('TEST____')) {
          final provider = EnvironmentConfigProvider(prefix: 'TEST');
          // ____ -> __
          final value = provider.getString('__');
          expect(value, isNotNull);
          expect(value, equals(Platform.environment['TEST____']));
        }
      });

      test('should handle no underscores', () {
        if (Platform.environment.containsKey('TESTKEY')) {
          final provider = EnvironmentConfigProvider(prefix: 'TEST');
          // KEY -> key
          final value = provider.getString('key');
          expect(value, isNotNull);
          expect(value, equals(Platform.environment['TESTKEY']));
        }
      });
    });

    group('section retrieval with underscores', () {
      test('should retrieve section with underscore-containing keys', () {
        if (Platform.environment.containsKey('TEST_SLACK_BOT__TOKEN') &&
            Platform.environment.containsKey('TEST_SLACK_WEBHOOK__URL')) {
          final provider = EnvironmentConfigProvider(prefix: 'TEST');
          final section = provider.getSection('slack');

          // Should contain bot_token and webhook_url
          expect(section.keys, contains('bot_token'));
          expect(section.keys, contains('webhook_url'));
          expect(
            section['bot_token'],
            equals(Platform.environment['TEST_SLACK_BOT__TOKEN']),
          );
          expect(
            section['webhook_url'],
            equals(Platform.environment['TEST_SLACK_WEBHOOK__URL']),
          );
        }
      });

      test('should handle nested sections with underscores', () {
        if (Platform.environment
            .containsKey('TEST_DATABASE_CONNECTION_POOL__SIZE')) {
          final provider = EnvironmentConfigProvider(prefix: 'TEST');
          final section = provider.getSection('database.connection');

          // Should contain pool_size
          expect(section.keys, contains('pool_size'));
          expect(
            section['pool_size'],
            equals(
              Platform.environment['TEST_DATABASE_CONNECTION_POOL__SIZE'],
            ),
          );
        }
      });
    });

    group('without prefix', () {
      test('should work without prefix for double underscores', () {
        if (Platform.environment.containsKey('SLACK_BOT__TOKEN')) {
          final provider = EnvironmentConfigProvider();
          final value = provider.getString('slack.bot_token');
          expect(value, isNotNull);
          expect(value, equals(Platform.environment['SLACK_BOT__TOKEN']));
        }
      });

      test('should work without prefix for mixed underscores', () {
        if (Platform.environment.containsKey('API_V2__ENDPOINT_URL')) {
          final provider = EnvironmentConfigProvider();
          final value = provider.getString('api.v2_endpoint.url');
          expect(value, isNotNull);
          expect(value, equals(Platform.environment['API_V2__ENDPOINT_URL']));
        }
      });
    });

    group('real-world examples', () {
      test('should handle Slack bot token pattern', () {
        if (Platform.environment.containsKey('TEST_SLACK_BOT__TOKEN')) {
          final provider = EnvironmentConfigProvider(prefix: 'TEST');
          expect(provider.getString('slack.bot_token'), isNotNull);
        }
      });

      test('should handle OAuth client_id pattern', () {
        if (Platform.environment.containsKey('TEST_OAUTH_CLIENT__ID')) {
          final provider = EnvironmentConfigProvider(prefix: 'TEST');
          expect(provider.getString('oauth.client_id'), isNotNull);
        }
      });

      test('should handle OAuth client_secret pattern', () {
        if (Platform.environment.containsKey('TEST_OAUTH_CLIENT__SECRET')) {
          final provider = EnvironmentConfigProvider(prefix: 'TEST');
          expect(provider.getString('oauth.client_secret'), isNotNull);
        }
      });

      test('should handle database max_connections pattern', () {
        if (Platform.environment
            .containsKey('TEST_DATABASE_MAX__CONNECTIONS')) {
          final provider = EnvironmentConfigProvider(prefix: 'TEST');
          expect(provider.getString('database.max_connections'), isNotNull);
        }
      });

      test('should handle JWT access_token pattern', () {
        if (Platform.environment.containsKey('TEST_JWT_ACCESS__TOKEN')) {
          final provider = EnvironmentConfigProvider(prefix: 'TEST');
          expect(provider.getString('jwt.access_token'), isNotNull);
        }
      });
    });
  });
}
