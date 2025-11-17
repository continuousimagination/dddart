import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dddart_webhooks/dddart_webhooks.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

/// Example demonstrating how to create a custom webhook verifier.
///
/// This example shows:
/// - Creating a custom verification result class
/// - Implementing a custom webhook verifier with HMAC-SHA256 signature
/// - Extracting metadata from headers
/// - Validating timestamps to prevent replay attacks
/// - Using constant-time comparison to prevent timing attacks
/// - Using WebhookResource directly with Shelf Router

void main() async {
  // Create webhook resource
  final webhook = WebhookResource<MyWebhookPayload, MyVerificationResult>(
    path: '/webhooks/custom',
    verifier: MyWebhookVerifier(secret: 'my-secret-key'),
    deserializer: (body) => WebhookDeserializers.json(
      body,
      MyWebhookPayload.fromJson,
    ),
    handler: _handleWebhook,
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
  print('curl -X POST http://localhost:8080/webhooks/custom \\');
  print('  -H "Content-Type: application/json" \\');
  print('  -H "X-Webhook-Signature: <computed-signature>" \\');
  print('  -H "X-Webhook-Timestamp: <unix-timestamp>" \\');
  print('  -H "X-User-Id: user-123" \\');
  print('  -d \'{"event": "user.created", "userId": "123"}\'');
  print('');
  print('Press Ctrl+C to stop');

  // Keep server running
  await ProcessSignal.sigint.watch().first;
  await server.close();
  print('Server stopped');
}

/// Handler for verified webhooks
Future<Response> _handleWebhook(
  MyWebhookPayload payload,
  MyVerificationResult verification,
) async {
  print('Received webhook:');
  print('  Event: ${payload.event}');
  print('  User ID: ${payload.userId}');
  print('  Verified User: ${verification.userId}');
  print('  Timestamp: ${verification.timestamp}');

  return Response.ok(
    jsonEncode({'status': 'received', 'event': payload.event}),
    headers: {'Content-Type': 'application/json'},
  );
}

// ============================================================================
// Custom Verification Result
// ============================================================================

/// Custom verification result with provider-specific metadata.
class MyVerificationResult extends WebhookVerificationResult {
  const MyVerificationResult({
    required super.isValid,
    super.errorMessage,
    this.userId,
    this.timestamp,
  });

  /// The user ID extracted from the X-User-Id header.
  final String? userId;

  /// The request timestamp from the X-Webhook-Timestamp header.
  final DateTime? timestamp;
}

// ============================================================================
// Custom Webhook Verifier
// ============================================================================

/// Custom webhook verifier implementing HMAC-SHA256 signature verification.
///
/// This verifier demonstrates:
/// - Extracting and validating required headers
/// - Computing HMAC-SHA256 signatures
/// - Validating timestamps to prevent replay attacks
/// - Using constant-time comparison to prevent timing attacks
/// - Extracting metadata from headers
class MyWebhookVerifier extends WebhookVerifier<MyVerificationResult> {
  MyWebhookVerifier({
    required this.secret,
    this.maxTimestampAge = const Duration(minutes: 5),
  });

  /// The secret key used to compute signatures.
  final String secret;

  /// Maximum age of request timestamp to prevent replay attacks.
  final Duration maxTimestampAge;

  @override
  Future<MyVerificationResult> verify(Request request, String body) async {
    // Extract required headers
    final signature = request.headers['x-webhook-signature'];
    final timestampStr = request.headers['x-webhook-timestamp'];
    final userId = request.headers['x-user-id'];

    // Validate required headers are present
    if (signature == null) {
      return const MyVerificationResult(
        isValid: false,
        errorMessage: 'Missing X-Webhook-Signature header',
      );
    }

    if (timestampStr == null) {
      return const MyVerificationResult(
        isValid: false,
        errorMessage: 'Missing X-Webhook-Timestamp header',
      );
    }

    // Parse and validate timestamp
    final timestamp = int.tryParse(timestampStr);
    if (timestamp == null) {
      return const MyVerificationResult(
        isValid: false,
        errorMessage: 'Invalid timestamp format',
      );
    }

    final requestTime = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final now = DateTime.now();

    // Check timestamp age (prevent replay attacks)
    if (now.difference(requestTime) > maxTimestampAge) {
      return MyVerificationResult(
        isValid: false,
        errorMessage: 'Request timestamp too old (replay attack prevention)',
        timestamp: requestTime,
      );
    }

    // Compute expected signature using HMAC-SHA256
    final expectedSignature = _computeSignature(body, timestampStr);

    // Compare signatures using constant-time comparison
    if (!_constantTimeCompare(signature, expectedSignature)) {
      return MyVerificationResult(
        isValid: false,
        errorMessage: 'Signature mismatch',
        timestamp: requestTime,
      );
    }

    // Verification succeeded
    return MyVerificationResult(
      isValid: true,
      userId: userId,
      timestamp: requestTime,
    );
  }

  /// Computes HMAC-SHA256 signature for the request.
  String _computeSignature(String body, String timestamp) {
    // Create signature base string: timestamp:body
    final baseString = '$timestamp:$body';

    // Compute HMAC-SHA256
    final hmac = Hmac(sha256, utf8.encode(secret));
    final digest = hmac.convert(utf8.encode(baseString));

    // Return hex-encoded signature
    return digest.toString();
  }

  /// Constant-time string comparison to prevent timing attacks.
  bool _constantTimeCompare(String a, String b) {
    if (a.length != b.length) return false;

    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }

    return result == 0;
  }
}

// ============================================================================
// Webhook Payload Model
// ============================================================================

/// Example webhook payload.
class MyWebhookPayload {
  MyWebhookPayload({
    required this.event,
    required this.userId,
  });

  factory MyWebhookPayload.fromJson(Map<String, dynamic> json) {
    return MyWebhookPayload(
      event: json['event'] as String,
      userId: json['userId'] as String,
    );
  }

  final String event;
  final String userId;

  Map<String, dynamic> toJson() {
    return {
      'event': event,
      'userId': userId,
    };
  }
}
