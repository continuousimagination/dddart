// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inherited_state_test.dart';

// **************************************************************************
// SerializableGenerator
// **************************************************************************

class InheritedStateAggregateJsonSerializer
    implements JsonSerializer<InheritedStateAggregate> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  InheritedStateAggregateJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig =
          defaultConfig ??
          const SerializationConfig(
            fieldRename: FieldRename.snake,
            includeNullFields: false,
          );

  @override
  Map<String, dynamic> toJson(
    InheritedStateAggregate instance, [
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
        'aggregateBaseName',
        effectiveConfig.fieldRename,
      ): instance.aggregateBaseName,
      SerializationUtils.applyFieldRename(
        'aggregateChildName',
        effectiveConfig.fieldRename,
      ): instance.aggregateChildName,
      SerializationUtils.applyFieldRename(
        'aggregateMiddleName',
        effectiveConfig.fieldRename,
      ): instance.aggregateMiddleName,
    };
    return json;
  }

  @override
  InheritedStateAggregate fromJson(
    dynamic json, [
    SerializationConfig? config,
  ]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize InheritedStateAggregate from null JSON',
        expectedType: 'InheritedStateAggregate',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'InheritedStateAggregate',
      );
    }
    try {
      return InheritedStateAggregate(
        aggregateBaseName:
            json[SerializationUtils.applyFieldRename(
                  'aggregateBaseName',
                  effectiveConfig.fieldRename,
                )]
                as String,
        aggregateChildName:
            json[SerializationUtils.applyFieldRename(
                  'aggregateChildName',
                  effectiveConfig.fieldRename,
                )]
                as String,
        aggregateMiddleName:
            json[SerializationUtils.applyFieldRename(
                  'aggregateMiddleName',
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
        'Failed to deserialize InheritedStateAggregate',
        expectedType: 'InheritedStateAggregate',
      );
    }
  }

  @override
  String serialize(InheritedStateAggregate object, [dynamic config]) {
    try {
      return jsonEncode(toJson(object, config as SerializationConfig?));
    } catch (_) {
      throw SerializationException(
        'Failed to serialize InheritedStateAggregate',
        expectedType: 'InheritedStateAggregate',
      );
    }
  }

  @override
  InheritedStateAggregate deserialize(String data, [dynamic config]) {
    try {
      final json = jsonDecode(data);
      if (json is! Map<String, dynamic>) {
        throw DeserializationException(
          'Expected JSON object',
          expectedType: 'InheritedStateAggregate',
        );
      }
      return fromJson(json, config as SerializationConfig?);
    } on DeserializationException {
      rethrow;
    } catch (_) {
      throw DeserializationException(
        'Failed to deserialize JSON',
        expectedType: 'InheritedStateAggregate',
      );
    }
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    InheritedStateAggregate instance, [
    SerializationConfig? config,
  ]) {
    return InheritedStateAggregateJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static InheritedStateAggregate decode(
    dynamic json, [
    SerializationConfig? config,
  ]) {
    return InheritedStateAggregateJsonSerializer().fromJson(json, config);
  }
}

class InheritedStateEntityJsonSerializer
    implements JsonSerializer<InheritedStateEntity> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  InheritedStateEntityJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig =
          defaultConfig ??
          const SerializationConfig(
            fieldRename: FieldRename.kebab,
            includeNullFields: false,
          );

  @override
  Map<String, dynamic> toJson(
    InheritedStateEntity instance, [
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
        'entityBaseName',
        effectiveConfig.fieldRename,
      ): instance.entityBaseName,
      SerializationUtils.applyFieldRename(
        'entityChildName',
        effectiveConfig.fieldRename,
      ): instance.entityChildName,
    };
    return json;
  }

  @override
  InheritedStateEntity fromJson(dynamic json, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize InheritedStateEntity from null JSON',
        expectedType: 'InheritedStateEntity',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'InheritedStateEntity',
      );
    }
    try {
      return InheritedStateEntity(
        entityBaseName:
            json[SerializationUtils.applyFieldRename(
                  'entityBaseName',
                  effectiveConfig.fieldRename,
                )]
                as String,
        entityChildName:
            json[SerializationUtils.applyFieldRename(
                  'entityChildName',
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
        'Failed to deserialize InheritedStateEntity',
        expectedType: 'InheritedStateEntity',
      );
    }
  }

  @override
  String serialize(InheritedStateEntity object, [dynamic config]) {
    try {
      return jsonEncode(toJson(object, config as SerializationConfig?));
    } catch (_) {
      throw SerializationException(
        'Failed to serialize InheritedStateEntity',
        expectedType: 'InheritedStateEntity',
      );
    }
  }

  @override
  InheritedStateEntity deserialize(String data, [dynamic config]) {
    try {
      final json = jsonDecode(data);
      if (json is! Map<String, dynamic>) {
        throw DeserializationException(
          'Expected JSON object',
          expectedType: 'InheritedStateEntity',
        );
      }
      return fromJson(json, config as SerializationConfig?);
    } on DeserializationException {
      rethrow;
    } catch (_) {
      throw DeserializationException(
        'Failed to deserialize JSON',
        expectedType: 'InheritedStateEntity',
      );
    }
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    InheritedStateEntity instance, [
    SerializationConfig? config,
  ]) {
    return InheritedStateEntityJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static InheritedStateEntity decode(
    dynamic json, [
    SerializationConfig? config,
  ]) {
    return InheritedStateEntityJsonSerializer().fromJson(json, config);
  }
}

class InheritedStateValueJsonSerializer
    implements JsonSerializer<InheritedStateValue> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  InheritedStateValueJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig =
          defaultConfig ??
          const SerializationConfig(
            fieldRename: FieldRename.snake,
            includeNullFields: false,
          );

  @override
  Map<String, dynamic> toJson(
    InheritedStateValue instance, [
    SerializationConfig? config,
  ]) {
    final effectiveConfig = config ?? _defaultConfig;
    final json = <String, dynamic>{
      SerializationUtils.applyFieldRename(
        'valueBaseName',
        effectiveConfig.fieldRename,
      ): instance.valueBaseName,
      SerializationUtils.applyFieldRename(
        'valueChildName',
        effectiveConfig.fieldRename,
      ): instance.valueChildName,
    };
    return json;
  }

  @override
  InheritedStateValue fromJson(dynamic json, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize InheritedStateValue from null JSON',
        expectedType: 'InheritedStateValue',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'InheritedStateValue',
      );
    }
    try {
      return InheritedStateValue(
        valueBaseName:
            json[SerializationUtils.applyFieldRename(
                  'valueBaseName',
                  effectiveConfig.fieldRename,
                )]
                as String,
        valueChildName:
            json[SerializationUtils.applyFieldRename(
                  'valueChildName',
                  effectiveConfig.fieldRename,
                )]
                as String,
      );
    } catch (e) {
      throw DeserializationException(
        'Failed to deserialize InheritedStateValue',
        expectedType: 'InheritedStateValue',
      );
    }
  }

  @override
  String serialize(InheritedStateValue object, [dynamic config]) {
    try {
      return jsonEncode(toJson(object, config as SerializationConfig?));
    } catch (_) {
      throw SerializationException(
        'Failed to serialize InheritedStateValue',
        expectedType: 'InheritedStateValue',
      );
    }
  }

  @override
  InheritedStateValue deserialize(String data, [dynamic config]) {
    try {
      final json = jsonDecode(data);
      if (json is! Map<String, dynamic>) {
        throw DeserializationException(
          'Expected JSON object',
          expectedType: 'InheritedStateValue',
        );
      }
      return fromJson(json, config as SerializationConfig?);
    } on DeserializationException {
      rethrow;
    } catch (_) {
      throw DeserializationException(
        'Failed to deserialize JSON',
        expectedType: 'InheritedStateValue',
      );
    }
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    InheritedStateValue instance, [
    SerializationConfig? config,
  ]) {
    return InheritedStateValueJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static InheritedStateValue decode(
    dynamic json, [
    SerializationConfig? config,
  ]) {
    return InheritedStateValueJsonSerializer().fromJson(json, config);
  }
}
