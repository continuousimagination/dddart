# Design Document

## Overview

This design implements webhook support for DDDart following a two-package architecture: `dddart_webhooks` (base framework) and `dddart_webhooks_slack` (Slack implementation). The design emphasizes strong typing, extensibility, and integration with the existing `dddart_http` package.

## Architecture

### Package Structure

```
packages/
├── dddart_webhooks/
│   ├── lib/
│   │   ├── dddart_webhooks.dart
│   │   └── src/
│   │       ├── webhook_resource.dart
│   │       ├── webhook_verifier.dart
│   │       └── webhook_verification_result.dart
│   ├── test/
│   └── example/
└── dddart_webhooks_slack/
    ├── lib/
    │   ├── dddart_webhooks_slack.dart
    │   └── src/
    │       ├── slack_webhook_verifier.dart
    │       └── slack_verification_result.dart
    ├── test/
    └── example/
```

### Dependencies

**dddart_webhooks:**
- `dddart_http` - For HttpServer integration and Response types
- `shelf` - For Request handling
- `dart:convert` - For JSON parsing

**dddart_webhooks_slack:**
- `dddart_webhooks` - Base webhook framework
- `crypto` - For HMAC-SHA256 signature verification

## Components and Interfaces

### 1. WebhookVerificationResult (Base Class)

```dart
/// Base class for webhook verification results.
///
/// Provides common properties for all verification results while allowing
/// provider-specific subclasses to add their own metadata.
abstract class WebhookVerificationResult {
  const WebhookVerificationResult({
    required this.isValid,
    this.errorMessage,
  });

  /// Whether the webhook signature verification succeeded.
  final bool isValid;

  /// Error message if verification failed, null otherwise.
  final String? errorMessage;
}
```

### 2. WebhookVerifier (Abstract Class)

```dart
/// Abstract base class for webhook signature verifiers.
///
/// Implementations verify webhook signatures using provider-specific
/// algorithms and return strongly-typed verification results.
abstract class WebhookVerifier<T extends WebhookVerificationResult> {
  /// Verifies the webhook request signature.
  ///
  /// Returns a strongly-typed verification result containing validation
  /// status and provider-specific metadata.
  Future<T> verify(Request request, String body);
}
```

### 3. WebhookResource (Generic Class)

```dart
/// HTTP resource for handling incoming webhooks.
///
/// Provides signature verification, payload deserialization, and handler
/// invocation with strongly-typed payloads and verification results.
class WebhookResource<TPayload, TVerification extends WebhookVerificationResult> {
  WebhookResource({
    required this.path,
    required this.verifier,
    this.deserializer,
    required this.handler,
    this.onDeserializationError,
  });

  /// The HTTP path for this webhook endpoint.
  final String path;

  /// The verifier used to validate webhook signatures.
  final WebhookVerifier<TVerification> verifier;

  /// Optional deserializer to convert raw body to strongly-typed payload.
  ///
  /// Receives the raw request body as a String and is responsible for parsing
  /// the format (JSON, form-encoded, XML, etc.) and converting to TPayload.
  ///
  /// If null and TPayload is String, raw body is passed to handler.
  final TPayload Function(String body)? deserializer;

  /// Handler function invoked with verified and deserialized payload.
  final Future<Response> Function(TPayload payload, TVerification verification) handler;

  /// Optional error handler for deserialization failures.
  ///
  /// If provided, receives raw body String and exception when deserialization fails.
  /// If not provided, returns 400 Bad Request on deserialization failure.
  final Future<Response> Function(String body, Object error)? onDeserializationError;

  /// Handles incoming webhook POST requests.
  Future<Response> handleRequest(Request request) async {
    // 1. Read request body
    final body = await request.readAsString();

    // 2. Verify signature
    final verification = await verifier.verify(request, body);
    if (!verification.isValid) {
      return Response(
        401,
        body: jsonEncode({
          'error': 'Signature verification failed',
          'message': verification.errorMessage ?? 'Invalid signature',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }

    // 3. Deserialize payload
    TPayload payload;
    try {
      if (deserializer != null) {
        payload = deserializer!(body);
      } else {
        // If no deserializer and TPayload is String, use raw body
        payload = body as TPayload;
      }
    } catch (e) {
      // Handle deserialization error
      if (onDeserializationError != null) {
        return await onDeserializationError!(body, e);
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

    // 5. Invoke handler
    try {
      return await handler(payload, verification);
    } catch (e, stackTrace) {
      // Log error (using logging package)
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
```

### 4. SlackVerificationResult (Slack-Specific)

```dart
/// Verification result for Slack webhooks.
///
/// Contains Slack-specific metadata extracted from headers and payload.
class SlackVerificationResult extends WebhookVerificationResult {
  const SlackVerificationResult({
    required super.isValid,
    super.errorMessage,
    this.teamId,
    this.timestamp,
    this.requestType,
  });

  /// The Slack team/workspace ID.
  final String? teamId;

  /// The request timestamp from X-Slack-Request-Timestamp header.
  final DateTime? timestamp;

  /// The type of Slack request (slash_command, interactive_message, etc.).
  final String? requestType;
}
```

### 5. SlackWebhookVerifier (Slack-Specific)

```dart
/// Webhook verifier for Slack webhooks.
///
/// Implements Slack's HMAC-SHA256 signature verification and timestamp
/// validation to prevent replay attacks.
class SlackWebhookVerifier extends WebhookVerifier<SlackVerificationResult> {
  SlackWebhookVerifier({
    required this.signingSecret,
    this.maxTimestampAge = const Duration(minutes: 5),
  });

  /// The Slack signing secret from your app configuration.
  final String signingSecret;

  /// Maximum age of request timestamp to prevent replay attacks.
  final Duration maxTimestampAge;

  @override
  Future<SlackVerificationResult> verify(Request request, String body) async {
    // Extract headers
    final signature = request.headers['X-Slack-Signature'];
    final timestampStr = request.headers['X-Slack-Request-Timestamp'];

    if (signature == null || timestampStr == null) {
      return SlackVerificationResult(
        isValid: false,
        errorMessage: 'Missing required Slack headers',
      );
    }

    // Parse and validate timestamp
    final timestamp = int.tryParse(timestampStr);
    if (timestamp == null) {
      return SlackVerificationResult(
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

    // Compute expected signature
    final baseString = 'v0:$timestampStr:$body';
    final hmac = Hmac(sha256, utf8.encode(signingSecret));
    final digest = hmac.convert(utf8.encode(baseString));
    final expectedSignature = 'v0=${digest.toString()}';

    // Compare signatures (constant-time comparison)
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
  bool _constantTimeCompare(String a, String b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }
}
```

## Deserialization Helpers

The `dddart_webhooks` package provides helper functions for common webhook formats:

```dart
/// Helper functions for deserializing webhook payloads.
class WebhookDeserializers {
  /// Deserializes JSON payload.
  static T json<T>(String body, T Function(Map<String, dynamic>) fromJson) {
    final parsed = jsonDecode(body) as Map<String, dynamic>;
    return fromJson(parsed);
  }

  /// Deserializes form-encoded payload.
  static T form<T>(String body, T Function(Map<String, String>) fromForm) {
    final parsed = Uri.splitQueryString(body);
    return fromForm(parsed);
  }
}
```

**Usage examples:**

```dart
// JSON webhook
WebhookResource<SlackEvent>(
  verifier: SlackWebhookVerifier(secret: 'xxx'),
  deserializer: (body) => WebhookDeserializers.json(body, SlackEvent.fromJson),
  handler: (event, verification) async { ... },
);

// Form-encoded webhook (Slack slash commands)
WebhookResource<SlackSlashCommand>(
  verifier: SlackWebhookVerifier(secret: 'xxx'),
  deserializer: (body) => WebhookDeserializers.form(body, SlackSlashCommand.fromForm),
  handler: (command, verification) async { ... },
);

// Raw string webhook
WebhookResource<String>(
  verifier: CustomVerifier(),
  // No deserializer - passes raw body
  handler: (body, verification) async { ... },
);
```

## Data Models

### Slack Slash Command Payload

```dart
/// Represents a Slack slash command webhook payload.
@Serializable()
class SlackSlashCommand extends Value {
  const SlackSlashCommand({
    required this.command,
    required this.text,
    required this.userId,
    required this.userName,
    required this.teamId,
    required this.channelId,
    required this.responseUrl,
    this.triggerId,
  });

  factory SlackSlashCommand.fromForm(Map<String, String> form) {
    return SlackSlashCommand(
      command: form['command']!,
      text: form['text'] ?? '',
      userId: form['user_id']!,
      userName: form['user_name']!,
      teamId: form['team_id']!,
      channelId: form['channel_id']!,
      responseUrl: form['response_url']!,
      triggerId: form['trigger_id'],
    );
  }

  final String command;
  final String text;
  final String userId;
  final String userName;
  final String teamId;
  final String channelId;
  final String responseUrl;
  final String? triggerId;

  @override
  List<Object?> get props => [
        command,
        text,
        userId,
        userName,
        teamId,
        channelId,
        responseUrl,
        triggerId,
      ];
}
```

## Integration with HttpServer

The `HttpServer` class in `dddart_http` will be extended to support webhook resources:

```dart
class HttpServer {
  // Existing methods...

  /// Registers a webhook resource.
  void registerWebhook<TPayload, TVerification extends WebhookVerificationResult>(
    WebhookResource<TPayload, TVerification> webhook,
  ) {
    // Register POST route for webhook path
    router.post(webhook.path, (Request request) async {
      return await webhook.handleRequest(request);
    });
  }
}
```

## Error Handling

### Error Response Format

All error responses follow a consistent JSON format:

```json
{
  "error": "Error category",
  "message": "Detailed error message"
}
```

### Error Scenarios

1. **Signature Verification Failure** → 401 Unauthorized
2. **Invalid JSON** → 400 Bad Request
3. **Deserialization Failure** → 400 Bad Request (or custom via error handler)
4. **Handler Exception** → 500 Internal Server Error
5. **Replay Attack (old timestamp)** → 401 Unauthorized

## Testing Strategy

### Unit Tests

**dddart_webhooks:**
- `webhook_resource_test.dart` - Test request handling, error responses
- `webhook_verification_result_test.dart` - Test base class properties

**dddart_webhooks_slack:**
- `slack_webhook_verifier_test.dart` - Test signature verification, timestamp validation
- `slack_verification_result_test.dart` - Test Slack-specific properties
- `slack_slash_command_test.dart` - Test payload deserialization

### Integration Tests

- `webhook_integration_test.dart` - Test end-to-end webhook processing with HttpServer
- `slack_webhook_integration_test.dart` - Test Slack webhook with real-world payloads

### Test Data

Use actual Slack webhook payloads from Slack's documentation for realistic testing.

## Security Considerations

1. **Constant-time signature comparison** - Prevents timing attacks
2. **Timestamp validation** - Prevents replay attacks (default 5-minute window)
3. **HTTPS enforcement** - Document that webhooks should only be exposed over HTTPS
4. **Secret management** - Document secure storage of signing secrets (environment variables, secret managers)

## Performance Considerations

1. **Async verification** - All verification is async to support future database lookups
2. **Minimal allocations** - Reuse parsed JSON for both verification and deserialization
3. **Streaming body read** - Read request body once and reuse

## Future Extensibility

The design supports future webhook providers:

1. **GitHub**: `dddart_webhooks_github` package with `GitHubWebhookVerifier`
2. **Stripe**: `dddart_webhooks_stripe` package with `StripeWebhookVerifier`
3. **Custom providers**: Developers can implement `WebhookVerifier` and `WebhookVerificationResult`

Each provider package follows the same pattern established by `dddart_webhooks_slack`.
