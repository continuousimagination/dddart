import 'dart:convert';

/// Helper functions for deserializing webhook payloads.
///
/// Provides static methods for common webhook payload formats (JSON,
/// form-encoded). These helpers are not used by default - developers must
/// explicitly choose the format when configuring their webhook resource.
///
/// ## Usage
///
/// ### JSON Webhooks
///
/// ```dart
/// WebhookResource<MyEvent, MyVerification>(
///   path: '/webhooks/events',
///   verifier: MyVerifier(),
///   deserializer: (body) => WebhookDeserializers.json(
///     body,
///     MyEvent.fromJson,
///   ),
///   handler: (event, verification) async {
///     // Handle event
///     return Response.ok('Received');
///   },
/// );
/// ```
///
/// ### Form-Encoded Webhooks
///
/// ```dart
/// WebhookResource<SlackSlashCommand, SlackVerification>(
///   path: '/webhooks/slack/commands',
///   verifier: SlackWebhookVerifier(signingSecret: 'secret'),
///   deserializer: (body) => WebhookDeserializers.form(
///     body,
///     SlackSlashCommand.fromForm,
///   ),
///   handler: (command, verification) async {
///     // Handle command
///     return Response.ok('Command received');
///   },
/// );
/// ```
///
/// ### Raw String Webhooks
///
/// If no deserializer is provided and the payload type is String, the raw
/// body is passed directly to the handler:
///
/// ```dart
/// WebhookResource<String, MyVerification>(
///   path: '/webhooks/raw',
///   verifier: MyVerifier(),
///   // No deserializer - raw body passed to handler
///   handler: (body, verification) async {
///     // Process raw body
///     return Response.ok('Received');
///   },
/// );
/// ```
class WebhookDeserializers {
  // Private constructor to prevent instantiation
  WebhookDeserializers._();

  /// Deserializes a JSON payload.
  ///
  /// Parses the raw body string as JSON and converts it to a strongly-typed
  /// object using the provided [fromJson] factory function.
  ///
  /// The [body] must be valid JSON that parses to a Map<String, dynamic>.
  /// The [fromJson] function receives the parsed map and returns an instance
  /// of type [T].
  ///
  /// Throws [FormatException] if the body is not valid JSON.
  /// Throws [TypeError] if the parsed JSON is not a Map<String, dynamic>.
  ///
  /// Example:
  /// ```dart
  /// class MyEvent {
  ///   MyEvent({required this.id, required this.type});
  ///
  ///   factory MyEvent.fromJson(Map<String, dynamic> json) {
  ///     return MyEvent(
  ///       id: json['id'] as String,
  ///       type: json['type'] as String,
  ///     );
  ///   }
  ///
  ///   final String id;
  ///   final String type;
  /// }
  ///
  /// final event = WebhookDeserializers.json(
  ///   '{"id": "123", "type": "user.created"}',
  ///   MyEvent.fromJson,
  /// );
  /// ```
  static T json<T>(String body, T Function(Map<String, dynamic>) fromJson) {
    final parsed = jsonDecode(body) as Map<String, dynamic>;
    return fromJson(parsed);
  }

  /// Deserializes a form-encoded payload.
  ///
  /// Parses the raw body string as application/x-www-form-urlencoded data
  /// and converts it to a strongly-typed object using the provided [fromForm]
  /// factory function.
  ///
  /// The [body] should be in the format: `key1=value1&key2=value2`.
  /// The [fromForm] function receives a Map<String, String> of the parsed
  /// form data and returns an instance of type [T].
  ///
  /// Example:
  /// ```dart
  /// class SlackSlashCommand {
  ///   SlackSlashCommand({
  ///     required this.command,
  ///     required this.text,
  ///     required this.userId,
  ///   });
  ///
  ///   factory SlackSlashCommand.fromForm(Map<String, String> form) {
  ///     return SlackSlashCommand(
  ///       command: form['command']!,
  ///       text: form['text'] ?? '',
  ///       userId: form['user_id']!,
  ///     );
  ///   }
  ///
  ///   final String command;
  ///   final String text;
  ///   final String userId;
  /// }
  ///
  /// final command = WebhookDeserializers.form(
  ///   'command=/hello&text=world&user_id=U123',
  ///   SlackSlashCommand.fromForm,
  /// );
  /// ```
  static T form<T>(String body, T Function(Map<String, String>) fromForm) {
    final parsed = Uri.splitQueryString(body);
    return fromForm(parsed);
  }
}
