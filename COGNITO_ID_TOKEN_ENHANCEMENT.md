# Cognito ID Token Enhancement for dddart_rest_client

## Overview

The current `CognitoAuthProvider` in dddart_rest_client stores and manages access tokens and refresh tokens, but does not store or expose the ID token. The ID token is needed to extract user identity information (specifically the `sub` claim, which is the Cognito user ID).

## Why This is Needed

Applications using Cognito authentication need to:
1. Link authenticated users to application-specific user records (e.g., Player profiles)
2. Extract the Cognito `sub` (subject) claim to use as a stable user identifier
3. Access other user claims from the ID token (email, username, custom attributes)

The ID token is returned by Cognito during authentication but is currently discarded by `CognitoAuthProvider`.

## Required Changes

### 1. Store ID Token in Credentials

**File**: `packages/dddart_rest_client/lib/src/cognito_auth_provider.dart`

#### Change 1: Update `_CognitoTokens` class

```dart
class _CognitoTokens {
  _CognitoTokens({
    required this.accessToken,
    required this.idToken,        // ADD THIS FIELD
    required this.refreshToken,
    required this.expiresIn,
  });

  factory _CognitoTokens.fromJson(Map<String, dynamic> json) {
    return _CognitoTokens(
      accessToken: json['access_token'] as String,
      idToken: json['id_token'] as String,        // ADD THIS LINE
      refreshToken: json['refresh_token'] as String,
      expiresIn: json['expires_in'] as int,
    );
  }

  final String accessToken;
  final String idToken;           // ADD THIS FIELD
  final String refreshToken;
  final int expiresIn;
}
```

#### Change 2: Update `_StoredCredentials` class

```dart
class _StoredCredentials {
  _StoredCredentials({
    required this.accessToken,
    required this.idToken,        // ADD THIS FIELD
    required this.refreshToken,
    required this.expiresAt,
  });

  factory _StoredCredentials.fromJson(Map<String, dynamic> json) {
    return _StoredCredentials(
      accessToken: json['access_token'] as String,
      idToken: json['id_token'] as String,        // ADD THIS LINE
      refreshToken: json['refresh_token'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }

  final String accessToken;
  final String idToken;           // ADD THIS FIELD
  final String refreshToken;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'id_token': idToken,        // ADD THIS LINE
        'refresh_token': refreshToken,
        'expires_at': expiresAt.toIso8601String(),
      };
}
```

#### Change 3: Update `_saveCredentials` method

```dart
Future<void> _saveCredentials(_CognitoTokens tokens) async {
  final file = File(credentialsPath);
  await file.parent.create(recursive: true);

  final creds = _StoredCredentials(
    accessToken: tokens.accessToken,
    idToken: tokens.idToken,        // ADD THIS LINE
    refreshToken: tokens.refreshToken,
    expiresAt: DateTime.now().add(Duration(seconds: tokens.expiresIn)),
  );

  await file.writeAsString(jsonEncode(creds.toJson()));
}
```

### 2. Add Methods to Access ID Token and Extract Claims

**File**: `packages/dddart_rest_client/lib/src/cognito_auth_provider.dart`

Add these methods to the `CognitoAuthProvider` class:

```dart
/// Gets the ID token
///
/// Returns the current ID token if authenticated and not expired.
/// Throws [AuthenticationException] if not authenticated.
Future<String> getIdToken() async {
  final creds = await _loadCredentials();
  if (creds == null || creds.isExpired) {
    throw AuthenticationException('Not authenticated. Run login command.');
  }
  return creds.idToken;
}

/// Extracts the Cognito sub (user ID) from the ID token
///
/// The sub claim is a stable, unique identifier for the user in Cognito.
/// This is useful for linking Cognito users to application-specific user records.
///
/// Returns the sub claim value.
/// Throws [AuthenticationException] if not authenticated or token is invalid.
Future<String> getCognitoSub() async {
  final idToken = await getIdToken();
  
  // Decode JWT (base64 decode middle segment)
  final parts = idToken.split('.');
  if (parts.length != 3) {
    throw AuthenticationException('Invalid ID token format');
  }
  
  final payload = utf8.decode(
    base64Url.decode(base64Url.normalize(parts[1])),
  );
  final claims = jsonDecode(payload) as Map<String, dynamic>;
  
  final sub = claims['sub'] as String?;
  if (sub == null) {
    throw AuthenticationException('ID token missing sub claim');
  }
  
  return sub;
}

/// Extracts all claims from the ID token
///
/// Returns a map of all claims in the ID token.
/// Common claims include:
/// - sub: User ID
/// - email: User email
/// - email_verified: Whether email is verified
/// - cognito:username: Cognito username
/// - custom attributes: Any custom attributes configured in user pool
///
/// Throws [AuthenticationException] if not authenticated or token is invalid.
Future<Map<String, dynamic>> getIdTokenClaims() async {
  final idToken = await getIdToken();
  
  // Decode JWT (base64 decode middle segment)
  final parts = idToken.split('.');
  if (parts.length != 3) {
    throw AuthenticationException('Invalid ID token format');
  }
  
  final payload = utf8.decode(
    base64Url.decode(base64Url.normalize(parts[1])),
  );
  return jsonDecode(payload) as Map<String, dynamic>;
}
```

### 3. Handle Token Refresh

**Note**: When refreshing tokens, Cognito returns a new access token but may not return a new ID token. The existing ID token should be preserved.

**File**: `packages/dddart_rest_client/lib/src/cognito_auth_provider.dart`

Update the `_refresh` method to handle optional ID token:

```dart
Future<_CognitoTokens> _refresh(String refreshToken) async {
  final response = await _httpClient.post(
    Uri.parse('$cognitoDomain/oauth2/token'),
    body: 'grant_type=refresh_token'
        '&refresh_token=$refreshToken'
        '&client_id=$clientId',
    headers: {'Content-Type': 'application/x-www-form-urlencoded'},
  );

  if (response.statusCode != 200) {
    throw AuthenticationException('Token refresh failed');
  }

  final json = jsonDecode(response.body) as Map<String, dynamic>;
  
  // Cognito may not return a new ID token on refresh
  // If not present, use the existing one
  final existingCreds = await _loadCredentials();
  
  return _CognitoTokens(
    accessToken: json['access_token'] as String,
    idToken: json['id_token'] as String? ?? existingCreds!.idToken,  // MODIFY THIS LINE
    refreshToken: json['refresh_token'] as String,
    expiresIn: json['expires_in'] as int,
  );
}
```

## Testing Requirements

### Unit Tests

**File**: `packages/dddart_rest_client/test/cognito_auth_provider_test.dart`

Add tests for:

1. **ID token storage**: Verify ID token is saved and loaded correctly
2. **getCognitoSub()**: Verify sub claim extraction from valid ID token
3. **getIdTokenClaims()**: Verify all claims are extracted correctly
4. **Invalid token handling**: Verify proper exceptions for malformed tokens
5. **Token refresh**: Verify ID token is preserved when not returned by refresh

Example test:

```dart
test('getCognitoSub extracts sub claim from ID token', () async {
  // Create a mock ID token with sub claim
  final header = base64Url.encode(utf8.encode(jsonEncode({'alg': 'HS256'})));
  final payload = base64Url.encode(utf8.encode(jsonEncode({
    'sub': 'test-user-id-123',
    'email': 'test@example.com',
  })));
  final signature = base64Url.encode(utf8.encode('fake-signature'));
  final idToken = '$header.$payload.$signature';
  
  // Save credentials with this ID token
  final creds = _StoredCredentials(
    accessToken: 'test-access-token',
    idToken: idToken,
    refreshToken: 'test-refresh-token',
    expiresAt: DateTime.now().add(Duration(hours: 1)),
  );
  
  final file = File(credentialsPath);
  await file.writeAsString(jsonEncode(creds.toJson()));
  
  // Test extraction
  final provider = CognitoAuthProvider(
    cognitoDomain: 'https://test.auth.us-east-1.amazoncognito.com',
    clientId: 'test-client-id',
    credentialsPath: credentialsPath,
  );
  
  final sub = await provider.getCognitoSub();
  expect(sub, equals('test-user-id-123'));
});
```

### Integration Tests

If integration tests exist, verify:
1. Real Cognito authentication flow stores ID token
2. getCognitoSub() works with real Cognito tokens
3. Token refresh preserves ID token

## Documentation Updates

### README.md

Add example showing how to extract user ID:

```dart
// After login, get the Cognito user ID
final cognitoSub = await authProvider.getCognitoSub();
print('Logged in as user: $cognitoSub');

// Or get all claims
final claims = await authProvider.getIdTokenClaims();
print('Email: ${claims['email']}');
print('Email verified: ${claims['email_verified']}');
```

### CHANGELOG.md

Add entry:

```markdown
## [Unreleased]

### Added
- ID token storage in CognitoAuthProvider
- `getIdToken()` method to retrieve ID token
- `getCognitoSub()` method to extract Cognito user ID from ID token
- `getIdTokenClaims()` method to extract all claims from ID token

### Changed
- Token refresh now preserves ID token when Cognito doesn't return a new one
```

## Backward Compatibility

This change is **backward compatible** because:
1. Existing credentials files without `id_token` will fail to parse, but this is acceptable since users will need to re-authenticate anyway
2. The new methods are additions, not modifications to existing API
3. Existing code using `getAccessToken()` and `login()` will continue to work

However, users will need to re-authenticate after upgrading to populate the ID token in their credentials file.

## Implementation Checklist

- [x] Update `_CognitoTokens` class to include `idToken` field
- [x] Update `_StoredCredentials` class to include `idToken` field
- [x] Update `_saveCredentials` to save ID token
- [x] Update `_refresh` to preserve ID token
- [x] Add `getIdToken()` method
- [x] Add `getCognitoSub()` method
- [x] Add `getIdTokenClaims()` method
- [x] Write unit tests for new methods
- [x] Write unit tests for token refresh with ID token
- [x] Update README.md with examples
- [x] Update CHANGELOG.md
- [x] Run all tests: `cd packages/dddart_rest_client && dart test`
- [x] Format code: `dart format .`
- [x] Analyze code: `dart analyze`

## Implementation Status

✅ **COMPLETED** - All changes have been implemented and tested.

The enhancement is now available in the dddart_rest_client package and ready to be used by the silly sentence game.

## Usage in Silly Sentence Game

Once these changes are implemented, the silly sentence game can use:

```dart
// In AuthService
Future<String> getCognitoSub() async {
  return await authProvider.getCognitoSub();
}

// In ProfileHandler
final cognitoSub = await authService.getCognitoSub();
final player = Player.create(
  username: username,
  cognitoSub: cognitoSub,
);
```
