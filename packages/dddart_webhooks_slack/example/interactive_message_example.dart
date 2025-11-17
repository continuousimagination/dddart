import 'dart:convert';
import 'dart:io';

import 'package:dddart_rest/dddart_rest.dart';
import 'package:dddart_webhooks/dddart_webhooks.dart';
import 'package:dddart_webhooks_slack/dddart_webhooks_slack.dart';
import 'package:shelf/shelf.dart';

/// Example demonstrating Slack interactive message webhook handling.
///
/// This example shows:
/// - Using SlackWebhookVerifier for interactive message payloads
/// - Handling JSON-encoded Slack interactive message payloads
/// - Processing button clicks and menu selections
/// - Updating messages in response to interactions
/// - Using block_actions and view_submission payloads

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
    print('dart run example/interactive_message_example.dart');
    exit(1);
  }

  // Create HTTP server
  final server = HttpServer(port: 8080);

  // Register Slack interactive message webhook
  server.registerWebhook(
    WebhookResource<SlackInteractivePayload, SlackVerificationResult>(
      path: '/slack/interactive',
      verifier: SlackWebhookVerifier(signingSecret: signingSecret),
      deserializer: (body) {
        // Slack sends interactive payloads as form-encoded with a 'payload' field
        final formData = Uri.splitQueryString(body);
        final payloadJson = formData['payload'];
        if (payloadJson == null) {
          throw FormatException('Missing payload field in form data');
        }
        return SlackInteractivePayload.fromJson(
          jsonDecode(payloadJson) as Map<String, dynamic>,
        );
      },
      handler: _handleInteractiveMessage,
    ),
  );

  // Start server
  await server.start();
  print('✅ Slack interactive message webhook server started');
  print('');
  print('Server listening on http://localhost:8080');
  print('Webhook endpoint: http://localhost:8080/slack/interactive');
  print('');
  print('📝 Setup Instructions:');
  print('');
  print('1. Go to https://api.slack.com/apps');
  print('2. Select your app (or create a new one)');
  print('3. Go to "Interactivity & Shortcuts" in the sidebar');
  print('4. Enable Interactivity');
  print('5. Set Request URL to: http://localhost:8080/slack/interactive');
  print('   (Use ngrok or similar for local testing)');
  print('');
  print('💡 For local testing with Slack:');
  print('   ngrok http 8080');
  print('   Then use the ngrok URL in Slack app configuration');
  print('');
  print('📤 To test, send a message with buttons using a slash command');
  print('   or the Slack API to post a message with interactive components');
  print('');
  print('Press Ctrl+C to stop');

  // Keep server running
  await ProcessSignal.sigint.watch().first;
  await server.stop();
  print('Server stopped');
}

/// Handler for verified Slack interactive messages
Future<Response> _handleInteractiveMessage(
  SlackInteractivePayload payload,
  SlackVerificationResult verification,
) async {
  print('Received Slack interactive message:');
  print('  Type: ${payload.type}');
  print('  User: ${payload.user['name']} (${payload.user['id']})');
  print('  Team: ${verification.teamId}');

  // Process different interaction types
  switch (payload.type) {
    case 'block_actions':
      return _handleBlockActions(payload);

    case 'view_submission':
      return _handleViewSubmission(payload);

    case 'view_closed':
      return _handleViewClosed(payload);

    default:
      print('  → Unknown interaction type: ${payload.type}');
      return Response.ok('');
  }
}

/// Handle block_actions (button clicks, menu selections, etc.)
Future<Response> _handleBlockActions(SlackInteractivePayload payload) async {
  final actions = payload.actions;
  if (actions == null || actions.isEmpty) {
    return Response.ok('');
  }

  final action = actions.first;
  final actionId = action['action_id'] as String?;
  final value = action['value'] as String?;

  print('  Action ID: $actionId');
  print('  Value: $value');

  // Process different actions
  switch (actionId) {
    case 'approve_request':
      return _handleApproveAction(payload, value);

    case 'reject_request':
      return _handleRejectAction(payload, value);

    case 'select_option':
      return _handleSelectOption(payload, value);

    default:
      print('  → Unknown action: $actionId');
      return Response.ok('');
  }
}

/// Handle approve button click
Future<Response> _handleApproveAction(
  SlackInteractivePayload payload,
  String? value,
) async {
  print('  → Approving request: $value');

  // Update the message to show approval
  final updatedMessage = {
    'replace_original': true,
    'text': 'Request Approved',
    'blocks': [
      {
        'type': 'section',
        'text': {
          'type': 'mrkdwn',
          'text': '✅ *Request Approved*',
        },
      },
      {
        'type': 'section',
        'text': {
          'type': 'mrkdwn',
          'text': 'Request ID: $value\nApproved by: <@${payload.user['id']}>',
        },
      },
      {
        'type': 'context',
        'elements': [
          {
            'type': 'mrkdwn',
            'text': '✓ Approved at ${DateTime.now().toIso8601String()}',
          },
        ],
      },
    ],
  };

  return Response.ok(
    jsonEncode(updatedMessage),
    headers: {'Content-Type': 'application/json'},
  );
}

/// Handle reject button click
Future<Response> _handleRejectAction(
  SlackInteractivePayload payload,
  String? value,
) async {
  print('  → Rejecting request: $value');

  // Update the message to show rejection
  final updatedMessage = {
    'replace_original': true,
    'text': 'Request Rejected',
    'blocks': [
      {
        'type': 'section',
        'text': {
          'type': 'mrkdwn',
          'text': '❌ *Request Rejected*',
        },
      },
      {
        'type': 'section',
        'text': {
          'type': 'mrkdwn',
          'text': 'Request ID: $value\nRejected by: <@${payload.user['id']}>',
        },
      },
      {
        'type': 'context',
        'elements': [
          {
            'type': 'mrkdwn',
            'text': '✗ Rejected at ${DateTime.now().toIso8601String()}',
          },
        ],
      },
    ],
  };

  return Response.ok(
    jsonEncode(updatedMessage),
    headers: {'Content-Type': 'application/json'},
  );
}

/// Handle select menu option
Future<Response> _handleSelectOption(
  SlackInteractivePayload payload,
  String? value,
) async {
  print('  → Selected option: $value');

  // Send an ephemeral message confirming the selection
  final response = {
    'response_type': 'ephemeral',
    'text': 'You selected: $value',
    'blocks': [
      {
        'type': 'section',
        'text': {
          'type': 'mrkdwn',
          'text': '✓ You selected: *$value*',
        },
      },
    ],
  };

  return Response.ok(
    jsonEncode(response),
    headers: {'Content-Type': 'application/json'},
  );
}

/// Handle view_submission (modal form submission)
Future<Response> _handleViewSubmission(SlackInteractivePayload payload) async {
  print('  → View submitted');

  // Extract form values from the view state
  final view = payload.view;
  if (view != null) {
    final state = view['state'] as Map<String, dynamic>?;
    print('  Form state: $state');
  }

  // Return empty response to close the modal
  return Response.ok('');
}

/// Handle view_closed (modal closed without submission)
Future<Response> _handleViewClosed(SlackInteractivePayload payload) async {
  print('  → View closed');

  // Return empty response
  return Response.ok('');
}

// ============================================================================
// Slack Interactive Payload Model
// ============================================================================

/// Represents a Slack interactive message payload.
///
/// Slack sends interactive payloads as form-encoded with a 'payload' field
/// containing JSON data.
class SlackInteractivePayload {
  SlackInteractivePayload({
    required this.type,
    required this.user,
    required this.team,
    this.actions,
    this.view,
    this.responseUrl,
  });

  factory SlackInteractivePayload.fromJson(Map<String, dynamic> json) {
    return SlackInteractivePayload(
      type: json['type'] as String,
      user: json['user'] as Map<String, dynamic>,
      team: json['team'] as Map<String, dynamic>,
      actions: json['actions'] as List<dynamic>?,
      view: json['view'] as Map<String, dynamic>?,
      responseUrl: json['response_url'] as String?,
    );
  }

  /// The type of interaction (block_actions, view_submission, etc.)
  final String type;

  /// The user who triggered the interaction
  final Map<String, dynamic> user;

  /// The team/workspace where the interaction occurred
  final Map<String, dynamic> team;

  /// The actions that were triggered (for block_actions)
  final List<dynamic>? actions;

  /// The view data (for view_submission and view_closed)
  final Map<String, dynamic>? view;

  /// URL for sending delayed responses
  final String? responseUrl;

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'user': user,
      'team': team,
      if (actions != null) 'actions': actions,
      if (view != null) 'view': view,
      if (responseUrl != null) 'response_url': responseUrl,
    };
  }
}
