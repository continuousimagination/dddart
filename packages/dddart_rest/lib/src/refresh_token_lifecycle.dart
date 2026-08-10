import 'package:dddart/dddart.dart';
import 'package:dddart_rest/src/refresh_token.dart';

/// Constructs and transitions refresh tokens without erasing their type.
///
/// Implementations for custom [RefreshToken] subtypes must preserve all
/// subtype-specific state when [revoke] creates the revoked token.
abstract interface class RefreshTokenLifecycle<T extends RefreshToken> {
  /// Creates a refresh token of type [T].
  T create({
    required UuidValue id,
    required String userId,
    required String token,
    required DateTime expiresAt,
    required String? deviceInfo,
    required DateTime createdAt,
  });

  /// Creates a revoked copy of [current] while preserving its concrete type.
  T revoke(T current, {required DateTime revokedAt});
}

/// Standard lifecycle for the base [RefreshToken] type.
final class StandardRefreshTokenLifecycle
    implements RefreshTokenLifecycle<RefreshToken> {
  /// Creates the standard refresh-token lifecycle.
  const StandardRefreshTokenLifecycle();

  @override
  RefreshToken create({
    required UuidValue id,
    required String userId,
    required String token,
    required DateTime expiresAt,
    required String? deviceInfo,
    required DateTime createdAt,
  }) {
    return RefreshToken(
      id: id,
      userId: userId,
      token: token,
      expiresAt: expiresAt,
      deviceInfo: deviceInfo,
      createdAt: createdAt,
      updatedAt: createdAt,
    );
  }

  @override
  RefreshToken revoke(
    RefreshToken current, {
    required DateTime revokedAt,
  }) {
    return RefreshToken(
      id: current.id,
      userId: current.userId,
      token: current.token,
      expiresAt: current.expiresAt,
      revoked: true,
      deviceInfo: current.deviceInfo,
      createdAt: current.createdAt,
      updatedAt: revokedAt,
    );
  }
}
