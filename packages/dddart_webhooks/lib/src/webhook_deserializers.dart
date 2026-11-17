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
/// See the [complete examples and setup](https://github.com/continuousimagination/dddart/blob/main/packages/dddart_webhooks/README.md).
///
/// ### Form-Encoded Webhooks
///
/// See the [complete examples and setup](https://github.com/continuousimagination/dddart/blob/main/packages/dddart_webhooks/README.md).
///
/// ### Raw String Webhooks
///
/// If no deserializer is provided and the payload type is String, the raw
/// body is passed directly to the handler:
///
/// See the [complete examples and setup](https://github.com/continuousimagination/dddart/blob/main/packages/dddart_webhooks/README.md).
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
  /// See the [complete examples and setup](https://github.com/continuousimagination/dddart/blob/main/packages/dddart_webhooks/README.md).
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
  /// See the [complete examples and setup](https://github.com/continuousimagination/dddart/blob/main/packages/dddart_webhooks/README.md).
  static T form<T>(String body, T Function(Map<String, String>) fromForm) {
    final parsed = Uri.splitQueryString(body);
    return fromForm(parsed);
  }
}
