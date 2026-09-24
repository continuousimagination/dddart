// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'versioned_user.dart';

// **************************************************************************
// SerializableGenerator
// **************************************************************************

class VersionedUserJsonSerializer implements JsonSerializer<VersionedUser> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  VersionedUserJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig =
          defaultConfig ??
          const SerializationConfig(
            fieldRename: FieldRename.none,
            includeNullFields: false,
          );

  @override
  Map<String, dynamic> toJson(
    VersionedUser instance, [
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
      SerializationUtils.applyFieldRename('name', effectiveConfig.fieldRename):
          instance.name,
      SerializationUtils.applyFieldRename(
        'revision',
        effectiveConfig.fieldRename,
      ): instance.revision.value,
    };
    return json;
  }

  @override
  VersionedUser fromJson(dynamic json, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize VersionedUser from null JSON',
        expectedType: 'VersionedUser',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'VersionedUser',
      );
    }
    try {
      return VersionedUser(
        name:
            json[SerializationUtils.applyFieldRename(
                  'name',
                  effectiveConfig.fieldRename,
                )]
                as String,
        revision: Revision.fromJson(
          json[SerializationUtils.applyFieldRename(
            'revision',
            effectiveConfig.fieldRename,
          )],
        ),
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
        'Failed to deserialize VersionedUser',
        expectedType: 'VersionedUser',
      );
    }
  }

  @override
  String serialize(VersionedUser object, [dynamic config]) {
    try {
      return jsonEncode(toJson(object, config as SerializationConfig?));
    } catch (_) {
      throw SerializationException(
        'Failed to serialize VersionedUser',
        expectedType: 'VersionedUser',
      );
    }
  }

  @override
  VersionedUser deserialize(String data, [dynamic config]) {
    try {
      final json = jsonDecode(data);
      if (json is! Map<String, dynamic>) {
        throw DeserializationException(
          'Expected JSON object',
          expectedType: 'VersionedUser',
        );
      }
      return fromJson(json, config as SerializationConfig?);
    } on DeserializationException {
      rethrow;
    } catch (_) {
      throw DeserializationException(
        'Failed to deserialize JSON',
        expectedType: 'VersionedUser',
      );
    }
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    VersionedUser instance, [
    SerializationConfig? config,
  ]) {
    return VersionedUserJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static VersionedUser decode(dynamic json, [SerializationConfig? config]) {
    return VersionedUserJsonSerializer().fromJson(json, config);
  }
}
