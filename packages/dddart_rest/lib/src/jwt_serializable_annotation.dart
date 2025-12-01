import 'package:meta/meta.dart';

/// Annotation to mark classes as JWT-serializable claims.
///
/// Classes annotated with @JwtSerializable() will have extension methods
/// generated on JwtAuthHandler that know how to serialize and deserialize
/// the claims to/from JSON.
///
/// Example:
/// ```dart
/// import 'package:dddart_rest/dddart_rest.dart';
///
/// part 'user_claims.g.dart';
///
/// @JwtSerializable()
/// class UserClaims {
///   const UserClaims({
///     required this.userId,
///     required this.email,
///     this.roles = const [],
///   });
///
///   final String userId;
///   final String email;
///   final List<String> roles;
/// }
///
/// // After running: dart run build_runner build
/// // Extension methods are generated automatically
///
/// // Usage - no manual serialization needed!
/// final authHandler = JwtAuthHandler<UserClaims, RefreshToken>(
///   secret: 'secret',
///   refreshTokenRepository: repo,
/// );
/// ```
@immutable
class JwtSerializable {
  /// Creates a JwtSerializable annotation.
  const JwtSerializable();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is JwtSerializable;
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'JwtSerializable()';
}
