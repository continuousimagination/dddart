# Design Document

## Overview

This design implements authentication and authorization for dddart_rest REST APIs, supporting both self-hosted authentication (where the application manages credentials and tokens) and delegated authentication (where external OAuth2/OIDC providers handle authentication). The system provides JWT-based access tokens for API requests, refresh tokens for long-lived sessions, and device flow for CLI tool authentication.

The architecture follows dddart's patterns: aggregate roots for domain entities (RefreshToken), repository pattern for persistence, and code generation for database implementations. Authentication is configured per-resource, allowing mixed public and protected endpoints. A companion client library (dddart_rest_client) provides automatic token management for CLI tools and applications.

## Architecture

### Package Structure

```
dddart_rest/
  - Auth handlers (JwtAuthHandler, OAuthJwtAuthHandler)
  - Auth endpoints (/auth/login, /auth/refresh, /auth/device, etc.)
  - RefreshToken aggregate root
  - AuthResult, Tokens value objects
  - Integration with CrudResource

dddart_rest_client/
  - RestClient (HTTP client with auto-auth)
  - AuthProvider interface
  - DeviceFlowAuthProvider (self-hosted)
  - CognitoAuthProvider (AWS Cognito)
  - Credential storage

dddart_repository_mongodb/
  - RefreshTokenMongoRepository (pre-generated)
  
dddart/ (existing)
  - InMemoryRepository<RefreshToken> (no generation needed)
```

### Authentication Flow Modes

**Mode 1: Self-Hosted Authentication**
```
┌─────────┐                    ┌──────────────┐                    ┌────────────┐
│  Client │                    │  dddart_rest │                    │  Database  │
└─────────┘                    └──────────────┘                    └────────────┘
     │                                │                                   │
     │ 1. POST /auth/device           │                                   │
     ├───────────────────────────────>│                                   │
     │                                │                                   │
     │ 2. Device code + user code     │                                   │
     │<───────────────────────────────┤                                   │
     │                                │                                   │
     │ (User visits verification URI, enters code, authenticates)         │
     │                                │                                   │
     │ 3. Poll /auth/token            │                                   │
     ├───────────────────────────────>│                                   │
     │                                │ 4. Store refresh token            │
     │                                ├──────────────────────────────────>│
     │                                │                                   │
     │ 5. Access + refresh tokens     │                                   │
     │<───────────────────────────────┤                                   │
     │                                │                                   │
     │ 6. GET /users (with access token)                                  │
     ├───────────────────────────────>│                                   │
     │                                │ 7. Validate JWT (no DB lookup)    │
     │                                │                                   │
     │ 8. Response                    │                                   │
     │<───────────────────────────────┤                                   │
     │                                │                                   │
     │ (Access token expires)         │                                   │
     │                                │                                   │
     │ 9. POST /auth/refresh          │                                   │
     ├───────────────────────────────>│                                   │
     │                                │ 10. Validate refresh token        │
     │                                ├──────────────────────────────────>│
     │                                │                                   │
     │ 11. New access token           │                                   │
     │<───────────────────────────────┤                                   │
```

**Mode 2: OAuth/OIDC (Cognito)**
```
┌─────────┐          ┌─────────┐          ┌──────────────┐
│  Client │          │ Cognito │          │  dddart_rest │
└─────────┘          └─────────┘          └──────────────┘
     │                    │                       │
     │ 1. Device flow     │                       │
     ├───────────────────>│                       │
     │                    │                       │
     │ 2. Tokens          │                       │
     │<───────────────────┤                       │
     │                    │                       │
     │ 3. GET /users (with Cognito JWT)           │
     ├───────────────────────────────────────────>│
     │                    │                       │
     │                    │ 4. Fetch JWKS         │
     │                    │<──────────────────────┤
     │                    │                       │
     │                    │ 5. Validate signature │
     │                    │                       │
     │ 6. Response        │                       │
     │<───────────────────────────────────────────┤
     │                    │                       │
     │ (Access token expires)                     │
     │                    │                       │
     │ 7. Refresh         │                       │
     ├───────────────────>│                       │
     │                    │                       │
     │ 8. New tokens      │                       │
     │<───────────────────┤                       │
```

## Components and Interfaces

### Core Authentication Components

#### AuthHandler (Abstract Base)

```dart
/// Base class for authentication handlers
abstract class AuthHandler<TClaims> {
  /// Authenticates a request and returns authentication result
  /// 
  /// Extracts credentials from the request (typically Authorization header),
  /// validates them, and returns user identity and claims.
  Future<AuthResult<TClaims>> authenticate(Request request);
}
```

#### AuthResult

```dart
/// Result of authentication attempt
class AuthResult<TClaims> {
  const AuthResult({
    required this.isAuthenticated,
    this.userId,
    this.claims,
    this.errorMessage,
  });
  
  /// Whether authentication succeeded
  final bool isAuthenticated;
  
  /// User ID if authenticated
  final String? userId;
  
  /// Strongly-typed custom claims from JWT or OAuth token
  final TClaims? claims;
  
  /// Error message if authentication failed
  final String? errorMessage;
}
```

#### JwtAuthHandler (Self-Hosted)

```dart
/// Handles JWT authentication for self-hosted mode
/// 
/// Generic over TClaims (claims type) and TRefreshToken (refresh token type).
/// TRefreshToken must extend RefreshToken to ensure compatibility.
/// 
/// Uses generated extension methods (parseClaimsFromJson, claimsToJson) 
/// to serialize/deserialize claims. Extension methods are generated by
/// annotating claims classes with @JwtSerializable().
class JwtAuthHandler<TClaims, TRefreshToken extends RefreshToken> 
    extends AuthHandler<TClaims> {
  JwtAuthHandler({
    required this.secret,
    required this.refreshTokenRepository,
    this.issuer,
    this.audience,
    this.accessTokenDuration = const Duration(minutes: 15),
    this.refreshTokenDuration = const Duration(days: 7),
  });
  
  /// Secret key for signing JWTs
  final String secret;
  
  /// Repository for storing refresh tokens
  /// Accepts Repository<TRefreshToken> where TRefreshToken extends RefreshToken
  final Repository<TRefreshToken> refreshTokenRepository;
  
  /// Optional issuer claim for JWTs
  final String? issuer;
  
  /// Optional audience claim for JWTs
  final String? audience;
  
  /// How long access tokens are valid
  final Duration accessTokenDuration;
  
  /// How long refresh tokens are valid
  final Duration refreshTokenDuration;
  
  @override
  Future<AuthResult<TClaims>> authenticate(Request request) async {
    // Extract Bearer token from Authorization header
    // Decode JWT
    // Verify signature using secret
    // Check expiration
    // Parse claims using parseClaimsFromJson() extension method
    // Return AuthResult with typed claims
  }
  
  /// Issues new access and refresh tokens for a user
  Future<Tokens> issueTokens(
    String userId,
    TClaims claims, {
    String? deviceInfo,
  }) async {
    // Serialize claims using claimsToJson() extension method
    // Create JWT with claims
    // Generate random refresh token
    // Store refresh token in repository
    // Return both tokens
  }
  
  /// Refreshes access token using refresh token
  Future<Tokens> refresh(String refreshToken) async {
    // Look up refresh token in repository
    // Validate not expired or revoked
    // Issue new access token
    // Return new tokens
  }
  
  /// Revokes a refresh token (logout)
  Future<void> revoke(String refreshToken) async {
    // Mark refresh token as revoked in repository
  }
}
```

#### OAuthJwtAuthHandler (Delegated)

```dart
/// Handles JWT validation for OAuth2/OIDC providers
/// 
/// Uses generated extension method (parseClaimsFromJson) to deserialize claims.
/// Extension method is generated by annotating claims class with @JwtSerializable().
class OAuthJwtAuthHandler<TClaims> extends AuthHandler<TClaims> {
  OAuthJwtAuthHandler({
    required this.jwksUri,
    this.issuer,
    this.audience,
    this.cacheDuration = const Duration(hours: 1),
  });
  
  /// URI to fetch JSON Web Key Set (public keys)
  final String jwksUri;
  
  /// Expected issuer claim
  final String? issuer;
  
  /// Expected audience claim
  final String? audience;
  
  /// How long to cache JWKS before refetching
  final Duration cacheDuration;
  
  /// Cached JWKS
  Map<String, dynamic>? _cachedJwks;
  DateTime? _jwksCachedAt;
  
  @override
  Future<AuthResult<TClaims>> authenticate(Request request) async {
    // Extract Bearer token from Authorization header
    // Decode JWT
    // Fetch JWKS if not cached or expired
    // Find matching key by kid (key ID)
    // Verify signature using public key
    // Verify issuer if configured
    // Verify audience if configured
    // Check expiration
    // Parse claims using parseClaimsFromJson() extension method
    // Return AuthResult with typed claims
  }
  
  /// Fetches JWKS from provider
  Future<Map<String, dynamic>> _fetchJwks() async {
    // HTTP GET to jwksUri
    // Parse JSON
    // Cache result
  }
}
```

### Authentication Endpoints

#### AuthEndpoints

```dart
/// Provides authentication endpoints for self-hosted mode
class AuthEndpoints {
  AuthEndpoints({
    required this.authHandler,
    required this.userValidator,
  });
  
  /// JWT auth handler for issuing/validating tokens
  final JwtAuthHandler authHandler;
  
  /// Callback to validate username/password
  final Future<String?> Function(String username, String password) userValidator;
  
  /// POST /auth/login - Username/password login
  Future<Response> handleLogin(Request request) async {
    // Parse username/password from body
    // Validate credentials using userValidator
    // Issue tokens using authHandler.issueTokens()
    // Return tokens as JSON
  }
  
  /// POST /auth/refresh - Refresh access token
  Future<Response> handleRefresh(Request request) async {
    // Parse refresh_token from body
    // Call authHandler.refresh()
    // Return new access token
  }
  
  /// POST /auth/logout - Revoke refresh token
  Future<Response> handleLogout(Request request) async {
    // Parse refresh_token from body
    // Call authHandler.revoke()
    // Return 204 No Content
  }
  
  /// POST /auth/device - Initiate device flow
  Future<Response> handleDeviceCode(Request request) async {
    // Parse client_id from body
    // Generate device code (random UUID)
    // Generate user code (short, human-readable)
    // Store device code with pending status
    // Return device_code, user_code, verification_uri, expires_in, interval
  }
  
  /// GET /auth/device/verify - Verification page for user
  Future<Response> handleDeviceVerify(Request request) async {
    // Show HTML form to enter user code
    // On submit, authenticate user and approve device code
  }
  
  /// POST /auth/token - Poll for device flow tokens
  Future<Response> handleToken(Request request) async {
    // Parse grant_type and device_code from body
    // If grant_type is device_code:
    //   - Look up device code
    //   - If pending: return authorization_pending
    //   - If approved: issue tokens and return
    //   - If expired: return error
    // If grant_type is refresh_token:
    //   - Delegate to handleRefresh()
  }
}
```

### Custom Claims

Developers define their own claims classes using code generation with the `@JwtSerializable()` annotation:

```dart
import 'package:dddart_rest/dddart_rest.dart';

part 'user_claims.g.dart';

@JwtSerializable()
class UserClaims {
  const UserClaims({
    required this.userId,
    required this.email,
    this.roles = const [],
    this.isAdmin = false,
  });
  
  final String userId;
  final String email;
  final List<String> roles;
  final bool isAdmin;
}

// Run: dart run build_runner build
// Generates: user_claims.g.dart with extension methods on JwtAuthHandler
```

**Generated Code:**

The code generator creates extension methods on `JwtAuthHandler<UserClaims>` that know how to serialize and deserialize the claims:

```dart
// Generated in user_claims.g.dart
extension JwtAuthHandlerUserClaimsExtension on JwtAuthHandler<UserClaims> {
  UserClaims parseClaimsFromJson(Map<String, dynamic> json) {
    return UserClaims(
      userId: json['userId'] as String,
      email: json['email'] as String,
      roles: (json['roles'] as List?)?.cast<String>() ?? const [],
      isAdmin: json['isAdmin'] as bool? ?? false,
    );
  }
  
  Map<String, dynamic> claimsToJson(UserClaims claims) {
    return {
      'userId': claims.userId,
      'email': claims.email,
      'roles': claims.roles,
      'isAdmin': claims.isAdmin,
    };
  }
}
```

**Usage with auth handlers - Zero Boilerplate:**

```dart
import 'user_claims.dart';  // Brings extension into scope automatically

// Self-hosted - no serialization functions needed!
final authHandler = JwtAuthHandler<UserClaims>(
  secret: 'your-secret',
  refreshTokenRepository: repo,
);

// OAuth - no serialization functions needed!
final oauthHandler = OAuthJwtAuthHandler<UserClaims>(
  jwksUri: 'https://cognito.../jwks.json',
);

// In resources
server.registerResource(
  CrudResource<User, UserClaims>(
    path: '/users',
    repository: userRepo,
    serializers: {'application/json': serializer},
    authHandler: authHandler,
  ),
);

// In custom handlers - type-safe access!
queryHandlers: {
  'me': (repo, params, skip, take, authResult) async {
    final email = authResult.claims.email;  // String, not dynamic!
    final isAdmin = authResult.claims.isAdmin;  // bool, not dynamic!
    // ...
  }
}
```

**How It Works:**

1. Developer annotates claims class with `@JwtSerializable()`
2. Code generator creates extension methods on `JwtAuthHandler<UserClaims>`
3. When `JwtAuthHandler<UserClaims>` needs to parse/serialize claims, it calls the extension methods
4. Extension methods are automatically in scope when you import the claims file
5. Multiple claims types work seamlessly - each gets its own extension

**Built-in StandardClaims:**

For simple cases, dddart_rest provides a pre-generated claims class:

```dart
// Already provided by dddart_rest
class StandardClaims {
  const StandardClaims({
    required this.sub,
    this.email,
    this.name,
  });
  
  final String sub;  // Subject (user ID)
  final String? email;
  final String? name;
}

// Use without defining custom claims
final authHandler = JwtAuthHandler<StandardClaims>(
  secret: 'your-secret',
  refreshTokenRepository: repo,
);
```

### Infrastructure Models

> **Note:** RefreshToken and DeviceCode extend AggregateRoot for persistence convenience, but they are infrastructure concerns, not domain concepts. dddart's Repository pattern is used here as a general-purpose persistence abstraction, not strictly for domain aggregates. This pragmatic approach allows us to reuse code generation, database abstraction, and consistent persistence patterns without requiring developers to write custom persistence code for authentication infrastructure.

#### RefreshToken (Aggregate Root)

```dart
/// Refresh token for maintaining long-lived sessions
@Serializable()
class RefreshToken extends AggregateRoot {
  RefreshToken({
    required super.id,
    required this.userId,
    required this.token,
    required this.expiresAt,
    this.revoked = false,
    this.deviceInfo,
  });
  
  /// User ID this token belongs to
  final String userId;
  
  /// The actual token string (random, opaque)
  final String token;
  
  /// When this token expires
  final DateTime expiresAt;
  
  /// Whether this token has been revoked
  final bool revoked;
  
  /// Optional device information (e.g., "CLI v1.0", "Chrome on MacOS")
  final String? deviceInfo;
  
  /// Checks if token is currently valid
  bool get isValid => 
      !revoked && 
      expiresAt.isAfter(DateTime.now());
  
  /// Creates a revoked copy of this token
  RefreshToken revoke() {
    return RefreshToken(
      id: id,
      userId: userId,
      token: token,
      expiresAt: expiresAt,
      revoked: true,
      deviceInfo: deviceInfo,
    );
  }
  
  @override
  List<Object?> get props => [id, userId, token, expiresAt, revoked, deviceInfo];
}
```

#### DeviceCode (Aggregate Root)

```dart
/// Device code for device flow authentication
@Serializable()
class DeviceCode extends AggregateRoot {
  DeviceCode({
    required super.id,
    required this.deviceCode,
    required this.userCode,
    required this.clientId,
    required this.expiresAt,
    this.userId,
    this.status = DeviceCodeStatus.pending,
  });
  
  /// The device code (long, random)
  final String deviceCode;
  
  /// The user code (short, human-readable)
  final String userCode;
  
  /// Client ID that requested this code
  final String clientId;
  
  /// When this code expires
  final DateTime expiresAt;
  
  /// User ID if approved
  final String? userId;
  
  /// Current status
  final DeviceCodeStatus status;
  
  /// Checks if code is expired
  bool get isExpired => DateTime.now().isAfter(expiresAt);
  
  /// Approves the device code for a user
  DeviceCode approve(String userId) {
    return DeviceCode(
      id: id,
      deviceCode: deviceCode,
      userCode: userCode,
      clientId: clientId,
      expiresAt: expiresAt,
      userId: userId,
      status: DeviceCodeStatus.approved,
    );
  }
  
  @override
  List<Object?> get props => [id, deviceCode, userCode, clientId, expiresAt, userId, status];
}

enum DeviceCodeStatus {
  pending,
  approved,
  denied,
  expired,
}
```

#### Tokens

```dart
/// Access and refresh tokens returned from authentication
class Tokens {
  const Tokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    this.tokenType = 'Bearer',
  });
  
  /// JWT access token
  final String accessToken;
  
  /// Opaque refresh token
  final String refreshToken;
  
  /// Seconds until access token expires
  final int expiresIn;
  
  /// Token type (always "Bearer")
  final String tokenType;
  
  /// Converts to JSON for API responses
  Map<String, dynamic> toJson() => {
    'access_token': accessToken,
    'refresh_token': refreshToken,
    'expires_in': expiresIn,
    'token_type': tokenType,
  };
}
```

### CrudResource Integration

```dart
/// Updated CrudResource to support authentication
class CrudResource<T extends AggregateRoot, TClaims> {
  CrudResource({
    required this.path,
    required this.repository,
    required this.serializers,
    this.authHandler,  // NEW: Optional auth handler
    // ... existing parameters
  });
  
  /// Optional authentication handler
  final AuthHandler<TClaims>? authHandler;
  
  /// Handles GET /:id with authentication
  Future<Response> handleGetById(Request request, String id) async {
    // NEW: Authenticate if handler provided
    if (authHandler != null) {
      final authResult = await authHandler!.authenticate(request);
      if (!authResult.isAuthenticated) {
        return _unauthorizedResponse(authResult.errorMessage);
      }
      // Store authResult in request context for handlers to access
      // Custom handlers can access typed claims: authResult.claims.email
    }
    
    // Existing logic...
  }
  
  // Similar updates for handleQuery, handleCreate, handleUpdate, handleDelete
}
```

### Client Library Components

#### RestClient

```dart
/// HTTP client with automatic authentication
class RestClient {
  RestClient({
    required this.baseUrl,
    required this.authProvider,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();
  
  final String baseUrl;
  final AuthProvider authProvider;
  final http.Client _httpClient;
  
  /// GET request with automatic auth
  Future<http.Response> get(String path, {Map<String, String>? headers}) async {
    final token = await authProvider.getAccessToken();
    final allHeaders = {
      'Authorization': 'Bearer $token',
      ...?headers,
    };
    return _httpClient.get(Uri.parse('$baseUrl$path'), headers: allHeaders);
  }
  
  /// POST request with automatic auth
  Future<http.Response> post(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) async {
    final token = await authProvider.getAccessToken();
    final allHeaders = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      ...?headers,
    };
    return _httpClient.post(
      Uri.parse('$baseUrl$path'),
      headers: allHeaders,
      body: body != null ? jsonEncode(body) : null,
    );
  }
  
  // Similar for put, delete, patch
}
```

#### AuthProvider (Interface)

```dart
/// Interface for authentication providers
abstract class AuthProvider {
  /// Gets a valid access token, refreshing if necessary
  Future<String> getAccessToken();
  
  /// Initiates login flow
  Future<void> login();
  
  /// Logs out and clears credentials
  Future<void> logout();
  
  /// Checks if currently authenticated
  Future<bool> isAuthenticated();
}
```

#### DeviceFlowAuthProvider

```dart
/// Auth provider for self-hosted device flow
class DeviceFlowAuthProvider implements AuthProvider {
  DeviceFlowAuthProvider({
    required this.authUrl,
    required this.clientId,
    required this.credentialsPath,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();
  
  final String authUrl;
  final String clientId;
  final String credentialsPath;
  final http.Client _httpClient;
  
  @override
  Future<String> getAccessToken() async {
    final creds = await _loadCredentials();
    
    // Check if access token is still valid
    if (creds != null && !creds.isExpired) {
      return creds.accessToken;
    }
    
    // Try to refresh
    if (creds?.refreshToken != null) {
      try {
        final newTokens = await _refresh(creds!.refreshToken);
        await _saveCredentials(newTokens);
        return newTokens.accessToken;
      } catch (e) {
        // Refresh failed, need to login again
      }
    }
    
    throw AuthenticationException('Not authenticated. Run login command.');
  }
  
  @override
  Future<void> login() async {
    // 1. Request device code
    final response = await _httpClient.post(
      Uri.parse('$authUrl/device'),
      body: jsonEncode({'client_id': clientId}),
      headers: {'Content-Type': 'application/json'},
    );
    
    final deviceCodeResponse = DeviceCodeResponse.fromJson(
      jsonDecode(response.body),
    );
    
    // 2. Display to user
    print('Visit: ${deviceCodeResponse.verificationUri}');
    print('Enter code: ${deviceCodeResponse.userCode}');
    print('\nWaiting for authorization...');
    
    // 3. Poll for tokens
    final tokens = await _pollForTokens(deviceCodeResponse);
    
    // 4. Save credentials
    await _saveCredentials(tokens);
    print('✓ Successfully authenticated!');
  }
  
  Future<Tokens> _pollForTokens(DeviceCodeResponse deviceCode) async {
    final deadline = DateTime.now().add(
      Duration(seconds: deviceCode.expiresIn),
    );
    var interval = deviceCode.interval;
    
    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(Duration(seconds: interval));
      
      final response = await _httpClient.post(
        Uri.parse('$authUrl/token'),
        body: jsonEncode({
          'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
          'device_code': deviceCode.deviceCode,
          'client_id': clientId,
        }),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        return Tokens.fromJson(jsonDecode(response.body));
      }
      
      final error = jsonDecode(response.body)['error'];
      if (error == 'authorization_pending') {
        continue;
      } else if (error == 'slow_down') {
        interval += 5;
        continue;
      } else {
        throw AuthenticationException('Authentication failed: $error');
      }
    }
    
    throw AuthenticationException('Authentication timed out');
  }
  
  Future<Tokens> _refresh(String refreshToken) async {
    final response = await _httpClient.post(
      Uri.parse('$authUrl/refresh'),
      body: jsonEncode({'refresh_token': refreshToken}),
      headers: {'Content-Type': 'application/json'},
    );
    
    if (response.statusCode != 200) {
      throw AuthenticationException('Token refresh failed');
    }
    
    return Tokens.fromJson(jsonDecode(response.body));
  }
  
  @override
  Future<void> logout() async {
    final creds = await _loadCredentials();
    if (creds?.refreshToken != null) {
      await _httpClient.post(
        Uri.parse('$authUrl/logout'),
        body: jsonEncode({'refresh_token': creds!.refreshToken}),
        headers: {'Content-Type': 'application/json'},
      );
    }
    await _deleteCredentials();
  }
  
  Future<StoredCredentials?> _loadCredentials() async {
    // Load from credentialsPath
  }
  
  Future<void> _saveCredentials(Tokens tokens) async {
    // Save to credentialsPath
  }
  
  Future<void> _deleteCredentials() async {
    // Delete credentialsPath
  }
  
  @override
  Future<bool> isAuthenticated() async {
    try {
      await getAccessToken();
      return true;
    } catch (e) {
      return false;
    }
  }
}
```

#### CognitoAuthProvider

```dart
/// Auth provider for AWS Cognito device flow
class CognitoAuthProvider implements AuthProvider {
  CognitoAuthProvider({
    required this.cognitoDomain,
    required this.clientId,
    required this.credentialsPath,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();
  
  final String cognitoDomain;
  final String clientId;
  final String credentialsPath;
  final http.Client _httpClient;
  
  // Similar implementation to DeviceFlowAuthProvider
  // but uses Cognito endpoints:
  // - $cognitoDomain/oauth2/device
  // - $cognitoDomain/oauth2/token
}
```

## Data Models

### JWT Structure

**Access Token (JWT):**
```json
{
  "header": {
    "alg": "HS256",
    "typ": "JWT"
  },
  "payload": {
    "sub": "user123",
    "iss": "https://api.example.com",
    "aud": "my-app",
    "exp": 1234567890,
    "iat": 1234567000,
    "custom_claim": "value"
  },
  "signature": "..."
}
```

**Refresh Token:**
- Opaque string (UUID or crypto-random)
- Not a JWT
- Stored in database

### API Request/Response Formats

**POST /auth/login:**
```json
Request:
{
  "username": "alice",
  "password": "secret"
}

Response (200):
{
  "access_token": "eyJhbGc...",
  "refresh_token": "def50200...",
  "expires_in": 900,
  "token_type": "Bearer"
}
```

**POST /auth/refresh:**
```json
Request:
{
  "refresh_token": "def50200..."
}

Response (200):
{
  "access_token": "eyJhbGc...",
  "expires_in": 900,
  "token_type": "Bearer"
}
```

**POST /auth/device:**
```json
Request:
{
  "client_id": "my-cli-app"
}

Response (200):
{
  "device_code": "abc123...",
  "user_code": "WDJB-MJHT",
  "verification_uri": "https://api.example.com/auth/device/verify",
  "expires_in": 600,
  "interval": 5
}
```

**POST /auth/token (device flow):**
```json
Request:
{
  "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
  "device_code": "abc123...",
  "client_id": "my-cli-app"
}

Response (pending):
{
  "error": "authorization_pending"
}

Response (approved):
{
  "access_token": "eyJhbGc...",
  "refresh_token": "def50200...",
  "expires_in": 900,
  "token_type": "Bearer"
}
```

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*


### JWT Token Validation Properties

Property 1: Missing authentication returns 401
*For any* protected endpoint request without an Authorization header, the system should return HTTP 401 with RFC 7807 error format
**Validates: Requirements 1.1**

Property 2: Valid tokens are accepted
*For any* valid JWT access token, the system should extract user identity and allow the request to proceed
**Validates: Requirements 1.2**

Property 3: Expired tokens are rejected
*For any* JWT with an expiration time in the past, the system should return HTTP 401 with error indicating expiration
**Validates: Requirements 1.3**

Property 4: Invalid signatures are rejected
*For any* JWT with a signature that doesn't match the payload, the system should return HTTP 401 with error indicating invalid token
**Validates: Requirements 1.4**

Property 5: User identity extraction
*For any* valid JWT, the extracted user identity and claims should match the claims encoded in the token
**Validates: Requirements 1.5**

### Self-Hosted Authentication Properties

Property 6: Login returns both tokens
*For any* valid credentials submitted to login endpoint, the response should contain both an access token and a refresh token
**Validates: Requirements 2.1**

Property 7: Access token structure
*For any* issued access token, decoding the JWT should reveal user identity, expiration time, and any provided custom claims
**Validates: Requirements 2.2**

Property 8: Refresh token persistence
*For any* issued refresh token, the token should exist in the configured repository as a RefreshToken aggregate
**Validates: Requirements 2.3**

Property 9: Refresh token exchange
*For any* valid refresh token submitted to refresh endpoint, the system should return a new valid access token
**Validates: Requirements 2.4**

Property 10: Invalid refresh tokens rejected
*For any* expired or revoked refresh token, the refresh endpoint should return HTTP 401
**Validates: Requirements 2.5**

Property 11: Logout revokes token
*For any* refresh token, after logout the token's revoked flag should be true in the repository
**Validates: Requirements 2.6**

Property 12: Repository operations for refresh tokens
*For any* refresh token validation, the system should query the repository for the token
**Validates: Requirements 6.5**

Property 13: Revocation updates repository
*For any* refresh token revocation, the token's revoked flag should be updated in the repository
**Validates: Requirements 6.6**

Property 14: Token creation saves to repository
*For any* new refresh token creation, a RefreshToken aggregate should be saved to the repository
**Validates: Requirements 6.7**

### OAuth/OIDC Properties

Property 15: OAuth signature verification
*For any* JWT from an OAuth provider, the system should verify the signature using the provider's public keys from JWKS
**Validates: Requirements 3.2**

Property 16: Issuer claim validation
*For any* OAuth JWT, if the issuer claim doesn't match the configured provider, the system should reject the token
**Validates: Requirements 3.3**

Property 17: Audience claim validation
*For any* OAuth JWT, if the audience claim doesn't match the configured client ID, the system should reject the token
**Validates: Requirements 3.4**

Property 18: OAuth claim extraction
*For any* valid OAuth JWT, the extracted user identity should match the standard claims (sub, email) in the token
**Validates: Requirements 3.5**

### Device Flow Properties

Property 19: Device code response structure
*For any* device code request, the response should contain device_code, user_code, verification_uri, expires_in, and interval
**Validates: Requirements 4.1**

Property 20: User code format
*For any* generated user code, the code should be 8-10 characters, uppercase letters and digits, with a hyphen separator (e.g., "WDJB-MJHT")
**Validates: Requirements 4.2**

Property 21: Pending status during polling
*For any* device code that hasn't been approved, polling the token endpoint should return "authorization_pending"
**Validates: Requirements 4.4**

Property 22: Approved device code returns tokens
*For any* device code that has been approved, polling the token endpoint should return access and refresh tokens
**Validates: Requirements 4.5**

Property 23: Expired device codes rejected
*For any* device code past its expiration time, polling should return an error indicating expiration
**Validates: Requirements 4.6**

### Client Library Properties

Property 24: Automatic token inclusion
*For any* API request made through the client library, the request should include a valid access token in the Authorization header
**Validates: Requirements 5.1**

Property 25: Automatic token refresh
*For any* expired access token, the client library should automatically refresh it before making the API request
**Validates: Requirements 5.2**

Property 26: Device flow execution
*For any* login initiation, the client library should request a device code, poll for tokens, and store credentials upon success
**Validates: Requirements 5.3**

Property 27: Credential persistence
*For any* successful authentication, the client library should save credentials to a file in the user's home directory
**Validates: Requirements 5.4**

Property 28: Logout cleanup
*For any* logout operation, the client library should revoke the refresh token and delete the stored credentials file
**Validates: Requirements 5.5**

Property 29: Self-hosted endpoint routing
*For any* client library configured for self-hosted auth, device flow and refresh operations should call the API's auth endpoints
**Validates: Requirements 9.1, 9.3**

Property 30: OAuth endpoint routing
*For any* client library configured for OAuth auth, device flow and refresh operations should call the OAuth provider's endpoints
**Validates: Requirements 9.2, 9.4**

### Resource Protection Properties

Property 31: Public resources without auth
*For any* CrudResource registered without an auth handler, requests should succeed without authentication
**Validates: Requirements 7.1**

Property 32: Protected resources require auth
*For any* CrudResource registered with an auth handler, all CRUD operations should require valid authentication
**Validates: Requirements 7.2**

Property 33: Auth handler invocation order
*For any* protected resource request, the auth handler should be invoked before any repository operations
**Validates: Requirements 7.3**

Property 34: Failed auth short-circuits
*For any* authentication failure on a protected resource, the system should return HTTP 401 without invoking repository operations
**Validates: Requirements 7.4**

Property 35: Auth result availability
*For any* successful authentication, the user identity and claims should be available to custom query handlers and exception handlers
**Validates: Requirements 7.5**

### Error Handling Properties

Property 36: No secret leakage in errors
*For any* authentication failure, the error response should not contain signing secrets, expected signatures, or other sensitive information
**Validates: Requirements 10.5**

### JWT Configuration Properties

Property 37: HMAC-SHA256 algorithm
*For any* issued JWT in self-hosted mode, the token header should specify "alg": "HS256"
**Validates: Requirements 11.5**

Property 38: Custom claims inclusion
*For any* custom claims provided when issuing a token, those claims should appear in the JWT payload
**Validates: Requirements 12.2**

Property 39: Custom claims extraction
*For any* JWT with custom claims, validating the token should extract those claims and include them in the AuthResult
**Validates: Requirements 12.3, 12.4**

Property 40: Standard claims only
*For any* token issued without custom claims, the JWT payload should contain only standard claims (sub, exp, iat, iss, aud)
**Validates: Requirements 12.5**

## Error Handling

### Authentication Errors

All authentication errors return HTTP 401 Unauthorized with RFC 7807 Problem Details format:

```json
{
  "type": "about:blank",
  "title": "Unauthorized",
  "status": 401,
  "detail": "<specific error message>"
}
```

**Error Cases:**

| Scenario | Detail Message |
|----------|----------------|
| Missing Authorization header | "Missing authorization header" |
| Invalid token format | "Invalid token format" |
| Expired token | "Token has expired" |
| Invalid signature | "Invalid token signature" |
| Invalid issuer | "Invalid token issuer" |
| Invalid audience | "Invalid token audience" |
| Refresh token not found | "Invalid refresh token" |
| Refresh token expired | "Refresh token has expired" |
| Refresh token revoked | "Refresh token has been revoked" |
| Device code not found | "Invalid device code" |
| Device code expired | "Device code has expired" |

**Security Considerations:**

- Error messages must not expose signing secrets
- Error messages must not expose expected vs actual signatures
- Error messages must not expose internal system details
- Error messages should be generic enough to prevent information leakage

### Repository Errors

Repository operations may throw `RepositoryException`. These should be caught and mapped to appropriate HTTP responses:

| Repository Exception | HTTP Status | Response |
|---------------------|-------------|----------|
| notFound | 401 | "Invalid refresh token" |
| connection | 503 | "Service temporarily unavailable" |
| timeout | 504 | "Request timeout" |
| unknown | 500 | "Internal server error" |

### Client Library Errors

The client library throws `AuthenticationException` for auth-related errors:

- `AuthenticationException('Not authenticated. Run login command.')` - No valid credentials
- `AuthenticationException('Token refresh failed')` - Refresh token invalid or expired
- `AuthenticationException('Authentication failed: <error>')` - Device flow error
- `AuthenticationException('Authentication timed out')` - Device flow timeout

## Testing Strategy

### Unit Testing

**Auth Handler Tests:**
- JWT signing and verification
- Token expiration validation
- Signature validation
- Claim extraction
- OAuth JWKS fetching and caching
- Error handling for invalid tokens

**Auth Endpoints Tests:**
- Login endpoint with valid/invalid credentials
- Refresh endpoint with valid/invalid tokens
- Logout endpoint
- Device code generation
- Device flow polling (pending, approved, expired)
- Token endpoint with different grant types

**Client Library Tests:**
- Automatic token inclusion in requests
- Automatic token refresh
- Device flow execution
- Credential storage and loading
- Logout cleanup
- Endpoint routing for different auth modes

**Repository Integration Tests:**
- RefreshToken CRUD operations
- DeviceCode CRUD operations
- Query operations for token lookup
- Revocation updates

### Property-Based Testing

Property-based tests will use the `test` package with custom generators for:
- Random JWTs (valid, expired, invalid signature)
- Random refresh tokens
- Random device codes
- Random user credentials
- Random custom claims

**Key Properties to Test:**
- JWT round-trip (issue → validate → extract claims)
- Refresh token lifecycle (create → validate → revoke)
- Device flow state machine (pending → approved → tokens)
- Auth handler consistency across token variations
- Error handling across invalid input variations

**Test Configuration:**
- Minimum 100 iterations per property test
- Use in-memory repository for fast execution
- Mock HTTP client for OAuth JWKS fetching
- Mock time for expiration testing

### Integration Testing

**End-to-End Flows:**
- Complete self-hosted auth flow (login → API request → refresh → logout)
- Complete OAuth flow (external token → API request)
- Complete device flow (request code → approve → poll → API request)
- Client library with real HTTP server
- Multiple concurrent device flows
- Token expiration and refresh during long-running operations

**Database Integration:**
- RefreshToken with MongoDB repository
- DeviceCode with MongoDB repository
- Concurrent token operations
- Repository error handling

### Security Testing

**Attack Scenarios:**
- Token tampering (modify claims, change expiration)
- Signature forgery attempts
- Replay attacks with expired tokens
- Brute force device code guessing
- JWKS cache poisoning
- Timing attacks on signature verification

**Validation:**
- All attacks should be rejected with 401
- No sensitive information in error responses
- Constant-time signature comparison
- Rate limiting on device flow endpoints

## Dependencies

### Server-Side (dddart_rest)

```yaml
dependencies:
  dddart: ^0.9.0
  dddart_serialization: ^0.9.0
  shelf: ^1.4.0
  shelf_router: ^1.1.0
  dart_jsonwebtoken: ^2.13.0  # JWT signing and verification
  crypto: ^3.0.3  # HMAC, random token generation
  http: ^1.2.0  # OAuth JWKS fetching
  uuid: ^4.0.0  # Device code generation

dev_dependencies:
  test: ^1.24.0
  build_runner: ^2.4.0
  dddart_json: ^0.9.0
```

### Client-Side (dddart_rest_client)

```yaml
dependencies:
  http: ^1.2.0  # HTTP client
  path: ^1.9.0  # Credential file paths

dev_dependencies:
  test: ^1.24.0
  mockito: ^5.4.0  # HTTP mocking
```

### Repository Generation

RefreshToken and DeviceCode are pre-annotated in dddart_rest with `@Serializable()` only. Developers choose their persistence strategy:

**Option 1: In-Memory (Quick Start / Testing)**

No code generation needed. Use RefreshToken and DeviceCode directly:

```dart
import 'package:dddart_rest/dddart_rest.dart';

final refreshTokenRepo = InMemoryRepository<RefreshToken>();
final deviceCodeRepo = InMemoryRepository<DeviceCode>();

final authHandler = JwtAuthHandler<UserClaims, RefreshToken>(
  secret: 'secret',
  refreshTokenRepository: refreshTokenRepo,
);
```

**Option 2: MongoDB (Production)**

Extend and annotate for code generation:

```dart
import 'package:dddart_rest/dddart_rest.dart';
import 'package:dddart_repository_mongodb/dddart_repository_mongodb.dart';

@Serializable()
@GenerateMongoRepository()
class AppRefreshToken extends RefreshToken {
  AppRefreshToken({
    required super.id,
    required super.userId,
    required super.token,
    required super.expiresAt,
    super.revoked,
    super.deviceInfo,
  });
}

@Serializable()
@GenerateMongoRepository()
class AppDeviceCode extends DeviceCode {
  AppDeviceCode({
    required super.id,
    required super.deviceCode,
    required super.userCode,
    required super.clientId,
    required super.expiresAt,
    super.userId,
    super.status,
  });
}

part 'auth_models.g.dart';

// Run: dart run build_runner build
// Generates: AppRefreshTokenMongoRepository, AppDeviceCodeMongoRepository

// Usage:
final refreshTokenRepo = AppRefreshTokenMongoRepository(database);
final deviceCodeRepo = AppDeviceCodeMongoRepository(database);

final authHandler = JwtAuthHandler<UserClaims, AppRefreshToken>(
  secret: 'secret',
  refreshTokenRepository: refreshTokenRepo,  // Repository<AppRefreshToken>
);
```

**Key Points:**

- Auth handler is generic: `JwtAuthHandler<TClaims, TRefreshToken extends RefreshToken>`
- Accepts `Repository<TRefreshToken>` where TRefreshToken can be RefreshToken itself or any subclass
- No cross-package dependencies between dddart_rest and dddart_repository_*
- Developers only extend when they need database-specific annotations

## Migration and Compatibility

### Existing dddart_rest Applications

Applications using dddart_rest without authentication will continue to work unchanged. Authentication is opt-in:

```dart
// Before (still works):
server.registerResource(
  CrudResource<User>(
    path: '/users',
    repository: userRepo,
    serializers: {'application/json': serializer},
  ),
);

// After (with auth):
server.registerResource(
  CrudResource<User>(
    path: '/users',
    repository: userRepo,
    serializers: {'application/json': serializer},
    authHandler: jwtAuthHandler,  // NEW: Optional parameter
  ),
);
```

### Database Schema

**RefreshToken Collection:**
```json
{
  "_id": "uuid",
  "userId": "user123",
  "token": "random-string",
  "expiresAt": "2024-12-05T10:00:00Z",
  "revoked": false,
  "deviceInfo": "CLI v1.0",
  "createdAt": "2024-11-28T10:00:00Z",
  "updatedAt": "2024-11-28T10:00:00Z"
}
```

**DeviceCode Collection:**
```json
{
  "_id": "uuid",
  "deviceCode": "abc123...",
  "userCode": "WDJB-MJHT",
  "clientId": "my-cli-app",
  "expiresAt": "2024-11-28T10:10:00Z",
  "userId": null,
  "status": "pending",
  "createdAt": "2024-11-28T10:00:00Z",
  "updatedAt": "2024-11-28T10:00:00Z"
}
```

### Indexes

**RefreshToken:**
- Index on `token` (unique) for fast lookup
- Index on `userId` for user token management
- Index on `expiresAt` for cleanup of expired tokens

**DeviceCode:**
- Index on `deviceCode` (unique) for polling
- Index on `userCode` (unique) for verification
- Index on `expiresAt` for cleanup

## Performance Considerations

### JWT Validation

- **No database lookup** for access token validation (stateless)
- Signature verification is CPU-bound (HMAC-SHA256)
- Expected latency: < 1ms per validation

### Refresh Token Operations

- **Database lookup required** for refresh token validation
- Expected latency: 5-50ms depending on database
- Consider caching recently used refresh tokens (with TTL)

### OAuth JWKS Caching

- JWKS fetched once and cached (default 1 hour)
- Reduces latency from ~100ms to < 1ms
- Automatic refresh on cache expiration
- Consider longer cache duration for production (24 hours)

### Device Flow Polling

- Default polling interval: 5 seconds
- Implement exponential backoff for slow_down errors
- Consider WebSocket alternative for real-time approval
- Cleanup expired device codes periodically (background job)

### Scalability

- **Stateless access tokens** enable horizontal scaling
- **Refresh tokens in database** require shared storage
- Consider Redis for refresh token storage (faster than MongoDB)
- Consider distributed cache for JWKS (Redis, Memcached)

## Security Considerations

### Token Security

**Access Tokens:**
- Short-lived (15 minutes default) to limit exposure
- Signed with HMAC-SHA256 (secure for symmetric keys)
- Include expiration time (exp claim)
- Include issued-at time (iat claim) for audit

**Refresh Tokens:**
- Long-lived (7 days default) but revocable
- Stored in database for revocation capability
- Random, cryptographically secure generation
- One-time use recommended (issue new refresh token on refresh)

**Signing Secrets:**
- Minimum 256 bits (32 bytes) for HMAC-SHA256
- Store in environment variables or secret manager
- Rotate periodically (requires invalidating all tokens)
- Never commit to version control

### OAuth Security

**JWKS Validation:**
- Always fetch JWKS over HTTPS
- Validate certificate chain
- Cache with reasonable TTL (1-24 hours)
- Handle key rotation gracefully

**Claim Validation:**
- Always validate issuer (iss) claim
- Always validate audience (aud) claim
- Always validate expiration (exp) claim
- Consider validating not-before (nbf) claim

### Device Flow Security

**User Codes:**
- Short (8-10 characters) for easy typing
- Avoid ambiguous characters (0/O, 1/I/l)
- Expire quickly (10 minutes default)
- Rate limit verification attempts

**Device Codes:**
- Long, random, cryptographically secure
- One-time use (invalidate after approval)
- Expire with user code
- Rate limit polling (prevent brute force)

### Transport Security

**HTTPS Required:**
- All authentication endpoints must use HTTPS in production
- Tokens transmitted in Authorization header (not URL)
- Consider HSTS header for strict transport security

**CORS Configuration:**
- Restrict origins for web applications
- Don't allow wildcard (*) in production
- Include credentials in CORS policy if needed

### Attack Mitigation

**Brute Force:**
- Rate limit login attempts (per IP, per user)
- Rate limit device code verification
- Rate limit token refresh
- Consider CAPTCHA for repeated failures

**Token Theft:**
- Short-lived access tokens limit exposure
- Refresh token rotation on use
- Revoke all tokens on password change
- Monitor for suspicious token usage patterns

**Replay Attacks:**
- Include timestamp in JWT (iat claim)
- Reject tokens older than reasonable threshold
- Consider nonce for critical operations

## Future Enhancements

### Potential Features

1. **Token Rotation** - Issue new refresh token on each refresh
2. **Multi-Factor Authentication** - TOTP, SMS, email verification
3. **Social Login** - Google, GitHub, Facebook OAuth
4. **API Key Support** - Long-lived keys for service accounts
5. **Scope-Based Authorization** - Fine-grained permissions
6. **Token Introspection** - Endpoint to check token validity
7. **Token Revocation List** - Blacklist for compromised tokens
8. **Audit Logging** - Track all authentication events
9. **Session Management** - View and revoke active sessions
10. **WebAuthn Support** - Passwordless authentication

### Backward Compatibility

All future enhancements will maintain backward compatibility:
- New features will be opt-in
- Existing auth handlers will continue to work
- API changes will follow semantic versioning
- Deprecation warnings before breaking changes
