import 'package:dddart_rest/src/authentication_handler.dart';
import 'package:dddart_rest/src/authentication_result.dart';
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
///   clockSkewTolerance: const Duration(seconds: 30),
/// );
/// ```
class OAuthJwtAuthHandler<TClaims> extends AuthenticationHandler<TClaims> {
  /// Creates an OAuth JWT authentication handler
  OAuthJwtAuthHandler({
    required this.jwksUri,
    required TClaims Function(Map<String, dynamic>) parseClaimsFromJson,
    this.issuer,
    this.audience,
    this.cacheDuration = const Duration(hours: 1),
    this.clockSkewTolerance = Duration.zero,
  }) : _parseClaimsFromJson = parseClaimsFromJson {
    if (clockSkewTolerance.isNegative) {
      throw ArgumentError.value(
        clockSkewTolerance,
        'clockSkewTolerance',
        'must not be negative',
      );
    }

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

  /// Clock-skew allowance applied when validating `exp` and `nbf` claims
  ///
  /// Defaults to zero. The token remains valid until `exp` plus this duration,
  /// and becomes valid this duration before `nbf`.
  final Duration clockSkewTolerance;

  /// Function to parse claims from JSON
  final TClaims Function(Map<String, dynamic>) _parseClaimsFromJson;

  /// JSON Web Key Store for verification
  late final JsonWebKeyStore _keyStore;

  @override
  Future<AuthenticationResult<TClaims>> authenticate(Request request) async {
    try {
      // Extract Bearer token from Authorization header
      final authHeader = request.headers['authorization'];
      if (authHeader == null) {
        return AuthenticationResult.failure('Missing authorization header');
      }

      if (!authHeader.startsWith('Bearer ')) {
        return AuthenticationResult.failure('Invalid token format');
      }

      final token = authHeader.substring(7).trim();

      // Parse and verify JWT
      JsonWebToken jwt;
      try {
        jwt = JsonWebToken.unverified(token);

        // Verify signature
        final verified = await jwt.verify(_keyStore);
        if (!verified) {
          return AuthenticationResult.failure('Invalid token signature');
        }
      } on JoseException catch (e) {
        // Sanitize error message to avoid leaking token data
        var errorMsg = e.message;
        // Remove any quoted strings that might be tokens
        errorMsg = errorMsg.replaceAll(RegExp('"[^"]*"'), '"[REDACTED]"');
        return AuthenticationResult.failure(
          'Token verification failed: $errorMsg',
        );
      } on Exception catch (e) {
        // Sanitize error message to avoid leaking token data
        var errorMsg = e.toString();
        // Remove any token-like strings (base64url patterns)
        errorMsg = errorMsg.replaceAll(
          RegExp('[A-Za-z0-9_-]{20,}'),
          '[REDACTED]',
        );
        return AuthenticationResult.failure(
          'Token verification failed: $errorMsg',
        );
      }

      // Verify issuer if configured
      if (issuer != null) {
        final tokenIssuer = jwt.claims['iss'] as String?;
        if (tokenIssuer != issuer) {
          return AuthenticationResult.failure('Invalid token issuer');
        }
      }

      // Verify audience if configured
      if (audience != null) {
        final tokenAudience = jwt.claims['aud'];
        // Audience can be a string or array of strings
        if (tokenAudience is String) {
          if (tokenAudience != audience) {
            return AuthenticationResult.failure('Invalid token audience');
          }
        } else if (tokenAudience is List) {
          if (!tokenAudience.contains(audience)) {
            return AuthenticationResult.failure('Invalid token audience');
          }
        } else {
          return AuthenticationResult.failure('Invalid token audience');
        }
      }

      // Validate token lifetime after signature, issuer, and audience so their
      // existing error precedence remains unchanged.
      final now = DateTime.now();
      final expiresAt = jwt.claims.expiry;
      if (expiresAt != null &&
          !now.isBefore(expiresAt.add(clockSkewTolerance))) {
        return AuthenticationResult.failure('Token has expired');
      }

      final notBefore = jwt.claims.notBefore;
      if (notBefore != null && notBefore.isAfter(now.add(clockSkewTolerance))) {
        return AuthenticationResult.failure('Token is not yet valid');
      }

      // Extract user ID from sub claim
      final userId = jwt.claims['sub'] as String?;
      if (userId == null) {
        return AuthenticationResult.failure('Token missing subject');
      }

      // Parse claims using provided callback
      final claims = _parseClaimsFromJson(
        jwt.claims.toJson().cast<String, dynamic>(),
      );

      return AuthenticationResult.success(
        userId: userId,
        claims: claims,
      );
    } catch (e) {
      // Sanitize error message to avoid leaking token data
      var errorMsg = e.toString();
      // Remove any quoted strings that might contain tokens
      errorMsg = errorMsg.replaceAll(RegExp('"[^"]*"'), '"[REDACTED]"');
      // Remove any token-like strings (base64url patterns)
      errorMsg = errorMsg.replaceAll(
        RegExp('[A-Za-z0-9_-]{20,}'),
        '[REDACTED]',
      );
      return AuthenticationResult.failure('Invalid token: $errorMsg');
    }
  }
}
