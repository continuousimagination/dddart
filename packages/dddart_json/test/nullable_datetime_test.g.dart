// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nullable_datetime_test.dart';

// **************************************************************************
// SerializableGenerator
// **************************************************************************

class TaskAggregateJsonSerializer implements JsonSerializer<TaskAggregate> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  TaskAggregateJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig =
          defaultConfig ??
          const SerializationConfig(
            fieldRename: FieldRename.none,
            includeNullFields: false,
          );

  @override
  Map<String, dynamic> toJson(
    TaskAggregate instance, [
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
      if (instance.completedAt != null || effectiveConfig.includeNullFields)
        SerializationUtils.applyFieldRename(
          'completedAt',
          effectiveConfig.fieldRename,
        ): instance.completedAt
            ?.toIso8601String(),
      if (instance.dueDate != null || effectiveConfig.includeNullFields)
        SerializationUtils.applyFieldRename(
          'dueDate',
          effectiveConfig.fieldRename,
        ): instance.dueDate
            ?.toIso8601String(),
      SerializationUtils.applyFieldRename('title', effectiveConfig.fieldRename):
          instance.title,
    };
    return json;
  }

  @override
  TaskAggregate fromJson(dynamic json, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize TaskAggregate from null JSON',
        expectedType: 'TaskAggregate',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'TaskAggregate',
      );
    }
    try {
      return TaskAggregate(
        completedAt:
            json[SerializationUtils.applyFieldRename(
                  'completedAt',
                  effectiveConfig.fieldRename,
                )] !=
                null
            ? DateTime.parse(
                json[SerializationUtils.applyFieldRename(
                      'completedAt',
                      effectiveConfig.fieldRename,
                    )]
                    as String,
              )
            : null,
        dueDate:
            json[SerializationUtils.applyFieldRename(
                  'dueDate',
                  effectiveConfig.fieldRename,
                )] !=
                null
            ? DateTime.parse(
                json[SerializationUtils.applyFieldRename(
                      'dueDate',
                      effectiveConfig.fieldRename,
                    )]
                    as String,
              )
            : null,
        title:
            json[SerializationUtils.applyFieldRename(
                  'title',
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
    } catch (e) {
      throw DeserializationException(
        'Failed to deserialize TaskAggregate',
        expectedType: 'TaskAggregate',
      );
    }
  }

  @override
  String serialize(TaskAggregate object, [dynamic config]) {
    try {
      return jsonEncode(toJson(object, config as SerializationConfig?));
    } catch (_) {
      throw SerializationException(
        'Failed to serialize TaskAggregate',
        expectedType: 'TaskAggregate',
      );
    }
  }

  @override
  TaskAggregate deserialize(String data, [dynamic config]) {
    try {
      final json = jsonDecode(data);
      if (json is! Map<String, dynamic>) {
        throw DeserializationException(
          'Expected JSON object',
          expectedType: 'TaskAggregate',
        );
      }
      return fromJson(json, config as SerializationConfig?);
    } on DeserializationException {
      rethrow;
    } catch (_) {
      throw DeserializationException(
        'Failed to deserialize JSON',
        expectedType: 'TaskAggregate',
      );
    }
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    TaskAggregate instance, [
    SerializationConfig? config,
  ]) {
    return TaskAggregateJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static TaskAggregate decode(dynamic json, [SerializationConfig? config]) {
    return TaskAggregateJsonSerializer().fromJson(json, config);
  }
}
