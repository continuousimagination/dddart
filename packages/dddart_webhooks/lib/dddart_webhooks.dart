/// Webhook support for DDDart.
///
/// Provides a framework for receiving, verifying, and processing webhooks
/// with strongly-typed payloads and verification results.
///
/// ## Features
///
/// - Generic webhook resource handling
/// - Pluggable signature verification
/// - Strongly-typed verification results
/// - Flexible payload deserialization
/// - Integration with dddart_http HttpServer
///
/// ## Usage
///
/// ```dart
/// import 'package:dddart_webhooks/dddart_webhooks.dart';
///
/// // Create a custom verifier
/// class MyWebhookVerifier extends WebhookVerifier<MyVerificationResult> {
///   @override
///   Future<MyVerificationResult> verify(Request request, String body) async {
///     // Implement verification logic
///   }
/// }
///
/// // Register webhook with HttpServer
/// final webhook = WebhookResource<MyPayload, MyVerificationResult>(
///   path: '/webhooks/my-service',
///   verifier: MyWebhookVerifier(),
///   deserializer: (body) => MyPayload.fromJson(jsonDecode(body)),
///   handler: (payload, verification) async {
///     // Handle webhook
///     return Response.ok('Received');
///   },
/// );
///
/// server.registerWebhook(webhook);
/// ```
library dddart_webhooks;

export 'src/webhook_deserializers.dart';
export 'src/webhook_resource.dart';
export 'src/webhook_verification_result.dart';
export 'src/webhook_verifier.dart';
