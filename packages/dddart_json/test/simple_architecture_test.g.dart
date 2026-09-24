// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'simple_architecture_test.dart';

// **************************************************************************
// SerializableGenerator
// **************************************************************************

class SimpleUserJsonSerializer implements JsonSerializer<SimpleUser> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  SimpleUserJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig =
          defaultConfig ??
          const SerializationConfig(
            fieldRename: FieldRename.none,
            includeNullFields: false,
          );

  @override
  Map<String, dynamic> toJson(
    SimpleUser instance, [
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
      SerializationUtils.applyFieldRename('email', effectiveConfig.fieldRename):
          instance.email,
      SerializationUtils.applyFieldRename('name', effectiveConfig.fieldRename):
          instance.name,
    };
    return json;
  }

  @override
  SimpleUser fromJson(dynamic json, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize SimpleUser from null JSON',
        expectedType: 'SimpleUser',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'SimpleUser',
      );
    }
    try {
      return SimpleUser(
        email:
            json[SerializationUtils.applyFieldRename(
                  'email',
                  effectiveConfig.fieldRename,
                )]
                as String,
        name:
            json[SerializationUtils.applyFieldRename(
                  'name',
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
        'Failed to deserialize SimpleUser',
        expectedType: 'SimpleUser',
      );
    }
  }

  @override
  String serialize(SimpleUser object, [dynamic config]) {
    try {
      return jsonEncode(toJson(object, config as SerializationConfig?));
    } catch (_) {
      throw SerializationException(
        'Failed to serialize SimpleUser',
        expectedType: 'SimpleUser',
      );
    }
  }

  @override
  SimpleUser deserialize(String data, [dynamic config]) {
    try {
      final json = jsonDecode(data);
      if (json is! Map<String, dynamic>) {
        throw DeserializationException(
          'Expected JSON object',
          expectedType: 'SimpleUser',
        );
      }
      return fromJson(json, config as SerializationConfig?);
    } on DeserializationException {
      rethrow;
    } catch (_) {
      throw DeserializationException(
        'Failed to deserialize JSON',
        expectedType: 'SimpleUser',
      );
    }
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    SimpleUser instance, [
    SerializationConfig? config,
  ]) {
    return SimpleUserJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static SimpleUser decode(dynamic json, [SerializationConfig? config]) {
    return SimpleUserJsonSerializer().fromJson(json, config);
  }
}

class SimpleAddressJsonSerializer implements JsonSerializer<SimpleAddress> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  SimpleAddressJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig =
          defaultConfig ??
          const SerializationConfig(
            fieldRename: FieldRename.none,
            includeNullFields: false,
          );

  @override
  Map<String, dynamic> toJson(
    SimpleAddress instance, [
    SerializationConfig? config,
  ]) {
    final effectiveConfig = config ?? _defaultConfig;
    final json = <String, dynamic>{
      SerializationUtils.applyFieldRename('city', effectiveConfig.fieldRename):
          instance.city,
      SerializationUtils.applyFieldRename(
        'street',
        effectiveConfig.fieldRename,
      ): instance.street,
    };
    return json;
  }

  @override
  SimpleAddress fromJson(dynamic json, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize SimpleAddress from null JSON',
        expectedType: 'SimpleAddress',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'SimpleAddress',
      );
    }
    try {
      return SimpleAddress(
        city:
            json[SerializationUtils.applyFieldRename(
                  'city',
                  effectiveConfig.fieldRename,
                )]
                as String,
        street:
            json[SerializationUtils.applyFieldRename(
                  'street',
                  effectiveConfig.fieldRename,
                )]
                as String,
      );
    } catch (e) {
      throw DeserializationException(
        'Failed to deserialize SimpleAddress',
        expectedType: 'SimpleAddress',
      );
    }
  }

  @override
  String serialize(SimpleAddress object, [dynamic config]) {
    try {
      return jsonEncode(toJson(object, config as SerializationConfig?));
    } catch (_) {
      throw SerializationException(
        'Failed to serialize SimpleAddress',
        expectedType: 'SimpleAddress',
      );
    }
  }

  @override
  SimpleAddress deserialize(String data, [dynamic config]) {
    try {
      final json = jsonDecode(data);
      if (json is! Map<String, dynamic>) {
        throw DeserializationException(
          'Expected JSON object',
          expectedType: 'SimpleAddress',
        );
      }
      return fromJson(json, config as SerializationConfig?);
    } on DeserializationException {
      rethrow;
    } catch (_) {
      throw DeserializationException(
        'Failed to deserialize JSON',
        expectedType: 'SimpleAddress',
      );
    }
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    SimpleAddress instance, [
    SerializationConfig? config,
  ]) {
    return SimpleAddressJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static SimpleAddress decode(dynamic json, [SerializationConfig? config]) {
    return SimpleAddressJsonSerializer().fromJson(json, config);
  }
}
