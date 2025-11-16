import 'package:dddart_webhooks/dddart_webhooks.dart';

/// Verification result for Slack webhooks.
///
/// Contains Slack-specific metadata extracted from headers and payload,
/// including team ID, request timestamp, and request type.
///
/// Example:
/// ```dart
/// final result = SlackVerificationResult(
///   isValid: true,
///   teamId: 'T1234567890',
///   timestamp: DateTime.now(),
///   requestType: 'slash_command',
/// );
///
/// if (result.isValid) {
///   print('Verified request from team: ${result.teamId}');
/// }
/// ```
class SlackVerificationResult extends WebhookVerificationResult {
  /// Creates a Slack verification result.
  const SlackVerificationResult({
    required super.isValid,
    super.errorMessage,
    this.teamId,
    this.timestamp,
    this.requestType,
  });

  /// The Slack team/workspace ID extracted from the request payload.
  ///
  /// This is typically found in the `team_id` field of Slack webhook payloads.
  /// May be null if the payload could not be parsed or does not contain
  /// a team ID.
  final String? teamId;

  /// The request timestamp from the X-Slack-Request-Timestamp header.
  ///
  /// Used for replay attack prevention. Slack includes this timestamp
  /// in the signature calculation, and requests with timestamps older
  /// than the configured maximum age are rejected.
  final DateTime? timestamp;

  /// The type of Slack request.
  ///
  /// Common values include:
  /// - `slash_command` - Slash command invocation
  /// - `interactive_message` - Button or menu interaction
  /// - `event_callback` - Event API callback
  /// - `url_verification` - URL verification challenge
  ///
  /// May be null if the payload could not be parsed or does not contain
  /// a type field.
  final String? requestType;
}
