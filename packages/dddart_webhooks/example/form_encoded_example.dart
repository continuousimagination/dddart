import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dddart_http/dddart_http.dart';
import 'package:dddart_webhooks/dddart_webhooks.dart';
import 'package:shelf/shelf.dart';

/// Example demonstrating form-encoded webhook handling.
///
/// This example shows:
/// - Using WebhookDeserializers.form() for form-encoded payloads
/// - Handling application/x-www-form-urlencoded data
/// - Processing form data similar to Slack slash commands
/// - Responding with formatted messages

void main() async {
  // Create HTTP server
  final server = HttpServer(port: 8080);

  // Register webhook for form-encoded commands
  server.registerWebhook(
    WebhookResource<CommandPayload, SimpleVerificationResult>(
      path: '/webhooks/commands',
      verifier: SimpleWebhookVerifier(secret: 'form-secret'),
      deserializer: (body) => WebhookDeserializers.form(
        body,
        CommandPayload.fromForm,
      ),
      handler: _handleCommand,
    ),
  );

  // Start server
  await server.start();
  print('Server listening on http://localhost:8080');
  print('');
  print('Test the webhook with:');
  print('');
  print('curl -X POST http://localhost:8080/webhooks/commands \\');
  print('  -H "Content-Type: application/x-www-form-urlencoded" \\');
  print('  -H "X-Signature: <computed-signature>" \\');
  print(
    '  -d "command=/hello&text=world&user_id=U123&user_name=alice&channel_id=C456"',
  );
  print('');
  print('Press Ctrl+C to stop');

  // Keep server running
  await ProcessSignal.sigint.watch().first;
  await server.stop();
  print('Server stopped');
}

/// Handler for verified form-encoded commands
Future<Response> _handleCommand(
  CommandPayload payload,
  SimpleVerificationResult verification,
) async {
  print('Received command:');
  print('  Command: ${payload.command}');
  print('  Text: ${payload.text}');
  print('  User: ${payload.userName} (${payload.userId})');
  print('  Channel: ${payload.channelId}');

  // Process command
  final response = _processCommand(payload);

  return Response.ok(
    jsonEncode(response),
    headers: {'Content-Type': 'application/json'},
  );
}

/// Process the command and generate a response
Map<String, dynamic> _processCommand(CommandPayload payload) {
  switch (payload.command) {
    case '/hello':
      return {
        'response_type': 'in_channel',
        'text': 'Hello, ${payload.userName}! You said: ${payload.text}',
      };

    case '/help':
      return {
        'response_type': 'ephemeral',
        'text': '''
Available commands:
• /hello [message] - Say hello
• /help - Show this help message
• /status - Check system status
''',
      };

    case '/status':
      return {
        'response_type': 'in_channel',
        'text': '✅ System is operational',
        'attachments': [
          {
            'color': 'good',
            'fields': [
              {'title': 'Uptime', 'value': '99.9%', 'short': true},
              {'title': 'Response Time', 'value': '45ms', 'short': true},
            ],
          },
        ],
      };

    default:
      return {
        'response_type': 'ephemeral',
        'text':
            'Unknown command: ${payload.command}. Type /help for available commands.',
      };
  }
}

// ============================================================================
// Simple Verification Result
// ============================================================================

/// Simple verification result with minimal metadata.
class SimpleVerificationResult extends WebhookVerificationResult {
  const SimpleVerificationResult({
    required super.isValid,
    super.errorMessage,
  });
}

// ============================================================================
// Simple Webhook Verifier
// ============================================================================

/// Simple webhook verifier using HMAC-SHA256.
class SimpleWebhookVerifier extends WebhookVerifier<SimpleVerificationResult> {
  SimpleWebhookVerifier({required this.secret});

  final String secret;

  @override
  Future<SimpleVerificationResult> verify(Request request, String body) async {
    final signature = request.headers['x-signature'];

    if (signature == null) {
      return const SimpleVerificationResult(
        isValid: false,
        errorMessage: 'Missing X-Signature header',
      );
    }

    // Compute expected signature
    final hmac = Hmac(sha256, utf8.encode(secret));
    final digest = hmac.convert(utf8.encode(body));
    final expectedSignature = digest.toString();

    // Compare signatures
    if (signature != expectedSignature) {
      return const SimpleVerificationResult(
        isValid: false,
        errorMessage: 'Invalid signature',
      );
    }

    return const SimpleVerificationResult(isValid: true);
  }
}

// ============================================================================
// Command Payload Model
// ============================================================================

/// Form-encoded command payload (similar to Slack slash commands).
class CommandPayload {
  CommandPayload({
    required this.command,
    required this.text,
    required this.userId,
    required this.userName,
    required this.channelId,
  });

  /// Creates a CommandPayload from form-encoded data.
  factory CommandPayload.fromForm(Map<String, String> form) {
    return CommandPayload(
      command: form['command'] ?? '',
      text: form['text'] ?? '',
      userId: form['user_id'] ?? '',
      userName: form['user_name'] ?? '',
      channelId: form['channel_id'] ?? '',
    );
  }

  final String command;
  final String text;
  final String userId;
  final String userName;
  final String channelId;

  Map<String, String> toForm() {
    return {
      'command': command,
      'text': text,
      'user_id': userId,
      'user_name': userName,
      'channel_id': channelId,
    };
  }
}
