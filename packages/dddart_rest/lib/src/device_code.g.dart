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
              'userId', effectiveConfig.fieldRename): instance.userId,
      };
      return json;
    }, expectedType: 'DeviceCode');
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
    return DeviceCode(
      clientId: JsonSerializer.readValue(
          () => json[SerializationUtils.applyFieldRename(
              'clientId', effectiveConfig.fieldRename)] as String,
          expectedType: 'DeviceCode',
          field: 'clientId',
          message: 'Failed to deserialize DeviceCode'),
      deviceCode: JsonSerializer.readValue(
          () => json[SerializationUtils.applyFieldRename(
              'deviceCode', effectiveConfig.fieldRename)] as String,
          expectedType: 'DeviceCode',
          field: 'deviceCode',
          message: 'Failed to deserialize DeviceCode'),
      expiresAt: JsonSerializer.readValue(
          () => DateTime.parse(json[SerializationUtils.applyFieldRename(
              'expiresAt', effectiveConfig.fieldRename)] as String),
          expectedType: 'DeviceCode',
          field: 'expiresAt',
          message: 'Failed to deserialize DeviceCode'),
      status: JsonSerializer.readValue(
          () => JsonSerializer.readEnum(
              DeviceCodeStatus.values,
              json[SerializationUtils.applyFieldRename(
                  'status', effectiveConfig.fieldRename)]),
          expectedType: 'DeviceCode',
          field: 'status',
          message: 'Failed to deserialize DeviceCode'),
      userCode: JsonSerializer.readValue(
          () => json[SerializationUtils.applyFieldRename(
              'userCode', effectiveConfig.fieldRename)] as String,
          expectedType: 'DeviceCode',
          field: 'userCode',
          message: 'Failed to deserialize DeviceCode'),
      userId: JsonSerializer.readValue(
          () => json[SerializationUtils.applyFieldRename(
                      'userId', effectiveConfig.fieldRename)] !=
                  null
              ? json[SerializationUtils.applyFieldRename(
                  'userId', effectiveConfig.fieldRename)] as String
              : null,
          expectedType: 'DeviceCode',
          field: 'userId',
          message: 'Failed to deserialize DeviceCode'),
      id: JsonSerializer.readValue(
          () => const UuidIdentityCodec().fromJson(json[
              SerializationUtils.applyFieldRename(
                  'id', effectiveConfig.fieldRename)]),
          expectedType: 'DeviceCode',
          field: 'id',
          message: 'Failed to deserialize DeviceCode'),
      createdAt: JsonSerializer.readValue(
          () => json[SerializationUtils.applyFieldRename(
                      'createdAt', effectiveConfig.fieldRename)] !=
                  null
              ? DateTime.parse(json[SerializationUtils.applyFieldRename(
                  'createdAt', effectiveConfig.fieldRename)] as String)
              : DateTime.now(),
          expectedType: 'DeviceCode',
          field: 'createdAt',
          message: 'Failed to deserialize DeviceCode'),
      updatedAt: JsonSerializer.readValue(
          () => json[SerializationUtils.applyFieldRename(
                      'updatedAt', effectiveConfig.fieldRename)] !=
                  null
              ? DateTime.parse(json[SerializationUtils.applyFieldRename(
                  'updatedAt', effectiveConfig.fieldRename)] as String)
              : DateTime.now(),
          expectedType: 'DeviceCode',
          field: 'updatedAt',
          message: 'Failed to deserialize DeviceCode'),
    );
  }

  @override
  String serialize(DeviceCode object, [SerializationConfig? config]) {
    return JsonSerializer.encodeValue(() => jsonEncode(toJson(object, config)),
        expectedType: 'DeviceCode');
  }

  @override
  DeviceCode deserialize(String data, [SerializationConfig? config]) {
    final json = JsonSerializer.readValue(() => jsonDecode(data),
        expectedType: 'DeviceCode', message: 'Failed to deserialize JSON');
    return fromJson(json, config);
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
