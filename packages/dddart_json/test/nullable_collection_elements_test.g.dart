// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nullable_collection_elements_test.dart';

// **************************************************************************
// SerializableGenerator
// **************************************************************************

class CollectionValueJsonSerializer implements JsonSerializer<CollectionValue> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  CollectionValueJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig =
          defaultConfig ??
          const SerializationConfig(
            fieldRename: FieldRename.none,
            includeNullFields: false,
          );

  @override
  Map<String, dynamic> toJson(
    CollectionValue instance, [
    SerializationConfig? config,
  ]) {
    final effectiveConfig = config ?? _defaultConfig;
    final json = <String, dynamic>{
      SerializationUtils.applyFieldRename('label', effectiveConfig.fieldRename):
          instance.label,
    };
    return json;
  }

  @override
  CollectionValue fromJson(dynamic json, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize CollectionValue from null JSON',
        expectedType: 'CollectionValue',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'CollectionValue',
      );
    }
    try {
      return CollectionValue(
        label:
            json[SerializationUtils.applyFieldRename(
                  'label',
                  effectiveConfig.fieldRename,
                )]
                as String,
      );
    } catch (e) {
      throw DeserializationException(
        'Failed to deserialize CollectionValue',
        expectedType: 'CollectionValue',
      );
    }
  }

  @override
  String serialize(CollectionValue object, [dynamic config]) {
    try {
      return jsonEncode(toJson(object, config as SerializationConfig?));
    } catch (_) {
      throw SerializationException(
        'Failed to serialize CollectionValue',
        expectedType: 'CollectionValue',
      );
    }
  }

  @override
  CollectionValue deserialize(String data, [dynamic config]) {
    try {
      final json = jsonDecode(data);
      if (json is! Map<String, dynamic>) {
        throw DeserializationException(
          'Expected JSON object',
          expectedType: 'CollectionValue',
        );
      }
      return fromJson(json, config as SerializationConfig?);
    } on DeserializationException {
      rethrow;
    } catch (_) {
      throw DeserializationException(
        'Failed to deserialize JSON',
        expectedType: 'CollectionValue',
      );
    }
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    CollectionValue instance, [
    SerializationConfig? config,
  ]) {
    return CollectionValueJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static CollectionValue decode(dynamic json, [SerializationConfig? config]) {
    return CollectionValueJsonSerializer().fromJson(json, config);
  }
}

class NullableElementAggregateJsonSerializer
    implements JsonSerializer<NullableElementAggregate> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  NullableElementAggregateJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig =
          defaultConfig ??
          const SerializationConfig(
            fieldRename: FieldRename.none,
            includeNullFields: false,
          );

  @override
  Map<String, dynamic> toJson(
    NullableElementAggregate instance, [
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
        'dateMap',
        effectiveConfig.fieldRename,
      ): instance.dateMap.map(
        (key, value) => MapEntry(key, value?.toIso8601String()),
      ),
      SerializationUtils.applyFieldRename(
        'dateSet',
        effectiveConfig.fieldRename,
      ): instance.dateSet
          .map((item) => item?.toIso8601String())
          .toList(),
      SerializationUtils.applyFieldRename(
        'enumList',
        effectiveConfig.fieldRename,
      ): instance.enumList
          .map((item) => item?.name)
          .toList(),
      SerializationUtils.applyFieldRename(
        'enumMap',
        effectiveConfig.fieldRename,
      ): instance.enumMap.map(
        (key, value) => MapEntry(key, value?.name),
      ),
      SerializationUtils.applyFieldRename(
        'primitiveList',
        effectiveConfig.fieldRename,
      ): instance.primitiveList,
      SerializationUtils.applyFieldRename(
        'primitiveMap',
        effectiveConfig.fieldRename,
      ): instance.primitiveMap,
      SerializationUtils.applyFieldRename(
        'valueList',
        effectiveConfig.fieldRename,
      ): instance.valueList
          .map(
            (item) => item != null
                ? CollectionValueJsonSerializer().toJson(item, effectiveConfig)
                : null,
          )
          .toList(),
      SerializationUtils.applyFieldRename(
        'valueMap',
        effectiveConfig.fieldRename,
      ): instance.valueMap.map(
        (key, value) => MapEntry(
          key,
          value != null
              ? CollectionValueJsonSerializer().toJson(value, effectiveConfig)
              : null,
        ),
      ),
    };
    return json;
  }

  @override
  NullableElementAggregate fromJson(
    dynamic json, [
    SerializationConfig? config,
  ]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize NullableElementAggregate from null JSON',
        expectedType: 'NullableElementAggregate',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'NullableElementAggregate',
      );
    }
    try {
      return NullableElementAggregate(
        dateMap:
            Map<String, dynamic>.from(
              json[SerializationUtils.applyFieldRename(
                    'dateMap',
                    effectiveConfig.fieldRename,
                  )]
                  as Map,
            ).map(
              (key, value) => MapEntry(
                key,
                value != null ? DateTime.parse(value as String) : null,
              ),
            ),
        dateSet:
            (json[SerializationUtils.applyFieldRename(
                      'dateSet',
                      effectiveConfig.fieldRename,
                    )]
                    as List)
                .map(
                  (item) =>
                      item != null ? DateTime.parse(item as String) : null,
                )
                .toSet(),
        enumList:
            (json[SerializationUtils.applyFieldRename(
                      'enumList',
                      effectiveConfig.fieldRename,
                    )]
                    as List)
                .map(
                  (item) => item != null
                      ? CollectionStatus.values.byName(item as String)
                      : null,
                )
                .toList(),
        enumMap:
            Map<String, dynamic>.from(
              json[SerializationUtils.applyFieldRename(
                    'enumMap',
                    effectiveConfig.fieldRename,
                  )]
                  as Map,
            ).map(
              (key, value) => MapEntry(
                key,
                value != null
                    ? CollectionStatus.values.byName(value as String)
                    : null,
              ),
            ),
        primitiveList:
            (json[SerializationUtils.applyFieldRename(
                      'primitiveList',
                      effectiveConfig.fieldRename,
                    )]
                    as List)
                .map((item) => item as String?)
                .toList(),
        primitiveMap: Map<String, dynamic>.from(
          json[SerializationUtils.applyFieldRename(
                'primitiveMap',
                effectiveConfig.fieldRename,
              )]
              as Map,
        ).map((key, value) => MapEntry(key, value as String?)),
        valueList:
            (json[SerializationUtils.applyFieldRename(
                      'valueList',
                      effectiveConfig.fieldRename,
                    )]
                    as List)
                .map(
                  (item) => item != null
                      ? CollectionValueJsonSerializer().fromJson(
                          item as Map<String, dynamic>,
                          effectiveConfig,
                        )
                      : null,
                )
                .toList(),
        valueMap:
            Map<String, dynamic>.from(
              json[SerializationUtils.applyFieldRename(
                    'valueMap',
                    effectiveConfig.fieldRename,
                  )]
                  as Map,
            ).map(
              (key, value) => MapEntry(
                key,
                value != null
                    ? CollectionValueJsonSerializer().fromJson(
                        value as Map<String, dynamic>,
                        effectiveConfig,
                      )
                    : null,
              ),
            ),
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
        'Failed to deserialize NullableElementAggregate',
        expectedType: 'NullableElementAggregate',
      );
    }
  }

  @override
  String serialize(NullableElementAggregate object, [dynamic config]) {
    try {
      return jsonEncode(toJson(object, config as SerializationConfig?));
    } catch (_) {
      throw SerializationException(
        'Failed to serialize NullableElementAggregate',
        expectedType: 'NullableElementAggregate',
      );
    }
  }

  @override
  NullableElementAggregate deserialize(String data, [dynamic config]) {
    try {
      final json = jsonDecode(data);
      if (json is! Map<String, dynamic>) {
        throw DeserializationException(
          'Expected JSON object',
          expectedType: 'NullableElementAggregate',
        );
      }
      return fromJson(json, config as SerializationConfig?);
    } on DeserializationException {
      rethrow;
    } catch (_) {
      throw DeserializationException(
        'Failed to deserialize JSON',
        expectedType: 'NullableElementAggregate',
      );
    }
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    NullableElementAggregate instance, [
    SerializationConfig? config,
  ]) {
    return NullableElementAggregateJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static NullableElementAggregate decode(
    dynamic json, [
    SerializationConfig? config,
  ]) {
    return NullableElementAggregateJsonSerializer().fromJson(json, config);
  }
}
