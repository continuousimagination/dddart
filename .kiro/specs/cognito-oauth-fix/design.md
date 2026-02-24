# Design Document: Fix AWS Cognito OAuth Support

## Overview

This design refactors the `CognitoAuthProvider` in the `dddart_rest_client` package to properly implement OAuth 2.0 Authorization Code flow with PKCE (Proof Key for Code Exchange). The current implementation has the correct flow but lacks flexibility for different platform scenarios.

The key improvement is introducing a **pluggable callback strategy pattern** that allows different platforms to handle the OAuth callback in the most appropriate way:

- **CLI/Desktop**: `LocalhostCallbackStrategy` (default) - automatic browser integration
- **Web/Cross-platform**: `ManualCallbackStrategy` - manual code entry
- **Mobile**: `CustomSchemeCallbackStrategy` (documented, not implemented) - platform-specific URL schemes

This design maintains backward compatibility with the existing `AuthProvider` interface while adding extensibility for diverse deployment scenarios.

### Design Goals

1. **Platform Flexibility**: Support CLI, web, and mobile platforms through pluggable strategies
2. **Best Default Experience**: CLI/desktop apps get automatic browser integration out of the box
3. **Framework Purity**: Keep `dddart_rest_client` platform-agnostic (no Flutter/mobile dependencies)
4. **Backward Compatibility**: Maintain the `AuthProvider` interface contract
5. **Security**: Implement PKCE correctly with proper state validation
6. **Extensibility**: Allow custom callback strategies for specialized scenarios

## Architecture

### Component Overview

```
CognitoAuthProvider (implements AuthProvider)
    ├── OAuthCallbackStrategy (interface)
    │   ├── LocalhostCallbackStrategy (default)
    │   ├── ManualCallbackStrategy
    │   └── CustomSchemeCallbackStrategy (documented only)
    ├── PKCE Generator
    ├── Token Manager
    └── Credentials Storage
```

### Key Architectural Decisions

1. **Strategy Pattern for Callbacks**: The callback mechanism is abstracted behind `OAuthCallbackStrategy`, allowing different implementations for different platforms without changing core logic.

2. **Default to Best Experience**: `LocalhostCallbackStrategy` is the default, providing automatic browser integration for the most common use case (CLI/desktop tools).

3. **No Platform-Specific Dependencies**: The framework package remains pure Dart. Mobile implementations can be provided by users using platform-specific packages.

4. **Separation of Concerns**:
   - `CognitoAuthProvider`: OAuth flow orchestration, PKCE, token management
   - `OAuthCallbackStrategy`: Platform-specific callback handling
   - `_TokenManager`: Token storage, refresh, expiration
   - `_PKCEGenerator`: PKCE code verifier and challenge generation

## Components and Interfaces

### OAuthCallbackStrategy Interface

```dart
/// Strategy for handling OAuth authorization callbacks
///
/// Different platforms require different approaches to receive the
/// authorization code from the OAuth provider:
/// - CLI/Desktop: Local HTTP server (LocalhostCallbackStrategy)
/// - Web: Manual code entry (ManualCallbackStrategy)
/// - Mobile: Custom URL schemes (CustomSchemeCallbackStrategy)
abstract class OAuthCallbackStrategy {
  /// Gets the redirect URI for this strategy
  ///
  /// This URI must match what's configured in the OAuth provider
  /// (e.g., Cognito app client settings).
  String getRedirectUri();

  /// Waits for and retrieves the authorization code
  ///
  /// This method should:
  /// 1. Display the authorization URL to the user (or open browser)
  /// 2. Wait for the OAuth callback with the authorization code
  /// 3. Extract and return the code and state parameters
  ///
  /// Parameters:
  /// - [authorizationUrl]: The complete OAuth authorization URL
  /// - [expectedState]: The state parameter sent in the request
  ///
  /// Returns a [CallbackResult] containing the authorization code and state.
  ///
  /// Throws [AuthenticationException] if:
  /// - User cancels or times out
  /// - OAuth provider returns an error
  /// - Callback handling fails
  Future<CallbackResult> waitForCallback({
    required String authorizationUrl,
    required String expectedState,
  });
}

/// Result from OAuth callback
class CallbackResult {
  CallbackResult({
    required this.code,
    required this.state,
    this.error,
    this.errorDescription,
  });

  /// Authorization code from OAuth provider
  final String code;

  /// State parameter for CSRF protection
  final String state;

  /// Error code if OAuth provider returned an error
  final String? error;

  /// Human-readable error description
  final String? errorDescription;

  /// Whether the callback indicates an error
  bool get hasError => error != null;
}
```

### LocalhostCallbackStrategy

```dart
/// Callback strategy using a temporary local HTTP server
///
/// This strategy:
/// 1. Starts a local HTTP server on localhost
/// 2. Opens the authorization URL in the system's default browser
/// 3. Waits for the OAuth callback to the local server
/// 4. Displays success/error page in the browser
/// 5. Shuts down the server
///
/// Best for: CLI applications, desktop applications
/// Requires: Ability to bind to localhost and open browser
class LocalhostCallbackStrategy implements OAuthCallbackStrategy {
  LocalhostCallbackStrategy({
    this.port = 8080,
    this.path = '/callback',
  });

  /// Port for the local HTTP server
  final int port;

  /// Path for the callback endpoint
  final String path;

  @override
  String getRedirectUri() => 'http://localhost:$port$path';

  @override
  Future<CallbackResult> waitForCallback({
    required String authorizationUrl,
    required String expectedState,
  }) async {
    // Implementation details in next section
  }
}
```

### ManualCallbackStrategy

```dart
/// Callback strategy where user manually enters the authorization code
///
/// This strategy:
/// 1. Prints the authorization URL for the user to open
/// 2. Provides instructions to copy the authorization code
/// 3. Prompts the user to paste the code or full callback URL
/// 4. Extracts the code and state from the input
///
/// Best for: Web applications, environments without browser access,
///           cross-platform scenarios
/// Requires: User interaction via stdin/stdout
class ManualCallbackStrategy implements OAuthCallbackStrategy {
  ManualCallbackStrategy({
    required this.redirectUri,
  });

  /// The redirect URI configured in the OAuth provider
  final String redirectUri;

  @override
  String getRedirectUri() => redirectUri;

  @override
  Future<CallbackResult> waitForCallback({
    required String authorizationUrl,
    required String expectedState,
  }) async {
    // Implementation details in next section
  }
}
```

### CognitoAuthProvider (Refactored)

```dart
class CognitoAuthProvider implements AuthProvider {
  CognitoAuthProvider({
    required this.cognitoDomain,
    required this.clientId,
    required this.credentialsPath,
    OAuthCallbackStrategy? callbackStrategy,
    List<String>? scopes,
    http.Client? httpClient,
  })  : callbackStrategy = callbackStrategy ?? LocalhostCallbackStrategy(),
        scopes = scopes ?? ['openid', 'email', 'profile'],
        _httpClient = httpClient ?? http.Client();

  final String cognitoDomain;
  final String clientId;
  final String credentialsPath;
  final OAuthCallbackStrategy callbackStrategy;
  final List<String> scopes;
  final http.Client _httpClient;

  @override
  Future<void> login() async {
    // 1. Generate PKCE parameters
    final codeVerifier = _generateCodeVerifier();
    final codeChallenge = _generateCodeChallenge(codeVerifier);
    final state = _generateState();

    // 2. Build authorization URL
    final authUrl = _buildAuthorizationUrl(
      codeChallenge: codeChallenge,
      state: state,
    );

    // 3. Use callback strategy to get authorization code
    final result = await callbackStrategy.waitForCallback(
      authorizationUrl: authUrl,
      expectedState: state,
    );

    // 4. Validate result
    if (result.hasError) {
      throw AuthenticationException(
        'OAuth error: ${result.error} - ${result.errorDescription}',
      );
    }

    if (result.state != state) {
      throw AuthenticationException(
        'State mismatch - possible CSRF attack',
      );
    }

    // 5. Exchange code for tokens
    final tokens = await _exchangeCodeForTokens(
      result.code,
      codeVerifier,
    );

    // 6. Save credentials
    await _saveCredentials(tokens);
  }

  // Other methods remain similar...
}
```

## Data Models

### Internal Token Models

```dart
/// Tokens received from Cognito
class _CognitoTokens {
  _CognitoTokens({
    required this.accessToken,
    required this.idToken,
    required this.refreshToken,
    required this.expiresIn,
  });

  factory _CognitoTokens.fromJson(Map<String, dynamic> json) {
    return _CognitoTokens(
      accessToken: json['access_token'] as String,
      idToken: json['id_token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiresIn: json['expires_in'] as int,
    );
  }

  final String accessToken;
  final String idToken;
  final String refreshToken;
  final int expiresIn;
}

/// Credentials stored on disk
class _StoredCredentials {
  _StoredCredentials({
    required this.accessToken,
    required this.idToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  factory _StoredCredentials.fromJson(Map<String, dynamic> json) {
    return _StoredCredentials(
      accessToken: json['access_token'] as String,
      idToken: json['id_token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }

  final String accessToken;
  final String idToken;
  final String refreshToken;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'id_token': idToken,
        'refresh_token': refreshToken,
        'expires_at': expiresAt.toIso8601String(),
      };
}
```

### PKCE Implementation

```dart
/// Generates PKCE code verifier and challenge
class _PKCEGenerator {
  /// Generates a cryptographically random code verifier
  ///
  /// Per RFC 7636, the code verifier is a random string of 43-128
  /// characters from the unreserved character set [A-Z, a-z, 0-9, -, ., _, ~]
  static String generateCodeVerifier() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// Generates code challenge from verifier
  ///
  /// Per RFC 7636, the code challenge is:
  /// BASE64URL(SHA256(ASCII(code_verifier)))
  static String generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  /// Generates random state parameter for CSRF protection
  static String generateState() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}
```

## Implementation Details

### LocalhostCallbackStrategy Implementation

The localhost strategy provides the best user experience for CLI and desktop applications:

1. **Start HTTP Server**: Bind to `127.0.0.1` (localhost only) on the configured port
2. **Open Browser**: Use platform-specific commands to open the authorization URL
3. **Wait for Callback**: Listen for HTTP requests to the callback path
4. **Extract Parameters**: Parse `code`, `state`, `error`, and `error_description` from query parameters
5. **Send Response**: Display success or error HTML page in the browser
6. **Shutdown Server**: Close the HTTP server after receiving the callback

```dart
Future<CallbackResult> waitForCallback({
  required String authorizationUrl,
  required String expectedState,
}) async {
  HttpServer? server;
  try {
    // Start server on localhost only
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);

    // Open browser
    print('\n🔐 Opening browser for authentication...');
    print('If browser does not open, visit: $authorizationUrl\n');
    
    try {
      await _openBrowser(authorizationUrl);
    } catch (e) {
      // Browser opening failed, user will use printed URL
    }

    print('Waiting for authentication...');

    // Wait for callback
    await for (final request in server) {
      if (request.uri.path == path) {
        final code = request.uri.queryParameters['code'];
        final state = request.uri.queryParameters['state'];
        final error = request.uri.queryParameters['error'];
        final errorDesc = request.uri.queryParameters['error_description'];

        // Send HTML response
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.html
          ..write(_getCallbackHtml(error == null));
        await request.response.close();

        return CallbackResult(
          code: code ?? '',
          state: state ?? '',
          error: error,
          errorDescription: errorDesc,
        );
      } else {
        // 404 for non-callback paths
        request.response
          ..statusCode = 404
          ..write('Not found');
        await request.response.close();
      }
    }

    throw AuthenticationException('Server closed without receiving callback');
  } finally {
    await server?.close();
  }
}
```

### ManualCallbackStrategy Implementation

The manual strategy works on any platform with stdin/stdout:

1. **Print URL**: Display the authorization URL for the user to open manually
2. **Print Instructions**: Explain how to copy the authorization code or full callback URL
3. **Prompt User**: Read input from stdin
4. **Parse Input**: Handle both full callback URLs and just the code parameter
5. **Extract Parameters**: Parse `code` and `state` from the input

```dart
Future<CallbackResult> waitForCallback({
  required String authorizationUrl,
  required String expectedState,
}) async {
  print('\n🔐 Manual Authentication Required');
  print('=' * 60);
  print('\n1. Open this URL in your browser:');
  print('   $authorizationUrl\n');
  print('2. After authenticating, you will be redirected to:');
  print('   $redirectUri?code=...\n');
  print('3. Copy the ENTIRE URL from your browser address bar');
  print('   OR just the authorization code\n');
  print('=' * 60);
  print('\nPaste here and press Enter:');

  final input = stdin.readLineSync()?.trim() ?? '';

  if (input.isEmpty) {
    throw AuthenticationException('No input provided');
  }

  // Try to parse as full URL first
  try {
    final uri = Uri.parse(input);
    final code = uri.queryParameters['code'];
    final state = uri.queryParameters['state'];
    final error = uri.queryParameters['error'];
    final errorDesc = uri.queryParameters['error_description'];

    if (code != null || error != null) {
      return CallbackResult(
        code: code ?? '',
        state: state ?? expectedState,
        error: error,
        errorDescription: errorDesc,
      );
    }
  } catch (e) {
    // Not a valid URL, treat as just the code
  }

  // Treat input as just the authorization code
  return CallbackResult(
    code: input,
    state: expectedState,
  );
}
```

### Token Refresh Logic

Token refresh must handle the case where Cognito may or may not return a new ID token:

```dart
Future<_CognitoTokens> _refresh(String refreshToken) async {
  final response = await _httpClient.post(
    Uri.parse('$cognitoDomain/oauth2/token'),
    headers: {'Content-Type': 'application/x-www-form-urlencoded'},
    body: {
      'grant_type': 'refresh_token',
      'client_id': clientId,
      'refresh_token': refreshToken,
    },
  );

  if (response.statusCode != 200) {
    throw AuthenticationException(
      'Token refresh failed: ${response.body}',
    );
  }

  final json = jsonDecode(response.body) as Map<String, dynamic>;

  // Cognito may not return a new ID token on refresh
  // If not present, preserve the existing one
  final existingCreds = await _loadCredentials();
  final newIdToken = json['id_token'] as String?;

  return _CognitoTokens(
    accessToken: json['access_token'] as String,
    idToken: newIdToken ?? existingCreds!.idToken,
    refreshToken: json['refresh_token'] as String? ?? refreshToken,
    expiresIn: json['expires_in'] as int,
  );
}
```

### ID Token Decoding

ID tokens are JWTs with three base64-encoded parts separated by dots:

```dart
Future<Map<String, dynamic>> getIdTokenClaims() async {
  final idToken = await getIdToken();

  // JWT format: header.payload.signature
  final parts = idToken.split('.');
  if (parts.length != 3) {
    throw AuthenticationException('Invalid ID token format');
  }

  // Decode the payload (middle part)
  final payload = utf8.decode(
    base64Url.decode(base64Url.normalize(parts[1])),
  );

  return jsonDecode(payload) as Map<String, dynamic>;
}

Future<String> getCognitoSub() async {
  final claims = await getIdTokenClaims();
  final sub = claims['sub'] as String?;

  if (sub == null) {
    throw AuthenticationException('ID token missing sub claim');
  }

  return sub;
}
```


## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property Reflection

After analyzing all acceptance criteria, I identified several areas of redundancy:

1. **State mismatch error handling** (3.7, 4.5, 9.2): These all test the same behavior - that state mismatches throw the correct exception. Combined into Property 5.
2. **PKCE generation properties** (1.1, 1.2, 1.3): These are related but test different aspects. 1.1 is subsumed by 1.2 (format validation), so 1.1 is redundant. Properties 1 and 2 remain.
3. **Token storage** (5.5, 6.1): Both test that tokens are stored correctly. Combined into Property 8.
4. **Default behavior** (2.2, 12.1, 12.5): These test default values. Kept as examples rather than properties.
5. **Error message properties** (9.2, 9.3, 9.4, 9.5): These all test error message content. Combined into Property 11 for consistency.
6. **Callback strategy contract** (2.4, 2.5): These test the strategy interface contract. Combined into Property 3.

### Properties

Property 1: PKCE Code Verifier Format
*For any* generated code verifier, the verifier must be a base64url-encoded string of 43-128 characters containing only unreserved characters [A-Z, a-z, 0-9, -, ., _, ~]
**Validates: Requirements 1.2**

Property 2: PKCE Code Challenge Computation
*For any* code verifier, the code challenge must equal Base64URL(SHA256(code_verifier)) with padding removed
**Validates: Requirements 1.3**

Property 3: Callback Strategy Contract
*For any* callback strategy that completes successfully, the result must contain a non-empty authorization code and state parameter; for any callback strategy that fails, an AuthenticationException must be thrown
**Validates: Requirements 2.4, 2.5**

Property 4: Authorization URL Construction
*For any* set of OAuth parameters (client_id, redirect_uri, scope, state, code_challenge), the authorization URL must include all parameters with correct values and use the /oauth2/authorize endpoint
**Validates: Requirements 1.4, 1.5**

Property 5: State Parameter Validation
*For any* OAuth callback where the received state does not match the expected state, an AuthenticationException with message "State mismatch - possible CSRF attack" must be thrown
**Validates: Requirements 3.7, 4.5, 9.2**

Property 6: HTTP Query Parameter Extraction
*For any* HTTP request with query parameters, the system must correctly extract code, state, error, and error_description parameters
**Validates: Requirements 3.4**

Property 7: Manual Input Parsing
*For any* user input that is either a full callback URL or just an authorization code, the system must correctly extract the code and state parameters
**Validates: Requirements 4.4**

Property 8: Token Storage Round Trip
*For any* set of tokens (access, ID, refresh) received from Cognito, storing then loading the credentials must produce equivalent token values
**Validates: Requirements 5.5, 6.1**

Property 9: Token Exchange Request Format
*For any* authorization code exchange, the request must include grant_type=authorization_code, client_id, code, redirect_uri, and code_verifier parameters
**Validates: Requirements 5.2**

Property 10: Token Refresh Request Format
*For any* token refresh operation, the request must include grant_type=refresh_token, client_id, and refresh_token parameters
**Validates: Requirements 7.2**

Property 11: Error Message Consistency
*For any* authentication error (state mismatch, missing code, token exchange failure, invalid ID token), the thrown AuthenticationException must contain a descriptive message indicating the specific error condition
**Validates: Requirements 9.2, 9.3, 9.4, 9.5**

Property 12: ID Token Preservation on Refresh
*For any* token refresh response that does not include a new id_token, the existing ID token must be preserved; for any refresh response that includes a new id_token, the new token must replace the old one
**Validates: Requirements 7.4, 7.5**

Property 13: JWT Structure Validation
*For any* ID token, decoding must verify the token has exactly three parts (header, payload, signature) separated by dots
**Validates: Requirements 6.3**

Property 14: JWT Claims Extraction
*For any* valid ID token, decoding the payload must return all claims as a map; extracting the sub claim must return the user ID
**Validates: Requirements 6.2, 6.5**

Property 15: Missing Sub Claim Error
*For any* ID token missing the sub claim, calling getCognitoSub() must throw an AuthenticationException
**Validates: Requirements 6.4**

Property 16: Redirect URI Construction
*For any* LocalhostCallbackStrategy with port P and path T, the redirect URI must equal 'http://localhost:P/T'
**Validates: Requirements 8.3**

Property 17: Custom Scope Usage
*For any* list of custom scopes provided to CognitoAuthProvider, the authorization URL must include those scopes joined with spaces instead of the default scopes
**Validates: Requirements 12.3, 12.4**

Property 18: HTTP 404 for Non-Callback Paths
*For any* HTTP request to the localhost callback server with a path that is not the configured callback path, the server must return HTTP 404
**Validates: Requirements 10.5**

Property 19: Automatic Token Refresh
*For any* expired access token with a valid refresh token, calling getAccessToken() must automatically refresh the token and return a new valid access token
**Validates: Requirements 11.2**

Property 20: Logout Cleanup
*For any* authenticated session, calling logout() must delete the stored credentials file
**Validates: Requirements 11.4**

Property 21: Authentication State Check
*For any* credential state (valid, expired, missing), isAuthenticated() must return true if and only if valid credentials exist and can be used to obtain an access token
**Validates: Requirements 11.5**

Property 22: OAuth Error Propagation
*For any* OAuth callback containing an error parameter, the system must throw an AuthenticationException containing both the error code and error_description
**Validates: Requirements 9.1**

Property 23: Token Exchange Error Handling
*For any* failed token exchange (non-200 response), the system must throw an AuthenticationException including the response body from Cognito
**Validates: Requirements 5.4**

Property 24: Token Refresh Error Handling
*For any* failed token refresh (non-200 response), the system must throw an AuthenticationException indicating the user needs to login again
**Validates: Requirements 7.6**

Property 25: HTML Response Generation
*For any* callback result (success or error), the localhost strategy must send an HTML response containing appropriate status indicators and user instructions
**Validates: Requirements 3.5**

## Error Handling

### Error Categories

1. **Configuration Errors**
   - Invalid Cognito domain format
   - Invalid client ID
   - Invalid redirect URI format
   - Handled by: Constructor validation

2. **Network Errors**
   - Cannot bind to localhost port (already in use)
   - Cannot connect to Cognito endpoints
   - HTTP request failures
   - Handled by: Try-catch with AuthenticationException wrapping

3. **OAuth Protocol Errors**
   - State mismatch (CSRF attack)
   - Missing authorization code
   - OAuth error responses from Cognito
   - Handled by: Validation checks with specific error messages

4. **Token Errors**
   - Invalid ID token format
   - Missing required claims
   - Token refresh failure
   - Handled by: JWT validation with AuthenticationException

5. **User Interaction Errors**
   - Browser cannot be opened
   - User cancels authentication
   - Invalid manual input
   - Handled by: Graceful fallbacks and clear error messages

### Error Handling Strategy

All errors are surfaced as `AuthenticationException` with descriptive messages. The exception includes:
- What went wrong
- Why it matters
- What the user should do next (when applicable)

Example error messages:
- "State mismatch - possible CSRF attack" (security issue)
- "Token refresh failed: <details>" (need to re-authenticate)
- "Invalid ID token format" (data corruption or tampering)
- "No authorization code received" (user cancelled or timeout)

### Resource Cleanup

All resources are properly cleaned up in finally blocks:
- HTTP servers are closed after callback
- HTTP clients can be provided externally for lifecycle management
- File handles are closed after reading/writing credentials

## Testing Strategy

### Dual Testing Approach

This implementation requires both unit tests and property-based tests:

**Unit Tests** focus on:
- Specific examples of OAuth flows
- Edge cases (empty tokens, malformed JWTs)
- Error conditions (network failures, invalid responses)
- Integration between components
- Platform-specific behavior (browser opening, server binding)

**Property-Based Tests** focus on:
- Universal properties across all inputs (PKCE generation, URL construction)
- Round-trip properties (token storage/loading, JWT encoding/decoding)
- Invariants (state validation, error handling consistency)
- Input validation (parsing various URL formats, handling all error types)

### Property-Based Testing Configuration

**Library**: Use `package:test` with custom property test helpers or `package:test_api` for parameterized tests

**Configuration**:
- Minimum 100 iterations per property test
- Each test tagged with: `Feature: cognito-oauth-fix, Property N: <property text>`
- Use random generators for: code verifiers, states, tokens, URLs, ports

**Example Property Test Structure**:
```dart
test('Property 1: PKCE Code Verifier Format', () {
  // Feature: cognito-oauth-fix, Property 1: PKCE Code Verifier Format
  for (var i = 0; i < 100; i++) {
    final verifier = _PKCEGenerator.generateCodeVerifier();
    
    // Must be 43-128 characters
    expect(verifier.length, greaterThanOrEqualTo(43));
    expect(verifier.length, lessThanOrEqualTo(128));
    
    // Must contain only unreserved characters
    expect(verifier, matches(RegExp(r'^[A-Za-z0-9\-._~]+$')));
  }
});
```

### Test Coverage Requirements

1. **OAuthCallbackStrategy Interface**
   - Test each strategy implementation independently
   - Mock HTTP requests/responses for localhost strategy
   - Mock stdin/stdout for manual strategy
   - Verify strategy contract is honored

2. **PKCE Generation**
   - Property tests for verifier format
   - Property tests for challenge computation
   - Verify randomness (no duplicates in large sample)

3. **Token Management**
   - Round-trip tests for storage/loading
   - Refresh logic with and without new ID token
   - Expiration checking
   - Error handling for missing/corrupt files

4. **JWT Decoding**
   - Valid tokens with various claims
   - Invalid formats (wrong number of parts)
   - Missing required claims
   - Malformed base64

5. **OAuth Flow Integration**
   - End-to-end flow with mock HTTP server
   - State validation
   - Error responses from Cognito
   - Token exchange and refresh

6. **Error Handling**
   - All error categories covered
   - Error messages verified
   - Resource cleanup verified

### Test Organization

```
test/
├── cognito_auth_provider_test.dart          # Main provider tests
├── oauth_callback_strategy_test.dart        # Strategy interface tests
├── localhost_callback_strategy_test.dart    # Localhost strategy tests
├── manual_callback_strategy_test.dart       # Manual strategy tests
├── pkce_generator_test.dart                 # PKCE property tests
└── token_manager_test.dart                  # Token storage/refresh tests
```

### Mocking Strategy

- Use `package:http` mock client for HTTP requests
- Use in-memory file system or temp directories for credentials storage
- Mock stdin/stdout for manual callback strategy
- Use test HTTP server for localhost callback strategy integration tests

## Migration Guide

### For Existing Users

The current `CognitoAuthProvider` already implements Authorization Code flow with PKCE, so existing code will continue to work. However, users can now customize the callback strategy:

**Before (still works)**:
```dart
final provider = CognitoAuthProvider(
  cognitoDomain: 'https://mydomain.auth.us-east-1.amazoncognito.com',
  clientId: 'my-client-id',
  credentialsPath: '.credentials.json',
);
```

**After (with custom strategy)**:
```dart
// For web apps or environments without browser access
final provider = CognitoAuthProvider(
  cognitoDomain: 'https://mydomain.auth.us-east-1.amazoncognito.com',
  clientId: 'my-client-id',
  credentialsPath: '.credentials.json',
  callbackStrategy: ManualCallbackStrategy(
    redirectUri: 'https://myapp.com/callback',
  ),
);

// For custom port/path
final provider = CognitoAuthProvider(
  cognitoDomain: 'https://mydomain.auth.us-east-1.amazoncognito.com',
  clientId: 'my-client-id',
  credentialsPath: '.credentials.json',
  callbackStrategy: LocalhostCallbackStrategy(
    port: 3000,
    path: '/auth/callback',
  ),
);
```

### Breaking Changes

None. The refactoring maintains backward compatibility:
- Default behavior unchanged (localhost callback on port 8080)
- All existing methods remain with same signatures
- Credentials file format unchanged

### New Features

1. **Pluggable callback strategies** - customize how authorization codes are received
2. **Better error messages** - more descriptive errors with actionable guidance
3. **Configurable scopes** - request custom OAuth scopes
4. **Improved documentation** - clear examples for different platforms

## Implementation Notes

### Platform Considerations

1. **Browser Opening**: The localhost strategy attempts to open the browser using platform-specific commands. If this fails, the URL is printed for manual opening.

2. **Port Binding**: The localhost strategy binds to `127.0.0.1` (IPv4 localhost) only, not `0.0.0.0` (all interfaces), for security.

3. **Stdin/Stdout**: The manual strategy uses `stdin.readLineSync()` which requires a terminal. This won't work in environments without stdin (e.g., some CI systems).

4. **Mobile Support**: Mobile apps should implement `CustomSchemeCallbackStrategy` using platform-specific packages like `uni_links` (Flutter) or `url_launcher` with custom schemes.

### Security Considerations

1. **PKCE**: Provides security for public clients without client secrets
2. **State Parameter**: Prevents CSRF attacks by validating the callback matches the request
3. **Localhost Only**: Callback server binds to localhost only, not accessible from network
4. **HTTPS**: Cognito domain must use HTTPS (enforced by Cognito)
5. **Token Storage**: Credentials stored in local file with appropriate permissions

### Performance Considerations

1. **HTTP Server Lifecycle**: Server is started only during login and shut down immediately after callback
2. **Token Caching**: Access tokens are cached and only refreshed when expired
3. **Minimal Dependencies**: Uses only standard Dart libraries plus `http` and `crypto`

### Dependencies

Required packages:
- `http`: ^1.0.0 - HTTP client for OAuth requests
- `crypto`: ^3.0.0 - SHA-256 for PKCE challenge generation

Both are standard, well-maintained packages with minimal transitive dependencies.

## Documentation Requirements

### API Documentation

All public classes and methods must have comprehensive dartdoc comments:
- Purpose and behavior
- Parameters and return values
- Exceptions that may be thrown
- Usage examples
- Platform-specific considerations

### README Updates

The `dddart_rest_client` README must be updated to:
- Explain the callback strategy pattern
- Provide examples for each strategy
- Document platform-specific considerations
- Include migration guide for existing users

### Example Code

The `example/` directory must include:
- CLI tool example using LocalhostCallbackStrategy (default)
- Web app example using ManualCallbackStrategy
- Documentation for mobile apps (CustomSchemeCallbackStrategy)

## Future Enhancements

These are explicitly out of scope for this spec but noted for future consideration:

1. **Token Revocation**: Call Cognito's revoke endpoint on logout
2. **Token Introspection**: Validate tokens with Cognito's introspection endpoint
3. **OIDC Discovery**: Auto-configure endpoints from .well-known/openid-configuration
4. **Multiple Concurrent Logins**: Support multiple login flows simultaneously
5. **Custom Browser Selection**: Allow specifying which browser to open
6. **Mobile Strategy Implementation**: Provide Flutter-specific callback strategy
7. **Token Encryption**: Encrypt tokens at rest in credentials file
8. **Automatic Token Rotation**: Proactively refresh tokens before expiration
