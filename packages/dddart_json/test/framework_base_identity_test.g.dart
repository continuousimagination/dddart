// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'framework_base_identity_test.dart';

// **************************************************************************
// SerializableGenerator
// **************************************************************************

class SameNamedBoundaryValueJsonSerializer
    implements JsonSerializer<SameNamedBoundaryValue> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  SameNamedBoundaryValueJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig =
          defaultConfig ??
          const SerializationConfig(
            fieldRename: FieldRename.snake,
            includeNullFields: false,
          );

  @override
  Map<String, dynamic> toJson(
    SameNamedBoundaryValue instance, [
    SerializationConfig? config,
  ]) {
    final effectiveConfig = config ?? _defaultConfig;
    final json = <String, dynamic>{
      SerializationUtils.applyFieldRename(
        'applicationBaseState',
        effectiveConfig.fieldRename,
      ): instance.applicationBaseState,
      SerializationUtils.applyFieldRename(
        'childState',
        effectiveConfig.fieldRename,
      ): instance.childState,
    };
    return json;
  }

  @override
  SameNamedBoundaryValue fromJson(dynamic json, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize SameNamedBoundaryValue from null JSON',
        expectedType: 'SameNamedBoundaryValue',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'SameNamedBoundaryValue',
      );
    }
    try {
      return SameNamedBoundaryValue(
        applicationBaseState:
            json[SerializationUtils.applyFieldRename(
                  'applicationBaseState',
                  effectiveConfig.fieldRename,
                )]
                as String,
        childState:
            json[SerializationUtils.applyFieldRename(
                  'childState',
                  effectiveConfig.fieldRename,
                )]
                as String,
      );
    } catch (e) {
      throw DeserializationException(
        'Failed to deserialize SameNamedBoundaryValue',
        expectedType: 'SameNamedBoundaryValue',
      );
    }
  }

  @override
  String serialize(SameNamedBoundaryValue object, [dynamic config]) {
    try {
      return jsonEncode(toJson(object, config as SerializationConfig?));
    } catch (_) {
      throw SerializationException(
        'Failed to serialize SameNamedBoundaryValue',
        expectedType: 'SameNamedBoundaryValue',
      );
    }
  }

  @override
  SameNamedBoundaryValue deserialize(String data, [dynamic config]) {
    try {
      final json = jsonDecode(data);
      if (json is! Map<String, dynamic>) {
        throw DeserializationException(
          'Expected JSON object',
          expectedType: 'SameNamedBoundaryValue',
        );
      }
      return fromJson(json, config as SerializationConfig?);
    } on DeserializationException {
      rethrow;
    } catch (_) {
      throw DeserializationException(
        'Failed to deserialize JSON',
        expectedType: 'SameNamedBoundaryValue',
      );
    }
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    SameNamedBoundaryValue instance, [
    SerializationConfig? config,
  ]) {
    return SameNamedBoundaryValueJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static SameNamedBoundaryValue decode(
    dynamic json, [
    SerializationConfig? config,
  ]) {
    return SameNamedBoundaryValueJsonSerializer().fromJson(json, config);
  }
}
