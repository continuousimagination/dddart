import 'package:dddart_rest/src/auth_handler.dart';
import 'package:dddart_rest/src/auth_result.dart';
import 'package:jose/jose.dart';
import 'package:shelf/shelf.dart';

/// Handles JWT validation for OAuth2/OIDC providers
///
/// Validates JWTs issued by external OAuth providers (like AWS Cognito, Auth0,
/// Okta) by fetching and caching the provider's public keys (JWKS) and
/// verifying JWT signatures.
///
/// Generic over [TClaims] to support strongly-typed custom claims.
///
/// Example:
/// ```dart
/// final authHandler = OAuthJwtAuthHandler<UserClaims>(
///   jwksUri: 'https://cognito-idp.us-east-1.amazonaws.com/us-east-1_xxxxx/.well-known/jwks.json',
///   parseClaimsFromJson: (json) => UserClaims.fromJson(json),
///   issuer: 'https://cognito-idp.us-east-1.amazonaws.com/us-east-1_xxxxx',
///   audience: 'my-client-id',
/// );
/// ```
class OAuthJwtAuthHandler<TClaims> extends AuthHandler<TClaims> {
  /// Creates an OAuth JWT authentication handler
  OAuthJwtAuthHandler({
    required this.jwksUri,
    required TClaims Function(Map<String, dynamic>) parseClaimsFromJson,
    this.issuer,
    this.audience,
    this.cacheDuration = const Duration(hours: 1),
  }) : _parseClaimsFromJson = parseClaimsFromJson {
    // Initialize the key store with the JWKS URI
    _keyStore = JsonWebKeyStore()..addKeySetUrl(Uri.parse(jwksUri));
  }

  /// URI to fetch JSON Web Key Set (public keys)
  final String jwksUri;

  /// Expected issuer claim
  final String? issuer;

  /// Expected audience claim
  final String? audience;

  /// How long to cache JWKS before refetching
  final Duration cacheDuration;

  /// Function to parse claims from JSON
  final TClaims Function(Map<String, dynamic>) _parseClaimsFromJson;

  /// JSON Web Key Store for verification
  late final JsonWebKeyStore _keyStore;

  @override
  Future<AuthResult<TClaims>> authenticate(Request request) async {
    try {
      // Extract Bearer token from Authorization header
      final authHeader = request.headers['authorization'];
      if (authHeader == null) {
        return AuthResult.failure('Missing authorization header');
      }

      if (!authHeader.startsWith('Bearer ')) {
        return AuthResult.failure('Invalid token format');
      }

      final token = authHeader.substring(7).trim();

      // Parse and verify JWT
      JsonWebToken jwt;
      try {
        jwt = JsonWebToken.unverified(token);

        // Verify signature
        final verified = await jwt.verify(_keyStore);
        if (!verified) {
          return AuthResult.failure('Invalid token signature');
        }
      } on JoseException catch (e) {
        // Sanitize error message to avoid leaking token data
        var errorMsg = e.message;
        // Remove any quoted strings that might be tokens
        errorMsg = errorMsg.replaceAll(RegExp(r'"[^"]*"'), '"[REDACTED]"');
        return AuthResult.failure('Token verification failed: $errorMsg');
      } on Exception catch (e) {
        // Sanitize error message to avoid leaking token data
        var errorMsg = e.toString();
        // Remove any token-like strings (base64url patterns)
        errorMsg = errorMsg.replaceAll(
          RegExp(r'[A-Za-z0-9_-]{20,}'),
          '[REDACTED]',
        );
        return AuthResult.failure('Token verification failed: $errorMsg');
      }

      // Verify issuer if configured
      if (issuer != null) {
        final tokenIssuer = jwt.claims['iss'] as String?;
        if (tokenIssuer != issuer) {
          return AuthResult.failure('Invalid token issuer');
        }
      }

      // Verify audience if configured
      if (audience != null) {
        final tokenAudience = jwt.claims['aud'];
        // Audience can be a string or array of strings
        if (tokenAudience is String) {
          if (tokenAudience != audience) {
            return AuthResult.failure('Invalid token audience');
          }
        } else if (tokenAudience is List) {
          if (!tokenAudience.contains(audience)) {
            return AuthResult.failure('Invalid token audience');
          }
        } else {
          return AuthResult.failure('Invalid token audience');
        }
      }

      // Extract user ID from sub claim
      final userId = jwt.claims['sub'] as String?;
      if (userId == null) {
        return AuthResult.failure('Token missing subject');
      }

      // Parse claims using provided callback
      final claims = _parseClaimsFromJson(
        jwt.claims.toJson().cast<String, dynamic>(),
      );

      return AuthResult.success(
        userId: userId,
        claims: claims,
      );
    } catch (e) {
      // Sanitize error message to avoid leaking token data
      var errorMsg = e.toString();
      // Remove any quoted strings that might contain tokens
      errorMsg = errorMsg.replaceAll(RegExp(r'"[^"]*"'), '"[REDACTED]"');
      // Remove any token-like strings (base64url patterns)
      errorMsg = errorMsg.replaceAll(
        RegExp(r'[A-Za-z0-9_-]{20,}'),
        '[REDACTED]',
      );
      return AuthResult.failure('Invalid token: $errorMsg');
    }
  }
}
