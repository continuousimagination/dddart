// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'standard_claims.dart';

// **************************************************************************
// JwtClaimsGenerator
// **************************************************************************

/// Extension methods for JWT claims serialization of StandardClaims
extension JwtAuthHandlerStandardClaimsExtension
    on JwtAuthHandler<StandardClaims, dynamic> {
  /// Parses StandardClaims from JWT payload JSON
  StandardClaims parseClaimsFromJson(Map<String, dynamic> json) {
    return StandardClaims(
      email: json['email'] as String?,
      name: json['name'] as String?,
      sub: json['sub'] as String,
    );
  }

  /// Converts StandardClaims to JWT payload JSON
  Map<String, dynamic> claimsToJson(StandardClaims claims) {
    return {
      if (claims.email != null) 'email': claims.email,
      if (claims.name != null) 'name': claims.name,
      'sub': claims.sub,
    };
  }
}
