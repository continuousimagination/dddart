import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dddart_webhooks/dddart_webhooks.dart';
import 'package:dddart_webhooks_slack/src/slack_verification_result.dart';
import 'package:shelf/shelf.dart';

/// Webhook verifier for Slack webhooks.
///
/// Implements Slack's HMAC-SHA256 signature verification algorithm and
/// timestamp validation to prevent replay attacks. The verifier extracts
/// Slack-specific metadata from the request and returns a strongly-typed
/// [SlackVerificationResult].
///
/// Slack signs webhook requests using your app's signing secret. The signature
/// is computed as:
/// ```text
/// HMAC-SHA256(signing_secret, "v0:{timestamp}:{body}")
/// ```
///
/// Example:
/// ```dart
/// final verifier = SlackWebhookVerifier(
///   signingSecret: 'your-slack-signing-secret',
///   maxTimestampAge: Duration(minutes: 5), // Optional, defaults to 5 minutes
/// );
///
/// final webhook = WebhookResource<SlackSlashCommand, SlackVerificationResult>(
///   path: '/slack/commands',
///   verifier: verifier,
///   deserializer: (body) => WebhookDeserializers.form(
///     body,
///     SlackSlashCommand.fromForm,
///   ),
///   handler: (command, verification) async {
///     print('Team ID: ${verification.teamId}');
///     return Response.ok('Command received!');
///   },
/// );
/// ```
///
/// Security considerations:
/// - Always use HTTPS in production to protect the signing secret
/// - Store the signing secret securely (environment variables, secret manager)
/// - The default 5-minute timestamp window prevents replay attacks
/// - Constant-time signature comparison prevents timing attacks
class SlackWebhookVerifier extends WebhookVerifier<SlackVerificationResult> {
  /// Creates a Slack webhook verifier.
  ///
  /// The [signingSecret] is provided by Slack in your app's configuration
  /// under "Basic Information" > "App Credentials" > "Signing Secret".
  ///
  /// The [maxTimestampAge] determines how old a request timestamp can be
  /// before it's rejected as a potential replay attack. Defaults to 5 minutes,
  /// which matches Slack's recommendation.
  SlackWebhookVerifier({
    required this.signingSecret,
    this.maxTimestampAge = const Duration(minutes: 5),
  });

  /// The Slack signing secret from your app configuration.
  ///
  /// This secret is used to compute the expected HMAC-SHA256 signature
  /// for incoming webhook requests.
  final String signingSecret;

  /// Maximum age of request timestamp to prevent replay attacks.
  ///
  /// Requests with timestamps older than this duration are rejected.
  /// Defaults to 5 minutes, which is Slack's recommended value.
  final Duration maxTimestampAge;

  @override
  Future<SlackVerificationResult> verify(Request request, String body) async {
    // Extract required Slack headers
    final signature = request.headers['x-slack-signature'];
    final timestampStr = request.headers['x-slack-request-timestamp'];

    if (signature == null || timestampStr == null) {
      return const SlackVerificationResult(
        isValid: false,
        errorMessage: 'Missing required Slack headers '
            '(X-Slack-Signature or X-Slack-Request-Timestamp)',
      );
    }

    // Parse and validate timestamp
    final timestamp = int.tryParse(timestampStr);
    if (timestamp == null) {
      return const SlackVerificationResult(
        isValid: false,
        errorMessage: 'Invalid timestamp format',
      );
    }

    final requestTime = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final now = DateTime.now();
    if (now.difference(requestTime) > maxTimestampAge) {
      return SlackVerificationResult(
        isValid: false,
        errorMessage: 'Request timestamp too old (replay attack prevention)',
        timestamp: requestTime,
      );
    }

    // Compute expected signature using Slack's algorithm
    final baseString = 'v0:$timestampStr:$body';
    final hmac = Hmac(sha256, utf8.encode(signingSecret));
    final digest = hmac.convert(utf8.encode(baseString));
    final expectedSignature = 'v0=$digest';

    // Compare signatures using constant-time comparison
    if (!_constantTimeCompare(signature, expectedSignature)) {
      return SlackVerificationResult(
        isValid: false,
        errorMessage: 'Signature mismatch',
        timestamp: requestTime,
      );
    }

    // Extract metadata from body if possible
    String? teamId;
    String? requestType;
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      teamId = json['team_id'] as String?;
      requestType = json['type'] as String?;
    } catch (_) {
      // Ignore JSON parsing errors - verification succeeded
    }

    return SlackVerificationResult(
      isValid: true,
      teamId: teamId,
      timestamp: requestTime,
      requestType: requestType,
    );
  }

  /// Constant-time string comparison to prevent timing attacks.
  ///
  /// Compares two strings character by character, always checking all
  /// characters even if a mismatch is found early. This prevents attackers
  /// from using timing information to guess the correct signature.
  bool _constantTimeCompare(String a, String b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }
}
