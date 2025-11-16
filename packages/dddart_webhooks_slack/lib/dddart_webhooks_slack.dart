/// Slack webhook implementation for DDDart.
///
/// Provides [SlackWebhookVerifier] for verifying Slack webhook signatures
/// using HMAC-SHA256 and [SlackVerificationResult] for strongly-typed
/// verification results with Slack-specific metadata.
///
/// Example:
/// ```dart
/// import 'package:dddart_webhooks_slack/dddart_webhooks_slack.dart';
///
/// final verifier = SlackWebhookVerifier(
///   signingSecret: 'your-slack-signing-secret',
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
///     // Handle slash command
///     return Response.ok('Command received!');
///   },
/// );
/// ```
library dddart_webhooks_slack;

export 'src/slack_slash_command.dart';
export 'src/slack_verification_result.dart';
export 'src/slack_webhook_verifier.dart';
