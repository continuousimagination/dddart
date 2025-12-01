/// Result of authentication attempt
///
/// Contains authentication status, user identity, and strongly-typed claims.
class AuthResult<TClaims> {
  /// Creates an authentication result
  const AuthResult({
    required this.isAuthenticated,
    this.userId,
    this.claims,
    this.errorMessage,
  });

  /// Creates a successful authentication result
  factory AuthResult.success({
    required String userId,
    TClaims? claims,
  }) {
    return AuthResult<TClaims>(
      isAuthenticated: true,
      userId: userId,
      claims: claims,
    );
  }

  /// Creates a failed authentication result
  factory AuthResult.failure(String errorMessage) {
    return AuthResult<TClaims>(
      isAuthenticated: false,
      errorMessage: errorMessage,
    );
  }

  /// Whether authentication succeeded
  final bool isAuthenticated;

  /// User ID if authenticated
  final String? userId;

  /// Strongly-typed custom claims from JWT or OAuth token
  final TClaims? claims;

  /// Error message if authentication failed
  final String? errorMessage;
}
