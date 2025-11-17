import 'dart:convert';
import 'dart:io';

import 'package:dddart_rest/dddart_rest.dart';
import 'package:dddart_webhooks/dddart_webhooks.dart';
import 'package:dddart_webhooks_slack/dddart_webhooks_slack.dart';
import 'package:shelf/shelf.dart';

/// Example demonstrating Slack slash command webhook handling.
///
/// This example shows:
/// - Using SlackWebhookVerifier for signature verification
/// - Handling form-encoded Slack slash command payloads
/// - Processing different slash commands
/// - Responding with formatted Slack messages
/// - Using response_url for delayed responses

void main() async {
  // Get Slack signing secret from environment
  final signingSecret = Platform.environment['SLACK_SIGNING_SECRET'];
  if (signingSecret == null) {
    print('Error: SLACK_SIGNING_SECRET environment variable not set');
    print('');
    print('Get your signing secret from:');
    print(
      'https://api.slack.com/apps → Your App → Basic Information → App Credentials',
    );
    print('');
    print('Then run:');
    print('export SLACK_SIGNING_SECRET="your-signing-secret"');
    print('dart run example/slash_command_example.dart');
    exit(1);
  }

  // Create HTTP server
  final server = HttpServer(port: 8080);

  // Register Slack slash command webhook
  server.registerWebhook(
    WebhookResource<SlackSlashCommand, SlackVerificationResult>(
      path: '/slack/commands',
      verifier: SlackWebhookVerifier(signingSecret: signingSecret),
      deserializer: (body) => WebhookDeserializers.form(
        body,
        SlackSlashCommand.fromForm,
      ),
      handler: _handleSlashCommand,
    ),
  );

  // Start server
  await server.start();
  print('✅ Slack slash command webhook server started');
  print('');
  print('Server listening on http://localhost:8080');
  print('Webhook endpoint: http://localhost:8080/slack/commands');
  print('');
  print('📝 Setup Instructions:');
  print('');
  print('1. Go to https://api.slack.com/apps');
  print('2. Select your app (or create a new one)');
  print('3. Go to "Slash Commands" in the sidebar');
  print('4. Click "Create New Command"');
  print('5. Set Request URL to: http://localhost:8080/slack/commands');
  print('   (Use ngrok or similar for local testing)');
  print('6. Create commands like:');
  print('   - /weather - Get weather information');
  print('   - /help - Show available commands');
  print('   - /status - Check system status');
  print('');
  print('💡 For local testing with Slack:');
  print('   ngrok http 8080');
  print('   Then use the ngrok URL in Slack app configuration');
  print('');
  print('Press Ctrl+C to stop');

  // Keep server running
  await ProcessSignal.sigint.watch().first;
  await server.stop();
  print('Server stopped');
}

/// Handler for verified Slack slash commands
Future<Response> _handleSlashCommand(
  SlackSlashCommand command,
  SlackVerificationResult verification,
) async {
  print('Received Slack slash command:');
  print('  Command: ${command.command}');
  print('  Text: ${command.text}');
  print('  User: ${command.userName} (${command.userId})');
  print('  Team: ${verification.teamId}');
  print('  Channel: ${command.channelId}');

  // Process command and generate response
  final response = await _processCommand(command);

  return Response.ok(
    jsonEncode(response),
    headers: {'Content-Type': 'application/json'},
  );
}

/// Process the slash command and generate a Slack-formatted response
Future<Map<String, dynamic>> _processCommand(SlackSlashCommand command) async {
  switch (command.command) {
    case '/weather':
      return _handleWeatherCommand(command);

    case '/help':
      return _handleHelpCommand(command);

    case '/status':
      return _handleStatusCommand(command);

    case '/echo':
      return _handleEchoCommand(command);

    default:
      return {
        'response_type': 'ephemeral',
        'text':
            'Unknown command: ${command.command}. Type `/help` for available commands.',
      };
  }
}

/// Handle /weather command
Map<String, dynamic> _handleWeatherCommand(SlackSlashCommand command) {
  final location = command.text.trim();

  if (location.isEmpty) {
    return {
      'response_type': 'ephemeral',
      'text': 'Please specify a location: `/weather San Francisco`',
    };
  }

  // In a real app, you would call a weather API here
  return {
    'response_type': 'in_channel',
    'text': 'Weather for $location',
    'blocks': [
      {
        'type': 'section',
        'text': {
          'type': 'mrkdwn',
          'text': '*Weather for $location* 🌤️',
        },
      },
      {
        'type': 'section',
        'fields': [
          {
            'type': 'mrkdwn',
            'text': '*Temperature:*\n72°F (22°C)',
          },
          {
            'type': 'mrkdwn',
            'text': '*Conditions:*\nPartly Cloudy',
          },
          {
            'type': 'mrkdwn',
            'text': '*Humidity:*\n65%',
          },
          {
            'type': 'mrkdwn',
            'text': '*Wind:*\n10 mph NW',
          },
        ],
      },
      {
        'type': 'context',
        'elements': [
          {
            'type': 'mrkdwn',
            'text': '🔄 Updated just now',
          },
        ],
      },
    ],
  };
}

/// Handle /help command
Map<String, dynamic> _handleHelpCommand(SlackSlashCommand command) {
  return {
    'response_type': 'ephemeral',
    'text': 'Available Commands',
    'blocks': [
      {
        'type': 'header',
        'text': {
          'type': 'plain_text',
          'text': '📚 Available Commands',
        },
      },
      {
        'type': 'section',
        'text': {
          'type': 'mrkdwn',
          'text': '''
*Weather Commands:*
• `/weather [location]` - Get current weather for a location

*System Commands:*
• `/status` - Check system status
• `/help` - Show this help message

*Utility Commands:*
• `/echo [message]` - Echo back your message
''',
        },
      },
      {
        'type': 'divider',
      },
      {
        'type': 'context',
        'elements': [
          {
            'type': 'mrkdwn',
            'text': 'Need more help? Contact your administrator.',
          },
        ],
      },
    ],
  };
}

/// Handle /status command
Map<String, dynamic> _handleStatusCommand(SlackSlashCommand command) {
  return {
    'response_type': 'in_channel',
    'text': 'System Status',
    'blocks': [
      {
        'type': 'header',
        'text': {
          'type': 'plain_text',
          'text': '✅ System Status',
        },
      },
      {
        'type': 'section',
        'fields': [
          {
            'type': 'mrkdwn',
            'text': '*API Server:*\n✅ Operational',
          },
          {
            'type': 'mrkdwn',
            'text': '*Database:*\n✅ Connected',
          },
          {
            'type': 'mrkdwn',
            'text': '*Uptime:*\n99.9%',
          },
          {
            'type': 'mrkdwn',
            'text': '*Response Time:*\n45ms',
          },
        ],
      },
      {
        'type': 'section',
        'text': {
          'type': 'mrkdwn',
          'text':
              '*Recent Activity:*\n• 1,234 requests in the last hour\n• 0 errors\n• Average response time: 42ms',
        },
      },
    ],
  };
}

/// Handle /echo command
Map<String, dynamic> _handleEchoCommand(SlackSlashCommand command) {
  final message = command.text.trim();

  if (message.isEmpty) {
    return {
      'response_type': 'ephemeral',
      'text': 'Please provide a message to echo: `/echo Hello, World!`',
    };
  }

  return {
    'response_type': 'in_channel',
    'text': message,
    'blocks': [
      {
        'type': 'section',
        'text': {
          'type': 'mrkdwn',
          'text': '💬 *Echo:*\n$message',
        },
      },
      {
        'type': 'context',
        'elements': [
          {
            'type': 'mrkdwn',
            'text': 'Sent by <@${command.userId}>',
          },
        ],
      },
    ],
  };
}
