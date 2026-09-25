// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_token_subtype_test.dart';

// **************************************************************************
// SerializableGenerator
// **************************************************************************

class CustomRefreshTokenJsonSerializer
    implements JsonSerializer<CustomRefreshToken> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  CustomRefreshTokenJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig =
          defaultConfig ??
          const SerializationConfig(
            fieldRename: FieldRename.none,
            includeNullFields: false,
          );

  @override
  Map<String, dynamic> toJson(
    CustomRefreshToken instance, [
    SerializationConfig? config,
  ]) {
    final effectiveConfig = config ?? _defaultConfig;
    final json = <String, dynamic>{
      SerializationUtils.applyFieldRename('id', effectiveConfig.fieldRename):
          instance.id.toString(),
      SerializationUtils.applyFieldRename(
        'createdAt',
        effectiveConfig.fieldRename,
      ): instance.createdAt
          .toIso8601String(),
      SerializationUtils.applyFieldRename(
        'updatedAt',
        effectiveConfig.fieldRename,
      ): instance.updatedAt
          .toIso8601String(),
      if (instance.deviceInfo != null || effectiveConfig.includeNullFields)
        SerializationUtils.applyFieldRename(
          'deviceInfo',
          effectiveConfig.fieldRename,
        ): instance.deviceInfo,
      SerializationUtils.applyFieldRename(
        'expiresAt',
        effectiveConfig.fieldRename,
      ): instance.expiresAt
          .toIso8601String(),
      SerializationUtils.applyFieldRename(
        'revoked',
        effectiveConfig.fieldRename,
      ): instance.revoked,
      SerializationUtils.applyFieldRename(
        'storagePartition',
        effectiveConfig.fieldRename,
      ): instance.storagePartition,
      SerializationUtils.applyFieldRename('token', effectiveConfig.fieldRename):
          instance.token,
      SerializationUtils.applyFieldRename(
        'userId',
        effectiveConfig.fieldRename,
      ): instance.userId,
    };
    return json;
  }

  @override
  CustomRefreshToken fromJson(dynamic json, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize CustomRefreshToken from null JSON',
        expectedType: 'CustomRefreshToken',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'CustomRefreshToken',
      );
    }
    try {
      return CustomRefreshToken(
        deviceInfo:
            json[SerializationUtils.applyFieldRename(
                  'deviceInfo',
                  effectiveConfig.fieldRename,
                )]
                as String?,
        expiresAt: DateTime.parse(
          json[SerializationUtils.applyFieldRename(
                'expiresAt',
                effectiveConfig.fieldRename,
              )]
              as String,
        ),
        revoked:
            json[SerializationUtils.applyFieldRename(
                  'revoked',
                  effectiveConfig.fieldRename,
                )]
                as bool,
        storagePartition:
            json[SerializationUtils.applyFieldRename(
                  'storagePartition',
                  effectiveConfig.fieldRename,
                )]
                as String,
        token:
            json[SerializationUtils.applyFieldRename(
                  'token',
                  effectiveConfig.fieldRename,
                )]
                as String,
        userId:
            json[SerializationUtils.applyFieldRename(
                  'userId',
                  effectiveConfig.fieldRename,
                )]
                as String,
        id: UuidValue.fromString(
          json[SerializationUtils.applyFieldRename(
                'id',
                effectiveConfig.fieldRename,
              )]
              as String,
        ),
        createdAt: DateTime.parse(
          json[SerializationUtils.applyFieldRename(
                'createdAt',
                effectiveConfig.fieldRename,
              )]
              as String,
        ),
        updatedAt: DateTime.parse(
          json[SerializationUtils.applyFieldRename(
                'updatedAt',
                effectiveConfig.fieldRename,
              )]
              as String,
        ),
      );
    } catch (e) {
      throw DeserializationException(
        'Failed to deserialize CustomRefreshToken',
        expectedType: 'CustomRefreshToken',
      );
    }
  }

  @override
  String serialize(CustomRefreshToken object, [dynamic config]) {
    try {
      return jsonEncode(toJson(object, config as SerializationConfig?));
    } catch (_) {
      throw SerializationException(
        'Failed to serialize CustomRefreshToken',
        expectedType: 'CustomRefreshToken',
      );
    }
  }

  @override
  CustomRefreshToken deserialize(String data, [dynamic config]) {
    try {
      final json = jsonDecode(data);
      if (json is! Map<String, dynamic>) {
        throw DeserializationException(
          'Expected JSON object',
          expectedType: 'CustomRefreshToken',
        );
      }
      return fromJson(json, config as SerializationConfig?);
    } on DeserializationException {
      rethrow;
    } catch (_) {
      throw DeserializationException(
        'Failed to deserialize JSON',
        expectedType: 'CustomRefreshToken',
      );
    }
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    CustomRefreshToken instance, [
    SerializationConfig? config,
  ]) {
    return CustomRefreshTokenJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static CustomRefreshToken decode(
    dynamic json, [
    SerializationConfig? config,
  ]) {
    return CustomRefreshTokenJsonSerializer().fromJson(json, config);
  }
}

class CustomDeviceCodeJsonSerializer
    implements JsonSerializer<CustomDeviceCode> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  CustomDeviceCodeJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig =
          defaultConfig ??
          const SerializationConfig(
            fieldRename: FieldRename.none,
            includeNullFields: false,
          );

  @override
  Map<String, dynamic> toJson(
    CustomDeviceCode instance, [
    SerializationConfig? config,
  ]) {
    final effectiveConfig = config ?? _defaultConfig;
    final json = <String, dynamic>{
      SerializationUtils.applyFieldRename('id', effectiveConfig.fieldRename):
          instance.id.toString(),
      SerializationUtils.applyFieldRename(
        'createdAt',
        effectiveConfig.fieldRename,
      ): instance.createdAt
          .toIso8601String(),
      SerializationUtils.applyFieldRename(
        'updatedAt',
        effectiveConfig.fieldRename,
      ): instance.updatedAt
          .toIso8601String(),
      SerializationUtils.applyFieldRename(
        'clientId',
        effectiveConfig.fieldRename,
      ): instance.clientId,
      SerializationUtils.applyFieldRename(
        'deviceCode',
        effectiveConfig.fieldRename,
      ): instance.deviceCode,
      SerializationUtils.applyFieldRename(
        'expiresAt',
        effectiveConfig.fieldRename,
      ): instance.expiresAt
          .toIso8601String(),
      SerializationUtils.applyFieldRename(
        'status',
        effectiveConfig.fieldRename,
      ): instance.status.name,
      SerializationUtils.applyFieldRename(
        'userCode',
        effectiveConfig.fieldRename,
      ): instance.userCode,
      if (instance.userId != null || effectiveConfig.includeNullFields)
        SerializationUtils.applyFieldRename(
          'userId',
          effectiveConfig.fieldRename,
        ): instance.userId,
      SerializationUtils.applyFieldRename(
        'verificationChannel',
        effectiveConfig.fieldRename,
      ): instance.verificationChannel,
    };
    return json;
  }

  @override
  CustomDeviceCode fromJson(dynamic json, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize CustomDeviceCode from null JSON',
        expectedType: 'CustomDeviceCode',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'CustomDeviceCode',
      );
    }
    try {
      return CustomDeviceCode(
        clientId:
            json[SerializationUtils.applyFieldRename(
                  'clientId',
                  effectiveConfig.fieldRename,
                )]
                as String,
        deviceCode:
            json[SerializationUtils.applyFieldRename(
                  'deviceCode',
                  effectiveConfig.fieldRename,
                )]
                as String,
        expiresAt: DateTime.parse(
          json[SerializationUtils.applyFieldRename(
                'expiresAt',
                effectiveConfig.fieldRename,
              )]
              as String,
        ),
        status: DeviceCodeStatus.values.byName(
          json[SerializationUtils.applyFieldRename(
                'status',
                effectiveConfig.fieldRename,
              )]
              as String,
        ),
        userCode:
            json[SerializationUtils.applyFieldRename(
                  'userCode',
                  effectiveConfig.fieldRename,
                )]
                as String,
        userId:
            json[SerializationUtils.applyFieldRename(
                  'userId',
                  effectiveConfig.fieldRename,
                )]
                as String?,
        verificationChannel:
            json[SerializationUtils.applyFieldRename(
                  'verificationChannel',
                  effectiveConfig.fieldRename,
                )]
                as String,
        id: UuidValue.fromString(
          json[SerializationUtils.applyFieldRename(
                'id',
                effectiveConfig.fieldRename,
              )]
              as String,
        ),
        createdAt: DateTime.parse(
          json[SerializationUtils.applyFieldRename(
                'createdAt',
                effectiveConfig.fieldRename,
              )]
              as String,
        ),
        updatedAt: DateTime.parse(
          json[SerializationUtils.applyFieldRename(
                'updatedAt',
                effectiveConfig.fieldRename,
              )]
              as String,
        ),
      );
    } catch (e) {
      throw DeserializationException(
        'Failed to deserialize CustomDeviceCode',
        expectedType: 'CustomDeviceCode',
      );
    }
  }

  @override
  String serialize(CustomDeviceCode object, [dynamic config]) {
    try {
      return jsonEncode(toJson(object, config as SerializationConfig?));
    } catch (_) {
      throw SerializationException(
        'Failed to serialize CustomDeviceCode',
        expectedType: 'CustomDeviceCode',
      );
    }
  }

  @override
  CustomDeviceCode deserialize(String data, [dynamic config]) {
    try {
      final json = jsonDecode(data);
      if (json is! Map<String, dynamic>) {
        throw DeserializationException(
          'Expected JSON object',
          expectedType: 'CustomDeviceCode',
        );
      }
      return fromJson(json, config as SerializationConfig?);
    } on DeserializationException {
      rethrow;
    } catch (_) {
      throw DeserializationException(
        'Failed to deserialize JSON',
        expectedType: 'CustomDeviceCode',
      );
    }
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    CustomDeviceCode instance, [
    SerializationConfig? config,
  ]) {
    return CustomDeviceCodeJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static CustomDeviceCode decode(dynamic json, [SerializationConfig? config]) {
    return CustomDeviceCodeJsonSerializer().fromJson(json, config);
  }
}
