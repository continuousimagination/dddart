import 'package:dddart_config/dddart_config.dart';
import 'package:test/test.dart';

void main() {
  const cases = {
    'DATABASE_HOST': 'database.host',
    'DATABASE_CONNECTION_POOL': 'database.connection.pool',
    'SLACK_BOT__TOKEN': 'slack.bot_token',
    'API__KEY': 'api_key',
    'DATABASE_USER__NAME': 'database.user_name',
    'SLACK_WEBHOOK__URL_PATH': 'slack.webhook_url.path',
    'API_V2__ENDPOINT_URL': 'api.v2_endpoint.url',
    'KEY____VALUE': 'key__value',
    'OAUTH_CLIENT__ID': 'oauth.client_id',
    'OAUTH_CLIENT__SECRET': 'oauth.client_secret',
    'DATABASE_MAX__CONNECTIONS': 'database.max_connections',
    'JWT_ACCESS__TOKEN': 'jwt.access_token',
  };
  for (final entry in cases.entries) {
    for (final prefix in <String?>[null, 'TEST']) {
      test('${entry.key} maps to ${entry.value} with prefix $prefix', () {
        final provider = EnvironmentConfigProvider(
          prefix: prefix,
          environment: {
            prefix == null ? entry.key : '${prefix}_${entry.key}':
                'native value',
          },
        );
        expect(provider.getString(entry.value), 'native value');
        expect(provider.lookup(entry.value).isPresent, isTrue);
      });
    }
  }
}
