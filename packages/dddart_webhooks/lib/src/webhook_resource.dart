import 'dart:convert';

import 'package:dddart_webhooks/dddart_webhooks.dart' show WebhookDeserializers;
import 'package:dddart_webhooks/src/webhook_deserializers.dart'
    show WebhookDeserializers;
import 'package:dddart_webhooks/src/webhook_verification_result.dart';
import 'package:dddart_webhooks/src/webhook_verifier.dart';
import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';

final _log = Logger('WebhookResource');

/// HTTP resource for handling incoming webhooks.
///
/// Provides signature verification, payload deserialization, and handler
/// invocation with strongly-typed payloads and verification results.
///
/// The generic type parameters allow for complete type safety:
/// - `TPayload`: The type of the deserialized webhook payload
/// - `TVerification`: The type of verification result (must extend
///   [WebhookVerificationResult])
///
/// ## Request Processing Flow
///
/// 1. **Read Request Body**: The raw body is read as a String
/// 2. **Verify Signature**: The [verifier] validates the request authenticity
/// 3. **Deserialize Payload**: The [deserializer] converts the body to
///    `TPayload`
/// 4. **Invoke Handler**: The [handler] processes the verified payload
/// 5. **Return Response**: The handler's response is returned to the provider
///
/// ## Error Handling
///
/// - **Verification Failure**: Returns 401 Unauthorized
/// - **Deserialization Failure**: Returns 400 Bad Request (or custom via
///   [onDeserializationError])
/// - **Handler Exception**: Returns 500 Internal Server Error
///
/// ## Usage Examples
///
/// ### JSON Webhook with Custom Verifier
///
/// ```dart
/// final webhook = WebhookResource<MyEvent, MyVerification>(
///   path: '/webhooks/events',
///   verifier: MyWebhookVerifier(secret: 'my-secret'),
///   deserializer: (body) => WebhookDeserializers.json(
///     body,
///     MyEvent.fromJson,
///   ),
///   handler: (event, verification) async {
///     print('Received event: ${event.type}');
///     print('From user: ${verification.userId}');
///     return Response.ok('Event processed');
///   },
/// );
///
/// server.registerWebhook(webhook);
/// ```
///
/// ### Form-Encoded Webhook
///
/// ```dart
/// final webhook = WebhookResource<SlackSlashCommand, SlackVerification>(
///   path: '/webhooks/slack/commands',
///   verifier: SlackWebhookVerifier(signingSecret: slackSecret),
///   deserializer: (body) => WebhookDeserializers.form(
///     body,
///     SlackSlashCommand.fromForm,
///   ),
///   handler: (command, verification) async {
///     print('Command: ${command.command}');
///     print('Team: ${verification.teamId}');
///     return Response.ok('Command received');
///   },
/// );
/// ```
///
/// ### Raw String Webhook
///
/// ```dart
/// final webhook = WebhookResource<String, MyVerification>(
///   path: '/webhooks/raw',
///   verifier: MyWebhookVerifier(secret: 'my-secret'),
///   // No deserializer - raw body passed to handler
///   handler: (body, verification) async {
///     print('Raw body: $body');
///     return Response.ok('Received');
///   },
/// );
/// ```
///
/// ### Custom Deserialization Error Handling
///
/// ```dart
/// final webhook = WebhookResource<MyEvent, MyVerification>(
///   path: '/webhooks/events',
///   verifier: MyWebhookVerifier(secret: 'my-secret'),
///   deserializer: (body) => MyEvent.fromJson(jsonDecode(body)),
///   handler: (event, verification) async {
///     return Response.ok('Processed');
///   },
///   onDeserializationError: (body, error) async {
///     // Log the error with the raw body for debugging
///     _log.severe('Failed to deserialize webhook', error);
///     _log.fine('Raw body: $body');
///
///     // Return custom error response
///     return Response(
///       400,
///       body: jsonEncode({
///         'error': 'Invalid payload format',
///         'details': error.toString(),
///       }),
///       headers: {'Content-Type': 'application/json'},
///     );
///   },
/// );
/// ```
///
/// ## Security Considerations
///
/// - Always use HTTPS in production to prevent man-in-the-middle attacks
/// - Store signing secrets securely (environment variables, secret managers)
/// - Implement proper signature verification in your [WebhookVerifier]
/// - Validate timestamps to prevent replay attacks
/// - Use constant-time comparison for signatures to prevent timing attacks
///
/// See also:
/// - [WebhookVerifier] for implementing signature verification
/// - [WebhookVerificationResult] for verification result types
/// - [WebhookDeserializers] for common deserialization helpers
class WebhookResource<TPayload,
    TVerification extends WebhookVerificationResult> {
  /// Creates a webhook resource.
  ///
  /// Parameters:
  /// - [path]: The HTTP path for this webhook endpoint
  /// - [verifier]: The verifier used to validate webhook signatures
  /// - [deserializer]: Optional function to convert raw body String to
  ///   `TPayload`. If null and `TPayload` is String, raw body is passed to
  ///   handler.
  /// - [handler]: Function invoked with verified and deserialized payload
  /// - [onDeserializationError]: Optional custom error handler for
  ///   deserialization failures. If not provided, returns 400 Bad Request.
  WebhookResource({
    required this.path,
    required this.verifier,
    required this.handler,
    this.deserializer,
    this.onDeserializationError,
  });

  /// The HTTP path for this webhook endpoint.
  final String path;

  /// The verifier used to validate webhook signatures.
  final WebhookVerifier<TVerification> verifier;

  /// Handler function invoked with verified and deserialized payload.
  ///
  /// Receives:
  /// - payload: The deserialized webhook payload of type `TPayload`
  /// - verification: The verification result with provider-specific metadata
  ///
  /// Returns a [Response] to send back to the webhook provider.
  ///
  /// If the handler throws an exception, a 500 Internal Server Error response
  /// is returned automatically.
  final Future<Response> Function(
    TPayload payload,
    TVerification verification,
  ) handler;

  /// Optional deserializer to convert raw body to strongly-typed payload.
  ///
  /// Receives the raw request body as a String and is responsible for parsing
  /// the format (JSON, form-encoded, XML, etc.) and converting to `TPayload`.
  ///
  /// If null and `TPayload` is String, raw body is passed to handler.
  /// If null and `TPayload` is not String, compilation will fail.
  final TPayload Function(String body)? deserializer;

  /// Optional error handler for deserialization failures.
  ///
  /// If provided, receives:
  /// - body: The raw request body String that failed to deserialize
  /// - error: The exception thrown during deserialization
  ///
  /// Returns a [Response] to send back to the webhook provider.
  ///
  /// If not provided, returns 400 Bad Request on deserialization failure.
  final Future<Response> Function(String body, Object error)?
      onDeserializationError;

  /// Handles incoming webhook POST requests.
  ///
  /// This method is called by the HTTP server when a POST request is received
  /// at the webhook [path]. It orchestrates the complete webhook processing
  /// flow: verification, deserialization, and handler invocation.
  ///
  /// Returns a [Response] to send back to the webhook provider.
  ///
  /// ## Error Responses
  ///
  /// - **401 Unauthorized**: Signature verification failed
  /// - **400 Bad Request**: Deserialization failed (if no custom error handler)
  /// - **500 Internal Server Error**: Handler threw an exception
  Future<Response> handleRequest(Request request) async {
    // 1. Read request body
    final body = await request.readAsString();

    // 2. Verify signature
    _log.fine('Verifying webhook signature for ${request.url.path}');
    final verification = await verifier.verify(request, body);

    if (!verification.isValid) {
      _log.warning(
        'Webhook signature verification failed: ${verification.errorMessage}',
      );
      return Response(
        401,
        body: jsonEncode({
          'error': 'Signature verification failed',
          'message': verification.errorMessage ?? 'Invalid signature',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }

    _log.fine('Webhook signature verified successfully');

    // 3. Deserialize payload
    TPayload payload;
    try {
      if (deserializer != null) {
        _log.fine('Deserializing webhook payload');
        payload = deserializer!(body);
      } else {
        // If no deserializer and TPayload is String, use raw body
        payload = body as TPayload;
      }
    } catch (e, stackTrace) {
      _log.warning('Webhook deserialization failed', e, stackTrace);

      // Handle deserialization error
      if (onDeserializationError != null) {
        return onDeserializationError!(body, e);
      }

      return Response(
        400,
        body: jsonEncode({
          'error': 'Deserialization failed',
          'message': e.toString(),
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }

    // 4. Invoke handler
    try {
      _log.fine('Invoking webhook handler');
      return await handler(payload, verification);
    } catch (e, stackTrace) {
      _log.severe('Webhook handler threw exception', e, stackTrace);

      return Response(
        500,
        body: jsonEncode({
          'error': 'Internal server error',
          'message': 'Handler threw exception',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
}
