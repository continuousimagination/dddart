/// Base class for webhook verification results.
///
/// Provides common properties for all verification results while allowing
/// provider-specific subclasses to add their own metadata.
abstract class WebhookVerificationResult {
  /// Creates a webhook verification result.
  const WebhookVerificationResult({
    required this.isValid,
    this.errorMessage,
  });

  /// Whether the webhook signature verification succeeded.
  final bool isValid;

  /// Error message if verification failed, null otherwise.
  final String? errorMessage;
}
