import 'package:meta/meta.dart';

/// Annotation to mark classes as JWT-serializable claims.
///
/// Classes annotated with `@JwtSerializable()` have convenience extension
/// methods generated on a compatible `JwtAuthHandler` for converting claims
/// to and from JSON. These helpers are not wired into the handler constructor
/// automatically; applications must still provide the handler's claims loader,
/// parser, and serializer callbacks explicitly.
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
///
///   factory UserClaims.fromJson(Map<String, dynamic> json) => UserClaims(
///     userId: json['userId'] as String,
///     email: json['email'] as String,
///     roles: (json['roles'] as List<dynamic>).cast<String>(),
///   );
///
///   Map<String, dynamic> toJson() => {
///     'userId': userId,
///     'email': email,
///     'roles': roles,
///   };
/// }
///
/// // After running: dart run build_runner build
/// // Convenience extension methods are generated for existing handlers.
///
/// final authHandler = JwtAuthHandler<UserClaims, RefreshToken>(
///   secret: 'secret',
///   refreshTokenRepository: repo,
///   claimsLoader: loadCurrentUserClaims,
///   parseClaimsFromJson: UserClaims.fromJson,
///   claimsToJson: (claims) => claims.toJson(),
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
