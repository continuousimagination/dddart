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
/// See the [complete examples and setup](https://github.com/continuousimagination/dddart/blob/main/packages/dddart_webhooks/README.md).
///
/// ## Security Considerations
///
/// When implementing a custom verifier:
///
/// - Use constant-time comparison for signatures to prevent timing attacks
/// - Bound past/future timestamps and deduplicate requests when required
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
  /// 5. Bound past/future timestamps and deduplicate requests when required
  /// 6. Extract and return provider-specific metadata
  ///
  /// ## Example
  ///
  /// See the [complete examples and setup](https://github.com/continuousimagination/dddart/blob/main/packages/dddart_webhooks/README.md).
  Future<T> verify(Request request, String body);
}
