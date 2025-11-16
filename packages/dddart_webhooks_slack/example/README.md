# dddart_webhooks_slack Examples

This directory contains runnable examples demonstrating how to use the dddart_webhooks_slack package to handle Slack webhooks.

## Prerequisites

Before running these examples, you need:

1. **A Slack App** - Create one at https://api.slack.com/apps
2. **Signing Secret** - Found in your app's "Basic Information" → "App Credentials"
3. **ngrok or similar** - For exposing localhost to Slack (for local testing)

## Examples

### 1. Slash Command Example

**File:** `slash_command_example.dart`

Demonstrates handling Slack slash commands with:
- SlackWebhookVerifier for signature verification
- Form-encoded payload deserialization
- Multiple command handlers (/weather, /help, /status, /echo)
- Slack Block Kit formatted responses
- Ephemeral vs in-channel responses

**Setup:**

1. Set your Slack signing secret:
   ```bash
   export SLACK_SIGNING_SECRET="your-signing-secret-here"
   ```

2. Run the example:
   ```bash
   dart run example/slash_command_example.dart
   ```

3. Expose localhost to the internet (for local testing):
   ```bash
   ngrok http 8080
   ```

4. Configure slash commands in your Slack app:
   - Go to https://api.slack.com/apps → Your App → "Slash Commands"
   - Click "Create New Command"
   - Set Request URL to: `https://your-ngrok-url.ngrok.io/slack/commands`
   - Create commands: `/weather`, `/help`, `/status`, `/echo`
   - Save and reinstall your app to your workspace

5. Test in Slack:
   ```
   /weather San Francisco
   /help
   /status
   /echo Hello, World!
   ```

**What it demonstrates:**
- ✅ Slack signature verification with HMAC-SHA256
- ✅ Timestamp validation to prevent replay attacks
- ✅ Form-encoded payload deserialization
- ✅ Strongly-typed SlackSlashCommand model
- ✅ Slack Block Kit message formatting
- ✅ Different response types (ephemeral, in_channel)
- ✅ Extracting team and user metadata

### 2. Interactive Message Example

**File:** `interactive_message_example.dart`

Demonstrates handling Slack interactive messages with:
- Button click handling
- Menu selection handling
- Modal form submission
- Message updates in response to interactions
- Block actions processing

**Setup:**

1. Set your Slack signing secret:
   ```bash
   export SLACK_SIGNING_SECRET="your-signing-secret-here"
   ```

2. Run the example:
   ```bash
   dart run example/interactive_message_example.dart
   ```

3. Expose localhost to the internet (for local testing):
   ```bash
   ngrok http 8080
   ```

4. Configure interactivity in your Slack app:
   - Go to https://api.slack.com/apps → Your App → "Interactivity & Shortcuts"
   - Enable Interactivity
   - Set Request URL to: `https://your-ngrok-url.ngrok.io/slack/interactive`
   - Save changes

5. Send a test message with buttons using the Slack API or a slash command that posts an interactive message:
   ```json
   {
     "text": "Approval Request",
     "blocks": [
       {
         "type": "section",
         "text": {
           "type": "mrkdwn",
           "text": "Please review this request"
         }
       },
       {
         "type": "actions",
         "elements": [
           {
             "type": "button",
             "text": {"type": "plain_text", "text": "Approve"},
             "action_id": "approve_request",
             "value": "request_123",
             "style": "primary"
           },
           {
             "type": "button",
             "text": {"type": "plain_text", "text": "Reject"},
             "action_id": "reject_request",
             "value": "request_123",
             "style": "danger"
           }
         ]
       }
     ]
   }
   ```

**What it demonstrates:**
- ✅ Slack signature verification for interactive payloads
- ✅ Form-encoded payload with nested JSON deserialization
- ✅ Button click handling (approve/reject)
- ✅ Menu selection handling
- ✅ Message updates (replace_original)
- ✅ Modal form submission handling
- ✅ Different interaction types (block_actions, view_submission)

## Slack Webhook Setup Guide

### Step 1: Create a Slack App

1. Go to https://api.slack.com/apps
2. Click "Create New App"
3. Choose "From scratch"
4. Enter app name and select workspace
5. Click "Create App"

### Step 2: Get Your Signing Secret

1. In your app settings, go to "Basic Information"
2. Scroll to "App Credentials"
3. Copy the "Signing Secret"
4. Set it as an environment variable:
   ```bash
   export SLACK_SIGNING_SECRET="your-signing-secret-here"
   ```

### Step 3: Configure Slash Commands (for slash_command_example.dart)

1. In your app settings, go to "Slash Commands"
2. Click "Create New Command"
3. Fill in the details:
   - **Command:** `/weather` (or any command name)
   - **Request URL:** `https://your-server.com/slack/commands`
   - **Short Description:** "Get weather information"
   - **Usage Hint:** "[location]"
4. Click "Save"
5. Repeat for other commands (/help, /status, /echo)

### Step 4: Configure Interactivity (for interactive_message_example.dart)

1. In your app settings, go to "Interactivity & Shortcuts"
2. Toggle "Interactivity" to On
3. Set **Request URL:** `https://your-server.com/slack/interactive`
4. Click "Save Changes"

### Step 5: Install App to Workspace

1. In your app settings, go to "Install App"
2. Click "Install to Workspace"
3. Review permissions and click "Allow"

### Step 6: Test Locally with ngrok

For local development, use ngrok to expose your localhost:

```bash
# Install ngrok (if not already installed)
# https://ngrok.com/download

# Start your webhook server
dart run example/slash_command_example.dart

# In another terminal, start ngrok
ngrok http 8080

# Copy the HTTPS URL (e.g., https://abc123.ngrok.io)
# Use this URL in your Slack app configuration
```

**Important:** Always use the HTTPS URL from ngrok, not HTTP.

## Common Patterns

### Handling Slash Commands

```dart
server.registerWebhook(
  WebhookResource<SlackSlashCommand, SlackVerificationResult>(
    path: '/slack/commands',
    verifier: SlackWebhookVerifier(signingSecret: signingSecret),
    deserializer: (body) => WebhookDeserializers.form(
      body,
      SlackSlashCommand.fromForm,
    ),
    handler: (command, verification) async {
      // Process command
      return Response.ok(
        jsonEncode({
          'response_type': 'in_channel',
          'text': 'Hello from ${command.command}!',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    },
  ),
);
```

### Handling Interactive Messages

```dart
server.registerWebhook(
  WebhookResource<SlackInteractivePayload, SlackVerificationResult>(
    path: '/slack/interactive',
    verifier: SlackWebhookVerifier(signingSecret: signingSecret),
    deserializer: (body) {
      // Slack sends interactive payloads as form-encoded with 'payload' field
      final formData = Uri.splitQueryString(body);
      final payloadJson = formData['payload']!;
      return SlackInteractivePayload.fromJson(jsonDecode(payloadJson));
    },
    handler: (payload, verification) async {
      // Process interaction
      return Response.ok(
        jsonEncode({
          'replace_original': true,
          'text': 'Button clicked!',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    },
  ),
);
```

### Response Types

**Ephemeral (only visible to user):**
```dart
{
  'response_type': 'ephemeral',
  'text': 'Only you can see this message'
}
```

**In-channel (visible to everyone):**
```dart
{
  'response_type': 'in_channel',
  'text': 'Everyone in the channel can see this'
}
```

**Replace original message:**
```dart
{
  'replace_original': true,
  'text': 'Updated message content'
}
```

### Using Slack Block Kit

Slack Block Kit provides rich message formatting:

```dart
{
  'text': 'Fallback text',
  'blocks': [
    {
      'type': 'header',
      'text': {
        'type': 'plain_text',
        'text': 'Header Text',
      },
    },
    {
      'type': 'section',
      'text': {
        'type': 'mrkdwn',
        'text': '*Bold* and _italic_ text with <https://example.com|links>',
      },
    },
    {
      'type': 'actions',
      'elements': [
        {
          'type': 'button',
          'text': {'type': 'plain_text', 'text': 'Click Me'},
          'action_id': 'button_click',
          'value': 'button_value',
        },
      ],
    },
  ],
}
```

Learn more: https://api.slack.com/block-kit

## Security Considerations

### Production Deployment

When deploying to production:

1. **Always use HTTPS** - Slack requires HTTPS for webhook URLs
2. **Store secrets securely** - Use environment variables or secret managers
3. **Validate signatures** - The SlackWebhookVerifier handles this automatically
4. **Check timestamp age** - Default 5-minute window prevents replay attacks
5. **Rate limiting** - Consider implementing rate limiting for webhook endpoints
6. **Logging** - Log webhook failures for debugging (but be careful with sensitive data)

### Environment Variables

Store your Slack signing secret securely:

```bash
# Development
export SLACK_SIGNING_SECRET="your-dev-secret"

# Production (use your deployment platform's secret management)
# AWS: AWS Secrets Manager
# GCP: Secret Manager
# Azure: Key Vault
# Heroku: Config Vars
# Docker: Docker Secrets
```

### Signature Verification

The SlackWebhookVerifier automatically:
- ✅ Validates HMAC-SHA256 signatures
- ✅ Checks timestamp age (prevents replay attacks)
- ✅ Uses constant-time comparison (prevents timing attacks)
- ✅ Extracts team and request metadata

You don't need to implement signature verification yourself!

## Troubleshooting

### "Missing required Slack headers" error

**Cause:** The webhook request is missing X-Slack-Signature or X-Slack-Request-Timestamp headers.

**Solution:** 
- Verify the request is coming from Slack
- Check that your Slack app is configured correctly
- Ensure you're using the correct webhook URL

### "Request timestamp too old" error

**Cause:** The request timestamp is older than 5 minutes (replay attack prevention).

**Solution:**
- Check that your server's clock is synchronized (use NTP)
- This is normal for replayed requests - it's a security feature

### "Signature mismatch" error

**Cause:** The computed signature doesn't match the X-Slack-Signature header.

**Solution:**
- Verify you're using the correct signing secret
- Check that the signing secret matches your Slack app configuration
- Ensure the request body is not being modified before verification

### Slash command not appearing in Slack

**Cause:** The slash command hasn't been installed to your workspace.

**Solution:**
- Go to your app settings → "Install App"
- Click "Reinstall App" to update permissions
- The command should appear in Slack after reinstalling

### Interactive messages not working

**Cause:** Interactivity is not enabled or the Request URL is incorrect.

**Solution:**
- Go to "Interactivity & Shortcuts" in your app settings
- Verify "Interactivity" is toggled On
- Check that the Request URL is correct and accessible
- Ensure the URL uses HTTPS (required by Slack)

## Dependencies

All examples require:
- `dddart_webhooks_slack` - Slack webhook implementation
- `dddart_webhooks` - Base webhook framework
- `dddart_http` - HTTP server integration
- `shelf` - HTTP request/response handling

## Next Steps

- Read the [Slack API documentation](https://api.slack.com/apis)
- Explore [Slack Block Kit Builder](https://api.slack.com/block-kit/building)
- Check the [dddart_webhooks README](../../dddart_webhooks/README.md) for base webhook concepts
- See the [design document](../../../.kiro/specs/webhook-support/design.md) for architecture details

## Additional Resources

- **Slack API Docs:** https://api.slack.com/
- **Block Kit Builder:** https://api.slack.com/block-kit/building
- **Slash Commands:** https://api.slack.com/interactivity/slash-commands
- **Interactive Messages:** https://api.slack.com/interactivity/handling
- **Webhook Security:** https://api.slack.com/authentication/verifying-requests-from-slack
- **ngrok:** https://ngrok.com/
