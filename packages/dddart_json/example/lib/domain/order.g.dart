// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order.dart';

// **************************************************************************
// SerializableGenerator
// **************************************************************************

class OrderJsonSerializer implements JsonSerializer<Order> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  OrderJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig = defaultConfig ?? const SerializationConfig();

  @override
  Map<String, dynamic> toJson(Order instance, [SerializationConfig? config]) {
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
      if (instance.billingAddress != null || effectiveConfig.includeNullFields)
        SerializationUtils.applyFieldRename(
          'billingAddress',
          effectiveConfig.fieldRename,
        ): instance.billingAddress != null
            ? AddressJsonSerializer().toJson(
                instance.billingAddress!,
                effectiveConfig,
              )
            : null,
      SerializationUtils.applyFieldRename(
        'customerId',
        effectiveConfig.fieldRename,
      ): instance.customerId
          .toString(),
      SerializationUtils.applyFieldRename(
        'items',
        effectiveConfig.fieldRename,
      ): instance.items
          .map(
            (item) => OrderItemJsonSerializer().toJson(item, effectiveConfig),
          )
          .toList(),
      if (instance.notes != null || effectiveConfig.includeNullFields)
        SerializationUtils.applyFieldRename(
          'notes',
          effectiveConfig.fieldRename,
        ): instance.notes,
      SerializationUtils.applyFieldRename(
        'shippingAddress',
        effectiveConfig.fieldRename,
      ): AddressJsonSerializer().toJson(
        instance.shippingAddress,
        effectiveConfig,
      ),
      SerializationUtils.applyFieldRename(
        'status',
        effectiveConfig.fieldRename,
      ): instance.status,
    };
    return json;
  }

  @override
  Order fromJson(dynamic json, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize Order from null JSON',
        expectedType: 'Order',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'Order',
      );
    }
    try {
      return Order(
        billingAddress:
            json[SerializationUtils.applyFieldRename(
                  'billingAddress',
                  effectiveConfig.fieldRename,
                )] !=
                null
            ? AddressJsonSerializer().fromJson(
                json[SerializationUtils.applyFieldRename(
                      'billingAddress',
                      effectiveConfig.fieldRename,
                    )]
                    as Map<String, dynamic>,
                effectiveConfig,
              )
            : null,
        customerId: UuidValue.fromString(
          json[SerializationUtils.applyFieldRename(
                'customerId',
                effectiveConfig.fieldRename,
              )]
              as String,
        ),
        items:
            (json[SerializationUtils.applyFieldRename(
                      'items',
                      effectiveConfig.fieldRename,
                    )]
                    as List)
                .map(
                  (item) => OrderItemJsonSerializer().fromJson(
                    item as Map<String, dynamic>,
                    effectiveConfig,
                  ),
                )
                .toList(),
        notes:
            json[SerializationUtils.applyFieldRename(
                  'notes',
                  effectiveConfig.fieldRename,
                )]
                as String?,
        shippingAddress: AddressJsonSerializer().fromJson(
          json[SerializationUtils.applyFieldRename(
                'shippingAddress',
                effectiveConfig.fieldRename,
              )]
              as Map<String, dynamic>,
          effectiveConfig,
        ),
        status:
            json[SerializationUtils.applyFieldRename(
                  'status',
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
        'Failed to deserialize Order: $e',
        expectedType: 'Order',
      );
    }
  }

  @override
  String serialize(Order object, [dynamic config]) {
    return jsonEncode(toJson(object, config as SerializationConfig?));
  }

  @override
  Order deserialize(String data, [dynamic config]) {
    final json = jsonDecode(data);
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected JSON object but got ${json.runtimeType}',
        expectedType: 'Order',
      );
    }
    return fromJson(json, config as SerializationConfig?);
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    Order instance, [
    SerializationConfig? config,
  ]) {
    return OrderJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static Order decode(dynamic json, [SerializationConfig? config]) {
    return OrderJsonSerializer().fromJson(json, config);
  }
}
