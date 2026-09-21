// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_item.dart';

// **************************************************************************
// SerializableGenerator
// **************************************************************************

class OrderItemJsonSerializer implements JsonSerializer<OrderItem> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  OrderItemJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig = defaultConfig ?? const SerializationConfig();

  @override
  Map<String, dynamic> toJson(
    OrderItem instance, [
    SerializationConfig? config,
  ]) {
    final effectiveConfig = config ?? _defaultConfig;
    final json = <String, dynamic>{
      SerializationUtils.applyFieldRename(
        'product',
        effectiveConfig.fieldRename,
      ): ProductInfoJsonSerializer().toJson(
        instance.product,
        effectiveConfig,
      ),
      SerializationUtils.applyFieldRename(
        'quantity',
        effectiveConfig.fieldRename,
      ): instance.quantity,
      SerializationUtils.applyFieldRename(
        'unitPrice',
        effectiveConfig.fieldRename,
      ): MoneyJsonSerializer().toJson(
        instance.unitPrice,
        effectiveConfig,
      ),
    };
    return json;
  }

  @override
  OrderItem fromJson(dynamic json, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize OrderItem from null JSON',
        expectedType: 'OrderItem',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'OrderItem',
      );
    }
    try {
      return OrderItem(
        product: ProductInfoJsonSerializer().fromJson(
          json[SerializationUtils.applyFieldRename(
                'product',
                effectiveConfig.fieldRename,
              )]
              as Map<String, dynamic>,
          effectiveConfig,
        ),
        quantity:
            json[SerializationUtils.applyFieldRename(
                  'quantity',
                  effectiveConfig.fieldRename,
                )]
                as int,
        unitPrice: MoneyJsonSerializer().fromJson(
          json[SerializationUtils.applyFieldRename(
                'unitPrice',
                effectiveConfig.fieldRename,
              )]
              as Map<String, dynamic>,
          effectiveConfig,
        ),
      );
    } catch (e, stackTrace) {
      throw DeserializationException(
        'Failed to deserialize OrderItem: $e',
        expectedType: 'OrderItem',
      );
    }
  }

  @override
  String serialize(OrderItem object, [dynamic config]) {
    return jsonEncode(toJson(object, config as SerializationConfig?));
  }

  @override
  OrderItem deserialize(String data, [dynamic config]) {
    final json = jsonDecode(data);
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected JSON object but got ${json.runtimeType}',
        expectedType: 'OrderItem',
      );
    }
    return fromJson(json, config as SerializationConfig?);
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    OrderItem instance, [
    SerializationConfig? config,
  ]) {
    return OrderItemJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static OrderItem decode(dynamic json, [SerializationConfig? config]) {
    return OrderItemJsonSerializer().fromJson(json, config);
  }
}
