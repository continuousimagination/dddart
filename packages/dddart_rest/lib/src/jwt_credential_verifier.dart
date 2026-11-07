import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:dddart_rest/src/authentication_result.dart';
import 'package:dddart_rest/src/token_authentication_handler.dart';

/// Built-in JWT verification without an HTTP request or token-issuance repository.
/// The HTTP issuer and native event authorizer use this exact implementation.
class JwtCredentialVerifier<TClaims> implements CredentialVerifier<TClaims> {
  /// Configures the same signature and claim validation used by JwtAuthHandler.
  JwtCredentialVerifier({
    required this.secret,
    required TClaims Function(Map<String, dynamic>) parseClaimsFromJson,
    this.issuer,
    this.audience,
  }) : _parseClaimsFromJson = parseClaimsFromJson;

  /// Existing built-in JWT signing secret.
  final String secret;

  /// Expected issuer, when configured.
  final String? issuer;

  /// Expected audience, when configured.
  final String? audience;
  final TClaims Function(Map<String, dynamic>) _parseClaimsFromJson;

  @override
  Future<AuthenticationResult<TClaims>> verifyCredential(String token) async {
    try {
      // Decode and verify JWT
      JWT? jwt;
      try {
        jwt = JWT.verify(token, SecretKey(secret));
      } on JWTExpiredException {
        return AuthenticationResult.failure('Token has expired');
      } on JWTException {
        return AuthenticationResult.failure('Invalid token signature');
      }

      // Verify issuer if configured
      if (issuer != null) {
        final tokenIssuer = jwt.payload['iss'] as String?;
        if (tokenIssuer != issuer) {
          return AuthenticationResult.failure('Invalid token issuer');
        }
      }

      // Verify audience if configured
      if (audience != null) {
        final tokenAudience = jwt.payload['aud'] as String?;
        if (tokenAudience != audience) {
          return AuthenticationResult.failure('Invalid token audience');
        }
      }

      // Extract user ID from sub claim
      final userId = jwt.payload['sub'] as String?;
      if (userId == null || userId.isEmpty) {
        return AuthenticationResult.failure('Token missing subject');
      }

      // Parse claims using provided callback
      final claims = _parseClaimsFromJson(jwt.payload as Map<String, dynamic>);

      return AuthenticationResult.success(
        userId: userId,
        claims: claims,
      );
    } catch (e) {
      return AuthenticationResult.failure('Invalid token: $e');
    }
  }
}
