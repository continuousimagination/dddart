// ignore_for_file: avoid_print

import 'package:dddart_config/dddart_config.dart';

/// Demonstrates the double underscore convention for environment variables.
///
/// This example shows how environment variable names are converted to
/// configuration keys, with special handling for underscores.
void main() {
  final config = Configuration([
    EnvironmentConfigProvider(prefix: 'DEMO'),
  ]);

  print('=== Environment Variable Underscore Convention ===\n');

  print('Single underscore (_) → dot (.) for hierarchy:');
  print('  DEMO_DATABASE_HOST → database.host');
  final dbHost = config.getString('database.host');
  print('  Value: ${dbHost ?? "(not set)"}\n');

  print('Double underscore (__) → single underscore (_) in key:');
  print('  DEMO_SLACK_BOT__TOKEN → slack.bot_token');
  final botToken = config.getString('slack.bot_token');
  print('  Value: ${botToken ?? "(not set)"}\n');

  print('Mixed usage:');
  print('  DEMO_DATABASE_MAX__CONNECTIONS → database.max_connections');
  final maxConn = config.getString('database.max_connections');
  print('  Value: ${maxConn ?? "(not set)"}\n');

  print('  DEMO_API_V2__ENDPOINT_URL → api.v2_endpoint.url');
  final apiUrl = config.getString('api.v2_endpoint.url');
  print('  Value: ${apiUrl ?? "(not set)"}\n');

  print('=== Try it yourself ===\n');
  print('Run with environment variables:');
  print(r'  DEMO_SLACK_BOT__TOKEN=xoxb-token \');
  print(r'  DEMO_DATABASE_MAX__CONNECTIONS=100 \');
  print(r'  DEMO_API_V2__ENDPOINT_URL=https://api.example.com \');
  print('  dart run example/underscore_demo.dart');
}
