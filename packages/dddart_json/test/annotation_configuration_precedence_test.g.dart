// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'annotation_configuration_precedence_test.dart';

// **************************************************************************
// SerializableGenerator
// **************************************************************************

class FrameworkDefaultValueJsonSerializer
    implements JsonSerializer<FrameworkDefaultValue> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  FrameworkDefaultValueJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig =
          defaultConfig ??
          const SerializationConfig(
            fieldRename: FieldRename.none,
            includeNullFields: false,
          );

  @override
  Map<String, dynamic> toJson(
    FrameworkDefaultValue instance, [
    SerializationConfig? config,
  ]) {
    final effectiveConfig = config ?? _defaultConfig;
    final json = <String, dynamic>{
      SerializationUtils.applyFieldRename(
        'displayName',
        effectiveConfig.fieldRename,
      ): instance.displayName,
      if (instance.optionalNote != null || effectiveConfig.includeNullFields)
        SerializationUtils.applyFieldRename(
          'optionalNote',
          effectiveConfig.fieldRename,
        ): instance.optionalNote,
    };
    return json;
  }

  @override
  FrameworkDefaultValue fromJson(dynamic json, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize FrameworkDefaultValue from null JSON',
        expectedType: 'FrameworkDefaultValue',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'FrameworkDefaultValue',
      );
    }
    try {
      return FrameworkDefaultValue(
        displayName:
            json[SerializationUtils.applyFieldRename(
                  'displayName',
                  effectiveConfig.fieldRename,
                )]
                as String,
        optionalNote:
            json[SerializationUtils.applyFieldRename(
                  'optionalNote',
                  effectiveConfig.fieldRename,
                )]
                as String?,
      );
    } catch (e) {
      throw DeserializationException(
        'Failed to deserialize FrameworkDefaultValue',
        expectedType: 'FrameworkDefaultValue',
      );
    }
  }

  @override
  String serialize(FrameworkDefaultValue object, [dynamic config]) {
    try {
      return jsonEncode(toJson(object, config as SerializationConfig?));
    } catch (_) {
      throw SerializationException(
        'Failed to serialize FrameworkDefaultValue',
        expectedType: 'FrameworkDefaultValue',
      );
    }
  }

  @override
  FrameworkDefaultValue deserialize(String data, [dynamic config]) {
    try {
      final json = jsonDecode(data);
      if (json is! Map<String, dynamic>) {
        throw DeserializationException(
          'Expected JSON object',
          expectedType: 'FrameworkDefaultValue',
        );
      }
      return fromJson(json, config as SerializationConfig?);
    } on DeserializationException {
      rethrow;
    } catch (_) {
      throw DeserializationException(
        'Failed to deserialize JSON',
        expectedType: 'FrameworkDefaultValue',
      );
    }
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    FrameworkDefaultValue instance, [
    SerializationConfig? config,
  ]) {
    return FrameworkDefaultValueJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static FrameworkDefaultValue decode(
    dynamic json, [
    SerializationConfig? config,
  ]) {
    return FrameworkDefaultValueJsonSerializer().fromJson(json, config);
  }
}

class AncestorConfiguredValueJsonSerializer
    implements JsonSerializer<AncestorConfiguredValue> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  AncestorConfiguredValueJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig =
          defaultConfig ??
          const SerializationConfig(
            fieldRename: FieldRename.snake,
            includeNullFields: true,
          );

  @override
  Map<String, dynamic> toJson(
    AncestorConfiguredValue instance, [
    SerializationConfig? config,
  ]) {
    final effectiveConfig = config ?? _defaultConfig;
    final json = <String, dynamic>{};
    return json;
  }

  @override
  AncestorConfiguredValue fromJson(
    dynamic json, [
    SerializationConfig? config,
  ]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize AncestorConfiguredValue from null JSON',
        expectedType: 'AncestorConfiguredValue',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'AncestorConfiguredValue',
      );
    }
    try {
      return AncestorConfiguredValue();
    } catch (e) {
      throw DeserializationException(
        'Failed to deserialize AncestorConfiguredValue',
        expectedType: 'AncestorConfiguredValue',
      );
    }
  }

  @override
  String serialize(AncestorConfiguredValue object, [dynamic config]) {
    try {
      return jsonEncode(toJson(object, config as SerializationConfig?));
    } catch (_) {
      throw SerializationException(
        'Failed to serialize AncestorConfiguredValue',
        expectedType: 'AncestorConfiguredValue',
      );
    }
  }

  @override
  AncestorConfiguredValue deserialize(String data, [dynamic config]) {
    try {
      final json = jsonDecode(data);
      if (json is! Map<String, dynamic>) {
        throw DeserializationException(
          'Expected JSON object',
          expectedType: 'AncestorConfiguredValue',
        );
      }
      return fromJson(json, config as SerializationConfig?);
    } on DeserializationException {
      rethrow;
    } catch (_) {
      throw DeserializationException(
        'Failed to deserialize JSON',
        expectedType: 'AncestorConfiguredValue',
      );
    }
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    AncestorConfiguredValue instance, [
    SerializationConfig? config,
  ]) {
    return AncestorConfiguredValueJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static AncestorConfiguredValue decode(
    dynamic json, [
    SerializationConfig? config,
  ]) {
    return AncestorConfiguredValueJsonSerializer().fromJson(json, config);
  }
}

class ConfiguredValueJsonSerializer implements JsonSerializer<ConfiguredValue> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  ConfiguredValueJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig =
          defaultConfig ??
          const SerializationConfig(
            fieldRename: FieldRename.kebab,
            includeNullFields: false,
          );

  @override
  Map<String, dynamic> toJson(
    ConfiguredValue instance, [
    SerializationConfig? config,
  ]) {
    final effectiveConfig = config ?? _defaultConfig;
    final json = <String, dynamic>{
      SerializationUtils.applyFieldRename(
        'displayName',
        effectiveConfig.fieldRename,
      ): instance.displayName,
      if (instance.optionalNote != null || effectiveConfig.includeNullFields)
        SerializationUtils.applyFieldRename(
          'optionalNote',
          effectiveConfig.fieldRename,
        ): instance.optionalNote,
    };
    return json;
  }

  @override
  ConfiguredValue fromJson(dynamic json, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize ConfiguredValue from null JSON',
        expectedType: 'ConfiguredValue',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'ConfiguredValue',
      );
    }
    try {
      return ConfiguredValue(
        displayName:
            json[SerializationUtils.applyFieldRename(
                  'displayName',
                  effectiveConfig.fieldRename,
                )]
                as String,
        optionalNote:
            json[SerializationUtils.applyFieldRename(
                  'optionalNote',
                  effectiveConfig.fieldRename,
                )]
                as String?,
      );
    } catch (e) {
      throw DeserializationException(
        'Failed to deserialize ConfiguredValue',
        expectedType: 'ConfiguredValue',
      );
    }
  }

  @override
  String serialize(ConfiguredValue object, [dynamic config]) {
    try {
      return jsonEncode(toJson(object, config as SerializationConfig?));
    } catch (_) {
      throw SerializationException(
        'Failed to serialize ConfiguredValue',
        expectedType: 'ConfiguredValue',
      );
    }
  }

  @override
  ConfiguredValue deserialize(String data, [dynamic config]) {
    try {
      final json = jsonDecode(data);
      if (json is! Map<String, dynamic>) {
        throw DeserializationException(
          'Expected JSON object',
          expectedType: 'ConfiguredValue',
        );
      }
      return fromJson(json, config as SerializationConfig?);
    } on DeserializationException {
      rethrow;
    } catch (_) {
      throw DeserializationException(
        'Failed to deserialize JSON',
        expectedType: 'ConfiguredValue',
      );
    }
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    ConfiguredValue instance, [
    SerializationConfig? config,
  ]) {
    return ConfiguredValueJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static ConfiguredValue decode(dynamic json, [SerializationConfig? config]) {
    return ConfiguredValueJsonSerializer().fromJson(json, config);
  }
}
