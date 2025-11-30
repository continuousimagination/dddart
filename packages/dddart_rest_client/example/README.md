# dddart_rest_client Examples

This directory contains examples demonstrating how to use the `dddart_rest_client` package to build CLI tools and applications with automatic authentication.

## Available Examples

### 1. Basic Usage (`basic_usage.dart`)

Simple example showing the core concepts:
- Creating an auth provider
- Creating a REST client
- Making authenticated requests
- Basic error handling

**Run:** `dart run basic_usage.dart`

### 2. Complete CLI Tool (`cli_tool_example.dart`)

Full-featured CLI tool demonstrating:
- Device flow authentication
- Multiple commands (login, logout, list, create, etc.)
- Automatic token management and refresh
- Credential storage in user's home directory
- Comprehensive error handling
- User-friendly output

**Run:** `dart run cli_tool_example.dart <command>`

**Commands:**
- `login` - Login with device flow
- `logout` - Logout and clear credentials
- `list-users` - List all users
- `get-user <id>` - Get user by ID
- `create-user <name> <email>` - Create a new user
- `me` - Get current user info
- `help` - Show help message

## Quick Start - CLI Tool

### Prerequisites

You need a running dddart_rest API with authentication. You can use the self-hosted auth example:

```bash
# In another terminal, start the API server
cd packages/dddart_rest/example
dart run self_hosted_auth_example.dart
```

### Running the CLI Tool

```bash
# First time - login with device flow
dart run cli_tool_example.dart login

# You'll see:
# 🔐 Logging in...
# 
# Visit: http://localhost:8080/auth/device/verify
# Enter code: WDJB-MJHT
# 
# Waiting for authorization...

# Open the URL in your browser and enter the code
# The CLI will automatically receive tokens once you approve

# ✓ Successfully authenticated!
# You can now use other commands.

# Now you can make authenticated requests
dart run cli_tool_example.dart list-users
dart run cli_tool_example.dart me
dart run cli_tool_example.dart create-user alice alice@example.com

# Logout when done
dart run cli_tool_example.dart logout
```

## How Device Flow Works

Device flow is perfect for CLI tools because:

1. **No browser in terminal** - User authenticates in their browser
2. **Easy to type** - Short user codes like "WDJB-MJHT"
3. **Secure** - No credentials stored in terminal history
4. **User-friendly** - Clear instructions and visual feedback

**The Flow:**

```
CLI Tool                    API Server                  User's Browser
   |                            |                              |
   |-- POST /auth/device ------>|                              |
   |                            |                              |
   |<-- device_code, user_code -|                              |
   |                            |                              |
   | Display code & URL         |                              |
   |                            |                              |
   |                            |<-- Visit verification URL ---|
   |                            |                              |
   |                            |<-- Enter user code ----------|
   |                            |                              |
   |                            |-- Authenticate user -------->|
   |                            |                              |
   |-- Poll /auth/token ------->|                              |
   |                            |                              |
   |<-- authorization_pending --|                              |
   |                            |                              |
   | (wait 5 seconds)           |                              |
   |                            |                              |
   |-- Poll /auth/token ------->|                              |
   |                            |                              |
   |<-- access_token, refresh_token                            |
   |                            |                              |
   | Store credentials          |                              |
   |                            |                              |
```

## Credential Storage

Credentials are stored in `~/.user-cli/credentials.json`:

```json
{
  "access_token": "eyJhbGc...",
  "refresh_token": "def50200...",
  "expires_at": "2024-11-28T10:15:00Z"
}
```

**Security:**
- Stored in user's home directory (not in project)
- File permissions should be 0600 (user read/write only)
- Never commit credentials to version control
- Cleared on logout

## Automatic Token Refresh

The client library automatically refreshes expired tokens:

```dart
// First request - uses stored access token
await client.get('/users');

// ... 15 minutes pass, access token expires ...

// Next request - automatically refreshes token before making request
await client.get('/users');  // Seamless! No error, no manual refresh
```

**How it works:**

1. Client checks if access token is expired
2. If expired, calls `/auth/refresh` with refresh token
3. Stores new access token
4. Makes the original request with new token
5. All transparent to your code!

## Building Your Own CLI Tool

Use the `cli_tool_example.dart` as a template:

1. **Copy the example** to your project
2. **Update configuration**:
   ```dart
   const apiUrl = 'https://your-api.com';
   const clientId = 'your-cli-app-id';
   ```
3. **Add your commands**:
   ```dart
   case 'your-command':
     await cli.yourCommand();
   ```
4. **Implement command methods**:
   ```dart
   Future<void> yourCommand() async {
     final response = await client.get('/your-endpoint');
     // Handle response
   }
   ```
5. **Build executable** (optional):
   ```bash
   dart compile exe cli_tool_example.dart -o my-cli
   ```

## Error Handling

The examples demonstrate comprehensive error handling:

```dart
try {
  await authProvider.login();
} on AuthenticationException catch (e) {
  // Handle auth errors (not logged in, token expired, etc.)
  print('Authentication error: ${e.message}');
} on HttpException catch (e) {
  // Handle network errors
  print('Network error: $e');
} catch (e) {
  // Handle other errors
  print('Error: $e');
}
```

## Testing Your CLI Tool

### Manual Testing

```bash
# Test login flow
dart run cli_tool_example.dart login

# Test authenticated requests
dart run cli_tool_example.dart list-users
dart run cli_tool_example.dart me

# Test error handling (without login)
dart run cli_tool_example.dart logout
dart run cli_tool_example.dart list-users  # Should show auth error

# Test token refresh (wait 15+ minutes after login)
dart run cli_tool_example.dart list-users  # Should auto-refresh
```

### Automated Testing

Mock the auth provider for testing:

```dart
import 'package:mockito/mockito.dart';
import 'package:dddart_rest_client/dddart_rest_client.dart';

class MockAuthProvider extends Mock implements AuthProvider {}

void main() {
  test('CLI handles authentication errors', () async {
    final mockAuth = MockAuthProvider();
    when(mockAuth.getAccessToken())
        .thenThrow(AuthenticationException('Not authenticated'));
    
    final cli = YourCLI(authProvider: mockAuth);
    
    expect(
      () => cli.listUsers(),
      throwsA(isA<AuthenticationException>()),
    );
  });
}
```

## Production Considerations

When building production CLI tools:

- **Error Messages**: Provide clear, actionable error messages
- **Logging**: Add debug logging (controlled by environment variable)
- **Configuration**: Support config files for API URL, client ID
- **Updates**: Implement version checking and auto-update
- **Help**: Comprehensive help text and examples
- **Progress**: Show progress for long-running operations
- **Colors**: Use ANSI colors for better UX (with fallback)
- **Testing**: Add integration tests with mock server

## Learn More

- [dddart_rest_client Package](../README.md) - Full API documentation
- [dddart_rest Package](../../dddart_rest/README.md) - Server-side authentication
- [OAuth 2.0 Device Flow](https://oauth.net/2/device-flow/) - Specification
- [Building CLI Tools in Dart](https://dart.dev/tutorials/server/cmdline) - Official guide
