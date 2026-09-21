// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'enum_example.dart';

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
      SerializationUtils.applyFieldRename(
        'orderNumber',
        effectiveConfig.fieldRename,
      ): instance.orderNumber,
      SerializationUtils.applyFieldRename(
        'status',
        effectiveConfig.fieldRename,
      ): instance.status.name,
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
        orderNumber:
            json[SerializationUtils.applyFieldRename(
                  'orderNumber',
                  effectiveConfig.fieldRename,
                )]
                as String,
        status: OrderStatus.values.byName(
          json[SerializationUtils.applyFieldRename(
                'status',
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
