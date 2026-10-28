// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'refresh_token.dart';

// **************************************************************************
// SerializableGenerator
// **************************************************************************

class RefreshTokenJsonSerializer implements JsonSerializer<RefreshToken> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;
  final IdentityCodecRegistry _identityCodecs;

  /// Identity codecs shared with nested serializers and composition code.
  IdentityCodecRegistry get identityCodecs => _identityCodecs;

  /// Creates a serializer with the specified default configuration.
  RefreshTokenJsonSerializer([SerializationConfig? defaultConfig])
      : this.withIdentityCodecs(IdentityCodecRegistry(), defaultConfig);

  /// Creates a serializer with explicit, shared identity encodings.
  RefreshTokenJsonSerializer.withIdentityCodecs(this._identityCodecs,
      [SerializationConfig? defaultConfig])
      : _defaultConfig = defaultConfig ??
            const SerializationConfig(
              fieldRename: FieldRename.none,
              includeNullFields: false,
            );

  @override
  Map<String, dynamic> toJson(RefreshToken instance,
      [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    final json = <String, dynamic>{
      SerializationUtils.applyFieldRename('id', effectiveConfig.fieldRename):
          const UuidIdentityCodec().toJson(instance.id),
      SerializationUtils.applyFieldRename(
              'createdAt', effectiveConfig.fieldRename):
          instance.createdAt.toIso8601String(),
      SerializationUtils.applyFieldRename(
              'updatedAt', effectiveConfig.fieldRename):
          instance.updatedAt.toIso8601String(),
      if (instance.deviceInfo != null || effectiveConfig.includeNullFields)
        SerializationUtils.applyFieldRename(
                'deviceInfo', effectiveConfig.fieldRename):
            instance.deviceInfo != null ? instance.deviceInfo! : null,
      SerializationUtils.applyFieldRename(
              'expiresAt', effectiveConfig.fieldRename):
          instance.expiresAt.toIso8601String(),
      SerializationUtils.applyFieldRename(
          'revoked', effectiveConfig.fieldRename): instance.revoked,
      SerializationUtils.applyFieldRename('token', effectiveConfig.fieldRename):
          instance.token,
      SerializationUtils.applyFieldRename(
          'userId', effectiveConfig.fieldRename): instance.userId,
    };
    return json;
  }

  @override
  RefreshToken fromJson(dynamic json, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize RefreshToken from null JSON',
        expectedType: 'RefreshToken',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'RefreshToken',
      );
    }
    try {
      return RefreshToken(
        deviceInfo: json[SerializationUtils.applyFieldRename(
                    'deviceInfo', effectiveConfig.fieldRename)] !=
                null
            ? json[SerializationUtils.applyFieldRename(
                'deviceInfo', effectiveConfig.fieldRename)] as String
            : null,
        expiresAt: DateTime.parse(json[SerializationUtils.applyFieldRename(
            'expiresAt', effectiveConfig.fieldRename)] as String),
        revoked: json[SerializationUtils.applyFieldRename(
            'revoked', effectiveConfig.fieldRename)] as bool,
        token: json[SerializationUtils.applyFieldRename(
            'token', effectiveConfig.fieldRename)] as String,
        userId: json[SerializationUtils.applyFieldRename(
            'userId', effectiveConfig.fieldRename)] as String,
        id: const UuidIdentityCodec().fromJson(json[
            SerializationUtils.applyFieldRename(
                'id', effectiveConfig.fieldRename)]),
        createdAt: json[SerializationUtils.applyFieldRename(
                    'createdAt', effectiveConfig.fieldRename)] !=
                null
            ? DateTime.parse(json[SerializationUtils.applyFieldRename(
                'createdAt', effectiveConfig.fieldRename)] as String)
            : DateTime.now(),
        updatedAt: json[SerializationUtils.applyFieldRename(
                    'updatedAt', effectiveConfig.fieldRename)] !=
                null
            ? DateTime.parse(json[SerializationUtils.applyFieldRename(
                'updatedAt', effectiveConfig.fieldRename)] as String)
            : DateTime.now(),
      );
    } catch (e) {
      throw DeserializationException(
        'Failed to deserialize RefreshToken: $e',
        expectedType: 'RefreshToken',
      );
    }
  }

  @override
  String serialize(RefreshToken object, [dynamic config]) {
    return jsonEncode(toJson(object, config as SerializationConfig?));
  }

  @override
  RefreshToken deserialize(String data, [dynamic config]) {
    try {
      final json = jsonDecode(data);
      if (json is! Map<String, dynamic>) {
        throw DeserializationException(
          'Expected JSON object but got ${json.runtimeType}',
          expectedType: 'RefreshToken',
        );
      }
      return fromJson(json, config as SerializationConfig?);
    } catch (e) {
      if (e is DeserializationException) rethrow;
      throw DeserializationException(
        'Failed to deserialize JSON: $e',
        expectedType: 'RefreshToken',
      );
    }
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(RefreshToken instance,
      [SerializationConfig? config, IdentityCodecRegistry? identityCodecs]) {
    return RefreshTokenJsonSerializer.withIdentityCodecs(
            identityCodecs ?? IdentityCodecRegistry())
        .toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static RefreshToken decode(dynamic json,
      [SerializationConfig? config, IdentityCodecRegistry? identityCodecs]) {
    return RefreshTokenJsonSerializer.withIdentityCodecs(
            identityCodecs ?? IdentityCodecRegistry())
        .fromJson(json, config);
  }
}
