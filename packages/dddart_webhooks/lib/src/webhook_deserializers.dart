import 'dart:convert';

/// Decodes a verified webhook body with an application-supplied factory.
///
/// Use [json] for a JSON object and [form] for URL-encoded fields. To handle
/// the raw body, use a string payload and omit the resource's deserializer.
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
  static T form<T>(String body, T Function(Map<String, String>) fromForm) {
    final parsed = Uri.splitQueryString(body);
    return fromForm(parsed);
  }
}
