# dddart_webhooks

Webhook support for DDDart - A framework for receiving, verifying, and processing webhooks from external services with strongly-typed payloads and verification results.

## Overview

Webhooks are HTTP callbacks that external services (GitHub, Slack, Stripe, etc.) use to notify your application of events. This package provides a robust framework for handling webhooks with:

- **Signature verification** to ensure webhooks come from legitimate sources
- **Strongly-typed payloads** for compile-time safety and IDE support
- **Flexible deserialization** supporting JSON, form-encoded, and custom formats
- **Extensible architecture** for implementing custom webhook providers
- **Seamless integration** with dddart_http's HttpServer

## Features

- **Generic webhook resource handling** - WebhookResource class for processing incoming webhooks
- **Pluggable signature verification** - Extensible WebhookVerifier interface for custom verification logic
- **Strongly-typed verification results** - Type-safe verification results with provider-specific metadata
- **Flexible payload deserialization** - Support for JSON, form-encoded, and custom formats
- **Error handling** - Customizable error responses for verification and deserialization failures
- **Integration with dddart_http** - Seamless integration with HttpServer

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  dddart_webhooks: ^0.9.0
```

## Quick Start

### 1. Create a Custom Verifier

```dart
import 'package:dddart_webhooks/dddart_webhooks.dart';
import 'package:shelf/shelf.dart';

class MyVerificationResult extends WebhookVerificationResult {
  const MyVerificationResult({
    required super.isValid,
    super.errorMessage,
    this.userId,
  });

  final String? userId;
}

class MyWebhookVerifier extends WebhookVerifier<MyVerificationResult> {
  MyWebhookVerifier(this.secret);

  final String secret;

  @override
  Future<MyVerificationResult> verify(Request request, String body) async {
    final signature = request.headers['X-Signature'];
    
    if (signature == null) {
      return MyVerificationResult(
        isValid: false,
        errorMessage: 'Missing signature header',
      );
    }

    // Implement your verification logic
    final isValid = _verifySignature(signature, body);

    return MyVerificationResult(
      isValid: isValid,
      errorMessage: isValid ? null : 'Invalid signature',
    );
  }

  bool _verifySignature(String signature, String body) {
    // Your verification logic here
    return true;
  }
}
```

### 2. Register Webhook with HttpServer

```dart
import 'package:dddart_http/dddart_http.dart';
import 'package:dddart_webhooks/dddart_webhooks.dart';

void main() async {
  final server = HttpServer(port: 8080);

  final webhook = WebhookResource<MyPayload, MyVerificationResult>(
    path: '/webhooks/my-service',
    verifier: MyWebhookVerifier('my-secret'),
    deserializer: (body) => WebhookDeserializers.json(
      body,
      MyPayload.fromJson,
    ),
    handler: (payload, verification) async {
      print('Received webhook from user: ${verification.userId}');
      print('Payload: ${payload.data}');
      
      return Response.ok('Webhook processed');
    },
  );

  server.registerWebhook(webhook);
  await server.start();
}
```

## Deserialization Helpers

The package provides helper functions for common webhook formats:

### JSON Webhooks

```dart
WebhookResource<MyPayload, MyVerificationResult>(
  deserializer: (body) => WebhookDeserializers.json(
    body,
    MyPayload.fromJson,
  ),
  // ...
);
```

### Form-Encoded Webhooks

```dart
WebhookResource<MyPayload, MyVerificationResult>(
  deserializer: (body) => WebhookDeserializers.form(
    body,
    MyPayload.fromForm,
  ),
  // ...
);
```

### Raw String Webhooks

```dart
WebhookResource<String, MyVerificationResult>(
  // No deserializer - passes raw body
  handler: (body, verification) async {
    print('Raw body: $body');
    return Response.ok('Received');
  },
);
```

## Error Handling

### Custom Deserialization Error Handler

```dart
WebhookResource<MyPayload, MyVerificationResult>(
  deserializer: (body) => MyPayload.fromJson(jsonDecode(body)),
  onDeserializationError: (body, error) async {
    print('Failed to deserialize: $error');
    return Response(
      400,
      body: jsonEncode({'error': 'Invalid payload format'}),
    );
  },
  // ...
);
```

## Security Considerations

### HTTPS Required

**Always use HTTPS for webhook endpoints in production.** Webhook payloads often contain sensitive data, and signature verification alone does not protect against man-in-the-middle attacks if transmitted over HTTP.

Options for HTTPS:
- Use a reverse proxy (nginx, Caddy, Traefik) with TLS termination
- Deploy to a platform with built-in HTTPS (Cloud Run, Heroku, Fly.io)
- Use Let's Encrypt for free TLS certificates

### Secret Management

**Never hardcode signing secrets in your source code.** Use environment variables or a secret management service:

```dart
// ✅ Good - Use environment variables
final secret = Platform.environment['WEBHOOK_SECRET']!;

// ❌ Bad - Hardcoded secret
final secret = 'my-secret-key';
```

For production applications, consider:
- **Environment variables** - Simple and widely supported
- **Secret management services** - AWS Secrets Manager, Google Secret Manager, HashiCorp Vault
- **Configuration files** - Encrypted configuration files loaded at runtime

### Signature Verification

Always implement proper signature verification in your custom verifiers:

1. **Use HMAC with SHA-256 or stronger** - Provides cryptographic integrity
2. **Constant-time comparison** - Prevents timing attacks
3. **Include timestamp in signature** - Prevents replay attacks
4. **Validate timestamp age** - Reject old requests (typically 5-15 minutes)

Example constant-time comparison:

```dart
bool constantTimeCompare(String a, String b) {
  if (a.length != b.length) return false;
  var result = 0;
  for (var i = 0; i < a.length; i++) {
    result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return result == 0;
}
```

### Request Validation

In addition to signature verification:

1. **Validate request method** - Only accept POST requests
2. **Validate Content-Type** - Ensure expected format (application/json, application/x-www-form-urlencoded)
3. **Limit request size** - Prevent memory exhaustion from large payloads
4. **Rate limiting** - Protect against abuse and DoS attacks

### Error Responses

Be careful about information disclosure in error responses:

```dart
// ✅ Good - Generic error message
return Response(401, body: jsonEncode({
  'error': 'Signature verification failed',
}));

// ❌ Bad - Reveals implementation details
return Response(401, body: jsonEncode({
  'error': 'Expected signature: $expectedSig, got: $actualSig',
}));
```

## Provider Implementations

For specific webhook providers, see:

- **dddart_webhooks_slack** - Slack webhook support with HMAC-SHA256 signature verification

## Architecture

### Extensibility

The package is designed for extensibility. To add support for a new webhook provider:

1. **Create a verification result class** extending `WebhookVerificationResult`
2. **Create a verifier class** extending `WebhookVerifier<YourVerificationResult>`
3. **Implement the verify() method** with provider-specific signature verification
4. **Create payload models** as needed (extending `Value` from dddart)
5. **Package as a separate library** (e.g., `dddart_webhooks_github`)

See `dddart_webhooks_slack` as a reference implementation.

## Examples

See the `example/` directory for complete examples:

- `custom_verifier_example.dart` - Custom verifier implementation
- `raw_json_example.dart` - Raw JSON handling
- `form_encoded_example.dart` - Form-encoded handling

## API Reference

### WebhookResource<TPayload, TVerification>

Generic webhook resource for handling incoming webhooks.

**Type Parameters:**
- `TPayload` - The type of the deserialized webhook payload
- `TVerification` - The type of the verification result (extends WebhookVerificationResult)

**Constructor Parameters:**
- `path` - The HTTP path for this webhook endpoint
- `verifier` - The verifier used to validate webhook signatures
- `deserializer` - Optional function to convert raw body String to TPayload
- `handler` - Handler function invoked with verified and deserialized payload
- `onDeserializationError` - Optional error handler for deserialization failures

### WebhookVerifier<T extends WebhookVerificationResult>

Abstract base class for webhook signature verifiers.

**Methods:**
- `verify(Request request, String body)` - Verifies the webhook request signature and returns a strongly-typed verification result

### WebhookVerificationResult

Base class for webhook verification results.

**Properties:**
- `isValid` - Whether the webhook signature verification succeeded
- `errorMessage` - Error message if verification failed, null otherwise

### WebhookDeserializers

Helper functions for common webhook formats.

**Static Methods:**
- `json<T>(String body, T Function(Map<String, dynamic>) fromJson)` - Deserializes JSON payload
- `form<T>(String body, T Function(Map<String, String>) fromForm)` - Deserializes form-encoded payload

## License

MIT License - see LICENSE file for details.
