/// Interface for authentication providers
///
/// Implementations handle authentication flows (device flow, OAuth, etc.)
/// and manage token lifecycle including refresh and storage.
abstract class AuthProvider {
  /// Gets a valid access token, refreshing if necessary
  ///
  /// This method should:
  /// - Return a cached token if still valid
  /// - Automatically refresh if expired
  /// - Throw [AuthenticationException] if not authenticated
  Future<String> getAccessToken();

  /// Gets a valid ID token (JWT), refreshing if necessary
  ///
  /// For OAuth2/OIDC providers like Cognito, the ID token is a JWT
  /// that contains user claims and can be verified with JWKS.
  ///
  /// For non-OIDC providers (like self-hosted device flow), this should
  /// return the access token if it's a JWT.
  ///
  /// This method should:
  /// - Return a cached ID token if still valid
  /// - Automatically refresh if expired
  /// - Throw [AuthenticationException] if not authenticated
  Future<String> getIdToken();

  /// Initiates login flow
  ///
  /// For device flow:
  /// - Requests device code from server
  /// - Displays user code and verification URI
  /// - Polls for tokens until approved or timeout
  /// - Stores credentials on success
  ///
  /// Throws [AuthenticationException] on failure.
  Future<void> login();

  /// Logs out and clears credentials
  ///
  /// This method should:
  /// - Revoke refresh token on server
  /// - Delete stored credentials
  /// - Clear any cached tokens
  Future<void> logout();

  /// Checks if currently authenticated
  ///
  /// Returns true if valid credentials are available,
  /// false otherwise.
  Future<bool> isAuthenticated();
}

/// Exception thrown when authentication operations fail
class AuthenticationException implements Exception {
  /// Creates an authentication exception with a message
  AuthenticationException(this.message);

  /// The error message
  final String message;

  @override
  String toString() => 'AuthenticationException: $message';
}
