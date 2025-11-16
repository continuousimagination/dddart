# dddart_webhooks_slack

Slack webhook implementation for DDDart. Provides signature verification and strongly-typed models for Slack webhooks.

## Features

- **SlackWebhookVerifier**: HMAC-SHA256 signature verification following Slack's security requirements
- **SlackVerificationResult**: Strongly-typed verification results with Slack-specific metadata (team ID, timestamp, request type)
- **SlackSlashCommand**: Value object for slash command payloads
- **Replay Attack Prevention**: Automatic timestamp validation to prevent replay attacks
- **Constant-Time Comparison**: Secure signature comparison to prevent timing attacks

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  dddart_webhooks_slack: ^0.9.0
```

## Quick Start

### 1. Set Up Slack App

1. **Create a Slack app** at https://api.slack.com/apps
   - Click "Create New App"
   - Choose "From scratch"
   - Enter app name and select workspace

2. **Enable features** you need:
   - **Slash Commands**: "Slash Commands" → "Create New Command"
   - **Interactive Components**: "Interactivity & Shortcuts" → Enable
   - **Event Subscriptions**: "Event Subscriptions" → Enable

3. **Get your signing secret**:
   - Go to "Basic Information" → "App Credentials"
   - Copy the "Signing Secret" (not the Client Secret)
   - Store it securely (environment variable, secret manager)

4. **Configure request URLs**:
   - Set your webhook endpoint URL (must be HTTPS in production)
   - Slack will send a verification request to validate the URL
   - Example: `https://yourdomain.com/slack/commands`

5. **Install app to workspace**:
   - Go to "Install App" → "Install to Workspace"
   - Authorize the requested permissions

### 2. Create Webhook Handler

```dart
import 'package:dddart_http/dddart_http.dart';
import 'package:dddart_webhooks/dddart_webhooks.dart';
import 'package:dddart_webhooks_slack/dddart_webhooks_slack.dart';

void main() async {
  final server = HttpServer(port: 8080);

  // Create Slack webhook verifier
  final verifier = SlackWebhookVerifier(
    signingSecret: 'your-slack-signing-secret',
  );

  // Register slash command webhook
  server.registerWebhook(
    WebhookResource<SlackSlashCommand, SlackVerificationResult>(
      path: '/slack/commands',
      verifier: verifier,
      deserializer: (body) => WebhookDeserializers.form(
        body,
        SlackSlashCommand.fromForm,
      ),
      handler: (command, verification) async {
        print('Command: ${command.command}');
        print('Text: ${command.text}');
        print('User: ${command.userName}');
        print('Team: ${verification.teamId}');

        return Response.ok('Command received!');
      },
    ),
  );

  await server.start();
  print('Server listening on port 8080');
}
```

## Security Considerations

### HTTPS Required

**Slack requires webhook endpoints to use HTTPS in production.** HTTP endpoints will be rejected by Slack.

Options for HTTPS:
- **Reverse proxy**: nginx, Caddy, or Traefik with TLS termination
- **Cloud platforms**: Cloud Run, Heroku, Fly.io (built-in HTTPS)
- **Let's Encrypt**: Free TLS certificates for your domain

Example nginx configuration:

```nginx
server {
    listen 443 ssl;
    server_name yourdomain.com;
    
    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;
    
    location /slack/ {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### Secret Management

**Never hardcode signing secrets in your source code.** Slack signing secrets are sensitive credentials that should be protected.

Best practices:

```dart
// ✅ Good - Environment variable
final signingSecret = Platform.environment['SLACK_SIGNING_SECRET']!;

// ✅ Good - Secret management service
final signingSecret = await secretManager.getSecret('slack-signing-secret');

// ❌ Bad - Hardcoded secret
final signingSecret = 'a1b2c3d4e5f6...';
```

For production:
- **Environment variables** - Simple and widely supported
- **AWS Secrets Manager** - Managed secret rotation
- **Google Secret Manager** - Integrated with GCP
- **HashiCorp Vault** - Enterprise secret management
- **Kubernetes Secrets** - For containerized deployments

### Replay Attack Prevention

The verifier automatically validates request timestamps and rejects requests older than 5 minutes (configurable):

```dart
final verifier = SlackWebhookVerifier(
  signingSecret: secret,
  maxTimestampAge: Duration(minutes: 5), // Default
);
```

This prevents attackers from capturing and replaying old webhook requests. Slack includes the timestamp in the signature calculation, so tampering with the timestamp will cause verification to fail.

### Signature Verification

The `SlackWebhookVerifier` implements Slack's signature verification algorithm:

1. **Extracts headers**: `X-Slack-Signature` and `X-Slack-Request-Timestamp`
2. **Validates timestamp**: Rejects requests older than `maxTimestampAge`
3. **Computes HMAC-SHA256**: Using the signing secret and request data
4. **Constant-time comparison**: Prevents timing attacks

The implementation follows Slack's official documentation: https://api.slack.com/authentication/verifying-requests-from-slack

### Rate Limiting

Consider implementing rate limiting to protect against abuse:

```dart
// Example using shelf_rate_limiter
final rateLimiter = RateLimiter(
  maxRequests: 100,
  window: Duration(minutes: 1),
);

server.use(rateLimiter.middleware);
```

### Logging and Monitoring

Log webhook events for security monitoring:

```dart
handler: (command, verification) async {
  logger.info('Slack command received', {
    'command': command.command,
    'user_id': command.userId,
    'team_id': verification.teamId,
    'timestamp': verification.timestamp,
  });
  
  // Process command...
}
```

Monitor for:
- Failed signature verifications (potential attack)
- Unusual request patterns
- Expired timestamp rejections (clock skew or replay attempts)

## API Reference

### SlackWebhookVerifier

Verifies Slack webhook signatures using HMAC-SHA256.

**Constructor:**
```dart
SlackWebhookVerifier({
  required String signingSecret,
  Duration maxTimestampAge = const Duration(minutes: 5),
})
```

**Parameters:**
- `signingSecret`: Your Slack app's signing secret
- `maxTimestampAge`: Maximum age of request timestamp (replay attack prevention)

### SlackVerificationResult

Strongly-typed verification result with Slack metadata.

**Properties:**
- `isValid`: Whether signature verification succeeded
- `errorMessage`: Error message if verification failed
- `teamId`: Slack workspace/team ID
- `timestamp`: Request timestamp from headers
- `requestType`: Type of Slack request (slash_command, interactive_message, etc.)

### SlackSlashCommand

Value object representing a Slack slash command payload.

**Properties:**
- `command`: The slash command (e.g., "/weather")
- `text`: Command arguments
- `userId`: User who invoked the command
- `userName`: Username
- `teamId`: Workspace/team ID
- `channelId`: Channel where command was invoked
- `responseUrl`: URL for delayed responses
- `triggerId`: Trigger ID for opening modals

## Advanced Usage

### Handling Different Request Types

Slack sends different types of webhooks. Use the `requestType` from the verification result to handle them appropriately:

```dart
handler: (payload, verification) async {
  switch (verification.requestType) {
    case 'url_verification':
      // Respond to Slack's URL verification challenge
      final challenge = jsonDecode(payload)['challenge'];
      return Response.ok(challenge);
      
    case 'slash_command':
      // Handle slash command
      return handleSlashCommand(payload);
      
    case 'interactive_message':
      // Handle button/menu interaction
      return handleInteraction(payload);
      
    default:
      return Response.ok('Event received');
  }
}
```

### Delayed Responses

Slack requires responses within 3 seconds. For longer operations, use the `response_url`:

```dart
handler: (command, verification) async {
  // Respond immediately
  unawaited(_processCommandAsync(command));
  
  return Response.ok(jsonEncode({
    'response_type': 'ephemeral',
    'text': 'Processing your request...',
  }));
}

Future<void> _processCommandAsync(SlackSlashCommand command) async {
  // Perform long-running operation
  final result = await expensiveOperation();
  
  // Send delayed response
  final client = http.Client();
  await client.post(
    Uri.parse(command.responseUrl),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'response_type': 'in_channel',
      'text': 'Operation complete: $result',
    }),
  );
}
```

### Custom Payload Models

For interactive messages or other Slack events, create custom payload models:

```dart
class SlackInteraction extends Value {
  const SlackInteraction({
    required this.type,
    required this.user,
    required this.actions,
    required this.responseUrl,
  });

  factory SlackInteraction.fromJson(Map<String, dynamic> json) {
    return SlackInteraction(
      type: json['type'] as String,
      user: json['user']['id'] as String,
      actions: (json['actions'] as List).cast<Map<String, dynamic>>(),
      responseUrl: json['response_url'] as String,
    );
  }

  final String type;
  final String user;
  final List<Map<String, dynamic>> actions;
  final String responseUrl;

  @override
  List<Object?> get props => [type, user, actions, responseUrl];
}
```

### Multiple Slack Workspaces

To support multiple Slack workspaces, use the `teamId` from the verification result:

```dart
final verifiers = {
  'T1234567890': SlackWebhookVerifier(signingSecret: secret1),
  'T0987654321': SlackWebhookVerifier(signingSecret: secret2),
};

handler: (command, verification) async {
  final teamId = verification.teamId!;
  final workspace = await getWorkspaceConfig(teamId);
  
  // Process command with workspace-specific logic
  return processCommand(command, workspace);
}
```

## Troubleshooting

### Signature Verification Fails

1. **Check signing secret**: Ensure you're using the Signing Secret, not the Client Secret
2. **Check timestamp**: Verify server clock is synchronized (use NTP)
3. **Check HTTPS**: Ensure your endpoint uses HTTPS in production
4. **Check headers**: Verify `X-Slack-Signature` and `X-Slack-Request-Timestamp` are present

### URL Verification Fails

When setting up your webhook URL, Slack sends a verification challenge:

```dart
handler: (body, verification) async {
  // Parse raw body for URL verification
  final json = jsonDecode(body);
  
  if (json['type'] == 'url_verification') {
    return Response.ok(json['challenge']);
  }
  
  // Handle normal webhook...
}
```

### Timeout Errors

Slack requires responses within 3 seconds. For long operations:

1. Respond immediately with acknowledgment
2. Process asynchronously
3. Send results to `response_url`

## Examples

See the `example/` directory for complete examples:

- `slash_command_example.dart`: Handle slash commands with immediate responses
- `interactive_message_example.dart`: Handle button and menu interactions

## Resources

- [Slack API Documentation](https://api.slack.com/)
- [Verifying Requests from Slack](https://api.slack.com/authentication/verifying-requests-from-slack)
- [Slash Commands](https://api.slack.com/interactivity/slash-commands)
- [Interactive Components](https://api.slack.com/interactivity/components)

## License

MIT License - see LICENSE file for details.
