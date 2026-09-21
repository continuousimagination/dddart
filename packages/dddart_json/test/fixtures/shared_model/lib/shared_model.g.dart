// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shared_model.dart';

// **************************************************************************
// SerializableGenerator
// **************************************************************************

class RemoteRecordJsonSerializer implements JsonSerializer<RemoteRecord> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  RemoteRecordJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig = defaultConfig ?? const SerializationConfig();

  @override
  Map<String, dynamic> toJson(
    RemoteRecord instance, [
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
      SerializationUtils.applyFieldRename('text', effectiveConfig.fieldRename):
          instance.text,
    };
    return json;
  }

  @override
  RemoteRecord fromJson(dynamic json, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize RemoteRecord from null JSON',
        expectedType: 'RemoteRecord',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'RemoteRecord',
      );
    }
    try {
      return RemoteRecord(
        text:
            json[SerializationUtils.applyFieldRename(
                  'text',
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
    } catch (e, stackTrace) {
      throw DeserializationException(
        'Failed to deserialize RemoteRecord',
        expectedType: 'RemoteRecord',
      );
    }
  }

  @override
  String serialize(RemoteRecord object, [dynamic config]) {
    try {
      return jsonEncode(toJson(object, config as SerializationConfig?));
    } catch (_) {
      throw SerializationException(
        'Failed to serialize RemoteRecord',
        expectedType: 'RemoteRecord',
      );
    }
  }

  @override
  RemoteRecord deserialize(String data, [dynamic config]) {
    try {
      final json = jsonDecode(data);
      if (json is! Map<String, dynamic>) {
        throw DeserializationException(
          'Expected JSON object',
          expectedType: 'RemoteRecord',
        );
      }
      return fromJson(json, config as SerializationConfig?);
    } on DeserializationException {
      rethrow;
    } catch (_) {
      throw DeserializationException(
        'Invalid JSON input',
        expectedType: 'RemoteRecord',
      );
    }
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    RemoteRecord instance, [
    SerializationConfig? config,
  ]) {
    return RemoteRecordJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static RemoteRecord decode(dynamic json, [SerializationConfig? config]) {
    return RemoteRecordJsonSerializer().fromJson(json, config);
  }
}
