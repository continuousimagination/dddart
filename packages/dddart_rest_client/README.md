# dddart_rest_client

Client library for dddart_rest APIs with automatic authentication and token management.

## Features

- **Automatic Authentication**: HTTP client that automatically includes access tokens in requests
- **Token Management**: Automatic token refresh when expired
- **Device Flow**: Built-in support for OAuth2 device flow authentication (perfect for CLI tools)
- **Credential Storage**: Secure credential storage in user's home directory
- **Multiple Providers**: Support for both self-hosted and OAuth (Cognito) authentication
- **Zero Configuration**: Works seamlessly with dddart_rest authentication

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  dddart_rest_client: ^0.1.0
  http: ^1.2.0
  path: ^1.9.0
```

## Usage

### Self-Hosted Authentication

For APIs using dddart_rest's built-in authentication:

```dart
import 'package:dddart_rest_client/dddart_rest_client.dart';
import 'package:path/path.dart' as path;

void main() async {
  // Create auth provider
  final authProvider = DeviceFlowAuthProvider(
    authUrl: 'https://api.example.com/auth',
    clientId: 'my-cli-app',
    credentialsPath: path.join(
      Platform.environment['HOME']!,
      '.my-app',
      'credentials.json',
    ),
  );

  // Login (first time only)
  if (!await authProvider.isAuthenticated()) {
    await authProvider.login();
    // User will see:
    // Visit: https://api.example.com/auth/device/verify
    // Enter code: WDJB-MJHT
    // Waiting for authorization...
    // ✓ Successfully authenticated!
  }

  // Create REST client
  final client = RestClient(
    baseUrl: 'https://api.example.com',
    authProvider: authProvider,
  );

  // Make authenticated requests
  final response = await client.get('/users');
  print(response.body);

  // Tokens are automatically refreshed when expired
  final createResponse = await client.post(
    '/users',
    body: {'name': 'Alice', 'email': 'alice@example.com'},
  );

  // Logout when done
  await authProvider.logout();
  client.close();
}
```

### AWS Cognito Authentication

For APIs using AWS Cognito:

```dart
import 'package:dddart_rest_client/dddart_rest_client.dart';
import 'package:path/path.dart' as path;

void main() async {
  // Create Cognito auth provider
  final authProvider = CognitoAuthProvider(
    cognitoDomain: 'https://mydomain.auth.us-east-1.amazoncognito.com',
    clientId: 'your-cognito-client-id',
    credentialsPath: path.join(
      Platform.environment['HOME']!,
      '.my-app',
      'credentials.json',
    ),
  );

  // Login and make requests (same as above)
  if (!await authProvider.isAuthenticated()) {
    await authProvider.login();
  }

  final client = RestClient(
    baseUrl: 'https://api.example.com',
    authProvider: authProvider,
  );

  final response = await client.get('/users');
  print(response.body);
}
```

## API Reference

### RestClient

HTTP client with automatic authentication.

**Methods:**
- `get(path, {headers})` - GET request
- `post(path, {body, headers})` - POST request
- `put(path, {body, headers})` - PUT request
- `delete(path, {headers})` - DELETE request
- `patch(path, {body, headers})` - PATCH request
- `close()` - Close the HTTP client

### AuthProvider

Interface for authentication providers.

**Methods:**
- `getAccessToken()` - Get valid access token (refreshes if needed)
- `login()` - Initiate login flow
- `logout()` - Logout and clear credentials
- `isAuthenticated()` - Check if authenticated

### DeviceFlowAuthProvider

Auth provider for self-hosted device flow.

**Constructor:**
```dart
DeviceFlowAuthProvider({
  required String authUrl,        // e.g., 'https://api.example.com/auth'
  required String clientId,       // Your app's client ID
  required String credentialsPath, // Where to store credentials
  http.Client? httpClient,        // Optional HTTP client
})
```

### CognitoAuthProvider

Auth provider for AWS Cognito device flow.

**Constructor:**
```dart
CognitoAuthProvider({
  required String cognitoDomain,   // e.g., 'https://mydomain.auth.us-east-1.amazoncognito.com'
  required String clientId,        // Cognito app client ID
  required String credentialsPath, // Where to store credentials
  http.Client? httpClient,         // Optional HTTP client
})
```

## Device Flow

Device flow is perfect for CLI tools and applications without a browser. The flow works like this:

1. **Request Code**: App requests a device code from the server
2. **Display Code**: App displays a short user code and verification URL
3. **User Authenticates**: User visits URL in browser and enters code
4. **Poll for Tokens**: App polls server until user completes authentication
5. **Store Credentials**: App stores tokens for future use

The client library handles all of this automatically when you call `login()`.

## Credential Storage

Credentials are stored as JSON in the specified file:

```json
{
  "access_token": "eyJhbGc...",
  "refresh_token": "def50200...",
  "expires_at": "2024-11-28T10:15:00Z"
}
```

**Security Considerations:**
- Store credentials in user's home directory (not in project)
- Use appropriate file permissions (0600 on Unix)
- Never commit credentials to version control
- Clear credentials on logout

## Error Handling

The library throws `AuthenticationException` for auth-related errors:

```dart
try {
  await authProvider.login();
} on AuthenticationException catch (e) {
  print('Authentication failed: ${e.message}');
}
```

Common errors:
- `Not authenticated. Run login command.` - No valid credentials
- `Token refresh failed` - Refresh token invalid or expired
- `Authentication failed: <error>` - Device flow error
- `Authentication timed out` - User didn't complete authentication in time

## Complete CLI Tool Example

Here's a complete example of a CLI tool using device flow authentication:

```dart
import 'dart:io';
import 'package:dddart_rest_client/dddart_rest_client.dart';
import 'package:path/path.dart' as path;

void main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: my_cli <command>');
    print('Commands: login, logout, list-users, create-user');
    exit(1);
  }

  final command = args[0];
  final cli = MyCLI();

  try {
    switch (command) {
      case 'login':
        await cli.login();
      case 'logout':
        await cli.logout();
      case 'list-users':
        await cli.listUsers();
      case 'create-user':
        if (args.length < 3) {
          print('Usage: my_cli create-user <name> <email>');
          exit(1);
        }
        await cli.createUser(args[1], args[2]);
      default:
        print('Unknown command: $command');
        exit(1);
    }
  } on AuthenticationException catch (e) {
    print('Authentication error: ${e.message}');
    print('Run "my_cli login" to authenticate');
    exit(1);
  } catch (e) {
    print('Error: $e');
    exit(1);
  }
}

class MyCLI {
  late final DeviceFlowAuthProvider authProvider;
  late final RestClient client;

  MyCLI() {
    final credentialsPath = path.join(
      Platform.environment['HOME']!,
      '.my-cli',
      'credentials.json',
    );

    authProvider = DeviceFlowAuthProvider(
      authUrl: 'https://api.example.com/auth',
      clientId: 'my-cli-app',
      credentialsPath: credentialsPath,
    );

    client = RestClient(
      baseUrl: 'https://api.example.com',
      authProvider: authProvider,
    );
  }

  Future<void> login() async {
    print('Logging in...');
    await authProvider.login();
    print('✓ Successfully authenticated!');
  }

  Future<void> logout() async {
    print('Logging out...');
    await authProvider.logout();
    print('✓ Logged out');
  }

  Future<void> listUsers() async {
    print('Fetching users...');
    final response = await client.get('/users');
    
    if (response.statusCode == 200) {
      print(response.body);
    } else {
      print('Error: ${response.statusCode}');
      print(response.body);
    }
  }

  Future<void> createUser(String name, String email) async {
    print('Creating user...');
    final response = await client.post(
      '/users',
      body: {
        'name': name,
        'email': email,
      },
    );
    
    if (response.statusCode == 201) {
      print('✓ User created');
      print(response.body);
    } else {
      print('Error: ${response.statusCode}');
      print(response.body);
    }
  }
}
```

**Usage:**

```bash
# First time - login with device flow
$ my_cli login
Visit: https://api.example.com/auth/device/verify
Enter code: WDJB-MJHT

Waiting for authorization...
✓ Successfully authenticated!

# Make authenticated requests
$ my_cli list-users
Fetching users...
[{"id":"123","name":"Alice","email":"alice@example.com"}]

$ my_cli create-user Bob bob@example.com
Creating user...
✓ User created
{"id":"456","name":"Bob","email":"bob@example.com"}

# Logout when done
$ my_cli logout
Logging out...
✓ Logged out
```

## How Device Flow Works

Device flow is perfect for CLI tools and devices with limited input capabilities. Here's the flow:

1. **Request Code**: CLI requests a device code from the auth server
   ```
   POST /auth/device
   {"client_id": "my-cli-app"}
   ```

2. **Display Code**: Server returns a short user code and verification URL
   ```json
   {
     "device_code": "abc123...",
     "user_code": "WDJB-MJHT",
     "verification_uri": "https://api.example.com/auth/device/verify",
     "expires_in": 600,
     "interval": 5
   }
   ```

3. **User Authenticates**: CLI displays the code and URL. User visits URL in browser and enters code.

4. **Poll for Tokens**: CLI polls the token endpoint every 5 seconds
   ```
   POST /auth/token
   {
     "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
     "device_code": "abc123...",
     "client_id": "my-cli-app"
   }
   ```

5. **Receive Tokens**: Once user approves, server returns tokens
   ```json
   {
     "access_token": "eyJhbGc...",
     "refresh_token": "def50200...",
     "expires_in": 900,
     "token_type": "Bearer"
   }
   ```

6. **Store Credentials**: CLI stores tokens in `~/.my-cli/credentials.json`

The `DeviceFlowAuthProvider` handles all of this automatically!

## Token Refresh

The client library automatically refreshes expired access tokens:

```dart
// First request - uses stored access token
final response1 = await client.get('/users');

// ... 15 minutes pass, access token expires ...

// Next request - automatically refreshes token before making request
final response2 = await client.get('/users');  // Seamless!
```

**How it works:**

1. Client checks if access token is expired
2. If expired, calls refresh endpoint with refresh token
3. Stores new access token
4. Makes the original request with new token
5. All transparent to your code!

## Credential Storage

Credentials are stored as JSON in the specified file:

```json
{
  "access_token": "eyJhbGc...",
  "refresh_token": "def50200...",
  "expires_at": "2024-11-28T10:15:00Z"
}
```

**Best Practices:**

- Store in user's home directory: `~/.my-app/credentials.json`
- Use appropriate file permissions (0600 on Unix)
- Never commit credentials to version control
- Clear credentials on logout
- Handle missing credentials gracefully

**Example credential path setup:**

```dart
import 'dart:io';
import 'package:path/path.dart' as path;

String getCredentialsPath() {
  final home = Platform.environment['HOME'] ?? 
                Platform.environment['USERPROFILE'];
  
  if (home == null) {
    throw Exception('Cannot determine home directory');
  }
  
  final configDir = path.join(home, '.my-app');
  
  // Create directory if it doesn't exist
  Directory(configDir).createSync(recursive: true);
  
  return path.join(configDir, 'credentials.json');
}
```

## Advanced Usage

### Custom HTTP Client

Provide your own HTTP client for custom configuration:

```dart
import 'package:http/http.dart' as http;

final httpClient = http.Client();

final authProvider = DeviceFlowAuthProvider(
  authUrl: 'https://api.example.com/auth',
  clientId: 'my-cli-app',
  credentialsPath: credentialsPath,
  httpClient: httpClient,  // Custom client
);

final client = RestClient(
  baseUrl: 'https://api.example.com',
  authProvider: authProvider,
  httpClient: httpClient,  // Same client
);
```

### Check Authentication Status

Check if user is authenticated before making requests:

```dart
if (await authProvider.isAuthenticated()) {
  print('Already logged in');
} else {
  print('Please login first');
  await authProvider.login();
}
```

### Manual Token Refresh

Force a token refresh:

```dart
try {
  final token = await authProvider.getAccessToken();
  print('Current token: $token');
} on AuthenticationException catch (e) {
  print('Need to login: ${e.message}');
  await authProvider.login();
}
```

### Error Handling

Handle different authentication errors:

```dart
try {
  await authProvider.login();
} on AuthenticationException catch (e) {
  if (e.message.contains('timed out')) {
    print('Authentication timed out. Please try again.');
  } else if (e.message.contains('failed')) {
    print('Authentication failed. Check your credentials.');
  } else {
    print('Authentication error: ${e.message}');
  }
}

try {
  final response = await client.get('/users');
  // Handle response
} on AuthenticationException catch (e) {
  print('Not authenticated. Run login command.');
} on http.ClientException catch (e) {
  print('Network error: $e');
}
```

## Switching Between Auth Modes

The same `RestClient` interface works with both self-hosted and OAuth providers:

**Self-Hosted:**
```dart
final authProvider = DeviceFlowAuthProvider(
  authUrl: 'https://api.example.com/auth',
  clientId: 'my-cli-app',
  credentialsPath: credentialsPath,
);
```

**AWS Cognito:**
```dart
final authProvider = CognitoAuthProvider(
  cognitoDomain: 'https://mydomain.auth.us-east-1.amazoncognito.com',
  clientId: 'cognito-client-id',
  credentialsPath: credentialsPath,
);
```

**Usage is identical:**
```dart
final client = RestClient(
  baseUrl: 'https://api.example.com',
  authProvider: authProvider,  // Works with either provider
);

await authProvider.login();
final response = await client.get('/users');
```

## Testing

Mock the auth provider for testing:

```dart
import 'package:mockito/mockito.dart';
import 'package:dddart_rest_client/dddart_rest_client.dart';

class MockAuthProvider extends Mock implements AuthProvider {}

void main() {
  test('client includes auth token', () async {
    final mockAuth = MockAuthProvider();
    when(mockAuth.getAccessToken())
        .thenAnswer((_) async => 'test-token');
    
    final client = RestClient(
      baseUrl: 'https://api.example.com',
      authProvider: mockAuth,
    );
    
    // Test your code that uses the client
  });
}
```

## Examples

See the `example/` directory for complete examples:
- `basic_usage.dart` - Simple CLI tool with device flow
- More examples coming soon!

## License

MIT License - see LICENSE file for details.
