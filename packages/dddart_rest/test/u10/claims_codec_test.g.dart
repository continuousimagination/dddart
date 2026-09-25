// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'claims_codec_test.dart';

// **************************************************************************
// JwtClaimsGenerator
// **************************************************************************

/// Extension methods for JWT claims serialization of MigrationClaims
extension JwtAuthHandlerMigrationClaimsExtension
    on JwtAuthHandler<MigrationClaims, dynamic> {
  /// Parses MigrationClaims from JWT payload JSON
  MigrationClaims parseClaimsFromJson(Map<String, dynamic> json) {
    return MigrationClaims(
      count: json['count'] as int?,
      name: json['name'] as String,
      tags: (json['tags'] as List).map((item) => item as String).toList(),
    );
  }

  /// Converts MigrationClaims to JWT payload JSON
  Map<String, dynamic> claimsToJson(MigrationClaims claims) {
    return {
      if (claims.count != null) 'count': claims.count,
      'name': claims.name,
      'tags': claims.tags,
    };
  }
}
