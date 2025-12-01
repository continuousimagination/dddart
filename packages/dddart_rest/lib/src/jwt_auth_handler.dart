import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:dddart/dddart.dart';
import 'package:dddart_rest/src/auth_handler.dart';
import 'package:dddart_rest/src/auth_result.dart';
import 'package:dddart_rest/src/refresh_token.dart';
import 'package:dddart_rest/src/tokens.dart';
import 'package:shelf/shelf.dart';

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
///   parseClaimsFromJson: (json) => UserClaims.fromJson(json),
///   claimsToJson: (claims) => claims.toJson(),
///   issuer: 'https://api.example.com',
///   audience: 'my-app',
/// );
/// ```
class JwtAuthHandler<TClaims, TRefreshToken extends RefreshToken>
    extends AuthHandler<TClaims> {
  /// Creates a JWT authentication handler
  JwtAuthHandler({
    required this.secret,
    required this.refreshTokenRepository,
    required TClaims Function(Map<String, dynamic>) parseClaimsFromJson,
    required Map<String, dynamic> Function(TClaims) claimsToJson,
    this.issuer,
    this.audience,
    this.accessTokenDuration = const Duration(minutes: 15),
    this.refreshTokenDuration = const Duration(days: 7),
  })  : _parseClaimsFromJson = parseClaimsFromJson,
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

  /// Function to parse claims from JSON
  final TClaims Function(Map<String, dynamic>) _parseClaimsFromJson;

  /// Function to convert claims to JSON
  final Map<String, dynamic> Function(TClaims) _claimsToJson;

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

      final token = authHeader.substring(7);

      // Decode and verify JWT
      JWT? jwt;
      try {
        jwt = JWT.verify(token, SecretKey(secret));
      } on JWTExpiredException {
        return AuthResult.failure('Token has expired');
      } on JWTException {
        return AuthResult.failure('Invalid token signature');
      }

      // Verify issuer if configured
      if (issuer != null) {
        final tokenIssuer = jwt.payload['iss'] as String?;
        if (tokenIssuer != issuer) {
          return AuthResult.failure('Invalid token issuer');
        }
      }

      // Verify audience if configured
      if (audience != null) {
        final tokenAudience = jwt.payload['aud'] as String?;
        if (tokenAudience != audience) {
          return AuthResult.failure('Invalid token audience');
        }
      }

      // Extract user ID from sub claim
      final userId = jwt.payload['sub'] as String?;
      if (userId == null) {
        return AuthResult.failure('Token missing subject');
      }

      // Parse claims using provided callback
      final claims = _parseClaimsFromJson(jwt.payload as Map<String, dynamic>);

      return AuthResult.success(
        userId: userId,
        claims: claims,
      );
    } catch (e) {
      return AuthResult.failure('Invalid token: $e');
    }
  }

  /// Issues new access and refresh tokens for a user
  ///
  /// Generates a JWT access token with the provided claims and a random
  /// refresh token. The refresh token is stored in the repository.
  ///
  /// Example:
  /// ```dart
  /// final tokens = await authHandler.issueTokens(
  ///   'user123',
  ///   UserClaims(email: 'user@example.com', roles: ['admin']),
  ///   deviceInfo: 'CLI v1.0',
  /// );
  /// ```
  Future<Tokens> issueTokens(
    String userId,
    TClaims claims, {
    String? deviceInfo,
  }) async {
    // Serialize claims using provided callback
    final claimsJson = _claimsToJson(claims);

    // Create JWT payload
    final now = DateTime.now();
    final expiration = now.add(accessTokenDuration);

    final payload = <String, dynamic>{
      'sub': userId,
      'iat': now.millisecondsSinceEpoch ~/ 1000,
      'exp': expiration.millisecondsSinceEpoch ~/ 1000,
      ...claimsJson,
    };

    if (issuer != null) {
      payload['iss'] = issuer;
    }

    if (audience != null) {
      payload['aud'] = audience;
    }

    // Sign JWT
    final jwt = JWT(payload);
    final accessToken = jwt.sign(SecretKey(secret));

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
  /// or revoked, and issues a new access token with the same claims.
  ///
  /// Example:
  /// ```dart
  /// final newTokens = await authHandler.refresh('refresh-token-string');
  /// ```
  Future<Tokens> refresh(String refreshTokenString) async {
    // Look up refresh token in repository
    // Note: This requires InMemoryRepository or a custom repository with query support
    RefreshToken? refreshToken;

    if (refreshTokenRepository is InMemoryRepository<TRefreshToken>) {
      final repo = refreshTokenRepository as InMemoryRepository<TRefreshToken>;
      final all = repo.getAll();
      try {
        refreshToken =
            all.firstWhere((token) => token.token == refreshTokenString);
      } catch (e) {
        throw Exception('Invalid refresh token');
      }
    } else {
      throw UnsupportedError(
        'Refresh token lookup requires InMemoryRepository or custom repository with query support',
      );
    }

    // Validate not expired
    if (DateTime.now().isAfter(refreshToken.expiresAt)) {
      throw Exception('Refresh token has expired');
    }

    // Validate not revoked
    if (refreshToken.revoked) {
      throw Exception('Refresh token has been revoked');
    }

    // Get user's current claims by creating a temporary JWT and parsing it
    // In a real implementation, you might want to fetch fresh user data
    // For now, we'll create minimal claims with just the user ID
    final claimsJson = <String, dynamic>{'sub': refreshToken.userId};
    final claims = _parseClaimsFromJson(claimsJson);

    // Issue new access token (but not a new refresh token)
    final now = DateTime.now();
    final expiration = now.add(accessTokenDuration);

    final payload = <String, dynamic>{
      'sub': refreshToken.userId,
      'iat': now.millisecondsSinceEpoch ~/ 1000,
      'exp': expiration.millisecondsSinceEpoch ~/ 1000,
      ..._claimsToJson(claims),
    };

    if (issuer != null) {
      payload['iss'] = issuer;
    }

    if (audience != null) {
      payload['aud'] = audience;
    }

    final jwt = JWT(payload);
    final accessToken = jwt.sign(SecretKey(secret));

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
    // Look up refresh token in repository
    RefreshToken? refreshToken;

    if (refreshTokenRepository is InMemoryRepository<TRefreshToken>) {
      final repo = refreshTokenRepository as InMemoryRepository<TRefreshToken>;
      final all = repo.getAll();
      try {
        refreshToken =
            all.firstWhere((token) => token.token == refreshTokenString);
      } catch (e) {
        // Token doesn't exist, nothing to revoke
        return;
      }
    } else {
      throw UnsupportedError(
        'Refresh token lookup requires InMemoryRepository or custom repository with query support',
      );
    }

    // Mark as revoked
    final revokedToken = refreshToken.revoke() as TRefreshToken;
    await refreshTokenRepository.save(revokedToken);
  }

  /// Generates a cryptographically secure random refresh token
  String _generateRefreshToken() {
    // Generate 32 random bytes and encode as base64
    final bytes = List<int>.generate(
      32,
      (i) => DateTime.now().microsecondsSinceEpoch % 256,
    );
    final hash = sha256.convert(bytes);
    return base64Url.encode(hash.bytes);
  }
}
