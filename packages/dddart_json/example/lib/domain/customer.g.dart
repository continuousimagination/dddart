// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'customer.dart';

// **************************************************************************
// SerializableGenerator
// **************************************************************************

class CustomerJsonSerializer implements JsonSerializer<Customer> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  CustomerJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig = defaultConfig ?? const SerializationConfig();

  @override
  Map<String, dynamic> toJson(
    Customer instance, [
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
      if (instance.defaultBillingAddress != null ||
          effectiveConfig.includeNullFields)
        SerializationUtils.applyFieldRename(
          'defaultBillingAddress',
          effectiveConfig.fieldRename,
        ): instance.defaultBillingAddress != null
            ? AddressJsonSerializer().toJson(
                instance.defaultBillingAddress!,
                effectiveConfig,
              )
            : null,
      SerializationUtils.applyFieldRename(
        'defaultShippingAddress',
        effectiveConfig.fieldRename,
      ): AddressJsonSerializer().toJson(
        instance.defaultShippingAddress,
        effectiveConfig,
      ),
      SerializationUtils.applyFieldRename('email', effectiveConfig.fieldRename):
          instance.email,
      SerializationUtils.applyFieldRename(
        'firstName',
        effectiveConfig.fieldRename,
      ): instance.firstName,
      SerializationUtils.applyFieldRename(
        'lastName',
        effectiveConfig.fieldRename,
      ): instance.lastName,
    };
    return json;
  }

  @override
  Customer fromJson(dynamic json, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize Customer from null JSON',
        expectedType: 'Customer',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'Customer',
      );
    }
    try {
      return Customer(
        defaultBillingAddress:
            json[SerializationUtils.applyFieldRename(
                  'defaultBillingAddress',
                  effectiveConfig.fieldRename,
                )] !=
                null
            ? AddressJsonSerializer().fromJson(
                json[SerializationUtils.applyFieldRename(
                      'defaultBillingAddress',
                      effectiveConfig.fieldRename,
                    )]
                    as Map<String, dynamic>,
                effectiveConfig,
              )
            : null,
        defaultShippingAddress: AddressJsonSerializer().fromJson(
          json[SerializationUtils.applyFieldRename(
                'defaultShippingAddress',
                effectiveConfig.fieldRename,
              )]
              as Map<String, dynamic>,
          effectiveConfig,
        ),
        email:
            json[SerializationUtils.applyFieldRename(
                  'email',
                  effectiveConfig.fieldRename,
                )]
                as String,
        firstName:
            json[SerializationUtils.applyFieldRename(
                  'firstName',
                  effectiveConfig.fieldRename,
                )]
                as String,
        lastName:
            json[SerializationUtils.applyFieldRename(
                  'lastName',
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
    } catch (e, stackTrace) {
      throw DeserializationException(
        'Failed to deserialize Customer',
        expectedType: 'Customer',
      );
    }
  }

  @override
  String serialize(Customer object, [dynamic config]) {
    try {
      return jsonEncode(toJson(object, config as SerializationConfig?));
    } catch (_) {
      throw SerializationException(
        'Failed to serialize Customer',
        expectedType: 'Customer',
      );
    }
  }

  @override
  Customer deserialize(String data, [dynamic config]) {
    try {
      final json = jsonDecode(data);
      if (json is! Map<String, dynamic>) {
        throw DeserializationException(
          'Expected JSON object',
          expectedType: 'Customer',
        );
      }
      return fromJson(json, config as SerializationConfig?);
    } on DeserializationException {
      rethrow;
    } catch (_) {
      throw DeserializationException(
        'Invalid JSON input',
        expectedType: 'Customer',
      );
    }
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    Customer instance, [
    SerializationConfig? config,
  ]) {
    return CustomerJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static Customer decode(dynamic json, [SerializationConfig? config]) {
    return CustomerJsonSerializer().fromJson(json, config);
  }
}
