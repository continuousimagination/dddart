import 'package:dddart_webhooks/dddart_webhooks.dart' show WebhookResource;
import 'package:dddart_webhooks/src/webhook_resource.dart' show WebhookResource;
import 'package:dddart_webhooks/src/webhook_verification_result.dart';
import 'package:shelf/shelf.dart';

/// Abstract base class for webhook signature verifiers.
///
/// Implementations verify webhook signatures using provider-specific
/// algorithms and return strongly-typed verification results.
///
/// The generic type parameter [T] specifies the type of verification result
/// returned by this verifier. This allows provider-specific verifiers to
/// return results with additional metadata beyond the base [isValid] and
/// [errorMessage] properties.
///
/// ## Creating a Custom Verifier
///
/// To implement a custom webhook verifier:
///
/// 1. Create a verification result class extending [WebhookVerificationResult]
/// 2. Create a verifier class extending [WebhookVerifier]
/// 3. Implement the [verify] method with your signature validation logic
///
/// ## Example
///
/// ```dart
/// // 1. Define verification result
/// class MyVerificationResult extends WebhookVerificationResult {
///   const MyVerificationResult({
///     required super.isValid,
///     super.errorMessage,
///     this.userId,
///     this.timestamp,
///   });
///
///   final String? userId;
///   final DateTime? timestamp;
/// }
///
/// // 2. Implement verifier
/// class MyWebhookVerifier extends WebhookVerifier<MyVerificationResult> {
///   MyWebhookVerifier({required this.secret});
///
///   final String secret;
///
///   @override
///   Future<MyVerificationResult> verify(Request request, String body) async {
///     // Extract signature from headers
///     final signature = request.headers['X-My-Signature'];
///     if (signature == null) {
///       return MyVerificationResult(
///         isValid: false,
///         errorMessage: 'Missing signature header',
///       );
///     }
///
///     // Compute expected signature
///     final expectedSignature = _computeSignature(body, secret);
///
///     // Compare signatures
///     if (signature != expectedSignature) {
///       return MyVerificationResult(
///         isValid: false,
///         errorMessage: 'Invalid signature',
///       );
///     }
///
///     // Extract metadata from request
///     final userId = request.headers['X-User-Id'];
///     final timestamp = DateTime.now();
///
///     return MyVerificationResult(
///       isValid: true,
///       userId: userId,
///       timestamp: timestamp,
///     );
///   }
///
///   String _computeSignature(String body, String secret) {
///     // Implement your signature algorithm (HMAC, etc.)
///     // ...
///   }
/// }
///
/// // 3. Use with WebhookResource
/// final webhook = WebhookResource<MyPayload, MyVerificationResult>(
///   path: '/webhooks/my-service',
///   verifier: MyWebhookVerifier(secret: 'my-secret'),
///   deserializer: (body) => MyPayload.fromJson(jsonDecode(body)),
///   handler: (payload, verification) async {
///     print('User ID: ${verification.userId}');
///     print('Timestamp: ${verification.timestamp}');
///     return Response.ok('Webhook processed');
///   },
/// );
/// ```
///
/// ## Security Considerations
///
/// When implementing a custom verifier:
///
/// - Use constant-time comparison for signatures to prevent timing attacks
/// - Validate timestamps to prevent replay attacks
/// - Use cryptographically secure algorithms (HMAC-SHA256, etc.)
/// - Store secrets securely (environment variables, secret managers)
/// - Only accept webhooks over HTTPS in production
///
/// See also:
/// - [WebhookVerificationResult] for the base verification result class
/// - [WebhookResource] for webhook request handling
abstract class WebhookVerifier<T extends WebhookVerificationResult> {
  /// Verifies the webhook request signature.
  ///
  /// This method is called by [WebhookResource] before processing the webhook
  /// payload. It should validate that the request came from the legitimate
  /// webhook provider using cryptographic signature verification.
  ///
  /// Parameters:
  /// - [request]: The incoming HTTP request containing headers and metadata
  /// - [body]: The raw request body as a String (already read from the request)
  ///
  /// Returns a strongly-typed verification result containing:
  /// - [WebhookVerificationResult.isValid]: Whether verification succeeded
  /// - [WebhookVerificationResult.errorMessage]: Error details if verification failed
  /// - Additional provider-specific metadata in the subclass
  ///
  /// The [body] parameter is provided separately because the request body
  /// can only be read once. The [WebhookResource] reads it and passes it
  /// to both the verifier and deserializer.
  ///
  /// ## Implementation Guidelines
  ///
  /// 1. Extract signature and metadata from request headers
  /// 2. Validate required headers are present
  /// 3. Compute expected signature using provider's algorithm
  /// 4. Compare signatures using constant-time comparison
  /// 5. Validate timestamps to prevent replay attacks
  /// 6. Extract and return provider-specific metadata
  ///
  /// ## Example
  ///
  /// ```dart
  /// @override
  /// Future<MyVerificationResult> verify(Request request, String body) async {
  ///   // Extract headers
  ///   final signature = request.headers['X-Signature'];
  ///   final timestamp = request.headers['X-Timestamp'];
  ///
  ///   // Validate headers present
  ///   if (signature == null || timestamp == null) {
  ///     return MyVerificationResult(
  ///       isValid: false,
  ///       errorMessage: 'Missing required headers',
  ///     );
  ///   }
  ///
  ///   // Validate timestamp (prevent replay attacks)
  ///   final requestTime = DateTime.parse(timestamp);
  ///   if (DateTime.now().difference(requestTime) > Duration(minutes: 5)) {
  ///     return MyVerificationResult(
  ///       isValid: false,
  ///       errorMessage: 'Request timestamp too old',
  ///     );
  ///   }
  ///
  ///   // Compute and compare signatures
  ///   final expected = _computeHmac(body, timestamp);
  ///   if (!_constantTimeCompare(signature, expected)) {
  ///     return MyVerificationResult(
  ///       isValid: false,
  ///       errorMessage: 'Invalid signature',
  ///     );
  ///   }
  ///
  ///   return MyVerificationResult(isValid: true);
  /// }
  /// ```
  Future<T> verify(Request request, String body);
}
