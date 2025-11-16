# dddart_webhooks Examples

This directory contains runnable examples demonstrating how to use the dddart_webhooks package.

## Examples

### 1. Custom Verifier Example

**File:** `custom_verifier_example.dart`

Demonstrates how to create a custom webhook verifier with:
- Custom verification result class with provider-specific metadata
- HMAC-SHA256 signature verification
- Timestamp validation to prevent replay attacks
- Constant-time comparison to prevent timing attacks
- Extracting metadata from request headers

**Run:**
```bash
dart run example/custom_verifier_example.dart
```

**Test:**
```bash
# Compute signature: HMAC-SHA256(secret, "timestamp:body")
TIMESTAMP=$(date +%s)
BODY='{"event":"user.created","userId":"123"}'
SIGNATURE=$(echo -n "$TIMESTAMP:$BODY" | openssl dgst -sha256 -hmac "my-secret-key" | cut -d' ' -f2)

curl -X POST http://localhost:8080/webhooks/custom \
  -H "Content-Type: application/json" \
  -H "X-Webhook-Signature: $SIGNATURE" \
  -H "X-Webhook-Timestamp: $TIMESTAMP" \
  -H "X-User-Id: user-123" \
  -d "$BODY"
```

### 2. Raw JSON Example

**File:** `raw_json_example.dart`

Demonstrates handling JSON webhook payloads with:
- Using `WebhookDeserializers.json()` for JSON deserialization
- Processing different event types from a single endpoint
- Custom deserialization error handling
- Strongly-typed JSON payloads

**Run:**
```bash
dart run example/raw_json_example.dart
```

**Test:**
```bash
# User created event
BODY='{"type":"user.created","data":{"id":"123","name":"Alice"}}'
SIGNATURE=$(echo -n "$BODY" | openssl dgst -sha256 -hmac "json-secret" | cut -d' ' -f2)

curl -X POST http://localhost:8080/webhooks/events \
  -H "Content-Type: application/json" \
  -H "X-Signature: $SIGNATURE" \
  -d "$BODY"

# Order placed event
BODY='{"type":"order.placed","data":{"orderId":"456","total":99.99}}'
SIGNATURE=$(echo -n "$BODY" | openssl dgst -sha256 -hmac "json-secret" | cut -d' ' -f2)

curl -X POST http://localhost:8080/webhooks/events \
  -H "Content-Type: application/json" \
  -H "X-Signature: $SIGNATURE" \
  -d "$BODY"
```

### 3. Form-Encoded Example

**File:** `form_encoded_example.dart`

Demonstrates handling form-encoded webhook payloads with:
- Using `WebhookDeserializers.form()` for form data deserialization
- Processing application/x-www-form-urlencoded data
- Command-style webhooks (similar to Slack slash commands)
- Formatted response messages

**Run:**
```bash
dart run example/form_encoded_example.dart
```

**Test:**
```bash
# Hello command
BODY="command=/hello&text=world&user_id=U123&user_name=alice&channel_id=C456"
SIGNATURE=$(echo -n "$BODY" | openssl dgst -sha256 -hmac "form-secret" | cut -d' ' -f2)

curl -X POST http://localhost:8080/webhooks/commands \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -H "X-Signature: $SIGNATURE" \
  -d "$BODY"

# Help command
BODY="command=/help&text=&user_id=U123&user_name=alice&channel_id=C456"
SIGNATURE=$(echo -n "$BODY" | openssl dgst -sha256 -hmac "form-secret" | cut -d' ' -f2)

curl -X POST http://localhost:8080/webhooks/commands \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -H "X-Signature: $SIGNATURE" \
  -d "$BODY"

# Status command
BODY="command=/status&text=&user_id=U123&user_name=alice&channel_id=C456"
SIGNATURE=$(echo -n "$BODY" | openssl dgst -sha256 -hmac "form-secret" | cut -d' ' -f2)

curl -X POST http://localhost:8080/webhooks/commands \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -H "X-Signature: $SIGNATURE" \
  -d "$BODY"
```

## Common Patterns

### Creating a Custom Verifier

1. **Define a verification result class:**
   ```dart
   class MyVerificationResult extends WebhookVerificationResult {
     const MyVerificationResult({
       required super.isValid,
       super.errorMessage,
       this.customMetadata,
     });
     
     final String? customMetadata;
   }
   ```

2. **Implement the verifier:**
   ```dart
   class MyWebhookVerifier extends WebhookVerifier<MyVerificationResult> {
     MyWebhookVerifier({required this.secret});
     
     final String secret;
     
     @override
     Future<MyVerificationResult> verify(Request request, String body) async {
       // Extract headers
       final signature = request.headers['x-signature'];
       
       // Validate signature
       final expectedSignature = _computeSignature(body);
       if (signature != expectedSignature) {
         return MyVerificationResult(
           isValid: false,
           errorMessage: 'Invalid signature',
         );
       }
       
       return MyVerificationResult(isValid: true);
     }
   }
   ```

3. **Use with WebhookResource:**
   ```dart
   server.registerWebhook(
     WebhookResource<MyPayload, MyVerificationResult>(
       path: '/webhooks/my-service',
       verifier: MyWebhookVerifier(secret: 'my-secret'),
       deserializer: (body) => MyPayload.fromJson(jsonDecode(body)),
       handler: (payload, verification) async {
         // Handle webhook
         return Response.ok('Received');
       },
     ),
   );
   ```

### Choosing a Deserializer

**JSON webhooks:**
```dart
deserializer: (body) => WebhookDeserializers.json(
  body,
  MyPayload.fromJson,
)
```

**Form-encoded webhooks:**
```dart
deserializer: (body) => WebhookDeserializers.form(
  body,
  MyPayload.fromForm,
)
```

**Raw string webhooks:**
```dart
// No deserializer - raw body passed to handler
WebhookResource<String, MyVerification>(
  verifier: myVerifier,
  handler: (body, verification) async {
    // body is the raw request body string
    return Response.ok('Received');
  },
)
```

### Error Handling

**Custom deserialization error handler:**
```dart
WebhookResource<MyPayload, MyVerification>(
  verifier: myVerifier,
  deserializer: (body) => MyPayload.fromJson(jsonDecode(body)),
  handler: (payload, verification) async {
    return Response.ok('Processed');
  },
  onDeserializationError: (body, error) async {
    // Log error with raw body for debugging
    print('Deserialization failed: $error');
    print('Raw body: $body');
    
    // Return custom error response
    return Response(
      400,
      body: jsonEncode({
        'error': 'Invalid payload',
        'details': error.toString(),
      }),
      headers: {'Content-Type': 'application/json'},
    );
  },
)
```

## Security Considerations

When implementing webhooks in production:

1. **Always use HTTPS** - Never expose webhook endpoints over HTTP in production
2. **Store secrets securely** - Use environment variables or secret managers
3. **Validate signatures** - Always verify webhook signatures before processing
4. **Prevent replay attacks** - Validate timestamps and reject old requests
5. **Use constant-time comparison** - Prevent timing attacks when comparing signatures
6. **Rate limiting** - Consider implementing rate limiting for webhook endpoints
7. **Logging** - Log webhook failures for debugging, but be careful with sensitive data

## Dependencies

All examples require:
- `dddart_webhooks` - The webhook framework
- `dddart_http` - HTTP server integration
- `crypto` - For HMAC signature computation
- `shelf` - HTTP request/response handling

## Next Steps

- See the [dddart_webhooks_slack](../../dddart_webhooks_slack) package for a complete Slack webhook implementation
- Read the [dddart_webhooks README](../README.md) for API documentation
- Check the [design document](../../../.kiro/specs/webhook-support/design.md) for architecture details
