// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'custom_stored_event.dart';

// **************************************************************************
// SerializableGenerator
// **************************************************************************

class CustomStoredEventJsonSerializer
    implements JsonSerializer<CustomStoredEvent> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  CustomStoredEventJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig = defaultConfig ?? const SerializationConfig();

  @override
  Map<String, dynamic> toJson(
    CustomStoredEvent instance, [
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
      SerializationUtils.applyFieldRename(
        'eventJson',
        effectiveConfig.fieldRename,
      ): instance.eventJson,
      SerializationUtils.applyFieldRename(
        'eventType',
        effectiveConfig.fieldRename,
      ): instance.eventType,
      if (instance.organizationId != null || effectiveConfig.includeNullFields)
        SerializationUtils.applyFieldRename(
          'organizationId',
          effectiveConfig.fieldRename,
        ): instance.organizationId,
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
      if (instance.userRoles != null || effectiveConfig.includeNullFields)
        SerializationUtils.applyFieldRename(
          'userRoles',
          effectiveConfig.fieldRename,
        ): instance.userRoles != null
            ? instance.userRoles!
            : null,
    };
    return json;
  }

  @override
  CustomStoredEvent fromJson(dynamic json, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize CustomStoredEvent from null JSON',
        expectedType: 'CustomStoredEvent',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'CustomStoredEvent',
      );
    }
    try {
      return CustomStoredEvent(
        aggregateId: UuidValue.fromString(
          json[SerializationUtils.applyFieldRename(
                'aggregateId',
                effectiveConfig.fieldRename,
              )]
              as String,
        ),
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
        organizationId:
            json[SerializationUtils.applyFieldRename(
                  'organizationId',
                  effectiveConfig.fieldRename,
                )]
                as String?,
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
            json[SerializationUtils.applyFieldRename(
                  'userRoles',
                  effectiveConfig.fieldRename,
                )] !=
                null
            ? (json[SerializationUtils.applyFieldRename(
                        'userRoles',
                        effectiveConfig.fieldRename,
                      )]
                      as List)
                  .map((item) => item as String)
                  .toList()
            : null,
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
        'Failed to deserialize CustomStoredEvent: $e',
        expectedType: 'CustomStoredEvent',
      );
    }
  }

  @override
  String serialize(CustomStoredEvent object, [dynamic config]) {
    return jsonEncode(toJson(object, config as SerializationConfig?));
  }

  @override
  CustomStoredEvent deserialize(String data, [dynamic config]) {
    final json = jsonDecode(data);
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected JSON object but got ${json.runtimeType}',
        expectedType: 'CustomStoredEvent',
      );
    }
    return fromJson(json, config as SerializationConfig?);
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    CustomStoredEvent instance, [
    SerializationConfig? config,
  ]) {
    return CustomStoredEventJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static CustomStoredEvent decode(dynamic json, [SerializationConfig? config]) {
    return CustomStoredEventJsonSerializer().fromJson(json, config);
  }
}
