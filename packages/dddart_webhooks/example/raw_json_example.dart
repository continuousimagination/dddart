import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dddart_webhooks/dddart_webhooks.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

/// Example demonstrating raw JSON webhook handling.
///
/// This example shows:
/// - Using WebhookDeserializers.json() for JSON payloads
/// - Handling strongly-typed JSON webhook payloads
/// - Processing different event types from a single webhook endpoint
/// - Custom deserialization error handling
/// - Using WebhookResource directly with Shelf Router

void main() async {
  // Create webhook resource
  final webhook = WebhookResource<EventPayload, SimpleVerificationResult>(
    path: '/webhooks/events',
    verifier: SimpleWebhookVerifier(secret: 'json-secret'),
    deserializer: (body) => WebhookDeserializers.json(
      body,
      EventPayload.fromJson,
    ),
    handler: _handleEvent,
    onDeserializationError: _handleDeserializationError,
  );

  // Create router and register webhook
  final router = Router();
  router.post(webhook.path, webhook.handleRequest);

  // Start server
  final server = await shelf_io.serve(
    router.call,
    InternetAddress.anyIPv4,
    8080,
  );
  print('Server listening on http://localhost:${server.port}');
  print('');
  print('Test the webhook with:');
  print('');
  print('# User created event');
  print('curl -X POST http://localhost:8080/webhooks/events \\');
  print('  -H "Content-Type: application/json" \\');
  print('  -H "X-Signature: <computed-signature>" \\');
  print(
    '  -d \'{"type": "user.created", "data": {"id": "123", "name": "Alice"}}\'',
  );
  print('');
  print('# Order placed event');
  print('curl -X POST http://localhost:8080/webhooks/events \\');
  print('  -H "Content-Type: application/json" \\');
  print('  -H "X-Signature: <computed-signature>" \\');
  print(
    '  -d \'{"type": "order.placed", "data": {"orderId": "456", "total": 99.99}}\'',
  );
  print('');
  print('Press Ctrl+C to stop');

  // Keep server running
  await ProcessSignal.sigint.watch().first;
  await server.close();
  print('Server stopped');
}

/// Handler for verified JSON events
Future<Response> _handleEvent(
  EventPayload payload,
  SimpleVerificationResult verification,
) async {
  print('Received event:');
  print('  Type: ${payload.type}');
  print('  Data: ${payload.data}');

  // Process different event types
  switch (payload.type) {
    case 'user.created':
      final userId = payload.data['id'] as String?;
      final userName = payload.data['name'] as String?;
      print('  → User created: $userName (ID: $userId)');

    case 'order.placed':
      final orderId = payload.data['orderId'] as String?;
      final total = payload.data['total'] as num?;
      print('  → Order placed: $orderId (Total: \$$total)');

    default:
      print('  → Unknown event type');
  }

  return Response.ok(
    jsonEncode({
      'status': 'processed',
      'eventType': payload.type,
    }),
    headers: {'Content-Type': 'application/json'},
  );
}

/// Custom error handler for deserialization failures
Future<Response> _handleDeserializationError(
  String body,
  Object error,
) async {
  print('Deserialization error:');
  print('  Error: $error');
  print('  Raw body: $body');

  return Response(
    400,
    body: jsonEncode({
      'error': 'Invalid JSON payload',
      'message': 'The webhook payload could not be deserialized',
      'details': error.toString(),
    }),
    headers: {'Content-Type': 'application/json'},
  );
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
// Event Payload Model
// ============================================================================

/// Generic event payload with type and data.
class EventPayload {
  EventPayload({
    required this.type,
    required this.data,
  });

  factory EventPayload.fromJson(Map<String, dynamic> json) {
    return EventPayload(
      type: json['type'] as String,
      data: json['data'] as Map<String, dynamic>,
    );
  }

  final String type;
  final Map<String, dynamic> data;

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'data': data,
    };
  }
}
