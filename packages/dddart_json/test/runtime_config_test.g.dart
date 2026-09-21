// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'runtime_config_test.dart';

// **************************************************************************
// SerializableGenerator
// **************************************************************************

class FlexibleUserJsonSerializer implements JsonSerializer<FlexibleUser> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  FlexibleUserJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig = defaultConfig ?? const SerializationConfig();

  @override
  Map<String, dynamic> toJson(
    FlexibleUser instance, [
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
        'emailAddress',
        effectiveConfig.fieldRename,
      ): instance.emailAddress,
      SerializationUtils.applyFieldRename(
        'firstName',
        effectiveConfig.fieldRename,
      ): instance.firstName,
      SerializationUtils.applyFieldRename(
        'lastName',
        effectiveConfig.fieldRename,
      ): instance.lastName,
    };
    return json;
  }

  @override
  FlexibleUser fromJson(dynamic json, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize FlexibleUser from null JSON',
        expectedType: 'FlexibleUser',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'FlexibleUser',
      );
    }
    try {
      return FlexibleUser(
        emailAddress:
            json[SerializationUtils.applyFieldRename(
                  'emailAddress',
                  effectiveConfig.fieldRename,
                )]
                as String,
        firstName:
            json[SerializationUtils.applyFieldRename(
                  'firstName',
                  effectiveConfig.fieldRename,
                )]
                as String,
        lastName:
            json[SerializationUtils.applyFieldRename(
                  'lastName',
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
        createdAt:
            json[SerializationUtils.applyFieldRename(
                  'createdAt',
                  effectiveConfig.fieldRename,
                )] !=
                null
            ? DateTime.parse(
                json[SerializationUtils.applyFieldRename(
                      'createdAt',
                      effectiveConfig.fieldRename,
                    )]
                    as String,
              )
            : DateTime.now(),
        updatedAt:
            json[SerializationUtils.applyFieldRename(
                  'updatedAt',
                  effectiveConfig.fieldRename,
                )] !=
                null
            ? DateTime.parse(
                json[SerializationUtils.applyFieldRename(
                      'updatedAt',
                      effectiveConfig.fieldRename,
                    )]
                    as String,
              )
            : DateTime.now(),
      );
    } catch (e, stackTrace) {
      throw DeserializationException(
        'Failed to deserialize FlexibleUser',
        expectedType: 'FlexibleUser',
      );
    }
  }

  @override
  String serialize(FlexibleUser object, [dynamic config]) {
    try {
      return jsonEncode(toJson(object, config as SerializationConfig?));
    } catch (_) {
      throw SerializationException(
        'Failed to serialize FlexibleUser',
        expectedType: 'FlexibleUser',
      );
    }
  }

  @override
  FlexibleUser deserialize(String data, [dynamic config]) {
    try {
      final json = jsonDecode(data);
      if (json is! Map<String, dynamic>) {
        throw DeserializationException(
          'Expected JSON object',
          expectedType: 'FlexibleUser',
        );
      }
      return fromJson(json, config as SerializationConfig?);
    } on DeserializationException {
      rethrow;
    } catch (_) {
      throw DeserializationException(
        'Invalid JSON input',
        expectedType: 'FlexibleUser',
      );
    }
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    FlexibleUser instance, [
    SerializationConfig? config,
  ]) {
    return FlexibleUserJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static FlexibleUser decode(dynamic json, [SerializationConfig? config]) {
    return FlexibleUserJsonSerializer().fromJson(json, config);
  }
}
