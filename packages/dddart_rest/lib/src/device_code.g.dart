// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_code.dart';

// **************************************************************************
// SerializableGenerator
// **************************************************************************

class DeviceCodeJsonSerializer implements JsonSerializer<DeviceCode> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;
  final IdentityCodecRegistry _identityCodecs;

  /// Identity codecs shared with nested serializers and composition code.
  IdentityCodecRegistry get identityCodecs => _identityCodecs;

  /// Creates a serializer with the specified default configuration.
  DeviceCodeJsonSerializer([SerializationConfig? defaultConfig])
      : this.withIdentityCodecs(IdentityCodecRegistry(), defaultConfig);

  /// Creates a serializer with explicit, shared identity encodings.
  DeviceCodeJsonSerializer.withIdentityCodecs(this._identityCodecs,
      [SerializationConfig? defaultConfig])
      : _defaultConfig = defaultConfig ??
            const SerializationConfig(
              fieldRename: FieldRename.none,
              includeNullFields: false,
            );

  @override
  Map<String, dynamic> toJson(DeviceCode instance,
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
      SerializationUtils.applyFieldRename(
          'clientId', effectiveConfig.fieldRename): instance.clientId,
      SerializationUtils.applyFieldRename(
          'deviceCode', effectiveConfig.fieldRename): instance.deviceCode,
      SerializationUtils.applyFieldRename(
              'expiresAt', effectiveConfig.fieldRename):
          instance.expiresAt.toIso8601String(),
      SerializationUtils.applyFieldRename(
          'status', effectiveConfig.fieldRename): instance.status.name,
      SerializationUtils.applyFieldRename(
          'userCode', effectiveConfig.fieldRename): instance.userCode,
      if (instance.userId != null || effectiveConfig.includeNullFields)
        SerializationUtils.applyFieldRename(
                'userId', effectiveConfig.fieldRename):
            instance.userId != null ? instance.userId! : null,
    };
    return json;
  }

  @override
  DeviceCode fromJson(dynamic json, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize DeviceCode from null JSON',
        expectedType: 'DeviceCode',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'DeviceCode',
      );
    }
    try {
      return DeviceCode(
        clientId: json[SerializationUtils.applyFieldRename(
            'clientId', effectiveConfig.fieldRename)] as String,
        deviceCode: json[SerializationUtils.applyFieldRename(
            'deviceCode', effectiveConfig.fieldRename)] as String,
        expiresAt: DateTime.parse(json[SerializationUtils.applyFieldRename(
            'expiresAt', effectiveConfig.fieldRename)] as String),
        status: DeviceCodeStatus.values.byName(json[
            SerializationUtils.applyFieldRename(
                'status', effectiveConfig.fieldRename)] as String),
        userCode: json[SerializationUtils.applyFieldRename(
            'userCode', effectiveConfig.fieldRename)] as String,
        userId: json[SerializationUtils.applyFieldRename(
                    'userId', effectiveConfig.fieldRename)] !=
                null
            ? json[SerializationUtils.applyFieldRename(
                'userId', effectiveConfig.fieldRename)] as String
            : null,
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
        'Failed to deserialize DeviceCode: $e',
        expectedType: 'DeviceCode',
      );
    }
  }

  @override
  String serialize(DeviceCode object, [dynamic config]) {
    return jsonEncode(toJson(object, config as SerializationConfig?));
  }

  @override
  DeviceCode deserialize(String data, [dynamic config]) {
    try {
      final json = jsonDecode(data);
      if (json is! Map<String, dynamic>) {
        throw DeserializationException(
          'Expected JSON object but got ${json.runtimeType}',
          expectedType: 'DeviceCode',
        );
      }
      return fromJson(json, config as SerializationConfig?);
    } catch (e) {
      if (e is DeserializationException) rethrow;
      throw DeserializationException(
        'Failed to deserialize JSON: $e',
        expectedType: 'DeviceCode',
      );
    }
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(DeviceCode instance,
      [SerializationConfig? config, IdentityCodecRegistry? identityCodecs]) {
    return DeviceCodeJsonSerializer.withIdentityCodecs(
            identityCodecs ?? IdentityCodecRegistry())
        .toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static DeviceCode decode(dynamic json,
      [SerializationConfig? config, IdentityCodecRegistry? identityCodecs]) {
    return DeviceCodeJsonSerializer.withIdentityCodecs(
            identityCodecs ?? IdentityCodecRegistry())
        .fromJson(json, config);
  }
}
