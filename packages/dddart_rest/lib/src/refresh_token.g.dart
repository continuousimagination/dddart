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
    return JsonSerializer.encodeValue(() {
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
              'deviceInfo', effectiveConfig.fieldRename): instance.deviceInfo,
        SerializationUtils.applyFieldRename(
                'expiresAt', effectiveConfig.fieldRename):
            instance.expiresAt.toIso8601String(),
        SerializationUtils.applyFieldRename(
            'revoked', effectiveConfig.fieldRename): instance.revoked,
        SerializationUtils.applyFieldRename(
            'token', effectiveConfig.fieldRename): instance.token,
        SerializationUtils.applyFieldRename(
            'userId', effectiveConfig.fieldRename): instance.userId,
      };
      return json;
    }, expectedType: 'RefreshToken');
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
    return RefreshToken(
      deviceInfo: JsonSerializer.readValue(
          () => json[SerializationUtils.applyFieldRename(
                      'deviceInfo', effectiveConfig.fieldRename)] !=
                  null
              ? json[SerializationUtils.applyFieldRename(
                  'deviceInfo', effectiveConfig.fieldRename)] as String
              : null,
          expectedType: 'RefreshToken',
          field: 'deviceInfo',
          message: 'Failed to deserialize RefreshToken'),
      expiresAt: JsonSerializer.readValue(
          () => DateTime.parse(json[SerializationUtils.applyFieldRename(
              'expiresAt', effectiveConfig.fieldRename)] as String),
          expectedType: 'RefreshToken',
          field: 'expiresAt',
          message: 'Failed to deserialize RefreshToken'),
      revoked: JsonSerializer.readValue(
          () => json[SerializationUtils.applyFieldRename(
              'revoked', effectiveConfig.fieldRename)] as bool,
          expectedType: 'RefreshToken',
          field: 'revoked',
          message: 'Failed to deserialize RefreshToken'),
      token: JsonSerializer.readValue(
          () => json[SerializationUtils.applyFieldRename(
              'token', effectiveConfig.fieldRename)] as String,
          expectedType: 'RefreshToken',
          field: 'token',
          message: 'Failed to deserialize RefreshToken'),
      userId: JsonSerializer.readValue(
          () => json[SerializationUtils.applyFieldRename(
              'userId', effectiveConfig.fieldRename)] as String,
          expectedType: 'RefreshToken',
          field: 'userId',
          message: 'Failed to deserialize RefreshToken'),
      id: JsonSerializer.readValue(
          () => const UuidIdentityCodec().fromJson(json[
              SerializationUtils.applyFieldRename(
                  'id', effectiveConfig.fieldRename)]),
          expectedType: 'RefreshToken',
          field: 'id',
          message: 'Failed to deserialize RefreshToken'),
      createdAt: JsonSerializer.readValue(
          () => json[SerializationUtils.applyFieldRename(
                      'createdAt', effectiveConfig.fieldRename)] !=
                  null
              ? DateTime.parse(json[SerializationUtils.applyFieldRename(
                  'createdAt', effectiveConfig.fieldRename)] as String)
              : DateTime.now(),
          expectedType: 'RefreshToken',
          field: 'createdAt',
          message: 'Failed to deserialize RefreshToken'),
      updatedAt: JsonSerializer.readValue(
          () => json[SerializationUtils.applyFieldRename(
                      'updatedAt', effectiveConfig.fieldRename)] !=
                  null
              ? DateTime.parse(json[SerializationUtils.applyFieldRename(
                  'updatedAt', effectiveConfig.fieldRename)] as String)
              : DateTime.now(),
          expectedType: 'RefreshToken',
          field: 'updatedAt',
          message: 'Failed to deserialize RefreshToken'),
    );
  }

  @override
  String serialize(RefreshToken object, [SerializationConfig? config]) {
    return JsonSerializer.encodeValue(() => jsonEncode(toJson(object, config)),
        expectedType: 'RefreshToken');
  }

  @override
  RefreshToken deserialize(String data, [SerializationConfig? config]) {
    final json = JsonSerializer.readValue(() => jsonDecode(data),
        expectedType: 'RefreshToken', message: 'Failed to deserialize JSON');
    return fromJson(json, config);
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
