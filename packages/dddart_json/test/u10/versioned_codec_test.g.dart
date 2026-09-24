// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'versioned_codec_test.dart';

// **************************************************************************
// SerializableGenerator
// **************************************************************************

class VersionedRecordJsonSerializer implements JsonSerializer<VersionedRecord> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  VersionedRecordJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig =
          defaultConfig ??
          const SerializationConfig(
            fieldRename: FieldRename.none,
            includeNullFields: false,
          );

  @override
  Map<String, dynamic> toJson(
    VersionedRecord instance, [
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
      SerializationUtils.applyFieldRename('label', effectiveConfig.fieldRename):
          instance.label,
      SerializationUtils.applyFieldRename(
        'revision',
        effectiveConfig.fieldRename,
      ): instance.revision.value,
    };
    return json;
  }

  @override
  VersionedRecord fromJson(dynamic json, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize VersionedRecord from null JSON',
        expectedType: 'VersionedRecord',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'VersionedRecord',
      );
    }
    try {
      return VersionedRecord(
        label:
            json[SerializationUtils.applyFieldRename(
                  'label',
                  effectiveConfig.fieldRename,
                )]
                as String,
        revision: domain.Revision.fromJson(
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
        'Failed to deserialize VersionedRecord',
        expectedType: 'VersionedRecord',
      );
    }
  }

  @override
  String serialize(VersionedRecord object, [dynamic config]) {
    try {
      return jsonEncode(toJson(object, config as SerializationConfig?));
    } catch (_) {
      throw SerializationException(
        'Failed to serialize VersionedRecord',
        expectedType: 'VersionedRecord',
      );
    }
  }

  @override
  VersionedRecord deserialize(String data, [dynamic config]) {
    try {
      final json = jsonDecode(data);
      if (json is! Map<String, dynamic>) {
        throw DeserializationException(
          'Expected JSON object',
          expectedType: 'VersionedRecord',
        );
      }
      return fromJson(json, config as SerializationConfig?);
    } on DeserializationException {
      rethrow;
    } catch (_) {
      throw DeserializationException(
        'Failed to deserialize JSON',
        expectedType: 'VersionedRecord',
      );
    }
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    VersionedRecord instance, [
    SerializationConfig? config,
  ]) {
    return VersionedRecordJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static VersionedRecord decode(dynamic json, [SerializationConfig? config]) {
    return VersionedRecordJsonSerializer().fromJson(json, config);
  }
}
