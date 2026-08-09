import 'dart:convert';
import 'dart:math';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:dddart/dddart.dart';
import 'package:dddart_rest/src/authentication_handler.dart';
import 'package:dddart_rest/src/authentication_result.dart';
import 'package:dddart_rest/src/refresh_token.dart';
import 'package:dddart_rest/src/repository_query_support.dart';
import 'package:dddart_rest/src/tokens.dart';
import 'package:shelf/shelf.dart';

/// Loads the current application claims for a validated user ID.
///
/// Returning `null` means the user is missing, disabled, or otherwise no longer
/// eligible to receive tokens. Implementations should read authoritative
/// application state on every call rather than caching claim snapshots.
typedef ApplicationClaimsLoader<TClaims> = Future<TClaims?> Function(
  String userId,
);

/// Handles JWT authentication for self-hosted mode
///
/// Generic over [TClaims] (claims type) and [TRefreshToken] (refresh token type).
/// [TRefreshToken] must extend [RefreshToken] to ensure compatibility.
///
/// Uses callback functions to serialize/deserialize claims. For convenience,
/// you can use generated extension methods by annotating claims classes with
/// @JwtSerializable().
///
/// Example:
/// ```dart
/// final authHandler = JwtAuthHandler<UserClaims, RefreshToken>(
///   secret: 'your-secret-key',
///   refreshTokenRepository: refreshTokenRepo,
///   claimsLoader: (userId) => loadCurrentClaims(userId),
///   parseClaimsFromJson: (json) => UserClaims.fromJson(json),
///   claimsToJson: (claims) => claims.toJson(),
///   issuer: 'https://api.example.com',
///   audience: 'my-app',
/// );
/// ```
class JwtAuthHandler<TClaims, TRefreshToken extends RefreshToken>
    extends AuthenticationHandler<TClaims> {
  /// Creates a JWT authentication handler
  JwtAuthHandler({
    required this.secret,
    required this.refreshTokenRepository,
    required ApplicationClaimsLoader<TClaims> claimsLoader,
    required TClaims Function(Map<String, dynamic>) parseClaimsFromJson,
    required Map<String, dynamic> Function(TClaims) claimsToJson,
    this.issuer,
    this.audience,
    this.accessTokenDuration = const Duration(minutes: 15),
    this.refreshTokenDuration = const Duration(days: 7),
  })  : _claimsLoader = claimsLoader,
        _parseClaimsFromJson = parseClaimsFromJson,
        _claimsToJson = claimsToJson;

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

  /// Loads current application claims for token issuance.
  final ApplicationClaimsLoader<TClaims> _claimsLoader;

  /// Function to parse claims from JSON
  final TClaims Function(Map<String, dynamic>) _parseClaimsFromJson;

  /// Function to convert claims to JSON
  final Map<String, dynamic> Function(TClaims) _claimsToJson;

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

      final token = authHeader.substring(7);

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
      if (userId == null) {
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

  /// Issues new access and refresh tokens for a user
  ///
  /// Loads the user's current application claims, generates a JWT access token
  /// and a random refresh token, and stores the refresh token in the repository.
  ///
  /// Example:
  /// ```dart
  /// final tokens = await authHandler.issueTokens(
  ///   'user123',
  ///   deviceInfo: 'CLI v1.0',
  /// );
  /// ```
  Future<Tokens> issueTokens(
    String userId, {
    String? deviceInfo,
  }) async {
    // Load and sign authoritative application claims before persisting a
    // refresh token. A missing or disabled user therefore receives no tokens.
    final accessToken = await _issueAccessToken(userId);
    final now = DateTime.now();

    // Generate random refresh token
    final refreshTokenString = _generateRefreshToken();
    final refreshTokenExpiration = now.add(refreshTokenDuration);

    // Store refresh token in repository
    final refreshToken = RefreshToken(
      id: UuidValue.generate(),
      userId: userId,
      token: refreshTokenString,
      expiresAt: refreshTokenExpiration,
      deviceInfo: deviceInfo,
    ) as TRefreshToken;

    await refreshTokenRepository.save(refreshToken);

    return Tokens(
      accessToken: accessToken,
      refreshToken: refreshTokenString,
      expiresIn: accessTokenDuration.inSeconds,
    );
  }

  /// Refreshes access token using refresh token
  ///
  /// Looks up the refresh token in the repository, validates it's not expired
  /// or revoked, reloads the user's current application claims, and issues a
  /// new access token. The existing opaque refresh token is returned unchanged.
  ///
  /// Example:
  /// ```dart
  /// final newTokens = await authHandler.refresh('refresh-token-string');
  /// ```
  Future<Tokens> refresh(String refreshTokenString) async {
    // Look up refresh token in repository
    final RefreshToken refreshToken;
    try {
      refreshToken = await findFirstItem(
        refreshTokenRepository,
        (token) => token.token == refreshTokenString,
        operationName: 'refresh token validation',
      );
    } catch (_) {
      throw Exception('Invalid refresh token');
    }

    // Validate not expired
    if (DateTime.now().isAfter(refreshToken.expiresAt)) {
      throw Exception('Refresh token has expired');
    }

    // Validate not revoked
    if (refreshToken.revoked) {
      throw Exception('Refresh token has been revoked');
    }

    // Reload authoritative claims. Refresh never reconstructs claims from an
    // access token or stores an application-claim snapshot.
    final accessToken = await _issueAccessToken(refreshToken.userId);

    return Tokens(
      accessToken: accessToken,
      refreshToken: refreshTokenString,
      expiresIn: accessTokenDuration.inSeconds,
    );
  }

  /// Revokes a refresh token (logout)
  ///
  /// Marks the refresh token as revoked in the repository, preventing it
  /// from being used to obtain new access tokens.
  ///
  /// Example:
  /// ```dart
  /// await authHandler.revoke('refresh-token-string');
  /// ```
  Future<void> revoke(String refreshTokenString) async {
    final refreshTokens = await getAllItems(
      refreshTokenRepository,
      operationName: 'refresh token revocation',
    );
    TRefreshToken? refreshToken;
    for (final token in refreshTokens) {
      if (token.token == refreshTokenString) {
        refreshToken = token;
        break;
      }
    }

    if (refreshToken == null) {
      return;
    }

    // Mark as revoked
    final revokedToken = refreshToken.revoke() as TRefreshToken;
    await refreshTokenRepository.save(revokedToken);
  }

  Future<String> _issueAccessToken(String userId) async {
    final claims = await _claimsLoader(userId);
    if (claims == null) {
      throw Exception('Authentication failed');
    }

    final issuedAt = DateTime.now();
    final payload = _buildAccessTokenPayload(
      userId: userId,
      issuedAt: issuedAt,
      customClaims: _claimsToJson(claims),
    );

    return JWT(payload).sign(SecretKey(secret));
  }

  Map<String, dynamic> _buildAccessTokenPayload({
    required String userId,
    required DateTime issuedAt,
    required Map<String, dynamic> customClaims,
  }) {
    final payload = Map<String, dynamic>.of(customClaims)
      ..remove('sub')
      ..remove('iat')
      ..remove('exp')
      ..remove('iss')
      ..remove('aud')
      ..addAll({
        'sub': userId,
        'iat': issuedAt.millisecondsSinceEpoch ~/ 1000,
        'exp': issuedAt.add(accessTokenDuration).millisecondsSinceEpoch ~/ 1000,
      });

    if (issuer != null) {
      payload['iss'] = issuer;
    }

    if (audience != null) {
      payload['aud'] = audience;
    }

    return payload;
  }

  /// Generates a cryptographically secure random refresh token
  String _generateRefreshToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }
}
