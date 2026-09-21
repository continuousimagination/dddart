// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inherited_codec_test.dart';

// **************************************************************************
// SerializableGenerator
// **************************************************************************

class InheritedRecordJsonSerializer implements JsonSerializer<InheritedRecord> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  InheritedRecordJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig = defaultConfig ?? const SerializationConfig();

  @override
  Map<String, dynamic> toJson(
    InheritedRecord instance, [
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
        'aggregateId',
        effectiveConfig.fieldRename,
      ): instance.aggregateId
          .toString(),
      if (instance.count != null || effectiveConfig.includeNullFields)
        SerializationUtils.applyFieldRename(
          'count',
          effectiveConfig.fieldRename,
        ): instance.count,
      SerializationUtils.applyFieldRename(
        'eventJson',
        effectiveConfig.fieldRename,
      ): instance.eventJson,
      SerializationUtils.applyFieldRename(
        'eventType',
        effectiveConfig.fieldRename,
      ): instance.eventType,
      SerializationUtils.applyFieldRename('label', effectiveConfig.fieldRename):
          instance.label,
      if (instance.organizationId != null || effectiveConfig.includeNullFields)
        SerializationUtils.applyFieldRename(
          'organizationId',
          effectiveConfig.fieldRename,
        ): instance.organizationId,
      SerializationUtils.applyFieldRename(
        'payload',
        effectiveConfig.fieldRename,
      ): instance.payload,
      if (instance.sessionId != null || effectiveConfig.includeNullFields)
        SerializationUtils.applyFieldRename(
          'sessionId',
          effectiveConfig.fieldRename,
        ): instance.sessionId,
      if (instance.tenantId != null || effectiveConfig.includeNullFields)
        SerializationUtils.applyFieldRename(
          'tenantId',
          effectiveConfig.fieldRename,
        ): instance.tenantId,
      if (instance.userId != null || effectiveConfig.includeNullFields)
        SerializationUtils.applyFieldRename(
          'userId',
          effectiveConfig.fieldRename,
        ): instance.userId,
      SerializationUtils.applyFieldRename(
        'userRoles',
        effectiveConfig.fieldRename,
      ): instance.userRoles,
    };
    return json;
  }

  @override
  InheritedRecord fromJson(dynamic json, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize InheritedRecord from null JSON',
        expectedType: 'InheritedRecord',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'InheritedRecord',
      );
    }
    try {
      return InheritedRecord(
        aggregateId: UuidValue.fromString(
          json[SerializationUtils.applyFieldRename(
                'aggregateId',
                effectiveConfig.fieldRename,
              )]
              as String,
        ),
        count:
            json[SerializationUtils.applyFieldRename(
                  'count',
                  effectiveConfig.fieldRename,
                )]
                as int?,
        eventJson:
            json[SerializationUtils.applyFieldRename(
                  'eventJson',
                  effectiveConfig.fieldRename,
                )]
                as String,
        eventType:
            json[SerializationUtils.applyFieldRename(
                  'eventType',
                  effectiveConfig.fieldRename,
                )]
                as String,
        label:
            json[SerializationUtils.applyFieldRename(
                  'label',
                  effectiveConfig.fieldRename,
                )]
                as String,
        organizationId:
            json[SerializationUtils.applyFieldRename(
                  'organizationId',
                  effectiveConfig.fieldRename,
                )]
                as String?,
        payload:
            json[SerializationUtils.applyFieldRename(
                  'payload',
                  effectiveConfig.fieldRename,
                )]
                as String,
        sessionId:
            json[SerializationUtils.applyFieldRename(
                  'sessionId',
                  effectiveConfig.fieldRename,
                )]
                as String?,
        tenantId:
            json[SerializationUtils.applyFieldRename(
                  'tenantId',
                  effectiveConfig.fieldRename,
                )]
                as String?,
        userId:
            json[SerializationUtils.applyFieldRename(
                  'userId',
                  effectiveConfig.fieldRename,
                )]
                as String?,
        userRoles:
            (json[SerializationUtils.applyFieldRename(
                      'userRoles',
                      effectiveConfig.fieldRename,
                    )]
                    as List)
                .map((item) => item as String)
                .toList(),
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
        'Failed to deserialize InheritedRecord: $e',
        expectedType: 'InheritedRecord',
      );
    }
  }

  @override
  String serialize(InheritedRecord object, [dynamic config]) {
    return jsonEncode(toJson(object, config as SerializationConfig?));
  }

  @override
  InheritedRecord deserialize(String data, [dynamic config]) {
    final json = jsonDecode(data);
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected JSON object but got ${json.runtimeType}',
        expectedType: 'InheritedRecord',
      );
    }
    return fromJson(json, config as SerializationConfig?);
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    InheritedRecord instance, [
    SerializationConfig? config,
  ]) {
    return InheritedRecordJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static InheritedRecord decode(dynamic json, [SerializationConfig? config]) {
    return InheritedRecordJsonSerializer().fromJson(json, config);
  }
}
