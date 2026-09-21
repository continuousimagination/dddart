// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'integration_test_models.dart';

// **************************************************************************
// SerializableGenerator
// **************************************************************************

class SimpleProductJsonSerializer implements JsonSerializer<SimpleProduct> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  SimpleProductJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig = defaultConfig ?? const SerializationConfig();

  @override
  Map<String, dynamic> toJson(
    SimpleProduct instance, [
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
      SerializationUtils.applyFieldRename('name', effectiveConfig.fieldRename):
          instance.name,
      SerializationUtils.applyFieldRename('price', effectiveConfig.fieldRename):
          instance.price,
    };
    return json;
  }

  @override
  SimpleProduct fromJson(dynamic json, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize SimpleProduct from null JSON',
        expectedType: 'SimpleProduct',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'SimpleProduct',
      );
    }
    try {
      return SimpleProduct(
        name:
            json[SerializationUtils.applyFieldRename(
                  'name',
                  effectiveConfig.fieldRename,
                )]
                as String,
        price:
            (json[SerializationUtils.applyFieldRename(
                  'price',
                  effectiveConfig.fieldRename,
                )]
                is int
            ? (json[SerializationUtils.applyFieldRename(
                        'price',
                        effectiveConfig.fieldRename,
                      )]
                      as int)
                  .toDouble()
            : json[SerializationUtils.applyFieldRename(
                    'price',
                    effectiveConfig.fieldRename,
                  )]
                  as double),
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
        'Failed to deserialize SimpleProduct',
        expectedType: 'SimpleProduct',
      );
    }
  }

  @override
  String serialize(SimpleProduct object, [dynamic config]) {
    try {
      return jsonEncode(toJson(object, config as SerializationConfig?));
    } catch (_) {
      throw SerializationException(
        'Failed to serialize SimpleProduct',
        expectedType: 'SimpleProduct',
      );
    }
  }

  @override
  SimpleProduct deserialize(String data, [dynamic config]) {
    try {
      final json = jsonDecode(data);
      if (json is! Map<String, dynamic>) {
        throw DeserializationException(
          'Expected JSON object',
          expectedType: 'SimpleProduct',
        );
      }
      return fromJson(json, config as SerializationConfig?);
    } on DeserializationException {
      rethrow;
    } catch (_) {
      throw DeserializationException(
        'Invalid JSON input',
        expectedType: 'SimpleProduct',
      );
    }
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    SimpleProduct instance, [
    SerializationConfig? config,
  ]) {
    return SimpleProductJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static SimpleProduct decode(dynamic json, [SerializationConfig? config]) {
    return SimpleProductJsonSerializer().fromJson(json, config);
  }
}

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
        'customerName',
        effectiveConfig.fieldRename,
      ): instance.customerName,
      SerializationUtils.applyFieldRename(
        'items',
        effectiveConfig.fieldRename,
      ): instance.items
          .map(
            (item) => OrderItemJsonSerializer().toJson(item, effectiveConfig),
          )
          .toList(),
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
        customerName:
            json[SerializationUtils.applyFieldRename(
                  'customerName',
                  effectiveConfig.fieldRename,
                )]
                as String,
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
        'Failed to deserialize Order',
        expectedType: 'Order',
      );
    }
  }

  @override
  String serialize(Order object, [dynamic config]) {
    try {
      return jsonEncode(toJson(object, config as SerializationConfig?));
    } catch (_) {
      throw SerializationException(
        'Failed to serialize Order',
        expectedType: 'Order',
      );
    }
  }

  @override
  Order deserialize(String data, [dynamic config]) {
    try {
      final json = jsonDecode(data);
      if (json is! Map<String, dynamic>) {
        throw DeserializationException(
          'Expected JSON object',
          expectedType: 'Order',
        );
      }
      return fromJson(json, config as SerializationConfig?);
    } on DeserializationException {
      rethrow;
    } catch (_) {
      throw DeserializationException(
        'Invalid JSON input',
        expectedType: 'Order',
      );
    }
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
      ): instance.unitPrice,
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
        unitPrice:
            (json[SerializationUtils.applyFieldRename(
                  'unitPrice',
                  effectiveConfig.fieldRename,
                )]
                is int
            ? (json[SerializationUtils.applyFieldRename(
                        'unitPrice',
                        effectiveConfig.fieldRename,
                      )]
                      as int)
                  .toDouble()
            : json[SerializationUtils.applyFieldRename(
                    'unitPrice',
                    effectiveConfig.fieldRename,
                  )]
                  as double),
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
      SerializationUtils.applyFieldRename('email', effectiveConfig.fieldRename):
          EmailJsonSerializer().toJson(instance.email, effectiveConfig),
      SerializationUtils.applyFieldRename('name', effectiveConfig.fieldRename):
          instance.name,
      SerializationUtils.applyFieldRename(
        'shippingAddress',
        effectiveConfig.fieldRename,
      ): AddressJsonSerializer().toJson(
        instance.shippingAddress,
        effectiveConfig,
      ),
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
        email: EmailJsonSerializer().fromJson(
          json[SerializationUtils.applyFieldRename(
                'email',
                effectiveConfig.fieldRename,
              )]
              as Map<String, dynamic>,
          effectiveConfig,
        ),
        name:
            json[SerializationUtils.applyFieldRename(
                  'name',
                  effectiveConfig.fieldRename,
                )]
                as String,
        shippingAddress: AddressJsonSerializer().fromJson(
          json[SerializationUtils.applyFieldRename(
                'shippingAddress',
                effectiveConfig.fieldRename,
              )]
              as Map<String, dynamic>,
          effectiveConfig,
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

class EmailJsonSerializer implements JsonSerializer<Email> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  EmailJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig = defaultConfig ?? const SerializationConfig();

  @override
  Map<String, dynamic> toJson(Email instance, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    final json = <String, dynamic>{
      SerializationUtils.applyFieldRename('value', effectiveConfig.fieldRename):
          instance.value,
    };
    return json;
  }

  @override
  Email fromJson(dynamic json, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize Email from null JSON',
        expectedType: 'Email',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'Email',
      );
    }
    try {
      return Email(
        value:
            json[SerializationUtils.applyFieldRename(
                  'value',
                  effectiveConfig.fieldRename,
                )]
                as String,
      );
    } catch (e, stackTrace) {
      throw DeserializationException(
        'Failed to deserialize Email',
        expectedType: 'Email',
      );
    }
  }

  @override
  String serialize(Email object, [dynamic config]) {
    try {
      return jsonEncode(toJson(object, config as SerializationConfig?));
    } catch (_) {
      throw SerializationException(
        'Failed to serialize Email',
        expectedType: 'Email',
      );
    }
  }

  @override
  Email deserialize(String data, [dynamic config]) {
    try {
      final json = jsonDecode(data);
      if (json is! Map<String, dynamic>) {
        throw DeserializationException(
          'Expected JSON object',
          expectedType: 'Email',
        );
      }
      return fromJson(json, config as SerializationConfig?);
    } on DeserializationException {
      rethrow;
    } catch (_) {
      throw DeserializationException(
        'Invalid JSON input',
        expectedType: 'Email',
      );
    }
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    Email instance, [
    SerializationConfig? config,
  ]) {
    return EmailJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static Email decode(dynamic json, [SerializationConfig? config]) {
    return EmailJsonSerializer().fromJson(json, config);
  }
}

class AddressJsonSerializer implements JsonSerializer<Address> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  AddressJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig = defaultConfig ?? const SerializationConfig();

  @override
  Map<String, dynamic> toJson(Address instance, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    final json = <String, dynamic>{
      SerializationUtils.applyFieldRename('city', effectiveConfig.fieldRename):
          instance.city,
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
    } catch (e, stackTrace) {
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
        'Invalid JSON input',
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

class ProductJsonSerializer implements JsonSerializer<Product> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  ProductJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig = defaultConfig ?? const SerializationConfig();

  @override
  Map<String, dynamic> toJson(Product instance, [SerializationConfig? config]) {
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
      SerializationUtils.applyFieldRename('name', effectiveConfig.fieldRename):
          instance.name,
      SerializationUtils.applyFieldRename('price', effectiveConfig.fieldRename):
          instance.price,
    };
    return json;
  }

  @override
  Product fromJson(dynamic json, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize Product from null JSON',
        expectedType: 'Product',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'Product',
      );
    }
    try {
      return Product(
        name:
            json[SerializationUtils.applyFieldRename(
                  'name',
                  effectiveConfig.fieldRename,
                )]
                as String,
        price:
            (json[SerializationUtils.applyFieldRename(
                  'price',
                  effectiveConfig.fieldRename,
                )]
                is int
            ? (json[SerializationUtils.applyFieldRename(
                        'price',
                        effectiveConfig.fieldRename,
                      )]
                      as int)
                  .toDouble()
            : json[SerializationUtils.applyFieldRename(
                    'price',
                    effectiveConfig.fieldRename,
                  )]
                  as double),
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
        'Failed to deserialize Product',
        expectedType: 'Product',
      );
    }
  }

  @override
  String serialize(Product object, [dynamic config]) {
    try {
      return jsonEncode(toJson(object, config as SerializationConfig?));
    } catch (_) {
      throw SerializationException(
        'Failed to serialize Product',
        expectedType: 'Product',
      );
    }
  }

  @override
  Product deserialize(String data, [dynamic config]) {
    try {
      final json = jsonDecode(data);
      if (json is! Map<String, dynamic>) {
        throw DeserializationException(
          'Expected JSON object',
          expectedType: 'Product',
        );
      }
      return fromJson(json, config as SerializationConfig?);
    } on DeserializationException {
      rethrow;
    } catch (_) {
      throw DeserializationException(
        'Invalid JSON input',
        expectedType: 'Product',
      );
    }
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    Product instance, [
    SerializationConfig? config,
  ]) {
    return ProductJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static Product decode(dynamic json, [SerializationConfig? config]) {
    return ProductJsonSerializer().fromJson(json, config);
  }
}

class MoneyJsonSerializer implements JsonSerializer<Money> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  MoneyJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig = defaultConfig ?? const SerializationConfig();

  @override
  Map<String, dynamic> toJson(Money instance, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    final json = <String, dynamic>{
      SerializationUtils.applyFieldRename(
        'amount',
        effectiveConfig.fieldRename,
      ): instance.amount,
      SerializationUtils.applyFieldRename(
        'currency',
        effectiveConfig.fieldRename,
      ): instance.currency,
    };
    return json;
  }

  @override
  Money fromJson(dynamic json, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize Money from null JSON',
        expectedType: 'Money',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'Money',
      );
    }
    try {
      return Money(
        amount:
            (json[SerializationUtils.applyFieldRename(
                  'amount',
                  effectiveConfig.fieldRename,
                )]
                is int
            ? (json[SerializationUtils.applyFieldRename(
                        'amount',
                        effectiveConfig.fieldRename,
                      )]
                      as int)
                  .toDouble()
            : json[SerializationUtils.applyFieldRename(
                    'amount',
                    effectiveConfig.fieldRename,
                  )]
                  as double),
        currency:
            json[SerializationUtils.applyFieldRename(
                  'currency',
                  effectiveConfig.fieldRename,
                )]
                as String,
      );
    } catch (e, stackTrace) {
      throw DeserializationException(
        'Failed to deserialize Money',
        expectedType: 'Money',
      );
    }
  }

  @override
  String serialize(Money object, [dynamic config]) {
    try {
      return jsonEncode(toJson(object, config as SerializationConfig?));
    } catch (_) {
      throw SerializationException(
        'Failed to serialize Money',
        expectedType: 'Money',
      );
    }
  }

  @override
  Money deserialize(String data, [dynamic config]) {
    try {
      final json = jsonDecode(data);
      if (json is! Map<String, dynamic>) {
        throw DeserializationException(
          'Expected JSON object',
          expectedType: 'Money',
        );
      }
      return fromJson(json, config as SerializationConfig?);
    } on DeserializationException {
      rethrow;
    } catch (_) {
      throw DeserializationException(
        'Invalid JSON input',
        expectedType: 'Money',
      );
    }
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    Money instance, [
    SerializationConfig? config,
  ]) {
    return MoneyJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static Money decode(dynamic json, [SerializationConfig? config]) {
    return MoneyJsonSerializer().fromJson(json, config);
  }
}

class TestPrimitiveCollectionsJsonSerializer
    implements JsonSerializer<TestPrimitiveCollections> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  TestPrimitiveCollectionsJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig = defaultConfig ?? const SerializationConfig();

  @override
  Map<String, dynamic> toJson(
    TestPrimitiveCollections instance, [
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
        'favoriteNumbers',
        effectiveConfig.fieldRename,
      ): instance.favoriteNumbers,
      SerializationUtils.applyFieldRename('name', effectiveConfig.fieldRename):
          instance.name,
      SerializationUtils.applyFieldRename(
        'scoresByGame',
        effectiveConfig.fieldRename,
      ): instance.scoresByGame,
      SerializationUtils.applyFieldRename('tags', effectiveConfig.fieldRename):
          instance.tags.toList(),
    };
    return json;
  }

  @override
  TestPrimitiveCollections fromJson(
    dynamic json, [
    SerializationConfig? config,
  ]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize TestPrimitiveCollections from null JSON',
        expectedType: 'TestPrimitiveCollections',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'TestPrimitiveCollections',
      );
    }
    try {
      return TestPrimitiveCollections(
        favoriteNumbers:
            (json[SerializationUtils.applyFieldRename(
                      'favoriteNumbers',
                      effectiveConfig.fieldRename,
                    )]
                    as List)
                .map((item) => item as int)
                .toList(),
        name:
            json[SerializationUtils.applyFieldRename(
                  'name',
                  effectiveConfig.fieldRename,
                )]
                as String,
        scoresByGame: Map<String, dynamic>.from(
          json[SerializationUtils.applyFieldRename(
                'scoresByGame',
                effectiveConfig.fieldRename,
              )]
              as Map,
        ).map((key, value) => MapEntry(key, value as int)),
        tags:
            (json[SerializationUtils.applyFieldRename(
                      'tags',
                      effectiveConfig.fieldRename,
                    )]
                    as List)
                .map((item) => item as String)
                .toSet(),
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
        'Failed to deserialize TestPrimitiveCollections',
        expectedType: 'TestPrimitiveCollections',
      );
    }
  }

  @override
  String serialize(TestPrimitiveCollections object, [dynamic config]) {
    try {
      return jsonEncode(toJson(object, config as SerializationConfig?));
    } catch (_) {
      throw SerializationException(
        'Failed to serialize TestPrimitiveCollections',
        expectedType: 'TestPrimitiveCollections',
      );
    }
  }

  @override
  TestPrimitiveCollections deserialize(String data, [dynamic config]) {
    try {
      final json = jsonDecode(data);
      if (json is! Map<String, dynamic>) {
        throw DeserializationException(
          'Expected JSON object',
          expectedType: 'TestPrimitiveCollections',
        );
      }
      return fromJson(json, config as SerializationConfig?);
    } on DeserializationException {
      rethrow;
    } catch (_) {
      throw DeserializationException(
        'Invalid JSON input',
        expectedType: 'TestPrimitiveCollections',
      );
    }
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    TestPrimitiveCollections instance, [
    SerializationConfig? config,
  ]) {
    return TestPrimitiveCollectionsJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static TestPrimitiveCollections decode(
    dynamic json, [
    SerializationConfig? config,
  ]) {
    return TestPrimitiveCollectionsJsonSerializer().fromJson(json, config);
  }
}

class TestValueCollectionsJsonSerializer
    implements JsonSerializer<TestValueCollections> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  TestValueCollectionsJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig = defaultConfig ?? const SerializationConfig();

  @override
  Map<String, dynamic> toJson(
    TestValueCollections instance, [
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
        'addresses',
        effectiveConfig.fieldRename,
      ): instance.addresses
          .map((item) => AddressJsonSerializer().toJson(item, effectiveConfig))
          .toList(),
      SerializationUtils.applyFieldRename('name', effectiveConfig.fieldRename):
          instance.name,
      SerializationUtils.applyFieldRename(
        'payments',
        effectiveConfig.fieldRename,
      ): instance.payments
          .map((item) => MoneyJsonSerializer().toJson(item, effectiveConfig))
          .toList(),
      SerializationUtils.applyFieldRename(
        'pricesByProduct',
        effectiveConfig.fieldRename,
      ): instance.pricesByProduct.map(
        (key, value) =>
            MapEntry(key, MoneyJsonSerializer().toJson(value, effectiveConfig)),
      ),
    };
    return json;
  }

  @override
  TestValueCollections fromJson(dynamic json, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize TestValueCollections from null JSON',
        expectedType: 'TestValueCollections',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'TestValueCollections',
      );
    }
    try {
      return TestValueCollections(
        addresses:
            (json[SerializationUtils.applyFieldRename(
                      'addresses',
                      effectiveConfig.fieldRename,
                    )]
                    as List)
                .map(
                  (item) => AddressJsonSerializer().fromJson(
                    item as Map<String, dynamic>,
                    effectiveConfig,
                  ),
                )
                .toSet(),
        name:
            json[SerializationUtils.applyFieldRename(
                  'name',
                  effectiveConfig.fieldRename,
                )]
                as String,
        payments:
            (json[SerializationUtils.applyFieldRename(
                      'payments',
                      effectiveConfig.fieldRename,
                    )]
                    as List)
                .map(
                  (item) => MoneyJsonSerializer().fromJson(
                    item as Map<String, dynamic>,
                    effectiveConfig,
                  ),
                )
                .toList(),
        pricesByProduct:
            Map<String, dynamic>.from(
              json[SerializationUtils.applyFieldRename(
                    'pricesByProduct',
                    effectiveConfig.fieldRename,
                  )]
                  as Map,
            ).map(
              (key, value) => MapEntry(
                key,
                MoneyJsonSerializer().fromJson(
                  value as Map<String, dynamic>,
                  effectiveConfig,
                ),
              ),
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
        'Failed to deserialize TestValueCollections',
        expectedType: 'TestValueCollections',
      );
    }
  }

  @override
  String serialize(TestValueCollections object, [dynamic config]) {
    try {
      return jsonEncode(toJson(object, config as SerializationConfig?));
    } catch (_) {
      throw SerializationException(
        'Failed to serialize TestValueCollections',
        expectedType: 'TestValueCollections',
      );
    }
  }

  @override
  TestValueCollections deserialize(String data, [dynamic config]) {
    try {
      final json = jsonDecode(data);
      if (json is! Map<String, dynamic>) {
        throw DeserializationException(
          'Expected JSON object',
          expectedType: 'TestValueCollections',
        );
      }
      return fromJson(json, config as SerializationConfig?);
    } on DeserializationException {
      rethrow;
    } catch (_) {
      throw DeserializationException(
        'Invalid JSON input',
        expectedType: 'TestValueCollections',
      );
    }
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    TestValueCollections instance, [
    SerializationConfig? config,
  ]) {
    return TestValueCollectionsJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static TestValueCollections decode(
    dynamic json, [
    SerializationConfig? config,
  ]) {
    return TestValueCollectionsJsonSerializer().fromJson(json, config);
  }
}

class TestNullableCollectionsJsonSerializer
    implements JsonSerializer<TestNullableCollections> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  TestNullableCollectionsJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig = defaultConfig ?? const SerializationConfig();

  @override
  Map<String, dynamic> toJson(
    TestNullableCollections instance, [
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
      SerializationUtils.applyFieldRename('name', effectiveConfig.fieldRename):
          instance.name,
      if (instance.optionalNumbers != null || effectiveConfig.includeNullFields)
        SerializationUtils.applyFieldRename(
          'optionalNumbers',
          effectiveConfig.fieldRename,
        ): instance.optionalNumbers != null
            ? instance.optionalNumbers!
            : null,
      if (instance.optionalScores != null || effectiveConfig.includeNullFields)
        SerializationUtils.applyFieldRename(
          'optionalScores',
          effectiveConfig.fieldRename,
        ): instance.optionalScores != null
            ? instance.optionalScores!
            : null,
      if (instance.optionalTags != null || effectiveConfig.includeNullFields)
        SerializationUtils.applyFieldRename(
          'optionalTags',
          effectiveConfig.fieldRename,
        ): instance.optionalTags != null
            ? instance.optionalTags!.toList()
            : null,
    };
    return json;
  }

  @override
  TestNullableCollections fromJson(
    dynamic json, [
    SerializationConfig? config,
  ]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize TestNullableCollections from null JSON',
        expectedType: 'TestNullableCollections',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'TestNullableCollections',
      );
    }
    try {
      return TestNullableCollections(
        name:
            json[SerializationUtils.applyFieldRename(
                  'name',
                  effectiveConfig.fieldRename,
                )]
                as String,
        optionalNumbers:
            json[SerializationUtils.applyFieldRename(
                  'optionalNumbers',
                  effectiveConfig.fieldRename,
                )] !=
                null
            ? (json[SerializationUtils.applyFieldRename(
                        'optionalNumbers',
                        effectiveConfig.fieldRename,
                      )]
                      as List)
                  .map((item) => item as int)
                  .toList()
            : null,
        optionalScores:
            json[SerializationUtils.applyFieldRename(
                  'optionalScores',
                  effectiveConfig.fieldRename,
                )] !=
                null
            ? Map<String, dynamic>.from(
                json[SerializationUtils.applyFieldRename(
                      'optionalScores',
                      effectiveConfig.fieldRename,
                    )]
                    as Map,
              ).map((key, value) => MapEntry(key, value as int))
            : null,
        optionalTags:
            json[SerializationUtils.applyFieldRename(
                  'optionalTags',
                  effectiveConfig.fieldRename,
                )] !=
                null
            ? (json[SerializationUtils.applyFieldRename(
                        'optionalTags',
                        effectiveConfig.fieldRename,
                      )]
                      as List)
                  .map((item) => item as String)
                  .toSet()
            : null,
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
        'Failed to deserialize TestNullableCollections',
        expectedType: 'TestNullableCollections',
      );
    }
  }

  @override
  String serialize(TestNullableCollections object, [dynamic config]) {
    try {
      return jsonEncode(toJson(object, config as SerializationConfig?));
    } catch (_) {
      throw SerializationException(
        'Failed to serialize TestNullableCollections',
        expectedType: 'TestNullableCollections',
      );
    }
  }

  @override
  TestNullableCollections deserialize(String data, [dynamic config]) {
    try {
      final json = jsonDecode(data);
      if (json is! Map<String, dynamic>) {
        throw DeserializationException(
          'Expected JSON object',
          expectedType: 'TestNullableCollections',
        );
      }
      return fromJson(json, config as SerializationConfig?);
    } on DeserializationException {
      rethrow;
    } catch (_) {
      throw DeserializationException(
        'Invalid JSON input',
        expectedType: 'TestNullableCollections',
      );
    }
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    TestNullableCollections instance, [
    SerializationConfig? config,
  ]) {
    return TestNullableCollectionsJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static TestNullableCollections decode(
    dynamic json, [
    SerializationConfig? config,
  ]) {
    return TestNullableCollectionsJsonSerializer().fromJson(json, config);
  }
}

// **************************************************************************
// MysqlRepositoryGenerator
// **************************************************************************

/// Generated MySQL repository for [SimpleProduct] aggregate.
///
/// This class provides CRUD operations with full normalization,
/// multi-table persistence, and value object embedding.
class SimpleProductMysqlRepository implements Repository<SimpleProduct> {
  /// Creates a repository instance.
  ///
  /// [connection] - An open MySQL database connection.
  SimpleProductMysqlRepository(this._connection);

  /// The MySQL database connection.
  final MysqlConnection _connection;

  /// The SQL dialect for MySQL.
  final _dialect = MysqlDialect();

  /// The JSON serializer for SimpleProduct aggregates.
  final _serializer = SimpleProductJsonSerializer();

  /// The table name for SimpleProduct aggregates.
  String get tableName => 'simple_product';

  /// Creates all tables for this aggregate.
  ///
  /// This method should be called once during application
  /// initialization to ensure all required tables exist.
  ///
  /// Uses CREATE TABLE IF NOT EXISTS, so it is safe to call
  /// multiple times.
  Future<void> createTables() async {
    await _connection.transaction(() async {
      // Create table: simple_product
      await _connection.execute('''
CREATE TABLE IF NOT EXISTS simple_product (
  name VARCHAR(255) NOT NULL,
  price DOUBLE NOT NULL,
  id BINARY(16) PRIMARY KEY NOT NULL,
  createdAt DATETIME NOT NULL,
  updatedAt DATETIME NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ''');
    });
  }

  @override
  Future<SimpleProduct> getById(UuidValue id) async {
    return await _connection.transaction(() async {
      try {
        // Query the aggregate root table
        final rows = await _connection.query(
          'SELECT `name`, `price`, BIN_TO_UUID(`id`) as `id`, `createdAt`, `updatedAt` FROM simple_product WHERE id = ?',
          [_dialect.encodeUuid(id)],
        );

        if (rows.isEmpty) {
          throw RepositoryException(
            'SimpleProduct with ID $id not found',
            type: RepositoryExceptionType.notFound,
          );
        }

        final row = rows.first;
        final json = _rowToJson(row);

        return _serializer.fromJson(json);
      } on RepositoryException {
        rethrow;
      } catch (e) {
        throw _mapMysqlException(e, 'getById');
      }
    });
  }

  @override
  Future<void> save(SimpleProduct aggregate) async {
    if (aggregate is VersionedAggregateRoot) {
      throw const RepositoryCapabilityException();
    }
    await _connection.transaction(() async {
      try {
        // Serialize aggregate to JSON
        final json = _serializer.toJson(aggregate);

        // Save aggregate root first (required for foreign key constraints)
        final rootData = _flattenForTable(json, []);
        final columns = rootData.keys.toList();
        final values = columns.map((k) => _encodeValue(rootData[k])).toList();

        final placeholders = List.filled(columns.length, '?').join(', ');
        final updateClauses = columns.map((c) => '$c = VALUES($c)').join(', ');
        await _connection.execute(
          'INSERT INTO simple_product (${columns.join(', ')}) VALUES ($placeholders) '
          'ON DUPLICATE KEY UPDATE $updateClauses',
          values,
        );
      } catch (e) {
        throw _mapMysqlException(e, 'save');
      }
    });
  }

  @override
  Future<void> deleteById(UuidValue id) async {
    await _connection.transaction(() async {
      try {
        // Check if aggregate exists
        final rows = await _connection.query(
          'SELECT BIN_TO_UUID(id) as id FROM simple_product WHERE id = ?',
          [_dialect.encodeUuid(id)],
        );

        if (rows.isEmpty) {
          throw RepositoryException(
            'SimpleProduct with ID $id not found',
            type: RepositoryExceptionType.notFound,
          );
        }

        // Delete aggregate (CASCADE will handle related entities)
        await _connection.execute('DELETE FROM simple_product WHERE id = ?', [
          _dialect.encodeUuid(id),
        ]);
      } on RepositoryException {
        rethrow;
      } catch (e) {
        throw _mapMysqlException(e, 'deleteById');
      }
    });
  }

  /// Flattens JSON for table storage, excluding specified keys.
  Map<String, dynamic> _flattenForTable(
    Map<String, dynamic> json,
    List<String> excludeKeys,
  ) {
    final flattened = <String, dynamic>{};

    for (final entry in json.entries) {
      final key = entry.key;
      if (excludeKeys.contains(key)) continue;

      final value = entry.value;

      if (value is Map<String, dynamic>) {
        // Flatten nested object (value object) with prefix
        for (final nestedEntry in value.entries) {
          flattened['${key}_${nestedEntry.key}'] = nestedEntry.value;
        }
      } else if (value is List) {
        // Skip lists - they're handled separately
        continue;
      } else {
        flattened[key] = value;
      }
    }

    return flattened;
  }

  /// Converts a SQL row to JSON, reconstructing embedded value objects.
  Map<String, dynamic> _rowToJson(Map<String, Object?> row) {
    final json = <String, dynamic>{};
    final processedPrefixes = <String>{};

    for (final entry in row.entries) {
      final key = entry.key;
      final value = entry.value;

      // Check if this is a prefixed column (value object field)
      if (key.contains('_')) {
        final parts = key.split('_');
        if (parts.length >= 2) {
          final prefix = parts[0];

          // Skip if already processed
          if (processedPrefixes.contains(prefix)) continue;

          // Collect all columns with this prefix
          final prefixedColumns = row.entries
              .where((e) => e.key.startsWith('${prefix}_'))
              .toList();

          if (prefixedColumns.isNotEmpty) {
            // Reconstruct value object
            final valueObject = <String, dynamic>{};
            var allNull = true;
            for (final col in prefixedColumns) {
              final fieldName = col.key.substring(prefix.length + 1);
              final decoded = _decodeValue(col.value, fieldName);
              valueObject[fieldName] = decoded;
              if (decoded != null) allNull = false;
            }
            // Only add if not all null (nullable value object)
            json[prefix] = allNull ? null : valueObject;
            processedPrefixes.add(prefix);
            continue;
          }
        }
      }

      // Regular field
      json[key] = _decodeValue(value, key);
    }

    return json;
  }

  /// Maps field names to their Dart types for type-aware encoding/decoding.
  static const Map<String, String> _fieldTypes = {
    'name': 'String',
    'price': 'double',
    'id': 'UuidValue',
    'createdAt': 'DateTime',
    'updatedAt': 'DateTime',
  };

  /// Encodes a value for SQL storage.
  Object? _encodeValue(dynamic value) {
    if (value == null) return null;

    // Handle UUID strings
    if (value is String && value.contains('-') && value.length == 36) {
      try {
        return _dialect.encodeUuid(UuidValue.fromString(value));
      } catch (_) {
        return value;
      }
    }

    // Handle DateTime strings
    if (value is String) {
      final dateTime = DateTime.tryParse(value);
      if (dateTime != null) {
        return _dialect.encodeDateTime(dateTime);
      }
    }

    // Handle booleans
    if (value is bool) {
      return value ? 1 : 0;
    }

    return value;
  }

  /// Decodes a value from SQL storage.
  dynamic _decodeValue(Object? value, String fieldName) {
    if (value == null) return null;

    // Get the Dart type for this field
    final dartType = _fieldTypes[fieldName];

    // UUIDs are returned as strings from BIN_TO_UUID()
    // No special decoding needed for UUID fields

    // Decode DateTimes (DATETIME format)
    if (dartType == 'DateTime') {
      try {
        if (value is DateTime) {
          return value.toIso8601String();
        }
        if (value is String) {
          return _dialect.decodeDateTime(value).toIso8601String();
        }
      } catch (_) {
        return value;
      }
    }

    // Decode booleans (TINYINT(1))
    if (dartType == 'bool' && value is int) {
      return value != 0;
    }

    return value;
  }

  /// Maps MySQL exceptions to RepositoryException types.
  RepositoryException _mapMysqlException(Object error, String operation) {
    final errorMessage = error.toString();

    // Map specific MySQL error patterns to RepositoryExceptionType
    // Error 1062: Duplicate entry
    if (errorMessage.contains('1062') ||
        errorMessage.contains('Duplicate entry')) {
      return RepositoryException(
        'Duplicate key error during $operation: $errorMessage',
        type: RepositoryExceptionType.duplicate,
        cause: error,
      );
    }

    // Error 2003: Connection refused
    // Error 1045: Access denied
    // Error 1049: Unknown database
    if (errorMessage.contains('2003') ||
        errorMessage.contains('1045') ||
        errorMessage.contains('1049') ||
        errorMessage.contains('Connection refused') ||
        errorMessage.contains('Access denied') ||
        errorMessage.contains('Unknown database')) {
      return RepositoryException(
        'Connection error during $operation: $errorMessage',
        type: RepositoryExceptionType.connection,
        cause: error,
      );
    }

    // Error 1205: Lock wait timeout
    // Error 3024: Query timeout
    if (errorMessage.contains('1205') ||
        errorMessage.contains('3024') ||
        errorMessage.contains('timeout')) {
      return RepositoryException(
        'Timeout during $operation: $errorMessage',
        type: RepositoryExceptionType.timeout,
        cause: error,
      );
    }

    return RepositoryException(
      'MySQL error during $operation: $errorMessage',
      type: RepositoryExceptionType.unknown,
      cause: error,
    );
  }
}

/// Generated MySQL repository for [Order] aggregate.
///
/// This class provides CRUD operations with full normalization,
/// multi-table persistence, and value object embedding.
class OrderMysqlRepository implements Repository<Order> {
  /// Creates a repository instance.
  ///
  /// [connection] - An open MySQL database connection.
  OrderMysqlRepository(this._connection);

  /// The MySQL database connection.
  final MysqlConnection _connection;

  /// The SQL dialect for MySQL.
  final _dialect = MysqlDialect();

  /// The JSON serializer for Order aggregates.
  final _serializer = OrderJsonSerializer();

  /// The table name for Order aggregates.
  String get tableName => 'orders';

  /// Creates all tables for this aggregate.
  ///
  /// This method should be called once during application
  /// initialization to ensure all required tables exist.
  ///
  /// Uses CREATE TABLE IF NOT EXISTS, so it is safe to call
  /// multiple times.
  Future<void> createTables() async {
    await _connection.transaction(() async {
      // Create table: orders
      await _connection.execute('''
CREATE TABLE IF NOT EXISTS orders (
  customerName VARCHAR(255) NOT NULL,
  id BINARY(16) PRIMARY KEY NOT NULL,
  createdAt DATETIME NOT NULL,
  updatedAt DATETIME NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ''');

      // Create table: order_item
      await _connection.execute('''
CREATE TABLE IF NOT EXISTS order_item (
  productName VARCHAR(255) NOT NULL,
  quantity BIGINT NOT NULL,
  unitPrice DOUBLE NOT NULL,
  id BINARY(16) PRIMARY KEY NOT NULL,
  createdAt DATETIME NOT NULL,
  updatedAt DATETIME NOT NULL,
  orders_id BINARY(16) NOT NULL,
  _list_position INTEGER NOT NULL,
  FOREIGN KEY (orders_id) REFERENCES `orders`(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ''');
    });
  }

  @override
  Future<Order> getById(UuidValue id) async {
    return await _connection.transaction(() async {
      try {
        // Query the aggregate root table
        final rows = await _connection.query(
          'SELECT `customerName`, BIN_TO_UUID(`id`) as `id`, `createdAt`, `updatedAt` FROM orders WHERE id = ?',
          [_dialect.encodeUuid(id)],
        );

        if (rows.isEmpty) {
          throw RepositoryException(
            'Order with ID $id not found',
            type: RepositoryExceptionType.notFound,
          );
        }

        final row = rows.first;
        final json = _rowToJson(row);

        // Load nested entities
        json['items'] = await _loadOrderItem(id);

        return _serializer.fromJson(json);
      } on RepositoryException {
        rethrow;
      } catch (e) {
        throw _mapMysqlException(e, 'getById');
      }
    });
  }

  @override
  Future<void> save(Order aggregate) async {
    if (aggregate is VersionedAggregateRoot) {
      throw const RepositoryCapabilityException();
    }
    await _connection.transaction(() async {
      try {
        // Serialize aggregate to JSON
        final json = _serializer.toJson(aggregate);

        // Save aggregate root first (required for foreign key constraints)
        final rootData = _flattenForTable(json, ['items']);
        final columns = rootData.keys.toList();
        final values = columns.map((k) => _encodeValue(rootData[k])).toList();

        final placeholders = List.filled(columns.length, '?').join(', ');
        final updateClauses = columns.map((c) => '$c = VALUES($c)').join(', ');
        await _connection.execute(
          'INSERT INTO orders (${columns.join(', ')}) VALUES ($placeholders) '
          'ON DUPLICATE KEY UPDATE $updateClauses',
          values,
        );

        // Save nested entities to their tables
        await _saveOrderItem(aggregate, json);
      } catch (e) {
        throw _mapMysqlException(e, 'save');
      }
    });
  }

  @override
  Future<void> deleteById(UuidValue id) async {
    await _connection.transaction(() async {
      try {
        // Check if aggregate exists
        final rows = await _connection.query(
          'SELECT BIN_TO_UUID(id) as id FROM orders WHERE id = ?',
          [_dialect.encodeUuid(id)],
        );

        if (rows.isEmpty) {
          throw RepositoryException(
            'Order with ID $id not found',
            type: RepositoryExceptionType.notFound,
          );
        }

        // Delete aggregate (CASCADE will handle related entities)
        await _connection.execute('DELETE FROM orders WHERE id = ?', [
          _dialect.encodeUuid(id),
        ]);
      } on RepositoryException {
        rethrow;
      } catch (e) {
        throw _mapMysqlException(e, 'deleteById');
      }
    });
  }

  /// Saves order_item entities.
  Future<void> _saveOrderItem(
    dynamic aggregate,
    Map<String, dynamic> json,
  ) async {
    // Delete existing entities for this aggregate
    await _connection.execute('DELETE FROM order_item WHERE orders_id = ?', [
      _dialect.encodeUuid(aggregate.id),
    ]);

    // Get entities from JSON
    final entitiesJson = json['items'];
    if (entitiesJson == null || entitiesJson is! List) return;

    // Save each entity with position to preserve List order
    for (var i = 0; i < entitiesJson.length; i++) {
      final entityJson = entitiesJson[i];
      if (entityJson is! Map<String, dynamic>) continue;

      // Add parent foreign key
      entityJson['orders_id'] = aggregate.id.toString();

      // Add position to preserve List order
      entityJson['_list_position'] = i;

      // Generate synthetic ID for entity if not present
      if (!entityJson.containsKey('id')) {
        entityJson['id'] = UuidValue.generate().toString();
      }

      // Flatten and save
      final flattened = _flattenForTable(entityJson, []);
      final columns = flattened.keys.toList();
      final values = columns.map((k) => _encodeValue(flattened[k])).toList();

      final placeholders = List.filled(columns.length, '?').join(', ');
      final updateClauses = columns.map((c) => '$c = VALUES($c)').join(', ');
      await _connection.execute(
        'INSERT INTO order_item (${columns.join(', ')}) VALUES ($placeholders) '
        'ON DUPLICATE KEY UPDATE $updateClauses',
        values,
      );
    }
  }

  /// Loads order_item entities for an aggregate.
  Future<List<Map<String, dynamic>>> _loadOrderItem(
    UuidValue aggregateId,
  ) async {
    final rows = await _connection.query(
      'SELECT `productName`, `quantity`, `unitPrice`, BIN_TO_UUID(`id`) as `id`, `createdAt`, `updatedAt`, BIN_TO_UUID(`orders_id`) as `orders_id`, `_list_position` FROM order_item WHERE orders_id = ? ORDER BY _list_position',
      [_dialect.encodeUuid(aggregateId)],
    );

    // Convert rows to JSON and remove the parent FK and position columns
    return rows.map((row) {
      final json = _rowToJson(row);
      json.remove('orders_id');
      json.remove('_list_position');
      return json;
    }).toList();
  }

  /// Flattens JSON for table storage, excluding specified keys.
  Map<String, dynamic> _flattenForTable(
    Map<String, dynamic> json,
    List<String> excludeKeys,
  ) {
    final flattened = <String, dynamic>{};

    for (final entry in json.entries) {
      final key = entry.key;
      if (excludeKeys.contains(key)) continue;

      final value = entry.value;

      if (value is Map<String, dynamic>) {
        // Flatten nested object (value object) with prefix
        for (final nestedEntry in value.entries) {
          flattened['${key}_${nestedEntry.key}'] = nestedEntry.value;
        }
      } else if (value is List) {
        // Skip lists - they're handled separately
        continue;
      } else {
        flattened[key] = value;
      }
    }

    return flattened;
  }

  /// Converts a SQL row to JSON, reconstructing embedded value objects.
  Map<String, dynamic> _rowToJson(Map<String, Object?> row) {
    final json = <String, dynamic>{};
    final processedPrefixes = <String>{};

    for (final entry in row.entries) {
      final key = entry.key;
      final value = entry.value;

      // Check if this is a prefixed column (value object field)
      if (key.contains('_')) {
        final parts = key.split('_');
        if (parts.length >= 2) {
          final prefix = parts[0];

          // Skip if already processed
          if (processedPrefixes.contains(prefix)) continue;

          // Collect all columns with this prefix
          final prefixedColumns = row.entries
              .where((e) => e.key.startsWith('${prefix}_'))
              .toList();

          if (prefixedColumns.isNotEmpty) {
            // Reconstruct value object
            final valueObject = <String, dynamic>{};
            var allNull = true;
            for (final col in prefixedColumns) {
              final fieldName = col.key.substring(prefix.length + 1);
              final decoded = _decodeValue(col.value, fieldName);
              valueObject[fieldName] = decoded;
              if (decoded != null) allNull = false;
            }
            // Only add if not all null (nullable value object)
            json[prefix] = allNull ? null : valueObject;
            processedPrefixes.add(prefix);
            continue;
          }
        }
      }

      // Regular field
      json[key] = _decodeValue(value, key);
    }

    return json;
  }

  /// Maps field names to their Dart types for type-aware encoding/decoding.
  static const Map<String, String> _fieldTypes = {
    'customerName': 'String',
    'id': 'UuidValue',
    'createdAt': 'DateTime',
    'updatedAt': 'DateTime',
  };

  /// Encodes a value for SQL storage.
  Object? _encodeValue(dynamic value) {
    if (value == null) return null;

    // Handle UUID strings
    if (value is String && value.contains('-') && value.length == 36) {
      try {
        return _dialect.encodeUuid(UuidValue.fromString(value));
      } catch (_) {
        return value;
      }
    }

    // Handle DateTime strings
    if (value is String) {
      final dateTime = DateTime.tryParse(value);
      if (dateTime != null) {
        return _dialect.encodeDateTime(dateTime);
      }
    }

    // Handle booleans
    if (value is bool) {
      return value ? 1 : 0;
    }

    return value;
  }

  /// Decodes a value from SQL storage.
  dynamic _decodeValue(Object? value, String fieldName) {
    if (value == null) return null;

    // Get the Dart type for this field
    final dartType = _fieldTypes[fieldName];

    // UUIDs are returned as strings from BIN_TO_UUID()
    // No special decoding needed for UUID fields

    // Decode DateTimes (DATETIME format)
    if (dartType == 'DateTime') {
      try {
        if (value is DateTime) {
          return value.toIso8601String();
        }
        if (value is String) {
          return _dialect.decodeDateTime(value).toIso8601String();
        }
      } catch (_) {
        return value;
      }
    }

    // Decode booleans (TINYINT(1))
    if (dartType == 'bool' && value is int) {
      return value != 0;
    }

    return value;
  }

  /// Maps MySQL exceptions to RepositoryException types.
  RepositoryException _mapMysqlException(Object error, String operation) {
    final errorMessage = error.toString();

    // Map specific MySQL error patterns to RepositoryExceptionType
    // Error 1062: Duplicate entry
    if (errorMessage.contains('1062') ||
        errorMessage.contains('Duplicate entry')) {
      return RepositoryException(
        'Duplicate key error during $operation: $errorMessage',
        type: RepositoryExceptionType.duplicate,
        cause: error,
      );
    }

    // Error 2003: Connection refused
    // Error 1045: Access denied
    // Error 1049: Unknown database
    if (errorMessage.contains('2003') ||
        errorMessage.contains('1045') ||
        errorMessage.contains('1049') ||
        errorMessage.contains('Connection refused') ||
        errorMessage.contains('Access denied') ||
        errorMessage.contains('Unknown database')) {
      return RepositoryException(
        'Connection error during $operation: $errorMessage',
        type: RepositoryExceptionType.connection,
        cause: error,
      );
    }

    // Error 1205: Lock wait timeout
    // Error 3024: Query timeout
    if (errorMessage.contains('1205') ||
        errorMessage.contains('3024') ||
        errorMessage.contains('timeout')) {
      return RepositoryException(
        'Timeout during $operation: $errorMessage',
        type: RepositoryExceptionType.timeout,
        cause: error,
      );
    }

    return RepositoryException(
      'MySQL error during $operation: $errorMessage',
      type: RepositoryExceptionType.unknown,
      cause: error,
    );
  }
}

/// Generated MySQL repository for [Customer] aggregate.
///
/// This class provides CRUD operations with full normalization,
/// multi-table persistence, and value object embedding.
class CustomerMysqlRepository implements Repository<Customer> {
  /// Creates a repository instance.
  ///
  /// [connection] - An open MySQL database connection.
  CustomerMysqlRepository(this._connection);

  /// The MySQL database connection.
  final MysqlConnection _connection;

  /// The SQL dialect for MySQL.
  final _dialect = MysqlDialect();

  /// The JSON serializer for Customer aggregates.
  final _serializer = CustomerJsonSerializer();

  /// The table name for Customer aggregates.
  String get tableName => 'customer';

  /// Creates all tables for this aggregate.
  ///
  /// This method should be called once during application
  /// initialization to ensure all required tables exist.
  ///
  /// Uses CREATE TABLE IF NOT EXISTS, so it is safe to call
  /// multiple times.
  Future<void> createTables() async {
    await _connection.transaction(() async {
      // Create table: customer
      await _connection.execute('''
CREATE TABLE IF NOT EXISTS customer (
  name VARCHAR(255) NOT NULL,
  email_value VARCHAR(255) NOT NULL,
  shippingAddress_street VARCHAR(255) NOT NULL,
  shippingAddress_city VARCHAR(255) NOT NULL,
  shippingAddress_state VARCHAR(255) NOT NULL,
  shippingAddress_zipCode VARCHAR(255) NOT NULL,
  billingAddress_street VARCHAR(255),
  billingAddress_city VARCHAR(255),
  billingAddress_state VARCHAR(255),
  billingAddress_zipCode VARCHAR(255),
  id BINARY(16) PRIMARY KEY NOT NULL,
  createdAt DATETIME NOT NULL,
  updatedAt DATETIME NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ''');
    });
  }

  @override
  Future<Customer> getById(UuidValue id) async {
    return await _connection.transaction(() async {
      try {
        // Query the aggregate root table
        final rows = await _connection.query(
          'SELECT `name`, `email_value`, `shippingAddress_street`, `shippingAddress_city`, `shippingAddress_state`, `shippingAddress_zipCode`, `billingAddress_street`, `billingAddress_city`, `billingAddress_state`, `billingAddress_zipCode`, BIN_TO_UUID(`id`) as `id`, `createdAt`, `updatedAt` FROM customer WHERE id = ?',
          [_dialect.encodeUuid(id)],
        );

        if (rows.isEmpty) {
          throw RepositoryException(
            'Customer with ID $id not found',
            type: RepositoryExceptionType.notFound,
          );
        }

        final row = rows.first;
        final json = _rowToJson(row);

        return _serializer.fromJson(json);
      } on RepositoryException {
        rethrow;
      } catch (e) {
        throw _mapMysqlException(e, 'getById');
      }
    });
  }

  @override
  Future<void> save(Customer aggregate) async {
    if (aggregate is VersionedAggregateRoot) {
      throw const RepositoryCapabilityException();
    }
    await _connection.transaction(() async {
      try {
        // Serialize aggregate to JSON
        final json = _serializer.toJson(aggregate);

        // Save aggregate root first (required for foreign key constraints)
        final rootData = _flattenForTable(json, []);
        final columns = rootData.keys.toList();
        final values = columns.map((k) => _encodeValue(rootData[k])).toList();

        final placeholders = List.filled(columns.length, '?').join(', ');
        final updateClauses = columns.map((c) => '$c = VALUES($c)').join(', ');
        await _connection.execute(
          'INSERT INTO customer (${columns.join(', ')}) VALUES ($placeholders) '
          'ON DUPLICATE KEY UPDATE $updateClauses',
          values,
        );
      } catch (e) {
        throw _mapMysqlException(e, 'save');
      }
    });
  }

  @override
  Future<void> deleteById(UuidValue id) async {
    await _connection.transaction(() async {
      try {
        // Check if aggregate exists
        final rows = await _connection.query(
          'SELECT BIN_TO_UUID(id) as id FROM customer WHERE id = ?',
          [_dialect.encodeUuid(id)],
        );

        if (rows.isEmpty) {
          throw RepositoryException(
            'Customer with ID $id not found',
            type: RepositoryExceptionType.notFound,
          );
        }

        // Delete aggregate (CASCADE will handle related entities)
        await _connection.execute('DELETE FROM customer WHERE id = ?', [
          _dialect.encodeUuid(id),
        ]);
      } on RepositoryException {
        rethrow;
      } catch (e) {
        throw _mapMysqlException(e, 'deleteById');
      }
    });
  }

  /// Flattens JSON for table storage, excluding specified keys.
  Map<String, dynamic> _flattenForTable(
    Map<String, dynamic> json,
    List<String> excludeKeys,
  ) {
    final flattened = <String, dynamic>{};

    for (final entry in json.entries) {
      final key = entry.key;
      if (excludeKeys.contains(key)) continue;

      final value = entry.value;

      if (value is Map<String, dynamic>) {
        // Flatten nested object (value object) with prefix
        for (final nestedEntry in value.entries) {
          flattened['${key}_${nestedEntry.key}'] = nestedEntry.value;
        }
      } else if (value is List) {
        // Skip lists - they're handled separately
        continue;
      } else {
        flattened[key] = value;
      }
    }

    return flattened;
  }

  /// Converts a SQL row to JSON, reconstructing embedded value objects.
  Map<String, dynamic> _rowToJson(Map<String, Object?> row) {
    final json = <String, dynamic>{};
    final processedPrefixes = <String>{};

    for (final entry in row.entries) {
      final key = entry.key;
      final value = entry.value;

      // Check if this is a prefixed column (value object field)
      if (key.contains('_')) {
        final parts = key.split('_');
        if (parts.length >= 2) {
          final prefix = parts[0];

          // Skip if already processed
          if (processedPrefixes.contains(prefix)) continue;

          // Collect all columns with this prefix
          final prefixedColumns = row.entries
              .where((e) => e.key.startsWith('${prefix}_'))
              .toList();

          if (prefixedColumns.isNotEmpty) {
            // Reconstruct value object
            final valueObject = <String, dynamic>{};
            var allNull = true;
            for (final col in prefixedColumns) {
              final fieldName = col.key.substring(prefix.length + 1);
              final decoded = _decodeValue(col.value, fieldName);
              valueObject[fieldName] = decoded;
              if (decoded != null) allNull = false;
            }
            // Only add if not all null (nullable value object)
            json[prefix] = allNull ? null : valueObject;
            processedPrefixes.add(prefix);
            continue;
          }
        }
      }

      // Regular field
      json[key] = _decodeValue(value, key);
    }

    return json;
  }

  /// Maps field names to their Dart types for type-aware encoding/decoding.
  static const Map<String, String> _fieldTypes = {
    'name': 'String',
    'email_value': 'String',
    'shippingAddress_street': 'String',
    'shippingAddress_city': 'String',
    'shippingAddress_state': 'String',
    'shippingAddress_zipCode': 'String',
    'billingAddress_street': 'String',
    'billingAddress_city': 'String',
    'billingAddress_state': 'String',
    'billingAddress_zipCode': 'String',
    'id': 'UuidValue',
    'createdAt': 'DateTime',
    'updatedAt': 'DateTime',
  };

  /// Encodes a value for SQL storage.
  Object? _encodeValue(dynamic value) {
    if (value == null) return null;

    // Handle UUID strings
    if (value is String && value.contains('-') && value.length == 36) {
      try {
        return _dialect.encodeUuid(UuidValue.fromString(value));
      } catch (_) {
        return value;
      }
    }

    // Handle DateTime strings
    if (value is String) {
      final dateTime = DateTime.tryParse(value);
      if (dateTime != null) {
        return _dialect.encodeDateTime(dateTime);
      }
    }

    // Handle booleans
    if (value is bool) {
      return value ? 1 : 0;
    }

    return value;
  }

  /// Decodes a value from SQL storage.
  dynamic _decodeValue(Object? value, String fieldName) {
    if (value == null) return null;

    // Get the Dart type for this field
    final dartType = _fieldTypes[fieldName];

    // UUIDs are returned as strings from BIN_TO_UUID()
    // No special decoding needed for UUID fields

    // Decode DateTimes (DATETIME format)
    if (dartType == 'DateTime') {
      try {
        if (value is DateTime) {
          return value.toIso8601String();
        }
        if (value is String) {
          return _dialect.decodeDateTime(value).toIso8601String();
        }
      } catch (_) {
        return value;
      }
    }

    // Decode booleans (TINYINT(1))
    if (dartType == 'bool' && value is int) {
      return value != 0;
    }

    return value;
  }

  /// Maps MySQL exceptions to RepositoryException types.
  RepositoryException _mapMysqlException(Object error, String operation) {
    final errorMessage = error.toString();

    // Map specific MySQL error patterns to RepositoryExceptionType
    // Error 1062: Duplicate entry
    if (errorMessage.contains('1062') ||
        errorMessage.contains('Duplicate entry')) {
      return RepositoryException(
        'Duplicate key error during $operation: $errorMessage',
        type: RepositoryExceptionType.duplicate,
        cause: error,
      );
    }

    // Error 2003: Connection refused
    // Error 1045: Access denied
    // Error 1049: Unknown database
    if (errorMessage.contains('2003') ||
        errorMessage.contains('1045') ||
        errorMessage.contains('1049') ||
        errorMessage.contains('Connection refused') ||
        errorMessage.contains('Access denied') ||
        errorMessage.contains('Unknown database')) {
      return RepositoryException(
        'Connection error during $operation: $errorMessage',
        type: RepositoryExceptionType.connection,
        cause: error,
      );
    }

    // Error 1205: Lock wait timeout
    // Error 3024: Query timeout
    if (errorMessage.contains('1205') ||
        errorMessage.contains('3024') ||
        errorMessage.contains('timeout')) {
      return RepositoryException(
        'Timeout during $operation: $errorMessage',
        type: RepositoryExceptionType.timeout,
        cause: error,
      );
    }

    return RepositoryException(
      'MySQL error during $operation: $errorMessage',
      type: RepositoryExceptionType.unknown,
      cause: error,
    );
  }
}

/// Generated abstract base MySQL repository for [Product] aggregate.
///
/// This abstract class implements the base Repository<Product> methods
/// and declares custom methods as abstract. Extend this class and
/// implement the abstract methods.
abstract class ProductMysqlRepositoryBase implements CustomProductRepository {
  /// Creates a repository instance.
  ///
  /// [connection] - An open MySQL database connection.
  ProductMysqlRepositoryBase(this._connection);

  /// The MySQL database connection (protected).
  final MysqlConnection _connection;

  /// The SQL dialect for MySQL (protected).
  final _dialect = MysqlDialect();

  /// The JSON serializer (protected).
  final _serializer = ProductJsonSerializer();

  /// The table name for Product aggregates.
  String get tableName => 'product';

  /// Creates all tables for this aggregate.
  ///
  /// This method should be called once during application
  /// initialization to ensure all required tables exist.
  ///
  /// Uses CREATE TABLE IF NOT EXISTS, so it is safe to call
  /// multiple times.
  Future<void> createTables() async {
    await _connection.transaction(() async {
      // Create table: product
      await _connection.execute('''
CREATE TABLE IF NOT EXISTS product (
  name VARCHAR(255) NOT NULL,
  price DOUBLE NOT NULL,
  id BINARY(16) PRIMARY KEY NOT NULL,
  createdAt DATETIME NOT NULL,
  updatedAt DATETIME NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ''');
    });
  }

  @override
  Future<Product> getById(UuidValue id) async {
    return await _connection.transaction(() async {
      try {
        // Query the aggregate root table
        final rows = await _connection.query(
          'SELECT `name`, `price`, BIN_TO_UUID(`id`) as `id`, `createdAt`, `updatedAt` FROM product WHERE id = ?',
          [_dialect.encodeUuid(id)],
        );

        if (rows.isEmpty) {
          throw RepositoryException(
            'Product with ID $id not found',
            type: RepositoryExceptionType.notFound,
          );
        }

        final row = rows.first;
        final json = _rowToJson(row);

        return _serializer.fromJson(json);
      } on RepositoryException {
        rethrow;
      } catch (e) {
        throw _mapMysqlException(e, 'getById');
      }
    });
  }

  @override
  Future<void> save(Product aggregate) async {
    if (aggregate is VersionedAggregateRoot) {
      throw const RepositoryCapabilityException();
    }
    await _connection.transaction(() async {
      try {
        // Serialize aggregate to JSON
        final json = _serializer.toJson(aggregate);

        // Save aggregate root first (required for foreign key constraints)
        final rootData = _flattenForTable(json, []);
        final columns = rootData.keys.toList();
        final values = columns.map((k) => _encodeValue(rootData[k])).toList();

        final placeholders = List.filled(columns.length, '?').join(', ');
        final updateClauses = columns.map((c) => '$c = VALUES($c)').join(', ');
        await _connection.execute(
          'INSERT INTO product (${columns.join(', ')}) VALUES ($placeholders) '
          'ON DUPLICATE KEY UPDATE $updateClauses',
          values,
        );
      } catch (e) {
        throw _mapMysqlException(e, 'save');
      }
    });
  }

  @override
  Future<void> deleteById(UuidValue id) async {
    await _connection.transaction(() async {
      try {
        // Check if aggregate exists
        final rows = await _connection.query(
          'SELECT BIN_TO_UUID(id) as id FROM product WHERE id = ?',
          [_dialect.encodeUuid(id)],
        );

        if (rows.isEmpty) {
          throw RepositoryException(
            'Product with ID $id not found',
            type: RepositoryExceptionType.notFound,
          );
        }

        // Delete aggregate (CASCADE will handle related entities)
        await _connection.execute('DELETE FROM product WHERE id = ?', [
          _dialect.encodeUuid(id),
        ]);
      } on RepositoryException {
        rethrow;
      } catch (e) {
        throw _mapMysqlException(e, 'deleteById');
      }
    });
  }

  /// Flattens JSON for table storage, excluding specified keys.
  Map<String, dynamic> _flattenForTable(
    Map<String, dynamic> json,
    List<String> excludeKeys,
  ) {
    final flattened = <String, dynamic>{};

    for (final entry in json.entries) {
      final key = entry.key;
      if (excludeKeys.contains(key)) continue;

      final value = entry.value;

      if (value is Map<String, dynamic>) {
        // Flatten nested object (value object) with prefix
        for (final nestedEntry in value.entries) {
          flattened['${key}_${nestedEntry.key}'] = nestedEntry.value;
        }
      } else if (value is List) {
        // Skip lists - they're handled separately
        continue;
      } else {
        flattened[key] = value;
      }
    }

    return flattened;
  }

  /// Converts a SQL row to JSON, reconstructing embedded value objects.
  Map<String, dynamic> _rowToJson(Map<String, Object?> row) {
    final json = <String, dynamic>{};
    final processedPrefixes = <String>{};

    for (final entry in row.entries) {
      final key = entry.key;
      final value = entry.value;

      // Check if this is a prefixed column (value object field)
      if (key.contains('_')) {
        final parts = key.split('_');
        if (parts.length >= 2) {
          final prefix = parts[0];

          // Skip if already processed
          if (processedPrefixes.contains(prefix)) continue;

          // Collect all columns with this prefix
          final prefixedColumns = row.entries
              .where((e) => e.key.startsWith('${prefix}_'))
              .toList();

          if (prefixedColumns.isNotEmpty) {
            // Reconstruct value object
            final valueObject = <String, dynamic>{};
            var allNull = true;
            for (final col in prefixedColumns) {
              final fieldName = col.key.substring(prefix.length + 1);
              final decoded = _decodeValue(col.value, fieldName);
              valueObject[fieldName] = decoded;
              if (decoded != null) allNull = false;
            }
            // Only add if not all null (nullable value object)
            json[prefix] = allNull ? null : valueObject;
            processedPrefixes.add(prefix);
            continue;
          }
        }
      }

      // Regular field
      json[key] = _decodeValue(value, key);
    }

    return json;
  }

  /// Maps field names to their Dart types for type-aware encoding/decoding.
  static const Map<String, String> _fieldTypes = {
    'name': 'String',
    'price': 'double',
    'id': 'UuidValue',
    'createdAt': 'DateTime',
    'updatedAt': 'DateTime',
  };

  /// Encodes a value for SQL storage.
  Object? _encodeValue(dynamic value) {
    if (value == null) return null;

    // Handle UUID strings
    if (value is String && value.contains('-') && value.length == 36) {
      try {
        return _dialect.encodeUuid(UuidValue.fromString(value));
      } catch (_) {
        return value;
      }
    }

    // Handle DateTime strings
    if (value is String) {
      final dateTime = DateTime.tryParse(value);
      if (dateTime != null) {
        return _dialect.encodeDateTime(dateTime);
      }
    }

    // Handle booleans
    if (value is bool) {
      return value ? 1 : 0;
    }

    return value;
  }

  /// Decodes a value from SQL storage.
  dynamic _decodeValue(Object? value, String fieldName) {
    if (value == null) return null;

    // Get the Dart type for this field
    final dartType = _fieldTypes[fieldName];

    // UUIDs are returned as strings from BIN_TO_UUID()
    // No special decoding needed for UUID fields

    // Decode DateTimes (DATETIME format)
    if (dartType == 'DateTime') {
      try {
        if (value is DateTime) {
          return value.toIso8601String();
        }
        if (value is String) {
          return _dialect.decodeDateTime(value).toIso8601String();
        }
      } catch (_) {
        return value;
      }
    }

    // Decode booleans (TINYINT(1))
    if (dartType == 'bool' && value is int) {
      return value != 0;
    }

    return value;
  }

  /// Maps MySQL exceptions to RepositoryException types.
  RepositoryException _mapMysqlException(Object error, String operation) {
    final errorMessage = error.toString();

    // Map specific MySQL error patterns to RepositoryExceptionType
    // Error 1062: Duplicate entry
    if (errorMessage.contains('1062') ||
        errorMessage.contains('Duplicate entry')) {
      return RepositoryException(
        'Duplicate key error during $operation: $errorMessage',
        type: RepositoryExceptionType.duplicate,
        cause: error,
      );
    }

    // Error 2003: Connection refused
    // Error 1045: Access denied
    // Error 1049: Unknown database
    if (errorMessage.contains('2003') ||
        errorMessage.contains('1045') ||
        errorMessage.contains('1049') ||
        errorMessage.contains('Connection refused') ||
        errorMessage.contains('Access denied') ||
        errorMessage.contains('Unknown database')) {
      return RepositoryException(
        'Connection error during $operation: $errorMessage',
        type: RepositoryExceptionType.connection,
        cause: error,
      );
    }

    // Error 1205: Lock wait timeout
    // Error 3024: Query timeout
    if (errorMessage.contains('1205') ||
        errorMessage.contains('3024') ||
        errorMessage.contains('timeout')) {
      return RepositoryException(
        'Timeout during $operation: $errorMessage',
        type: RepositoryExceptionType.timeout,
        cause: error,
      );
    }

    return RepositoryException(
      'MySQL error during $operation: $errorMessage',
      type: RepositoryExceptionType.unknown,
      cause: error,
    );
  }

  // Custom methods (must be implemented by subclass)

  @override
  Future<List<Product>> findByMinPrice(double minPrice);

  @override
  Future<int> countProducts();
}

/// Generated MySQL repository for [TestPrimitiveCollections] aggregate.
///
/// This class provides CRUD operations with full normalization,
/// multi-table persistence, and value object embedding.
class TestPrimitiveCollectionsMysqlRepository
    implements Repository<TestPrimitiveCollections> {
  /// Creates a repository instance.
  ///
  /// [connection] - An open MySQL database connection.
  TestPrimitiveCollectionsMysqlRepository(this._connection);

  /// The MySQL database connection.
  final MysqlConnection _connection;

  /// The SQL dialect for MySQL.
  final _dialect = MysqlDialect();

  /// The JSON serializer for TestPrimitiveCollections aggregates.
  final _serializer = TestPrimitiveCollectionsJsonSerializer();

  /// The table name for TestPrimitiveCollections aggregates.
  String get tableName => 'test_primitive_collections';

  /// Creates all tables for this aggregate.
  ///
  /// This method should be called once during application
  /// initialization to ensure all required tables exist.
  ///
  /// Uses CREATE TABLE IF NOT EXISTS, so it is safe to call
  /// multiple times.
  Future<void> createTables() async {
    await _connection.transaction(() async {
      // Create table: test_primitive_collections
      await _connection.execute('''
CREATE TABLE IF NOT EXISTS test_primitive_collections (
  name VARCHAR(255) NOT NULL,
  id BINARY(16) PRIMARY KEY NOT NULL,
  createdAt DATETIME NOT NULL,
  updatedAt DATETIME NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ''');

      // Create junction table for collection: favoriteNumbers
      await _connection.execute('''
CREATE TABLE IF NOT EXISTS test_primitive_collections_favoriteNumbers_items (
  test_primitive_collections_id BINARY(16) NOT NULL,
  position INT NOT NULL,
  value BIGINT NOT NULL,
  FOREIGN KEY (test_primitive_collections_id) REFERENCES `test_primitive_collections`(id) ON DELETE CASCADE,
  UNIQUE (test_primitive_collections_id, position)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ''');

      // Create junction table for collection: tags
      await _connection.execute('''
CREATE TABLE IF NOT EXISTS test_primitive_collections_tags_items (
  test_primitive_collections_id BINARY(16) NOT NULL,
  value VARCHAR(255) NOT NULL,
  FOREIGN KEY (test_primitive_collections_id) REFERENCES `test_primitive_collections`(id) ON DELETE CASCADE,
  UNIQUE (test_primitive_collections_id, value)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ''');

      // Create junction table for collection: scoresByGame
      await _connection.execute('''
CREATE TABLE IF NOT EXISTS test_primitive_collections_scoresByGame_items (
  test_primitive_collections_id BINARY(16) NOT NULL,
  map_key VARCHAR(255) NOT NULL,
  value BIGINT NOT NULL,
  FOREIGN KEY (test_primitive_collections_id) REFERENCES `test_primitive_collections`(id) ON DELETE CASCADE,
  UNIQUE (test_primitive_collections_id, map_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ''');
    });
  }

  @override
  Future<TestPrimitiveCollections> getById(UuidValue id) async {
    return await _connection.transaction(() async {
      try {
        // Query the aggregate root table
        final rows = await _connection.query(
          'SELECT `name`, BIN_TO_UUID(`id`) as `id`, `createdAt`, `updatedAt` FROM test_primitive_collections WHERE id = ?',
          [_dialect.encodeUuid(id)],
        );

        if (rows.isEmpty) {
          throw RepositoryException(
            'TestPrimitiveCollections with ID $id not found',
            type: RepositoryExceptionType.notFound,
          );
        }

        final row = rows.first;
        final json = _rowToJson(row);

        // Load collections
        json['favoriteNumbers'] = await _loadFavoriteNumbers(id);
        json['tags'] = await _loadTags(id);
        json['scoresByGame'] = await _loadScoresByGame(id);

        return _serializer.fromJson(json);
      } on RepositoryException {
        rethrow;
      } catch (e) {
        throw _mapMysqlException(e, 'getById');
      }
    });
  }

  @override
  Future<void> save(TestPrimitiveCollections aggregate) async {
    if (aggregate is VersionedAggregateRoot) {
      throw const RepositoryCapabilityException();
    }
    await _connection.transaction(() async {
      try {
        // Serialize aggregate to JSON
        final json = _serializer.toJson(aggregate);

        // Save aggregate root first (required for foreign key constraints)
        final rootData = _flattenForTable(json, [
          'favoriteNumbers',
          'tags',
          'scoresByGame',
        ]);
        final columns = rootData.keys.toList();
        final values = columns.map((k) => _encodeValue(rootData[k])).toList();

        final placeholders = List.filled(columns.length, '?').join(', ');
        final updateClauses = columns.map((c) => '$c = VALUES($c)').join(', ');
        await _connection.execute(
          'INSERT INTO test_primitive_collections (${columns.join(', ')}) VALUES ($placeholders) '
          'ON DUPLICATE KEY UPDATE $updateClauses',
          values,
        );

        // Save collections to their junction tables
        await _saveFavoriteNumbers(aggregate.id, json['favoriteNumbers']);
        await _saveTags(aggregate.id, json['tags']);
        await _saveScoresByGame(aggregate.id, json['scoresByGame']);
      } catch (e) {
        throw _mapMysqlException(e, 'save');
      }
    });
  }

  @override
  Future<void> deleteById(UuidValue id) async {
    await _connection.transaction(() async {
      try {
        // Check if aggregate exists
        final rows = await _connection.query(
          'SELECT BIN_TO_UUID(id) as id FROM test_primitive_collections WHERE id = ?',
          [_dialect.encodeUuid(id)],
        );

        if (rows.isEmpty) {
          throw RepositoryException(
            'TestPrimitiveCollections with ID $id not found',
            type: RepositoryExceptionType.notFound,
          );
        }

        // Delete aggregate (CASCADE will handle related entities)
        await _connection.execute(
          'DELETE FROM test_primitive_collections WHERE id = ?',
          [_dialect.encodeUuid(id)],
        );
      } on RepositoryException {
        rethrow;
      } catch (e) {
        throw _mapMysqlException(e, 'deleteById');
      }
    });
  }

  /// Saves the favoriteNumbers collection.
  Future<void> _saveFavoriteNumbers(
    UuidValue aggregateId,
    dynamic collectionValue,
  ) async {
    // Delete existing items
    await _connection.execute(
      'DELETE FROM test_primitive_collections_favoriteNumbers_items WHERE test_primitive_collections_id = ?',
      [_dialect.encodeUuid(aggregateId)],
    );

    // Handle null or empty collections
    if (collectionValue == null) return;

    final items = collectionValue as List;
    if (items.isEmpty) return;

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final values = <Object?>[
        _dialect.encodeUuid(aggregateId),
        i, // position
        _encodeValue(item),
      ];

      await _connection.execute(
        'INSERT INTO test_primitive_collections_favoriteNumbers_items (test_primitive_collections_id, position, value) VALUES (?, ?, ?)',
        values,
      );
    }
  }

  /// Saves the tags collection.
  Future<void> _saveTags(UuidValue aggregateId, dynamic collectionValue) async {
    // Delete existing items
    await _connection.execute(
      'DELETE FROM test_primitive_collections_tags_items WHERE test_primitive_collections_id = ?',
      [_dialect.encodeUuid(aggregateId)],
    );

    // Handle null or empty collections
    if (collectionValue == null) return;

    final items = collectionValue is Set
        ? collectionValue as Set
        : (collectionValue as List).toSet();
    if (items.isEmpty) return;

    for (final item in items) {
      final values = <Object?>[
        _dialect.encodeUuid(aggregateId),
        _encodeValue(item),
      ];

      await _connection.execute(
        'INSERT INTO test_primitive_collections_tags_items (test_primitive_collections_id, value) VALUES (?, ?)',
        values,
      );
    }
  }

  /// Saves the scoresByGame collection.
  Future<void> _saveScoresByGame(
    UuidValue aggregateId,
    dynamic collectionValue,
  ) async {
    // Delete existing items
    await _connection.execute(
      'DELETE FROM test_primitive_collections_scoresByGame_items WHERE test_primitive_collections_id = ?',
      [_dialect.encodeUuid(aggregateId)],
    );

    // Handle null or empty collections
    if (collectionValue == null) return;

    final map = collectionValue as Map;
    if (map.isEmpty) return;

    for (final entry in map.entries) {
      final key = entry.key;
      final value = entry.value;
      final values = <Object?>[
        _dialect.encodeUuid(aggregateId),
        _encodeValue(key), // map_key
        _encodeValue(value),
      ];

      await _connection.execute(
        'INSERT INTO test_primitive_collections_scoresByGame_items (test_primitive_collections_id, map_key, value) VALUES (?, ?, ?)',
        values,
      );
    }
  }

  /// Loads the favoriteNumbers collection.
  Future<dynamic> _loadFavoriteNumbers(UuidValue aggregateId) async {
    final rows = await _connection.query(
      'SELECT position, value FROM test_primitive_collections_favoriteNumbers_items WHERE test_primitive_collections_id = ? ORDER BY position',
      [_dialect.encodeUuid(aggregateId)],
    );

    if (rows.isEmpty) {
      return <dynamic>[];
    }

    final items = <dynamic>[];
    for (final row in rows) {
      items.add(_decodeValue(row['value'], 'value'));
    }
    return items;
  }

  /// Loads the tags collection.
  Future<dynamic> _loadTags(UuidValue aggregateId) async {
    final rows = await _connection.query(
      'SELECT value FROM test_primitive_collections_tags_items WHERE test_primitive_collections_id = ?',
      [_dialect.encodeUuid(aggregateId)],
    );

    if (rows.isEmpty) {
      return <dynamic>[]; // Sets are serialized as Lists
    }

    final items = <dynamic>{};
    for (final row in rows) {
      items.add(_decodeValue(row['value'], 'value'));
    }
    return items.toList(); // Convert to List for JSON serialization
  }

  /// Loads the scoresByGame collection.
  Future<dynamic> _loadScoresByGame(UuidValue aggregateId) async {
    final rows = await _connection.query(
      'SELECT map_key, value FROM test_primitive_collections_scoresByGame_items WHERE test_primitive_collections_id = ?',
      [_dialect.encodeUuid(aggregateId)],
    );

    if (rows.isEmpty) {
      return <dynamic, dynamic>{};
    }

    final map = <dynamic, dynamic>{};
    for (final row in rows) {
      final key = _decodeValue(row['map_key'], 'map_key');
      final value = _decodeValue(row['value'], 'value');
      map[key] = value;
    }
    return map;
  }

  /// Flattens JSON for table storage, excluding specified keys.
  Map<String, dynamic> _flattenForTable(
    Map<String, dynamic> json,
    List<String> excludeKeys,
  ) {
    final flattened = <String, dynamic>{};

    for (final entry in json.entries) {
      final key = entry.key;
      if (excludeKeys.contains(key)) continue;

      final value = entry.value;

      if (value is Map<String, dynamic>) {
        // Flatten nested object (value object) with prefix
        for (final nestedEntry in value.entries) {
          flattened['${key}_${nestedEntry.key}'] = nestedEntry.value;
        }
      } else if (value is List) {
        // Skip lists - they're handled separately
        continue;
      } else {
        flattened[key] = value;
      }
    }

    return flattened;
  }

  /// Converts a SQL row to JSON, reconstructing embedded value objects.
  Map<String, dynamic> _rowToJson(Map<String, Object?> row) {
    final json = <String, dynamic>{};
    final processedPrefixes = <String>{};

    for (final entry in row.entries) {
      final key = entry.key;
      final value = entry.value;

      // Check if this is a prefixed column (value object field)
      if (key.contains('_')) {
        final parts = key.split('_');
        if (parts.length >= 2) {
          final prefix = parts[0];

          // Skip if already processed
          if (processedPrefixes.contains(prefix)) continue;

          // Collect all columns with this prefix
          final prefixedColumns = row.entries
              .where((e) => e.key.startsWith('${prefix}_'))
              .toList();

          if (prefixedColumns.isNotEmpty) {
            // Reconstruct value object
            final valueObject = <String, dynamic>{};
            var allNull = true;
            for (final col in prefixedColumns) {
              final fieldName = col.key.substring(prefix.length + 1);
              final decoded = _decodeValue(col.value, fieldName);
              valueObject[fieldName] = decoded;
              if (decoded != null) allNull = false;
            }
            // Only add if not all null (nullable value object)
            json[prefix] = allNull ? null : valueObject;
            processedPrefixes.add(prefix);
            continue;
          }
        }
      }

      // Regular field
      json[key] = _decodeValue(value, key);
    }

    return json;
  }

  /// Maps field names to their Dart types for type-aware encoding/decoding.
  static const Map<String, String> _fieldTypes = {
    'name': 'String',
    'id': 'UuidValue',
    'createdAt': 'DateTime',
    'updatedAt': 'DateTime',
  };

  /// Encodes a value for SQL storage.
  Object? _encodeValue(dynamic value) {
    if (value == null) return null;

    // Handle UUID strings
    if (value is String && value.contains('-') && value.length == 36) {
      try {
        return _dialect.encodeUuid(UuidValue.fromString(value));
      } catch (_) {
        return value;
      }
    }

    // Handle DateTime strings
    if (value is String) {
      final dateTime = DateTime.tryParse(value);
      if (dateTime != null) {
        return _dialect.encodeDateTime(dateTime);
      }
    }

    // Handle booleans
    if (value is bool) {
      return value ? 1 : 0;
    }

    return value;
  }

  /// Decodes a value from SQL storage.
  dynamic _decodeValue(Object? value, String fieldName) {
    if (value == null) return null;

    // Get the Dart type for this field
    final dartType = _fieldTypes[fieldName];

    // UUIDs are returned as strings from BIN_TO_UUID()
    // No special decoding needed for UUID fields

    // Decode DateTimes (DATETIME format)
    if (dartType == 'DateTime') {
      try {
        if (value is DateTime) {
          return value.toIso8601String();
        }
        if (value is String) {
          return _dialect.decodeDateTime(value).toIso8601String();
        }
      } catch (_) {
        return value;
      }
    }

    // Decode booleans (TINYINT(1))
    if (dartType == 'bool' && value is int) {
      return value != 0;
    }

    return value;
  }

  /// Maps MySQL exceptions to RepositoryException types.
  RepositoryException _mapMysqlException(Object error, String operation) {
    final errorMessage = error.toString();

    // Map specific MySQL error patterns to RepositoryExceptionType
    // Error 1062: Duplicate entry
    if (errorMessage.contains('1062') ||
        errorMessage.contains('Duplicate entry')) {
      return RepositoryException(
        'Duplicate key error during $operation: $errorMessage',
        type: RepositoryExceptionType.duplicate,
        cause: error,
      );
    }

    // Error 2003: Connection refused
    // Error 1045: Access denied
    // Error 1049: Unknown database
    if (errorMessage.contains('2003') ||
        errorMessage.contains('1045') ||
        errorMessage.contains('1049') ||
        errorMessage.contains('Connection refused') ||
        errorMessage.contains('Access denied') ||
        errorMessage.contains('Unknown database')) {
      return RepositoryException(
        'Connection error during $operation: $errorMessage',
        type: RepositoryExceptionType.connection,
        cause: error,
      );
    }

    // Error 1205: Lock wait timeout
    // Error 3024: Query timeout
    if (errorMessage.contains('1205') ||
        errorMessage.contains('3024') ||
        errorMessage.contains('timeout')) {
      return RepositoryException(
        'Timeout during $operation: $errorMessage',
        type: RepositoryExceptionType.timeout,
        cause: error,
      );
    }

    return RepositoryException(
      'MySQL error during $operation: $errorMessage',
      type: RepositoryExceptionType.unknown,
      cause: error,
    );
  }
}

/// Generated MySQL repository for [TestValueCollections] aggregate.
///
/// This class provides CRUD operations with full normalization,
/// multi-table persistence, and value object embedding.
class TestValueCollectionsMysqlRepository
    implements Repository<TestValueCollections> {
  /// Creates a repository instance.
  ///
  /// [connection] - An open MySQL database connection.
  TestValueCollectionsMysqlRepository(this._connection);

  /// The MySQL database connection.
  final MysqlConnection _connection;

  /// The SQL dialect for MySQL.
  final _dialect = MysqlDialect();

  /// The JSON serializer for TestValueCollections aggregates.
  final _serializer = TestValueCollectionsJsonSerializer();

  /// The table name for TestValueCollections aggregates.
  String get tableName => 'test_value_collections';

  /// Creates all tables for this aggregate.
  ///
  /// This method should be called once during application
  /// initialization to ensure all required tables exist.
  ///
  /// Uses CREATE TABLE IF NOT EXISTS, so it is safe to call
  /// multiple times.
  Future<void> createTables() async {
    await _connection.transaction(() async {
      // Create table: test_value_collections
      await _connection.execute('''
CREATE TABLE IF NOT EXISTS test_value_collections (
  name VARCHAR(255) NOT NULL,
  id BINARY(16) PRIMARY KEY NOT NULL,
  createdAt DATETIME NOT NULL,
  updatedAt DATETIME NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ''');

      // Create junction table for collection: payments
      await _connection.execute('''
CREATE TABLE IF NOT EXISTS test_value_collections_payments_items (
  test_value_collections_id BINARY(16) NOT NULL,
  position INT NOT NULL,
  amount DOUBLE NOT NULL,
  currency VARCHAR(255) NOT NULL,
  FOREIGN KEY (test_value_collections_id) REFERENCES `test_value_collections`(id) ON DELETE CASCADE,
  UNIQUE (test_value_collections_id, position)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ''');

      // Create junction table for collection: addresses
      await _connection.execute('''
CREATE TABLE IF NOT EXISTS test_value_collections_addresses_items (
  test_value_collections_id BINARY(16) NOT NULL,
  street VARCHAR(255) NOT NULL,
  city VARCHAR(255) NOT NULL,
  state VARCHAR(255) NOT NULL,
  zipCode VARCHAR(255) NOT NULL,
  FOREIGN KEY (test_value_collections_id) REFERENCES `test_value_collections`(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ''');

      // Create junction table for collection: pricesByProduct
      await _connection.execute('''
CREATE TABLE IF NOT EXISTS test_value_collections_pricesByProduct_items (
  test_value_collections_id BINARY(16) NOT NULL,
  map_key VARCHAR(255) NOT NULL,
  amount DOUBLE NOT NULL,
  currency VARCHAR(255) NOT NULL,
  FOREIGN KEY (test_value_collections_id) REFERENCES `test_value_collections`(id) ON DELETE CASCADE,
  UNIQUE (test_value_collections_id, map_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ''');
    });
  }

  @override
  Future<TestValueCollections> getById(UuidValue id) async {
    return await _connection.transaction(() async {
      try {
        // Query the aggregate root table
        final rows = await _connection.query(
          'SELECT `name`, BIN_TO_UUID(`id`) as `id`, `createdAt`, `updatedAt` FROM test_value_collections WHERE id = ?',
          [_dialect.encodeUuid(id)],
        );

        if (rows.isEmpty) {
          throw RepositoryException(
            'TestValueCollections with ID $id not found',
            type: RepositoryExceptionType.notFound,
          );
        }

        final row = rows.first;
        final json = _rowToJson(row);

        // Load collections
        json['payments'] = await _loadPayments(id);
        json['addresses'] = await _loadAddresses(id);
        json['pricesByProduct'] = await _loadPricesByProduct(id);

        return _serializer.fromJson(json);
      } on RepositoryException {
        rethrow;
      } catch (e) {
        throw _mapMysqlException(e, 'getById');
      }
    });
  }

  @override
  Future<void> save(TestValueCollections aggregate) async {
    if (aggregate is VersionedAggregateRoot) {
      throw const RepositoryCapabilityException();
    }
    await _connection.transaction(() async {
      try {
        // Serialize aggregate to JSON
        final json = _serializer.toJson(aggregate);

        // Save aggregate root first (required for foreign key constraints)
        final rootData = _flattenForTable(json, [
          'payments',
          'addresses',
          'pricesByProduct',
        ]);
        final columns = rootData.keys.toList();
        final values = columns.map((k) => _encodeValue(rootData[k])).toList();

        final placeholders = List.filled(columns.length, '?').join(', ');
        final updateClauses = columns.map((c) => '$c = VALUES($c)').join(', ');
        await _connection.execute(
          'INSERT INTO test_value_collections (${columns.join(', ')}) VALUES ($placeholders) '
          'ON DUPLICATE KEY UPDATE $updateClauses',
          values,
        );

        // Save collections to their junction tables
        await _savePayments(aggregate.id, json['payments']);
        await _saveAddresses(aggregate.id, json['addresses']);
        await _savePricesByProduct(aggregate.id, json['pricesByProduct']);
      } catch (e) {
        throw _mapMysqlException(e, 'save');
      }
    });
  }

  @override
  Future<void> deleteById(UuidValue id) async {
    await _connection.transaction(() async {
      try {
        // Check if aggregate exists
        final rows = await _connection.query(
          'SELECT BIN_TO_UUID(id) as id FROM test_value_collections WHERE id = ?',
          [_dialect.encodeUuid(id)],
        );

        if (rows.isEmpty) {
          throw RepositoryException(
            'TestValueCollections with ID $id not found',
            type: RepositoryExceptionType.notFound,
          );
        }

        // Delete aggregate (CASCADE will handle related entities)
        await _connection.execute(
          'DELETE FROM test_value_collections WHERE id = ?',
          [_dialect.encodeUuid(id)],
        );
      } on RepositoryException {
        rethrow;
      } catch (e) {
        throw _mapMysqlException(e, 'deleteById');
      }
    });
  }

  /// Saves the payments collection.
  Future<void> _savePayments(
    UuidValue aggregateId,
    dynamic collectionValue,
  ) async {
    // Delete existing items
    await _connection.execute(
      'DELETE FROM test_value_collections_payments_items WHERE test_value_collections_id = ?',
      [_dialect.encodeUuid(aggregateId)],
    );

    // Handle null or empty collections
    if (collectionValue == null) return;

    final items = collectionValue as List;
    if (items.isEmpty) return;

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final values = <Object?>[
        _dialect.encodeUuid(aggregateId),
        i, // position
      ];

      // Flatten value object fields
      if (item is Map<String, dynamic>) {
        final columns = ['test_value_collections_id', 'position'];
        for (final key in item.keys) {
          columns.add(key);
          values.add(_encodeValue(item[key]));
        }

        final placeholders = List.filled(columns.length, '?').join(', ');
        await _connection.execute(
          'INSERT INTO test_value_collections_payments_items (${columns.join(', ')}) VALUES ($placeholders)',
          values,
        );
      }
    }
  }

  /// Saves the addresses collection.
  Future<void> _saveAddresses(
    UuidValue aggregateId,
    dynamic collectionValue,
  ) async {
    // Delete existing items
    await _connection.execute(
      'DELETE FROM test_value_collections_addresses_items WHERE test_value_collections_id = ?',
      [_dialect.encodeUuid(aggregateId)],
    );

    // Handle null or empty collections
    if (collectionValue == null) return;

    final items = collectionValue is Set
        ? collectionValue as Set
        : (collectionValue as List).toSet();
    if (items.isEmpty) return;

    for (final item in items) {
      final values = <Object?>[_dialect.encodeUuid(aggregateId)];

      // Flatten value object fields
      if (item is Map<String, dynamic>) {
        final columns = ['test_value_collections_id'];
        for (final key in item.keys) {
          columns.add(key);
          values.add(_encodeValue(item[key]));
        }

        final placeholders = List.filled(columns.length, '?').join(', ');
        await _connection.execute(
          'INSERT INTO test_value_collections_addresses_items (${columns.join(', ')}) VALUES ($placeholders)',
          values,
        );
      }
    }
  }

  /// Saves the pricesByProduct collection.
  Future<void> _savePricesByProduct(
    UuidValue aggregateId,
    dynamic collectionValue,
  ) async {
    // Delete existing items
    await _connection.execute(
      'DELETE FROM test_value_collections_pricesByProduct_items WHERE test_value_collections_id = ?',
      [_dialect.encodeUuid(aggregateId)],
    );

    // Handle null or empty collections
    if (collectionValue == null) return;

    final map = collectionValue as Map;
    if (map.isEmpty) return;

    for (final entry in map.entries) {
      final key = entry.key;
      final value = entry.value;
      final values = <Object?>[
        _dialect.encodeUuid(aggregateId),
        _encodeValue(key), // map_key
      ];

      // Flatten value object fields
      if (value is Map<String, dynamic>) {
        final columns = ['test_value_collections_id', 'map_key'];
        for (final valueKey in value.keys) {
          columns.add(valueKey);
          values.add(_encodeValue(value[valueKey]));
        }

        final placeholders = List.filled(columns.length, '?').join(', ');
        await _connection.execute(
          'INSERT INTO test_value_collections_pricesByProduct_items (${columns.join(', ')}) VALUES ($placeholders)',
          values,
        );
      }
    }
  }

  /// Loads the payments collection.
  Future<dynamic> _loadPayments(UuidValue aggregateId) async {
    final rows = await _connection.query(
      'SELECT position, amount, currency FROM test_value_collections_payments_items WHERE test_value_collections_id = ? ORDER BY position',
      [_dialect.encodeUuid(aggregateId)],
    );

    if (rows.isEmpty) {
      return <dynamic>[];
    }

    final items = <dynamic>[];
    for (final row in rows) {
      // Reconstruct value object from flattened columns
      final valueObject = <String, dynamic>{};
      for (final entry in row.entries) {
        // Skip position, map_key, and binary UUID columns (parent FK)
        if (entry.key != 'position' &&
            entry.key != 'map_key' &&
            !entry.key.endsWith('_id') &&
            entry.value.runtimeType.toString() != 'Uint8List') {
          valueObject[entry.key] = _decodeValue(entry.value, entry.key);
        }
      }
      items.add(valueObject);
    }
    return items;
  }

  /// Loads the addresses collection.
  Future<dynamic> _loadAddresses(UuidValue aggregateId) async {
    final rows = await _connection.query(
      'SELECT street, city, state, zipCode FROM test_value_collections_addresses_items WHERE test_value_collections_id = ?',
      [_dialect.encodeUuid(aggregateId)],
    );

    if (rows.isEmpty) {
      return <dynamic>[]; // Sets are serialized as Lists
    }

    final items = <dynamic>{};
    for (final row in rows) {
      // Reconstruct value object from flattened columns
      final valueObject = <String, dynamic>{};
      for (final entry in row.entries) {
        // Skip binary UUID columns (parent FK)
        if (!entry.key.endsWith('_id') &&
            entry.value.runtimeType.toString() != 'Uint8List') {
          valueObject[entry.key] = _decodeValue(entry.value, entry.key);
        }
      }
      items.add(valueObject);
    }
    return items.toList(); // Convert to List for JSON serialization
  }

  /// Loads the pricesByProduct collection.
  Future<dynamic> _loadPricesByProduct(UuidValue aggregateId) async {
    final rows = await _connection.query(
      'SELECT map_key, amount, currency FROM test_value_collections_pricesByProduct_items WHERE test_value_collections_id = ?',
      [_dialect.encodeUuid(aggregateId)],
    );

    if (rows.isEmpty) {
      return <dynamic, dynamic>{};
    }

    final map = <dynamic, dynamic>{};
    for (final row in rows) {
      final key = _decodeValue(row['map_key'], 'map_key');
      // Reconstruct value object from flattened columns
      final valueObject = <String, dynamic>{};
      for (final entry in row.entries) {
        // Skip map_key and binary UUID columns (parent FK)
        if (entry.key != 'map_key' &&
            !entry.key.endsWith('_id') &&
            entry.value.runtimeType.toString() != 'Uint8List') {
          valueObject[entry.key] = _decodeValue(entry.value, entry.key);
        }
      }
      map[key] = valueObject;
    }
    return map;
  }

  /// Flattens JSON for table storage, excluding specified keys.
  Map<String, dynamic> _flattenForTable(
    Map<String, dynamic> json,
    List<String> excludeKeys,
  ) {
    final flattened = <String, dynamic>{};

    for (final entry in json.entries) {
      final key = entry.key;
      if (excludeKeys.contains(key)) continue;

      final value = entry.value;

      if (value is Map<String, dynamic>) {
        // Flatten nested object (value object) with prefix
        for (final nestedEntry in value.entries) {
          flattened['${key}_${nestedEntry.key}'] = nestedEntry.value;
        }
      } else if (value is List) {
        // Skip lists - they're handled separately
        continue;
      } else {
        flattened[key] = value;
      }
    }

    return flattened;
  }

  /// Converts a SQL row to JSON, reconstructing embedded value objects.
  Map<String, dynamic> _rowToJson(Map<String, Object?> row) {
    final json = <String, dynamic>{};
    final processedPrefixes = <String>{};

    for (final entry in row.entries) {
      final key = entry.key;
      final value = entry.value;

      // Check if this is a prefixed column (value object field)
      if (key.contains('_')) {
        final parts = key.split('_');
        if (parts.length >= 2) {
          final prefix = parts[0];

          // Skip if already processed
          if (processedPrefixes.contains(prefix)) continue;

          // Collect all columns with this prefix
          final prefixedColumns = row.entries
              .where((e) => e.key.startsWith('${prefix}_'))
              .toList();

          if (prefixedColumns.isNotEmpty) {
            // Reconstruct value object
            final valueObject = <String, dynamic>{};
            var allNull = true;
            for (final col in prefixedColumns) {
              final fieldName = col.key.substring(prefix.length + 1);
              final decoded = _decodeValue(col.value, fieldName);
              valueObject[fieldName] = decoded;
              if (decoded != null) allNull = false;
            }
            // Only add if not all null (nullable value object)
            json[prefix] = allNull ? null : valueObject;
            processedPrefixes.add(prefix);
            continue;
          }
        }
      }

      // Regular field
      json[key] = _decodeValue(value, key);
    }

    return json;
  }

  /// Maps field names to their Dart types for type-aware encoding/decoding.
  static const Map<String, String> _fieldTypes = {
    'name': 'String',
    'id': 'UuidValue',
    'createdAt': 'DateTime',
    'updatedAt': 'DateTime',
  };

  /// Encodes a value for SQL storage.
  Object? _encodeValue(dynamic value) {
    if (value == null) return null;

    // Handle UUID strings
    if (value is String && value.contains('-') && value.length == 36) {
      try {
        return _dialect.encodeUuid(UuidValue.fromString(value));
      } catch (_) {
        return value;
      }
    }

    // Handle DateTime strings
    if (value is String) {
      final dateTime = DateTime.tryParse(value);
      if (dateTime != null) {
        return _dialect.encodeDateTime(dateTime);
      }
    }

    // Handle booleans
    if (value is bool) {
      return value ? 1 : 0;
    }

    return value;
  }

  /// Decodes a value from SQL storage.
  dynamic _decodeValue(Object? value, String fieldName) {
    if (value == null) return null;

    // Get the Dart type for this field
    final dartType = _fieldTypes[fieldName];

    // UUIDs are returned as strings from BIN_TO_UUID()
    // No special decoding needed for UUID fields

    // Decode DateTimes (DATETIME format)
    if (dartType == 'DateTime') {
      try {
        if (value is DateTime) {
          return value.toIso8601String();
        }
        if (value is String) {
          return _dialect.decodeDateTime(value).toIso8601String();
        }
      } catch (_) {
        return value;
      }
    }

    // Decode booleans (TINYINT(1))
    if (dartType == 'bool' && value is int) {
      return value != 0;
    }

    return value;
  }

  /// Maps MySQL exceptions to RepositoryException types.
  RepositoryException _mapMysqlException(Object error, String operation) {
    final errorMessage = error.toString();

    // Map specific MySQL error patterns to RepositoryExceptionType
    // Error 1062: Duplicate entry
    if (errorMessage.contains('1062') ||
        errorMessage.contains('Duplicate entry')) {
      return RepositoryException(
        'Duplicate key error during $operation: $errorMessage',
        type: RepositoryExceptionType.duplicate,
        cause: error,
      );
    }

    // Error 2003: Connection refused
    // Error 1045: Access denied
    // Error 1049: Unknown database
    if (errorMessage.contains('2003') ||
        errorMessage.contains('1045') ||
        errorMessage.contains('1049') ||
        errorMessage.contains('Connection refused') ||
        errorMessage.contains('Access denied') ||
        errorMessage.contains('Unknown database')) {
      return RepositoryException(
        'Connection error during $operation: $errorMessage',
        type: RepositoryExceptionType.connection,
        cause: error,
      );
    }

    // Error 1205: Lock wait timeout
    // Error 3024: Query timeout
    if (errorMessage.contains('1205') ||
        errorMessage.contains('3024') ||
        errorMessage.contains('timeout')) {
      return RepositoryException(
        'Timeout during $operation: $errorMessage',
        type: RepositoryExceptionType.timeout,
        cause: error,
      );
    }

    return RepositoryException(
      'MySQL error during $operation: $errorMessage',
      type: RepositoryExceptionType.unknown,
      cause: error,
    );
  }
}

/// Generated MySQL repository for [TestNullableCollections] aggregate.
///
/// This class provides CRUD operations with full normalization,
/// multi-table persistence, and value object embedding.
class TestNullableCollectionsMysqlRepository
    implements Repository<TestNullableCollections> {
  /// Creates a repository instance.
  ///
  /// [connection] - An open MySQL database connection.
  TestNullableCollectionsMysqlRepository(this._connection);

  /// The MySQL database connection.
  final MysqlConnection _connection;

  /// The SQL dialect for MySQL.
  final _dialect = MysqlDialect();

  /// The JSON serializer for TestNullableCollections aggregates.
  final _serializer = TestNullableCollectionsJsonSerializer();

  /// The table name for TestNullableCollections aggregates.
  String get tableName => 'test_nullable_collections';

  /// Creates all tables for this aggregate.
  ///
  /// This method should be called once during application
  /// initialization to ensure all required tables exist.
  ///
  /// Uses CREATE TABLE IF NOT EXISTS, so it is safe to call
  /// multiple times.
  Future<void> createTables() async {
    await _connection.transaction(() async {
      // Create table: test_nullable_collections
      await _connection.execute('''
CREATE TABLE IF NOT EXISTS test_nullable_collections (
  name VARCHAR(255) NOT NULL,
  id BINARY(16) PRIMARY KEY NOT NULL,
  createdAt DATETIME NOT NULL,
  updatedAt DATETIME NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ''');

      // Create junction table for collection: optionalNumbers
      await _connection.execute('''
CREATE TABLE IF NOT EXISTS test_nullable_collections_optionalNumbers_items (
  test_nullable_collections_id BINARY(16) NOT NULL,
  position INT NOT NULL,
  value BIGINT NOT NULL,
  FOREIGN KEY (test_nullable_collections_id) REFERENCES `test_nullable_collections`(id) ON DELETE CASCADE,
  UNIQUE (test_nullable_collections_id, position)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ''');

      // Create junction table for collection: optionalTags
      await _connection.execute('''
CREATE TABLE IF NOT EXISTS test_nullable_collections_optionalTags_items (
  test_nullable_collections_id BINARY(16) NOT NULL,
  value VARCHAR(255) NOT NULL,
  FOREIGN KEY (test_nullable_collections_id) REFERENCES `test_nullable_collections`(id) ON DELETE CASCADE,
  UNIQUE (test_nullable_collections_id, value)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ''');

      // Create junction table for collection: optionalScores
      await _connection.execute('''
CREATE TABLE IF NOT EXISTS test_nullable_collections_optionalScores_items (
  test_nullable_collections_id BINARY(16) NOT NULL,
  map_key VARCHAR(255) NOT NULL,
  value BIGINT NOT NULL,
  FOREIGN KEY (test_nullable_collections_id) REFERENCES `test_nullable_collections`(id) ON DELETE CASCADE,
  UNIQUE (test_nullable_collections_id, map_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ''');
    });
  }

  @override
  Future<TestNullableCollections> getById(UuidValue id) async {
    return await _connection.transaction(() async {
      try {
        // Query the aggregate root table
        final rows = await _connection.query(
          'SELECT `name`, BIN_TO_UUID(`id`) as `id`, `createdAt`, `updatedAt` FROM test_nullable_collections WHERE id = ?',
          [_dialect.encodeUuid(id)],
        );

        if (rows.isEmpty) {
          throw RepositoryException(
            'TestNullableCollections with ID $id not found',
            type: RepositoryExceptionType.notFound,
          );
        }

        final row = rows.first;
        final json = _rowToJson(row);

        // Load collections
        json['optionalNumbers'] = await _loadOptionalNumbers(id);
        json['optionalTags'] = await _loadOptionalTags(id);
        json['optionalScores'] = await _loadOptionalScores(id);

        return _serializer.fromJson(json);
      } on RepositoryException {
        rethrow;
      } catch (e) {
        throw _mapMysqlException(e, 'getById');
      }
    });
  }

  @override
  Future<void> save(TestNullableCollections aggregate) async {
    if (aggregate is VersionedAggregateRoot) {
      throw const RepositoryCapabilityException();
    }
    await _connection.transaction(() async {
      try {
        // Serialize aggregate to JSON
        final json = _serializer.toJson(aggregate);

        // Save aggregate root first (required for foreign key constraints)
        final rootData = _flattenForTable(json, [
          'optionalNumbers',
          'optionalTags',
          'optionalScores',
        ]);
        final columns = rootData.keys.toList();
        final values = columns.map((k) => _encodeValue(rootData[k])).toList();

        final placeholders = List.filled(columns.length, '?').join(', ');
        final updateClauses = columns.map((c) => '$c = VALUES($c)').join(', ');
        await _connection.execute(
          'INSERT INTO test_nullable_collections (${columns.join(', ')}) VALUES ($placeholders) '
          'ON DUPLICATE KEY UPDATE $updateClauses',
          values,
        );

        // Save collections to their junction tables
        await _saveOptionalNumbers(aggregate.id, json['optionalNumbers']);
        await _saveOptionalTags(aggregate.id, json['optionalTags']);
        await _saveOptionalScores(aggregate.id, json['optionalScores']);
      } catch (e) {
        throw _mapMysqlException(e, 'save');
      }
    });
  }

  @override
  Future<void> deleteById(UuidValue id) async {
    await _connection.transaction(() async {
      try {
        // Check if aggregate exists
        final rows = await _connection.query(
          'SELECT BIN_TO_UUID(id) as id FROM test_nullable_collections WHERE id = ?',
          [_dialect.encodeUuid(id)],
        );

        if (rows.isEmpty) {
          throw RepositoryException(
            'TestNullableCollections with ID $id not found',
            type: RepositoryExceptionType.notFound,
          );
        }

        // Delete aggregate (CASCADE will handle related entities)
        await _connection.execute(
          'DELETE FROM test_nullable_collections WHERE id = ?',
          [_dialect.encodeUuid(id)],
        );
      } on RepositoryException {
        rethrow;
      } catch (e) {
        throw _mapMysqlException(e, 'deleteById');
      }
    });
  }

  /// Saves the optionalNumbers collection.
  Future<void> _saveOptionalNumbers(
    UuidValue aggregateId,
    dynamic collectionValue,
  ) async {
    // Delete existing items
    await _connection.execute(
      'DELETE FROM test_nullable_collections_optionalNumbers_items WHERE test_nullable_collections_id = ?',
      [_dialect.encodeUuid(aggregateId)],
    );

    // Handle null or empty collections
    if (collectionValue == null) return;

    final items = collectionValue as List;
    if (items.isEmpty) return;

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final values = <Object?>[
        _dialect.encodeUuid(aggregateId),
        i, // position
        _encodeValue(item),
      ];

      await _connection.execute(
        'INSERT INTO test_nullable_collections_optionalNumbers_items (test_nullable_collections_id, position, value) VALUES (?, ?, ?)',
        values,
      );
    }
  }

  /// Saves the optionalTags collection.
  Future<void> _saveOptionalTags(
    UuidValue aggregateId,
    dynamic collectionValue,
  ) async {
    // Delete existing items
    await _connection.execute(
      'DELETE FROM test_nullable_collections_optionalTags_items WHERE test_nullable_collections_id = ?',
      [_dialect.encodeUuid(aggregateId)],
    );

    // Handle null or empty collections
    if (collectionValue == null) return;

    final items = collectionValue is Set
        ? collectionValue as Set
        : (collectionValue as List).toSet();
    if (items.isEmpty) return;

    for (final item in items) {
      final values = <Object?>[
        _dialect.encodeUuid(aggregateId),
        _encodeValue(item),
      ];

      await _connection.execute(
        'INSERT INTO test_nullable_collections_optionalTags_items (test_nullable_collections_id, value) VALUES (?, ?)',
        values,
      );
    }
  }

  /// Saves the optionalScores collection.
  Future<void> _saveOptionalScores(
    UuidValue aggregateId,
    dynamic collectionValue,
  ) async {
    // Delete existing items
    await _connection.execute(
      'DELETE FROM test_nullable_collections_optionalScores_items WHERE test_nullable_collections_id = ?',
      [_dialect.encodeUuid(aggregateId)],
    );

    // Handle null or empty collections
    if (collectionValue == null) return;

    final map = collectionValue as Map;
    if (map.isEmpty) return;

    for (final entry in map.entries) {
      final key = entry.key;
      final value = entry.value;
      final values = <Object?>[
        _dialect.encodeUuid(aggregateId),
        _encodeValue(key), // map_key
        _encodeValue(value),
      ];

      await _connection.execute(
        'INSERT INTO test_nullable_collections_optionalScores_items (test_nullable_collections_id, map_key, value) VALUES (?, ?, ?)',
        values,
      );
    }
  }

  /// Loads the optionalNumbers collection.
  Future<dynamic> _loadOptionalNumbers(UuidValue aggregateId) async {
    final rows = await _connection.query(
      'SELECT position, value FROM test_nullable_collections_optionalNumbers_items WHERE test_nullable_collections_id = ? ORDER BY position',
      [_dialect.encodeUuid(aggregateId)],
    );

    if (rows.isEmpty) {
      return <dynamic>[];
    }

    final items = <dynamic>[];
    for (final row in rows) {
      items.add(_decodeValue(row['value'], 'value'));
    }
    return items;
  }

  /// Loads the optionalTags collection.
  Future<dynamic> _loadOptionalTags(UuidValue aggregateId) async {
    final rows = await _connection.query(
      'SELECT value FROM test_nullable_collections_optionalTags_items WHERE test_nullable_collections_id = ?',
      [_dialect.encodeUuid(aggregateId)],
    );

    if (rows.isEmpty) {
      return <dynamic>[]; // Sets are serialized as Lists
    }

    final items = <dynamic>{};
    for (final row in rows) {
      items.add(_decodeValue(row['value'], 'value'));
    }
    return items.toList(); // Convert to List for JSON serialization
  }

  /// Loads the optionalScores collection.
  Future<dynamic> _loadOptionalScores(UuidValue aggregateId) async {
    final rows = await _connection.query(
      'SELECT map_key, value FROM test_nullable_collections_optionalScores_items WHERE test_nullable_collections_id = ?',
      [_dialect.encodeUuid(aggregateId)],
    );

    if (rows.isEmpty) {
      return <dynamic, dynamic>{};
    }

    final map = <dynamic, dynamic>{};
    for (final row in rows) {
      final key = _decodeValue(row['map_key'], 'map_key');
      final value = _decodeValue(row['value'], 'value');
      map[key] = value;
    }
    return map;
  }

  /// Flattens JSON for table storage, excluding specified keys.
  Map<String, dynamic> _flattenForTable(
    Map<String, dynamic> json,
    List<String> excludeKeys,
  ) {
    final flattened = <String, dynamic>{};

    for (final entry in json.entries) {
      final key = entry.key;
      if (excludeKeys.contains(key)) continue;

      final value = entry.value;

      if (value is Map<String, dynamic>) {
        // Flatten nested object (value object) with prefix
        for (final nestedEntry in value.entries) {
          flattened['${key}_${nestedEntry.key}'] = nestedEntry.value;
        }
      } else if (value is List) {
        // Skip lists - they're handled separately
        continue;
      } else {
        flattened[key] = value;
      }
    }

    return flattened;
  }

  /// Converts a SQL row to JSON, reconstructing embedded value objects.
  Map<String, dynamic> _rowToJson(Map<String, Object?> row) {
    final json = <String, dynamic>{};
    final processedPrefixes = <String>{};

    for (final entry in row.entries) {
      final key = entry.key;
      final value = entry.value;

      // Check if this is a prefixed column (value object field)
      if (key.contains('_')) {
        final parts = key.split('_');
        if (parts.length >= 2) {
          final prefix = parts[0];

          // Skip if already processed
          if (processedPrefixes.contains(prefix)) continue;

          // Collect all columns with this prefix
          final prefixedColumns = row.entries
              .where((e) => e.key.startsWith('${prefix}_'))
              .toList();

          if (prefixedColumns.isNotEmpty) {
            // Reconstruct value object
            final valueObject = <String, dynamic>{};
            var allNull = true;
            for (final col in prefixedColumns) {
              final fieldName = col.key.substring(prefix.length + 1);
              final decoded = _decodeValue(col.value, fieldName);
              valueObject[fieldName] = decoded;
              if (decoded != null) allNull = false;
            }
            // Only add if not all null (nullable value object)
            json[prefix] = allNull ? null : valueObject;
            processedPrefixes.add(prefix);
            continue;
          }
        }
      }

      // Regular field
      json[key] = _decodeValue(value, key);
    }

    return json;
  }

  /// Maps field names to their Dart types for type-aware encoding/decoding.
  static const Map<String, String> _fieldTypes = {
    'name': 'String',
    'id': 'UuidValue',
    'createdAt': 'DateTime',
    'updatedAt': 'DateTime',
  };

  /// Encodes a value for SQL storage.
  Object? _encodeValue(dynamic value) {
    if (value == null) return null;

    // Handle UUID strings
    if (value is String && value.contains('-') && value.length == 36) {
      try {
        return _dialect.encodeUuid(UuidValue.fromString(value));
      } catch (_) {
        return value;
      }
    }

    // Handle DateTime strings
    if (value is String) {
      final dateTime = DateTime.tryParse(value);
      if (dateTime != null) {
        return _dialect.encodeDateTime(dateTime);
      }
    }

    // Handle booleans
    if (value is bool) {
      return value ? 1 : 0;
    }

    return value;
  }

  /// Decodes a value from SQL storage.
  dynamic _decodeValue(Object? value, String fieldName) {
    if (value == null) return null;

    // Get the Dart type for this field
    final dartType = _fieldTypes[fieldName];

    // UUIDs are returned as strings from BIN_TO_UUID()
    // No special decoding needed for UUID fields

    // Decode DateTimes (DATETIME format)
    if (dartType == 'DateTime') {
      try {
        if (value is DateTime) {
          return value.toIso8601String();
        }
        if (value is String) {
          return _dialect.decodeDateTime(value).toIso8601String();
        }
      } catch (_) {
        return value;
      }
    }

    // Decode booleans (TINYINT(1))
    if (dartType == 'bool' && value is int) {
      return value != 0;
    }

    return value;
  }

  /// Maps MySQL exceptions to RepositoryException types.
  RepositoryException _mapMysqlException(Object error, String operation) {
    final errorMessage = error.toString();

    // Map specific MySQL error patterns to RepositoryExceptionType
    // Error 1062: Duplicate entry
    if (errorMessage.contains('1062') ||
        errorMessage.contains('Duplicate entry')) {
      return RepositoryException(
        'Duplicate key error during $operation: $errorMessage',
        type: RepositoryExceptionType.duplicate,
        cause: error,
      );
    }

    // Error 2003: Connection refused
    // Error 1045: Access denied
    // Error 1049: Unknown database
    if (errorMessage.contains('2003') ||
        errorMessage.contains('1045') ||
        errorMessage.contains('1049') ||
        errorMessage.contains('Connection refused') ||
        errorMessage.contains('Access denied') ||
        errorMessage.contains('Unknown database')) {
      return RepositoryException(
        'Connection error during $operation: $errorMessage',
        type: RepositoryExceptionType.connection,
        cause: error,
      );
    }

    // Error 1205: Lock wait timeout
    // Error 3024: Query timeout
    if (errorMessage.contains('1205') ||
        errorMessage.contains('3024') ||
        errorMessage.contains('timeout')) {
      return RepositoryException(
        'Timeout during $operation: $errorMessage',
        type: RepositoryExceptionType.timeout,
        cause: error,
      );
    }

    return RepositoryException(
      'MySQL error during $operation: $errorMessage',
      type: RepositoryExceptionType.unknown,
      cause: error,
    );
  }
}
