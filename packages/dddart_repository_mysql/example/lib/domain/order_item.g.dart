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
        'createdAt',
        effectiveConfig.fieldRename,
      ): instance.createdAt
          .toIso8601String(),
      SerializationUtils.applyFieldRename('id', effectiveConfig.fieldRename):
          instance.id.toString(),
      SerializationUtils.applyFieldRename(
        'productName',
        effectiveConfig.fieldRename,
      ): instance.productName,
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
      SerializationUtils.applyFieldRename(
        'updatedAt',
        effectiveConfig.fieldRename,
      ): instance.updatedAt
          .toIso8601String(),
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
        createdAt: DateTime.parse(
          json[SerializationUtils.applyFieldRename(
                'createdAt',
                effectiveConfig.fieldRename,
              )]
              as String,
        ),
        id: UuidValue.fromString(
          json[SerializationUtils.applyFieldRename(
                'id',
                effectiveConfig.fieldRename,
              )]
              as String,
        ),
        productName:
            json[SerializationUtils.applyFieldRename(
                  'productName',
                  effectiveConfig.fieldRename,
                )]
                as String,
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
        updatedAt: DateTime.parse(
          json[SerializationUtils.applyFieldRename(
                'updatedAt',
                effectiveConfig.fieldRename,
              )]
              as String,
        ),
      );
    } catch (e, stackTrace) {
      throw DeserializationException(
        'Failed to deserialize OrderItem',
        expectedType: 'OrderItem',
      );
    }
  }

  @override
  String serialize(OrderItem object, [dynamic config]) {
    try {
      return jsonEncode(toJson(object, config as SerializationConfig?));
    } catch (_) {
      throw SerializationException(
        'Failed to serialize OrderItem',
        expectedType: 'OrderItem',
      );
    }
  }

  @override
  OrderItem deserialize(String data, [dynamic config]) {
    try {
      final json = jsonDecode(data);
      if (json is! Map<String, dynamic>) {
        throw DeserializationException(
          'Expected JSON object',
          expectedType: 'OrderItem',
        );
      }
      return fromJson(json, config as SerializationConfig?);
    } on DeserializationException {
      rethrow;
    } catch (_) {
      throw DeserializationException(
        'Invalid JSON input',
        expectedType: 'OrderItem',
      );
    }
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
