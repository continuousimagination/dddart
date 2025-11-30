import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

/// Refresh token for maintaining long-lived sessions
///
/// Refresh tokens are opaque, long-lived tokens stored in a repository
/// that can be exchanged for new access tokens without re-authentication.
///
/// Note: RefreshToken extends AggregateRoot for persistence convenience,
/// but it is an infrastructure concern, not a domain concept. The Repository
/// pattern is used here as a general-purpose persistence abstraction.
@Serializable()
class RefreshToken extends AggregateRoot {
  /// Creates a refresh token
  RefreshToken({
    required super.id,
    required this.userId,
    required this.token,
    required this.expiresAt,
    this.revoked = false,
    this.deviceInfo,
    super.createdAt,
    super.updatedAt,
  });

  /// User ID this token belongs to
  final String userId;

  /// The actual token string (random, opaque)
  final String token;

  /// When this token expires
  final DateTime expiresAt;

  /// Whether this token has been revoked
  final bool revoked;

  /// Optional device information (e.g., "CLI v1.0", "Chrome on MacOS")
  final String? deviceInfo;

  /// Checks if token is currently valid
  bool get isValid => !revoked && expiresAt.isAfter(DateTime.now());

  /// Creates a revoked copy of this token
  RefreshToken revoke() {
    return RefreshToken(
      id: id,
      userId: userId,
      token: token,
      expiresAt: expiresAt,
      revoked: true,
      deviceInfo: deviceInfo,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
