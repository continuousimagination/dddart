// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'address.dart';

// **************************************************************************
// SerializableGenerator
// **************************************************************************

class AddressJsonSerializer implements JsonSerializer<Address> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  AddressJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig =
          defaultConfig ??
          const SerializationConfig(
            fieldRename: FieldRename.none,
            includeNullFields: false,
          );

  @override
  Map<String, dynamic> toJson(Address instance, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    final json = <String, dynamic>{
      SerializationUtils.applyFieldRename('city', effectiveConfig.fieldRename):
          instance.city,
      SerializationUtils.applyFieldRename(
        'country',
        effectiveConfig.fieldRename,
      ): instance.country,
      SerializationUtils.applyFieldRename('state', effectiveConfig.fieldRename):
          instance.state,
      SerializationUtils.applyFieldRename(
        'street',
        effectiveConfig.fieldRename,
      ): instance.street,
      SerializationUtils.applyFieldRename(
        'zipCode',
        effectiveConfig.fieldRename,
      ): instance.zipCode,
    };
    return json;
  }

  @override
  Address fromJson(dynamic json, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize Address from null JSON',
        expectedType: 'Address',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'Address',
      );
    }
    try {
      return Address(
        city:
            json[SerializationUtils.applyFieldRename(
                  'city',
                  effectiveConfig.fieldRename,
                )]
                as String,
        country:
            json[SerializationUtils.applyFieldRename(
                  'country',
                  effectiveConfig.fieldRename,
                )]
                as String,
        state:
            json[SerializationUtils.applyFieldRename(
                  'state',
                  effectiveConfig.fieldRename,
                )]
                as String,
        street:
            json[SerializationUtils.applyFieldRename(
                  'street',
                  effectiveConfig.fieldRename,
                )]
                as String,
        zipCode:
            json[SerializationUtils.applyFieldRename(
                  'zipCode',
                  effectiveConfig.fieldRename,
                )]
                as String,
      );
    } catch (e) {
      throw DeserializationException(
        'Failed to deserialize Address',
        expectedType: 'Address',
      );
    }
  }

  @override
  String serialize(Address object, [dynamic config]) {
    try {
      return jsonEncode(toJson(object, config as SerializationConfig?));
    } catch (_) {
      throw SerializationException(
        'Failed to serialize Address',
        expectedType: 'Address',
      );
    }
  }

  @override
  Address deserialize(String data, [dynamic config]) {
    try {
      final json = jsonDecode(data);
      if (json is! Map<String, dynamic>) {
        throw DeserializationException(
          'Expected JSON object',
          expectedType: 'Address',
        );
      }
      return fromJson(json, config as SerializationConfig?);
    } on DeserializationException {
      rethrow;
    } catch (_) {
      throw DeserializationException(
        'Failed to deserialize JSON',
        expectedType: 'Address',
      );
    }
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    Address instance, [
    SerializationConfig? config,
  ]) {
    return AddressJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static Address decode(dynamic json, [SerializationConfig? config]) {
    return AddressJsonSerializer().fromJson(json, config);
  }
}
