/// Result of an authorization check
///
/// Contains authorization status and optional error message explaining
/// why authorization was denied.
class AuthorizationResult {
  /// Creates an authorization result
  const AuthorizationResult({
    required this.isAuthorized,
    this.errorMessage,
  });

  /// Creates a successful authorization result
  factory AuthorizationResult.allow() {
    return const AuthorizationResult(isAuthorized: true);
  }

  /// Creates a failed authorization result with error message
  factory AuthorizationResult.deny(String errorMessage) {
    return AuthorizationResult(
      isAuthorized: false,
      errorMessage: errorMessage,
    );
  }

  /// Whether authorization succeeded
  final bool isAuthorized;

  /// Error message if authorization failed
  final String? errorMessage;
}
