/// Access and refresh tokens returned from authentication
///
/// Represents the token response from login and device flow endpoints.
class Tokens {
  /// Creates a tokens response
  const Tokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    this.tokenType = 'Bearer',
  });

  /// Creates tokens from JSON
  factory Tokens.fromJson(Map<String, dynamic> json) {
    return Tokens(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiresIn: json['expires_in'] as int,
      tokenType: json['token_type'] as String? ?? 'Bearer',
    );
  }

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
