import 'package:dddart_rest/src/jwt_auth_handler.dart';
import 'package:dddart_rest/src/jwt_serializable_annotation.dart';

part 'standard_claims.g.dart';

/// Standard JWT claims for simple authentication scenarios
///
/// Provides basic user identity claims without requiring custom claim classes.
/// For applications with custom claims, define your own claims class and
/// annotate it with @JwtSerializable().
@JwtSerializable()
class StandardClaims {
  /// Creates standard claims
  const StandardClaims({
    required this.sub,
    this.email,
    this.name,
  });

  /// Creates standard claims from JSON
  factory StandardClaims.fromJson(Map<String, dynamic> json) {
    return StandardClaims(
      sub: json['sub'] as String,
      email: json['email'] as String?,
      name: json['name'] as String?,
    );
  }

  /// Subject (user ID)
  final String sub;

  /// User email address
  final String? email;

  /// User display name
  final String? name;

  /// Converts standard claims to JSON
  Map<String, dynamic> toJson() {
    return {
      'sub': sub,
      if (email != null) 'email': email,
      if (name != null) 'name': name,
    };
  }
}
