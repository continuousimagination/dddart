// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'test_models.dart';

// **************************************************************************
// SerializableGenerator
// **************************************************************************

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
        'Failed to deserialize Money: $e',
        expectedType: 'Money',
      );
    }
  }

  @override
  String serialize(Money object, [dynamic config]) {
    return jsonEncode(toJson(object, config as SerializationConfig?));
  }

  @override
  Money deserialize(String data, [dynamic config]) {
    final json = jsonDecode(data);
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected JSON object but got ${json.runtimeType}',
        expectedType: 'Money',
      );
    }
    return fromJson(json, config as SerializationConfig?);
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
      SerializationUtils.applyFieldRename(
        'country',
        effectiveConfig.fieldRename,
      ): instance.country,
      SerializationUtils.applyFieldRename(
        'street',
        effectiveConfig.fieldRename,
      ): instance.street,
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
        street:
            json[SerializationUtils.applyFieldRename(
                  'street',
                  effectiveConfig.fieldRename,
                )]
                as String,
      );
    } catch (e, stackTrace) {
      throw DeserializationException(
        'Failed to deserialize Address: $e',
        expectedType: 'Address',
      );
    }
  }

  @override
  String serialize(Address object, [dynamic config]) {
    return jsonEncode(toJson(object, config as SerializationConfig?));
  }

  @override
  Address deserialize(String data, [dynamic config]) {
    final json = jsonDecode(data);
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected JSON object but got ${json.runtimeType}',
        expectedType: 'Address',
      );
    }
    return fromJson(json, config as SerializationConfig?);
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
      SerializationUtils.applyFieldRename('price', effectiveConfig.fieldRename):
          MoneyJsonSerializer().toJson(instance.price, effectiveConfig),
      SerializationUtils.applyFieldRename(
        'productId',
        effectiveConfig.fieldRename,
      ): instance.productId
          .toString(),
      SerializationUtils.applyFieldRename(
        'quantity',
        effectiveConfig.fieldRename,
      ): instance.quantity,
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
        price: MoneyJsonSerializer().fromJson(
          json[SerializationUtils.applyFieldRename(
                'price',
                effectiveConfig.fieldRename,
              )]
              as Map<String, dynamic>,
          effectiveConfig,
        ),
        productId: UuidValue.fromString(
          json[SerializationUtils.applyFieldRename(
                'productId',
                effectiveConfig.fieldRename,
              )]
              as String,
        ),
        quantity:
            json[SerializationUtils.applyFieldRename(
                  'quantity',
                  effectiveConfig.fieldRename,
                )]
                as int,
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
      SerializationUtils.applyFieldRename(
        'shippingAddress',
        effectiveConfig.fieldRename,
      ): AddressJsonSerializer().toJson(
        instance.shippingAddress,
        effectiveConfig,
      ),
      SerializationUtils.applyFieldRename(
        'totalAmount',
        effectiveConfig.fieldRename,
      ): MoneyJsonSerializer().toJson(
        instance.totalAmount,
        effectiveConfig,
      ),
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
        shippingAddress: AddressJsonSerializer().fromJson(
          json[SerializationUtils.applyFieldRename(
                'shippingAddress',
                effectiveConfig.fieldRename,
              )]
              as Map<String, dynamic>,
          effectiveConfig,
        ),
        totalAmount: MoneyJsonSerializer().fromJson(
          json[SerializationUtils.applyFieldRename(
                'totalAmount',
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

class TestUserJsonSerializer implements JsonSerializer<TestUser> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  TestUserJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig = defaultConfig ?? const SerializationConfig();

  @override
  Map<String, dynamic> toJson(
    TestUser instance, [
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
      SerializationUtils.applyFieldRename(
        'isActive',
        effectiveConfig.fieldRename,
      ): instance.isActive,
      SerializationUtils.applyFieldRename('name', effectiveConfig.fieldRename):
          instance.name,
    };
    return json;
  }

  @override
  TestUser fromJson(dynamic json, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize TestUser from null JSON',
        expectedType: 'TestUser',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'TestUser',
      );
    }
    try {
      return TestUser(
        email:
            json[SerializationUtils.applyFieldRename(
                  'email',
                  effectiveConfig.fieldRename,
                )]
                as String,
        isActive:
            json[SerializationUtils.applyFieldRename(
                  'isActive',
                  effectiveConfig.fieldRename,
                )]
                as bool,
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
    } catch (e, stackTrace) {
      throw DeserializationException(
        'Failed to deserialize TestUser: $e',
        expectedType: 'TestUser',
      );
    }
  }

  @override
  String serialize(TestUser object, [dynamic config]) {
    return jsonEncode(toJson(object, config as SerializationConfig?));
  }

  @override
  TestUser deserialize(String data, [dynamic config]) {
    final json = jsonDecode(data);
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected JSON object but got ${json.runtimeType}',
        expectedType: 'TestUser',
      );
    }
    return fromJson(json, config as SerializationConfig?);
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    TestUser instance, [
    SerializationConfig? config,
  ]) {
    return TestUserJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static TestUser decode(dynamic json, [SerializationConfig? config]) {
    return TestUserJsonSerializer().fromJson(json, config);
  }
}

class TestProductJsonSerializer implements JsonSerializer<TestProduct> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  TestProductJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig = defaultConfig ?? const SerializationConfig();

  @override
  Map<String, dynamic> toJson(
    TestProduct instance, [
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
      if (instance.discount != null || effectiveConfig.includeNullFields)
        SerializationUtils.applyFieldRename(
          'discount',
          effectiveConfig.fieldRename,
        ): instance.discount != null
            ? MoneyJsonSerializer().toJson(instance.discount!, effectiveConfig)
            : null,
      SerializationUtils.applyFieldRename('name', effectiveConfig.fieldRename):
          instance.name,
      SerializationUtils.applyFieldRename('price', effectiveConfig.fieldRename):
          MoneyJsonSerializer().toJson(instance.price, effectiveConfig),
    };
    return json;
  }

  @override
  TestProduct fromJson(dynamic json, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize TestProduct from null JSON',
        expectedType: 'TestProduct',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'TestProduct',
      );
    }
    try {
      return TestProduct(
        discount:
            json[SerializationUtils.applyFieldRename(
                  'discount',
                  effectiveConfig.fieldRename,
                )] !=
                null
            ? MoneyJsonSerializer().fromJson(
                json[SerializationUtils.applyFieldRename(
                      'discount',
                      effectiveConfig.fieldRename,
                    )]
                    as Map<String, dynamic>,
                effectiveConfig,
              )
            : null,
        name:
            json[SerializationUtils.applyFieldRename(
                  'name',
                  effectiveConfig.fieldRename,
                )]
                as String,
        price: MoneyJsonSerializer().fromJson(
          json[SerializationUtils.applyFieldRename(
                'price',
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
        'Failed to deserialize TestProduct: $e',
        expectedType: 'TestProduct',
      );
    }
  }

  @override
  String serialize(TestProduct object, [dynamic config]) {
    return jsonEncode(toJson(object, config as SerializationConfig?));
  }

  @override
  TestProduct deserialize(String data, [dynamic config]) {
    final json = jsonDecode(data);
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected JSON object but got ${json.runtimeType}',
        expectedType: 'TestProduct',
      );
    }
    return fromJson(json, config as SerializationConfig?);
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    TestProduct instance, [
    SerializationConfig? config,
  ]) {
    return TestProductJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static TestProduct decode(dynamic json, [SerializationConfig? config]) {
    return TestProductJsonSerializer().fromJson(json, config);
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
        'Failed to deserialize TestPrimitiveCollections: $e',
        expectedType: 'TestPrimitiveCollections',
      );
    }
  }

  @override
  String serialize(TestPrimitiveCollections object, [dynamic config]) {
    return jsonEncode(toJson(object, config as SerializationConfig?));
  }

  @override
  TestPrimitiveCollections deserialize(String data, [dynamic config]) {
    final json = jsonDecode(data);
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected JSON object but got ${json.runtimeType}',
        expectedType: 'TestPrimitiveCollections',
      );
    }
    return fromJson(json, config as SerializationConfig?);
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
        'Failed to deserialize TestValueCollections: $e',
        expectedType: 'TestValueCollections',
      );
    }
  }

  @override
  String serialize(TestValueCollections object, [dynamic config]) {
    return jsonEncode(toJson(object, config as SerializationConfig?));
  }

  @override
  TestValueCollections deserialize(String data, [dynamic config]) {
    final json = jsonDecode(data);
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected JSON object but got ${json.runtimeType}',
        expectedType: 'TestValueCollections',
      );
    }
    return fromJson(json, config as SerializationConfig?);
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

class TestItemJsonSerializer implements JsonSerializer<TestItem> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  TestItemJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig = defaultConfig ?? const SerializationConfig();

  @override
  Map<String, dynamic> toJson(
    TestItem instance, [
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
      SerializationUtils.applyFieldRename('name', effectiveConfig.fieldRename):
          instance.name,
      SerializationUtils.applyFieldRename(
        'quantity',
        effectiveConfig.fieldRename,
      ): instance.quantity,
      SerializationUtils.applyFieldRename(
        'updatedAt',
        effectiveConfig.fieldRename,
      ): instance.updatedAt
          .toIso8601String(),
    };
    return json;
  }

  @override
  TestItem fromJson(dynamic json, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize TestItem from null JSON',
        expectedType: 'TestItem',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'TestItem',
      );
    }
    try {
      return TestItem(
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
        name:
            json[SerializationUtils.applyFieldRename(
                  'name',
                  effectiveConfig.fieldRename,
                )]
                as String,
        quantity:
            json[SerializationUtils.applyFieldRename(
                  'quantity',
                  effectiveConfig.fieldRename,
                )]
                as int,
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
        'Failed to deserialize TestItem: $e',
        expectedType: 'TestItem',
      );
    }
  }

  @override
  String serialize(TestItem object, [dynamic config]) {
    return jsonEncode(toJson(object, config as SerializationConfig?));
  }

  @override
  TestItem deserialize(String data, [dynamic config]) {
    final json = jsonDecode(data);
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected JSON object but got ${json.runtimeType}',
        expectedType: 'TestItem',
      );
    }
    return fromJson(json, config as SerializationConfig?);
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    TestItem instance, [
    SerializationConfig? config,
  ]) {
    return TestItemJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static TestItem decode(dynamic json, [SerializationConfig? config]) {
    return TestItemJsonSerializer().fromJson(json, config);
  }
}

class TestEntityCollectionsJsonSerializer
    implements JsonSerializer<TestEntityCollections> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  TestEntityCollectionsJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig = defaultConfig ?? const SerializationConfig();

  @override
  Map<String, dynamic> toJson(
    TestEntityCollections instance, [
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
        'itemsByCategory',
        effectiveConfig.fieldRename,
      ): instance.itemsByCategory.map(
        (key, value) => MapEntry(
          key,
          TestItemJsonSerializer().toJson(value, effectiveConfig),
        ),
      ),
      SerializationUtils.applyFieldRename('name', effectiveConfig.fieldRename):
          instance.name,
      SerializationUtils.applyFieldRename(
        'uniqueItems',
        effectiveConfig.fieldRename,
      ): instance.uniqueItems
          .map((item) => TestItemJsonSerializer().toJson(item, effectiveConfig))
          .toList(),
    };
    return json;
  }

  @override
  TestEntityCollections fromJson(dynamic json, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize TestEntityCollections from null JSON',
        expectedType: 'TestEntityCollections',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'TestEntityCollections',
      );
    }
    try {
      return TestEntityCollections(
        itemsByCategory:
            Map<String, dynamic>.from(
              json[SerializationUtils.applyFieldRename(
                    'itemsByCategory',
                    effectiveConfig.fieldRename,
                  )]
                  as Map,
            ).map(
              (key, value) => MapEntry(
                key,
                TestItemJsonSerializer().fromJson(
                  value as Map<String, dynamic>,
                  effectiveConfig,
                ),
              ),
            ),
        name:
            json[SerializationUtils.applyFieldRename(
                  'name',
                  effectiveConfig.fieldRename,
                )]
                as String,
        uniqueItems:
            (json[SerializationUtils.applyFieldRename(
                      'uniqueItems',
                      effectiveConfig.fieldRename,
                    )]
                    as List)
                .map(
                  (item) => TestItemJsonSerializer().fromJson(
                    item as Map<String, dynamic>,
                    effectiveConfig,
                  ),
                )
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
        'Failed to deserialize TestEntityCollections: $e',
        expectedType: 'TestEntityCollections',
      );
    }
  }

  @override
  String serialize(TestEntityCollections object, [dynamic config]) {
    return jsonEncode(toJson(object, config as SerializationConfig?));
  }

  @override
  TestEntityCollections deserialize(String data, [dynamic config]) {
    final json = jsonDecode(data);
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected JSON object but got ${json.runtimeType}',
        expectedType: 'TestEntityCollections',
      );
    }
    return fromJson(json, config as SerializationConfig?);
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    TestEntityCollections instance, [
    SerializationConfig? config,
  ]) {
    return TestEntityCollectionsJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static TestEntityCollections decode(
    dynamic json, [
    SerializationConfig? config,
  ]) {
    return TestEntityCollectionsJsonSerializer().fromJson(json, config);
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
        'Failed to deserialize TestNullableCollections: $e',
        expectedType: 'TestNullableCollections',
      );
    }
  }

  @override
  String serialize(TestNullableCollections object, [dynamic config]) {
    return jsonEncode(toJson(object, config as SerializationConfig?));
  }

  @override
  TestNullableCollections deserialize(String data, [dynamic config]) {
    final json = jsonDecode(data);
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected JSON object but got ${json.runtimeType}',
        expectedType: 'TestNullableCollections',
      );
    }
    return fromJson(json, config as SerializationConfig?);
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

class TestNullableElementsJsonSerializer
    implements JsonSerializer<TestNullableElements> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  TestNullableElementsJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig = defaultConfig ?? const SerializationConfig();

  @override
  Map<String, dynamic> toJson(
    TestNullableElements instance, [
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
      SerializationUtils.applyFieldRename(
        'nullableNumbers',
        effectiveConfig.fieldRename,
      ): instance.nullableNumbers,
    };
    return json;
  }

  @override
  TestNullableElements fromJson(dynamic json, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize TestNullableElements from null JSON',
        expectedType: 'TestNullableElements',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'TestNullableElements',
      );
    }
    try {
      return TestNullableElements(
        name:
            json[SerializationUtils.applyFieldRename(
                  'name',
                  effectiveConfig.fieldRename,
                )]
                as String,
        nullableNumbers:
            (json[SerializationUtils.applyFieldRename(
                      'nullableNumbers',
                      effectiveConfig.fieldRename,
                    )]
                    as List)
                .map((item) => item as int?)
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
        'Failed to deserialize TestNullableElements: $e',
        expectedType: 'TestNullableElements',
      );
    }
  }

  @override
  String serialize(TestNullableElements object, [dynamic config]) {
    return jsonEncode(toJson(object, config as SerializationConfig?));
  }

  @override
  TestNullableElements deserialize(String data, [dynamic config]) {
    final json = jsonDecode(data);
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected JSON object but got ${json.runtimeType}',
        expectedType: 'TestNullableElements',
      );
    }
    return fromJson(json, config as SerializationConfig?);
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    TestNullableElements instance, [
    SerializationConfig? config,
  ]) {
    return TestNullableElementsJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static TestNullableElements decode(
    dynamic json, [
    SerializationConfig? config,
  ]) {
    return TestNullableElementsJsonSerializer().fromJson(json, config);
  }
}

// **************************************************************************
// SqliteRepositoryGenerator
// **************************************************************************

/// Generated SQLite repository for [Order] aggregate.
///
/// This class provides CRUD operations with full normalization,
/// multi-table persistence, and value object embedding.
class OrderSqliteRepository implements Repository<Order> {
  /// Creates a repository instance.
  ///
  /// [connection] - An open SQLite database connection.
  OrderSqliteRepository(this._connection);

  /// The SQLite database connection.
  final SqliteConnection _connection;

  /// The SQL dialect for SQLite.
  final _dialect = SqliteDialect();

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
      // Create table: order_item
      await _connection.execute('''
CREATE TABLE IF NOT EXISTS "order_item" (
  "productId" BLOB NOT NULL,
  "quantity" INTEGER NOT NULL,
  "price_amount" REAL NOT NULL,
  "price_currency" TEXT NOT NULL,
  "id" BLOB PRIMARY KEY NOT NULL,
  "createdAt" TEXT NOT NULL,
  "updatedAt" TEXT NOT NULL,
  "orders_id" BLOB NOT NULL,
  FOREIGN KEY ("orders_id") REFERENCES "orders"("id") ON DELETE CASCADE
)
        ''');

      // Create table: orders
      await _connection.execute('''
CREATE TABLE IF NOT EXISTS "orders" (
  "customerId" BLOB NOT NULL,
  "totalAmount_amount" REAL NOT NULL,
  "totalAmount_currency" TEXT NOT NULL,
  "shippingAddress_street" TEXT NOT NULL,
  "shippingAddress_city" TEXT NOT NULL,
  "shippingAddress_country" TEXT NOT NULL,
  "id" BLOB PRIMARY KEY NOT NULL,
  "createdAt" TEXT NOT NULL,
  "updatedAt" TEXT NOT NULL
)
        ''');

      // Create junction table for collection: items
      await _connection.execute('''
CREATE TABLE IF NOT EXISTS "orders_items" (
  "orders_id" BLOB NOT NULL,
  "position" INTEGER NOT NULL,
  "id" BLOB PRIMARY KEY NOT NULL,
  "productId" BLOB NOT NULL,
  "quantity" INTEGER NOT NULL,
  "price_amount" REAL NOT NULL,
  "price_currency" TEXT NOT NULL,
  "createdAt" TEXT NOT NULL,
  "updatedAt" TEXT NOT NULL,
  FOREIGN KEY ("orders_id") REFERENCES "orders"("id") ON DELETE CASCADE,
  UNIQUE (orders_id, position)
)
        ''');
    });
  }

  @override
  Future<Order> getById(UuidValue id) async {
    return await _connection.transaction(() async {
      try {
        // Query the aggregate root table
        final rows = await _connection.query(
          'SELECT * FROM "orders" WHERE "id" = ?',
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

        // Load collections
        json['items'] = await _loadItems(id);

        return _serializer.fromJson(json);
      } on RepositoryException {
        rethrow;
      } catch (e) {
        throw _mapSqliteException(e, 'getById');
      }
    });
  }

  @override
  Future<void> save(Order aggregate) async {
    await _connection.transaction(() async {
      try {
        // Serialize aggregate to JSON
        final json = _serializer.toJson(aggregate);

        // Save aggregate root first (required for foreign key constraints)
        final rootData = _flattenForTable(json, ['items', 'items']);
        final columns = rootData.keys.toList();
        final values = columns.map((k) => _encodeValue(rootData[k])).toList();

        final placeholders = List.filled(columns.length, '?').join(', ');
        await _connection.execute(
          'INSERT OR REPLACE INTO "orders" (${columns.map((c) => '"$c"').join(', ')}) VALUES ($placeholders)',
          values,
        );

        // Save collections to their junction tables
        await _saveItems(aggregate.id, json['items']);
      } catch (e) {
        throw _mapSqliteException(e, 'save');
      }
    });
  }

  @override
  Future<void> deleteById(UuidValue id) async {
    await _connection.transaction(() async {
      try {
        // Check if aggregate exists
        final rows = await _connection.query(
          'SELECT "id" FROM "orders" WHERE "id" = ?',
          [_dialect.encodeUuid(id)],
        );

        if (rows.isEmpty) {
          throw RepositoryException(
            'Order with ID $id not found',
            type: RepositoryExceptionType.notFound,
          );
        }

        // Delete aggregate (CASCADE will handle related entities)
        await _connection.execute('DELETE FROM "orders" WHERE "id" = ?', [
          _dialect.encodeUuid(id),
        ]);
      } on RepositoryException {
        rethrow;
      } catch (e) {
        throw _mapSqliteException(e, 'deleteById');
      }
    });
  }

  /// Saves the items collection.
  Future<void> _saveItems(
    UuidValue aggregateId,
    dynamic collectionValue,
  ) async {
    // Delete existing items
    await _connection.execute(
      'DELETE FROM "orders_items" WHERE "orders_id" = ?',
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

      // Add entity fields
      if (item is Map<String, dynamic>) {
        // Flatten nested value objects in the entity
        final flattened = _flattenForTable(item, []);
        final columns = ['orders_id', 'position'];
        for (final entry in flattened.entries) {
          columns.add(entry.key);
          values.add(_encodeValue(entry.value));
        }

        final placeholders = List.filled(columns.length, '?').join(', ');
        await _connection.execute(
          'INSERT INTO "orders_items" (${columns.map((c) => '"$c"').join(', ')}) VALUES ($placeholders)',
          values,
        );
      }
    }
  }

  /// Loads the items collection.
  Future<dynamic> _loadItems(UuidValue aggregateId) async {
    final rows = await _connection.query(
      'SELECT * FROM "orders_items" WHERE "orders_id" = ? ORDER BY position',
      [_dialect.encodeUuid(aggregateId)],
    );

    if (rows.isEmpty) {
      return <dynamic>[];
    }

    return rows.map((row) {
      // Filter out position and foreign key columns
      final filtered = <String, Object?>{};
      for (final entry in row.entries) {
        if (entry.key != 'position' && !entry.key.endsWith('_id')) {
          filtered[entry.key] = entry.value;
        }
      }
      // Reconstruct flattened value objects
      return _rowToJson(filtered);
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
    'customerId': 'UuidValue',
    'totalAmount_amount': 'double',
    'totalAmount_currency': 'String',
    'shippingAddress_street': 'String',
    'shippingAddress_city': 'String',
    'shippingAddress_country': 'String',
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

    // Decode UUIDs (BLOB)
    if (value is List<int> &&
        (dartType == 'UuidValue' ||
            fieldName == 'id' ||
            fieldName.endsWith('Id'))) {
      try {
        return _dialect.decodeUuid(value).toString();
      } catch (_) {
        return value;
      }
    }

    // Decode DateTimes (TEXT in ISO8601 format)
    if (dartType == 'DateTime' && value is String) {
      try {
        return _dialect.decodeDateTime(value).toIso8601String();
      } catch (_) {
        return value;
      }
    }

    // Decode booleans (INTEGER 0/1)
    if (dartType == 'bool' && value is int) {
      return value != 0;
    }

    return value;
  }

  /// Maps SQLite exceptions to RepositoryException types.
  RepositoryException _mapSqliteException(Object error, String operation) {
    final errorMessage = error.toString();

    // Map specific SQLite error patterns to RepositoryExceptionType
    if (errorMessage.contains('UNIQUE constraint')) {
      return RepositoryException(
        'Duplicate key error during $operation: $errorMessage',
        type: RepositoryExceptionType.duplicate,
        cause: error,
      );
    }

    if (errorMessage.contains('database is locked') ||
        errorMessage.contains('unable to open database')) {
      return RepositoryException(
        'Connection error during $operation: $errorMessage',
        type: RepositoryExceptionType.connection,
        cause: error,
      );
    }

    return RepositoryException(
      'SQLite error during $operation: $errorMessage',
      type: RepositoryExceptionType.unknown,
      cause: error,
    );
  }
}

/// Generated SQLite repository for [TestUser] aggregate.
///
/// This class provides CRUD operations with full normalization,
/// multi-table persistence, and value object embedding.
class TestUserSqliteRepository implements Repository<TestUser> {
  /// Creates a repository instance.
  ///
  /// [connection] - An open SQLite database connection.
  TestUserSqliteRepository(this._connection);

  /// The SQLite database connection.
  final SqliteConnection _connection;

  /// The SQL dialect for SQLite.
  final _dialect = SqliteDialect();

  /// The JSON serializer for TestUser aggregates.
  final _serializer = TestUserJsonSerializer();

  /// The table name for TestUser aggregates.
  String get tableName => 'test_users';

  /// Creates all tables for this aggregate.
  ///
  /// This method should be called once during application
  /// initialization to ensure all required tables exist.
  ///
  /// Uses CREATE TABLE IF NOT EXISTS, so it is safe to call
  /// multiple times.
  Future<void> createTables() async {
    await _connection.transaction(() async {
      // Create table: test_users
      await _connection.execute('''
CREATE TABLE IF NOT EXISTS "test_users" (
  "name" TEXT NOT NULL,
  "email" TEXT NOT NULL,
  "isActive" INTEGER NOT NULL,
  "id" BLOB PRIMARY KEY NOT NULL,
  "createdAt" TEXT NOT NULL,
  "updatedAt" TEXT NOT NULL
)
        ''');
    });
  }

  @override
  Future<TestUser> getById(UuidValue id) async {
    return await _connection.transaction(() async {
      try {
        // Query the aggregate root table
        final rows = await _connection.query(
          'SELECT * FROM "test_users" WHERE "id" = ?',
          [_dialect.encodeUuid(id)],
        );

        if (rows.isEmpty) {
          throw RepositoryException(
            'TestUser with ID $id not found',
            type: RepositoryExceptionType.notFound,
          );
        }

        final row = rows.first;
        final json = _rowToJson(row);

        return _serializer.fromJson(json);
      } on RepositoryException {
        rethrow;
      } catch (e) {
        throw _mapSqliteException(e, 'getById');
      }
    });
  }

  @override
  Future<void> save(TestUser aggregate) async {
    await _connection.transaction(() async {
      try {
        // Serialize aggregate to JSON
        final json = _serializer.toJson(aggregate);

        // Save aggregate root first (required for foreign key constraints)
        final rootData = _flattenForTable(json, []);
        final columns = rootData.keys.toList();
        final values = columns.map((k) => _encodeValue(rootData[k])).toList();

        final placeholders = List.filled(columns.length, '?').join(', ');
        await _connection.execute(
          'INSERT OR REPLACE INTO "test_users" (${columns.map((c) => '"$c"').join(', ')}) VALUES ($placeholders)',
          values,
        );
      } catch (e) {
        throw _mapSqliteException(e, 'save');
      }
    });
  }

  @override
  Future<void> deleteById(UuidValue id) async {
    await _connection.transaction(() async {
      try {
        // Check if aggregate exists
        final rows = await _connection.query(
          'SELECT "id" FROM "test_users" WHERE "id" = ?',
          [_dialect.encodeUuid(id)],
        );

        if (rows.isEmpty) {
          throw RepositoryException(
            'TestUser with ID $id not found',
            type: RepositoryExceptionType.notFound,
          );
        }

        // Delete aggregate (CASCADE will handle related entities)
        await _connection.execute('DELETE FROM "test_users" WHERE "id" = ?', [
          _dialect.encodeUuid(id),
        ]);
      } on RepositoryException {
        rethrow;
      } catch (e) {
        throw _mapSqliteException(e, 'deleteById');
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
    'email': 'String',
    'isActive': 'bool',
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

    // Decode UUIDs (BLOB)
    if (value is List<int> &&
        (dartType == 'UuidValue' ||
            fieldName == 'id' ||
            fieldName.endsWith('Id'))) {
      try {
        return _dialect.decodeUuid(value).toString();
      } catch (_) {
        return value;
      }
    }

    // Decode DateTimes (TEXT in ISO8601 format)
    if (dartType == 'DateTime' && value is String) {
      try {
        return _dialect.decodeDateTime(value).toIso8601String();
      } catch (_) {
        return value;
      }
    }

    // Decode booleans (INTEGER 0/1)
    if (dartType == 'bool' && value is int) {
      return value != 0;
    }

    return value;
  }

  /// Maps SQLite exceptions to RepositoryException types.
  RepositoryException _mapSqliteException(Object error, String operation) {
    final errorMessage = error.toString();

    // Map specific SQLite error patterns to RepositoryExceptionType
    if (errorMessage.contains('UNIQUE constraint')) {
      return RepositoryException(
        'Duplicate key error during $operation: $errorMessage',
        type: RepositoryExceptionType.duplicate,
        cause: error,
      );
    }

    if (errorMessage.contains('database is locked') ||
        errorMessage.contains('unable to open database')) {
      return RepositoryException(
        'Connection error during $operation: $errorMessage',
        type: RepositoryExceptionType.connection,
        cause: error,
      );
    }

    return RepositoryException(
      'SQLite error during $operation: $errorMessage',
      type: RepositoryExceptionType.unknown,
      cause: error,
    );
  }
}

/// Generated SQLite repository for [TestProduct] aggregate.
///
/// This class provides CRUD operations with full normalization,
/// multi-table persistence, and value object embedding.
class TestProductSqliteRepository implements Repository<TestProduct> {
  /// Creates a repository instance.
  ///
  /// [connection] - An open SQLite database connection.
  TestProductSqliteRepository(this._connection);

  /// The SQLite database connection.
  final SqliteConnection _connection;

  /// The SQL dialect for SQLite.
  final _dialect = SqliteDialect();

  /// The JSON serializer for TestProduct aggregates.
  final _serializer = TestProductJsonSerializer();

  /// The table name for TestProduct aggregates.
  String get tableName => 'test_products';

  /// Creates all tables for this aggregate.
  ///
  /// This method should be called once during application
  /// initialization to ensure all required tables exist.
  ///
  /// Uses CREATE TABLE IF NOT EXISTS, so it is safe to call
  /// multiple times.
  Future<void> createTables() async {
    await _connection.transaction(() async {
      // Create table: test_products
      await _connection.execute('''
CREATE TABLE IF NOT EXISTS "test_products" (
  "name" TEXT NOT NULL,
  "price_amount" REAL NOT NULL,
  "price_currency" TEXT NOT NULL,
  "discount_amount" REAL,
  "discount_currency" TEXT,
  "id" BLOB PRIMARY KEY NOT NULL,
  "createdAt" TEXT NOT NULL,
  "updatedAt" TEXT NOT NULL
)
        ''');
    });
  }

  @override
  Future<TestProduct> getById(UuidValue id) async {
    return await _connection.transaction(() async {
      try {
        // Query the aggregate root table
        final rows = await _connection.query(
          'SELECT * FROM "test_products" WHERE "id" = ?',
          [_dialect.encodeUuid(id)],
        );

        if (rows.isEmpty) {
          throw RepositoryException(
            'TestProduct with ID $id not found',
            type: RepositoryExceptionType.notFound,
          );
        }

        final row = rows.first;
        final json = _rowToJson(row);

        return _serializer.fromJson(json);
      } on RepositoryException {
        rethrow;
      } catch (e) {
        throw _mapSqliteException(e, 'getById');
      }
    });
  }

  @override
  Future<void> save(TestProduct aggregate) async {
    await _connection.transaction(() async {
      try {
        // Serialize aggregate to JSON
        final json = _serializer.toJson(aggregate);

        // Save aggregate root first (required for foreign key constraints)
        final rootData = _flattenForTable(json, []);
        final columns = rootData.keys.toList();
        final values = columns.map((k) => _encodeValue(rootData[k])).toList();

        final placeholders = List.filled(columns.length, '?').join(', ');
        await _connection.execute(
          'INSERT OR REPLACE INTO "test_products" (${columns.map((c) => '"$c"').join(', ')}) VALUES ($placeholders)',
          values,
        );
      } catch (e) {
        throw _mapSqliteException(e, 'save');
      }
    });
  }

  @override
  Future<void> deleteById(UuidValue id) async {
    await _connection.transaction(() async {
      try {
        // Check if aggregate exists
        final rows = await _connection.query(
          'SELECT "id" FROM "test_products" WHERE "id" = ?',
          [_dialect.encodeUuid(id)],
        );

        if (rows.isEmpty) {
          throw RepositoryException(
            'TestProduct with ID $id not found',
            type: RepositoryExceptionType.notFound,
          );
        }

        // Delete aggregate (CASCADE will handle related entities)
        await _connection.execute(
          'DELETE FROM "test_products" WHERE "id" = ?',
          [_dialect.encodeUuid(id)],
        );
      } on RepositoryException {
        rethrow;
      } catch (e) {
        throw _mapSqliteException(e, 'deleteById');
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
    'price_amount': 'double',
    'price_currency': 'String',
    'discount_amount': 'double',
    'discount_currency': 'String',
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

    // Decode UUIDs (BLOB)
    if (value is List<int> &&
        (dartType == 'UuidValue' ||
            fieldName == 'id' ||
            fieldName.endsWith('Id'))) {
      try {
        return _dialect.decodeUuid(value).toString();
      } catch (_) {
        return value;
      }
    }

    // Decode DateTimes (TEXT in ISO8601 format)
    if (dartType == 'DateTime' && value is String) {
      try {
        return _dialect.decodeDateTime(value).toIso8601String();
      } catch (_) {
        return value;
      }
    }

    // Decode booleans (INTEGER 0/1)
    if (dartType == 'bool' && value is int) {
      return value != 0;
    }

    return value;
  }

  /// Maps SQLite exceptions to RepositoryException types.
  RepositoryException _mapSqliteException(Object error, String operation) {
    final errorMessage = error.toString();

    // Map specific SQLite error patterns to RepositoryExceptionType
    if (errorMessage.contains('UNIQUE constraint')) {
      return RepositoryException(
        'Duplicate key error during $operation: $errorMessage',
        type: RepositoryExceptionType.duplicate,
        cause: error,
      );
    }

    if (errorMessage.contains('database is locked') ||
        errorMessage.contains('unable to open database')) {
      return RepositoryException(
        'Connection error during $operation: $errorMessage',
        type: RepositoryExceptionType.connection,
        cause: error,
      );
    }

    return RepositoryException(
      'SQLite error during $operation: $errorMessage',
      type: RepositoryExceptionType.unknown,
      cause: error,
    );
  }
}

/// Generated SQLite repository for [TestPrimitiveCollections] aggregate.
///
/// This class provides CRUD operations with full normalization,
/// multi-table persistence, and value object embedding.
class TestPrimitiveCollectionsSqliteRepository
    implements Repository<TestPrimitiveCollections> {
  /// Creates a repository instance.
  ///
  /// [connection] - An open SQLite database connection.
  TestPrimitiveCollectionsSqliteRepository(this._connection);

  /// The SQLite database connection.
  final SqliteConnection _connection;

  /// The SQL dialect for SQLite.
  final _dialect = SqliteDialect();

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
CREATE TABLE IF NOT EXISTS "test_primitive_collections" (
  "name" TEXT NOT NULL,
  "id" BLOB PRIMARY KEY NOT NULL,
  "createdAt" TEXT NOT NULL,
  "updatedAt" TEXT NOT NULL
)
        ''');

      // Create junction table for collection: favoriteNumbers
      await _connection.execute('''
CREATE TABLE IF NOT EXISTS "test_primitive_collections_favoriteNumbers" (
  "test_primitive_collections_id" BLOB NOT NULL,
  "position" INTEGER NOT NULL,
  "value" INTEGER NOT NULL,
  FOREIGN KEY ("test_primitive_collections_id") REFERENCES "test_primitive_collections"("id") ON DELETE CASCADE,
  UNIQUE (test_primitive_collections_id, position)
)
        ''');

      // Create junction table for collection: tags
      await _connection.execute('''
CREATE TABLE IF NOT EXISTS "test_primitive_collections_tags" (
  "test_primitive_collections_id" BLOB NOT NULL,
  "value" TEXT NOT NULL,
  FOREIGN KEY ("test_primitive_collections_id") REFERENCES "test_primitive_collections"("id") ON DELETE CASCADE,
  UNIQUE (test_primitive_collections_id, value)
)
        ''');

      // Create junction table for collection: scoresByGame
      await _connection.execute('''
CREATE TABLE IF NOT EXISTS "test_primitive_collections_scoresByGame" (
  "test_primitive_collections_id" BLOB NOT NULL,
  "map_key" TEXT NOT NULL,
  "value" INTEGER NOT NULL,
  FOREIGN KEY ("test_primitive_collections_id") REFERENCES "test_primitive_collections"("id") ON DELETE CASCADE,
  UNIQUE (test_primitive_collections_id, map_key)
)
        ''');
    });
  }

  @override
  Future<TestPrimitiveCollections> getById(UuidValue id) async {
    return await _connection.transaction(() async {
      try {
        // Query the aggregate root table
        final rows = await _connection.query(
          'SELECT * FROM "test_primitive_collections" WHERE "id" = ?',
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
        throw _mapSqliteException(e, 'getById');
      }
    });
  }

  @override
  Future<void> save(TestPrimitiveCollections aggregate) async {
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
        await _connection.execute(
          'INSERT OR REPLACE INTO "test_primitive_collections" (${columns.map((c) => '"$c"').join(', ')}) VALUES ($placeholders)',
          values,
        );

        // Save collections to their junction tables
        await _saveFavoriteNumbers(aggregate.id, json['favoriteNumbers']);
        await _saveTags(aggregate.id, json['tags']);
        await _saveScoresByGame(aggregate.id, json['scoresByGame']);
      } catch (e) {
        throw _mapSqliteException(e, 'save');
      }
    });
  }

  @override
  Future<void> deleteById(UuidValue id) async {
    await _connection.transaction(() async {
      try {
        // Check if aggregate exists
        final rows = await _connection.query(
          'SELECT "id" FROM "test_primitive_collections" WHERE "id" = ?',
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
          'DELETE FROM "test_primitive_collections" WHERE "id" = ?',
          [_dialect.encodeUuid(id)],
        );
      } on RepositoryException {
        rethrow;
      } catch (e) {
        throw _mapSqliteException(e, 'deleteById');
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
      'DELETE FROM "test_primitive_collections_favoriteNumbers" WHERE "test_primitive_collections_id" = ?',
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
        'INSERT INTO "test_primitive_collections_favoriteNumbers" ("test_primitive_collections_id", "position", "value") VALUES (?, ?, ?)',
        values,
      );
    }
  }

  /// Saves the tags collection.
  Future<void> _saveTags(UuidValue aggregateId, dynamic collectionValue) async {
    // Delete existing items
    await _connection.execute(
      'DELETE FROM "test_primitive_collections_tags" WHERE "test_primitive_collections_id" = ?',
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
        'INSERT INTO "test_primitive_collections_tags" ("test_primitive_collections_id", "value") VALUES (?, ?)',
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
      'DELETE FROM "test_primitive_collections_scoresByGame" WHERE "test_primitive_collections_id" = ?',
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
        'INSERT INTO "test_primitive_collections_scoresByGame" ("test_primitive_collections_id", "map_key", "value") VALUES (?, ?, ?)',
        values,
      );
    }
  }

  /// Loads the favoriteNumbers collection.
  Future<dynamic> _loadFavoriteNumbers(UuidValue aggregateId) async {
    final rows = await _connection.query(
      'SELECT * FROM "test_primitive_collections_favoriteNumbers" WHERE "test_primitive_collections_id" = ? ORDER BY position',
      [_dialect.encodeUuid(aggregateId)],
    );

    if (rows.isEmpty) {
      return <dynamic>[];
    }

    return rows.map((row) {
      return _decodeValue(row['value'], 'value');
    }).toList();
  }

  /// Loads the tags collection.
  Future<dynamic> _loadTags(UuidValue aggregateId) async {
    final rows = await _connection.query(
      'SELECT * FROM "test_primitive_collections_tags" WHERE "test_primitive_collections_id" = ?',
      [_dialect.encodeUuid(aggregateId)],
    );

    if (rows.isEmpty) {
      return <dynamic>[];
    }

    return rows.map((row) {
      return _decodeValue(row['value'], 'value');
    }).toList();
  }

  /// Loads the scoresByGame collection.
  Future<dynamic> _loadScoresByGame(UuidValue aggregateId) async {
    final rows = await _connection.query(
      'SELECT * FROM "test_primitive_collections_scoresByGame" WHERE "test_primitive_collections_id" = ?',
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

    // Decode UUIDs (BLOB)
    if (value is List<int> &&
        (dartType == 'UuidValue' ||
            fieldName == 'id' ||
            fieldName.endsWith('Id'))) {
      try {
        return _dialect.decodeUuid(value).toString();
      } catch (_) {
        return value;
      }
    }

    // Decode DateTimes (TEXT in ISO8601 format)
    if (dartType == 'DateTime' && value is String) {
      try {
        return _dialect.decodeDateTime(value).toIso8601String();
      } catch (_) {
        return value;
      }
    }

    // Decode booleans (INTEGER 0/1)
    if (dartType == 'bool' && value is int) {
      return value != 0;
    }

    return value;
  }

  /// Maps SQLite exceptions to RepositoryException types.
  RepositoryException _mapSqliteException(Object error, String operation) {
    final errorMessage = error.toString();

    // Map specific SQLite error patterns to RepositoryExceptionType
    if (errorMessage.contains('UNIQUE constraint')) {
      return RepositoryException(
        'Duplicate key error during $operation: $errorMessage',
        type: RepositoryExceptionType.duplicate,
        cause: error,
      );
    }

    if (errorMessage.contains('database is locked') ||
        errorMessage.contains('unable to open database')) {
      return RepositoryException(
        'Connection error during $operation: $errorMessage',
        type: RepositoryExceptionType.connection,
        cause: error,
      );
    }

    return RepositoryException(
      'SQLite error during $operation: $errorMessage',
      type: RepositoryExceptionType.unknown,
      cause: error,
    );
  }
}

/// Generated SQLite repository for [TestValueCollections] aggregate.
///
/// This class provides CRUD operations with full normalization,
/// multi-table persistence, and value object embedding.
class TestValueCollectionsSqliteRepository
    implements Repository<TestValueCollections> {
  /// Creates a repository instance.
  ///
  /// [connection] - An open SQLite database connection.
  TestValueCollectionsSqliteRepository(this._connection);

  /// The SQLite database connection.
  final SqliteConnection _connection;

  /// The SQL dialect for SQLite.
  final _dialect = SqliteDialect();

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
CREATE TABLE IF NOT EXISTS "test_value_collections" (
  "name" TEXT NOT NULL,
  "id" BLOB PRIMARY KEY NOT NULL,
  "createdAt" TEXT NOT NULL,
  "updatedAt" TEXT NOT NULL
)
        ''');

      // Create junction table for collection: payments
      await _connection.execute('''
CREATE TABLE IF NOT EXISTS "test_value_collections_payments" (
  "test_value_collections_id" BLOB NOT NULL,
  "position" INTEGER NOT NULL,
  "amount" REAL NOT NULL,
  "currency" TEXT NOT NULL,
  FOREIGN KEY ("test_value_collections_id") REFERENCES "test_value_collections"("id") ON DELETE CASCADE,
  UNIQUE (test_value_collections_id, position)
)
        ''');

      // Create junction table for collection: addresses
      await _connection.execute('''
CREATE TABLE IF NOT EXISTS "test_value_collections_addresses" (
  "test_value_collections_id" BLOB NOT NULL,
  "street" TEXT NOT NULL,
  "city" TEXT NOT NULL,
  "country" TEXT NOT NULL,
  FOREIGN KEY ("test_value_collections_id") REFERENCES "test_value_collections"("id") ON DELETE CASCADE
)
        ''');

      // Create junction table for collection: pricesByProduct
      await _connection.execute('''
CREATE TABLE IF NOT EXISTS "test_value_collections_pricesByProduct" (
  "test_value_collections_id" BLOB NOT NULL,
  "map_key" TEXT NOT NULL,
  "amount" REAL NOT NULL,
  "currency" TEXT NOT NULL,
  FOREIGN KEY ("test_value_collections_id") REFERENCES "test_value_collections"("id") ON DELETE CASCADE,
  UNIQUE (test_value_collections_id, map_key)
)
        ''');
    });
  }

  @override
  Future<TestValueCollections> getById(UuidValue id) async {
    return await _connection.transaction(() async {
      try {
        // Query the aggregate root table
        final rows = await _connection.query(
          'SELECT * FROM "test_value_collections" WHERE "id" = ?',
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
        throw _mapSqliteException(e, 'getById');
      }
    });
  }

  @override
  Future<void> save(TestValueCollections aggregate) async {
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
        await _connection.execute(
          'INSERT OR REPLACE INTO "test_value_collections" (${columns.map((c) => '"$c"').join(', ')}) VALUES ($placeholders)',
          values,
        );

        // Save collections to their junction tables
        await _savePayments(aggregate.id, json['payments']);
        await _saveAddresses(aggregate.id, json['addresses']);
        await _savePricesByProduct(aggregate.id, json['pricesByProduct']);
      } catch (e) {
        throw _mapSqliteException(e, 'save');
      }
    });
  }

  @override
  Future<void> deleteById(UuidValue id) async {
    await _connection.transaction(() async {
      try {
        // Check if aggregate exists
        final rows = await _connection.query(
          'SELECT "id" FROM "test_value_collections" WHERE "id" = ?',
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
          'DELETE FROM "test_value_collections" WHERE "id" = ?',
          [_dialect.encodeUuid(id)],
        );
      } on RepositoryException {
        rethrow;
      } catch (e) {
        throw _mapSqliteException(e, 'deleteById');
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
      'DELETE FROM "test_value_collections_payments" WHERE "test_value_collections_id" = ?',
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
          'INSERT INTO "test_value_collections_payments" (${columns.map((c) => '"$c"').join(', ')}) VALUES ($placeholders)',
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
      'DELETE FROM "test_value_collections_addresses" WHERE "test_value_collections_id" = ?',
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
          'INSERT INTO "test_value_collections_addresses" (${columns.map((c) => '"$c"').join(', ')}) VALUES ($placeholders)',
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
      'DELETE FROM "test_value_collections_pricesByProduct" WHERE "test_value_collections_id" = ?',
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
          'INSERT INTO "test_value_collections_pricesByProduct" (${columns.map((c) => '"$c"').join(', ')}) VALUES ($placeholders)',
          values,
        );
      }
    }
  }

  /// Loads the payments collection.
  Future<dynamic> _loadPayments(UuidValue aggregateId) async {
    final rows = await _connection.query(
      'SELECT * FROM "test_value_collections_payments" WHERE "test_value_collections_id" = ? ORDER BY position',
      [_dialect.encodeUuid(aggregateId)],
    );

    if (rows.isEmpty) {
      return <dynamic>[];
    }

    return rows.map((row) {
      // Filter out position and foreign key columns
      final filtered = <String, Object?>{};
      for (final entry in row.entries) {
        if (entry.key != 'position' && !entry.key.endsWith('_id')) {
          filtered[entry.key] = entry.value;
        }
      }
      // Reconstruct flattened value objects
      return _rowToJson(filtered);
    }).toList();
  }

  /// Loads the addresses collection.
  Future<dynamic> _loadAddresses(UuidValue aggregateId) async {
    final rows = await _connection.query(
      'SELECT * FROM "test_value_collections_addresses" WHERE "test_value_collections_id" = ?',
      [_dialect.encodeUuid(aggregateId)],
    );

    if (rows.isEmpty) {
      return <dynamic>[];
    }

    return rows.map((row) {
      // Filter out foreign key columns
      final filtered = <String, Object?>{};
      for (final entry in row.entries) {
        if (!entry.key.endsWith('_id')) {
          filtered[entry.key] = entry.value;
        }
      }
      // Reconstruct flattened value objects
      return _rowToJson(filtered);
    }).toList();
  }

  /// Loads the pricesByProduct collection.
  Future<dynamic> _loadPricesByProduct(UuidValue aggregateId) async {
    final rows = await _connection.query(
      'SELECT * FROM "test_value_collections_pricesByProduct" WHERE "test_value_collections_id" = ?',
      [_dialect.encodeUuid(aggregateId)],
    );

    if (rows.isEmpty) {
      return <dynamic, dynamic>{};
    }

    final map = <dynamic, dynamic>{};
    for (final row in rows) {
      final key = _decodeValue(row['map_key'], 'map_key');
      // Filter out map_key and foreign key columns
      final filtered = <String, Object?>{};
      for (final entry in row.entries) {
        if (entry.key != 'map_key' && !entry.key.endsWith('_id')) {
          filtered[entry.key] = entry.value;
        }
      }
      // Reconstruct flattened value objects
      map[key] = _rowToJson(filtered);
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

    // Decode UUIDs (BLOB)
    if (value is List<int> &&
        (dartType == 'UuidValue' ||
            fieldName == 'id' ||
            fieldName.endsWith('Id'))) {
      try {
        return _dialect.decodeUuid(value).toString();
      } catch (_) {
        return value;
      }
    }

    // Decode DateTimes (TEXT in ISO8601 format)
    if (dartType == 'DateTime' && value is String) {
      try {
        return _dialect.decodeDateTime(value).toIso8601String();
      } catch (_) {
        return value;
      }
    }

    // Decode booleans (INTEGER 0/1)
    if (dartType == 'bool' && value is int) {
      return value != 0;
    }

    return value;
  }

  /// Maps SQLite exceptions to RepositoryException types.
  RepositoryException _mapSqliteException(Object error, String operation) {
    final errorMessage = error.toString();

    // Map specific SQLite error patterns to RepositoryExceptionType
    if (errorMessage.contains('UNIQUE constraint')) {
      return RepositoryException(
        'Duplicate key error during $operation: $errorMessage',
        type: RepositoryExceptionType.duplicate,
        cause: error,
      );
    }

    if (errorMessage.contains('database is locked') ||
        errorMessage.contains('unable to open database')) {
      return RepositoryException(
        'Connection error during $operation: $errorMessage',
        type: RepositoryExceptionType.connection,
        cause: error,
      );
    }

    return RepositoryException(
      'SQLite error during $operation: $errorMessage',
      type: RepositoryExceptionType.unknown,
      cause: error,
    );
  }
}

/// Generated SQLite repository for [TestEntityCollections] aggregate.
///
/// This class provides CRUD operations with full normalization,
/// multi-table persistence, and value object embedding.
class TestEntityCollectionsSqliteRepository
    implements Repository<TestEntityCollections> {
  /// Creates a repository instance.
  ///
  /// [connection] - An open SQLite database connection.
  TestEntityCollectionsSqliteRepository(this._connection);

  /// The SQLite database connection.
  final SqliteConnection _connection;

  /// The SQL dialect for SQLite.
  final _dialect = SqliteDialect();

  /// The JSON serializer for TestEntityCollections aggregates.
  final _serializer = TestEntityCollectionsJsonSerializer();

  /// The table name for TestEntityCollections aggregates.
  String get tableName => 'test_entity_collections';

  /// Creates all tables for this aggregate.
  ///
  /// This method should be called once during application
  /// initialization to ensure all required tables exist.
  ///
  /// Uses CREATE TABLE IF NOT EXISTS, so it is safe to call
  /// multiple times.
  Future<void> createTables() async {
    await _connection.transaction(() async {
      // Create table: test_item
      await _connection.execute('''
CREATE TABLE IF NOT EXISTS "test_item" (
  "name" TEXT NOT NULL,
  "quantity" INTEGER NOT NULL,
  "id" BLOB PRIMARY KEY NOT NULL,
  "createdAt" TEXT NOT NULL,
  "updatedAt" TEXT NOT NULL,
  "testentitycollections_id" BLOB NOT NULL,
  FOREIGN KEY ("testentitycollections_id") REFERENCES "test_entity_collections"("id") ON DELETE CASCADE
)
        ''');

      // Create table: test_entity_collections
      await _connection.execute('''
CREATE TABLE IF NOT EXISTS "test_entity_collections" (
  "name" TEXT NOT NULL,
  "id" BLOB PRIMARY KEY NOT NULL,
  "createdAt" TEXT NOT NULL,
  "updatedAt" TEXT NOT NULL
)
        ''');

      // Create junction table for collection: uniqueItems
      await _connection.execute('''
CREATE TABLE IF NOT EXISTS "test_entity_collections_uniqueItems" (
  "test_entity_collections_id" BLOB NOT NULL,
  "id" BLOB PRIMARY KEY NOT NULL,
  "name" TEXT NOT NULL,
  "quantity" INTEGER NOT NULL,
  "createdAt" TEXT NOT NULL,
  "updatedAt" TEXT NOT NULL,
  FOREIGN KEY ("test_entity_collections_id") REFERENCES "test_entity_collections"("id") ON DELETE CASCADE
)
        ''');

      // Create junction table for collection: itemsByCategory
      await _connection.execute('''
CREATE TABLE IF NOT EXISTS "test_entity_collections_itemsByCategory" (
  "test_entity_collections_id" BLOB NOT NULL,
  "map_key" TEXT NOT NULL,
  "id" BLOB PRIMARY KEY NOT NULL,
  "name" TEXT NOT NULL,
  "quantity" INTEGER NOT NULL,
  "createdAt" TEXT NOT NULL,
  "updatedAt" TEXT NOT NULL,
  FOREIGN KEY ("test_entity_collections_id") REFERENCES "test_entity_collections"("id") ON DELETE CASCADE,
  UNIQUE (test_entity_collections_id, map_key)
)
        ''');
    });
  }

  @override
  Future<TestEntityCollections> getById(UuidValue id) async {
    return await _connection.transaction(() async {
      try {
        // Query the aggregate root table
        final rows = await _connection.query(
          'SELECT * FROM "test_entity_collections" WHERE "id" = ?',
          [_dialect.encodeUuid(id)],
        );

        if (rows.isEmpty) {
          throw RepositoryException(
            'TestEntityCollections with ID $id not found',
            type: RepositoryExceptionType.notFound,
          );
        }

        final row = rows.first;
        final json = _rowToJson(row);

        // Load collections
        json['uniqueItems'] = await _loadUniqueItems(id);
        json['itemsByCategory'] = await _loadItemsByCategory(id);

        return _serializer.fromJson(json);
      } on RepositoryException {
        rethrow;
      } catch (e) {
        throw _mapSqliteException(e, 'getById');
      }
    });
  }

  @override
  Future<void> save(TestEntityCollections aggregate) async {
    await _connection.transaction(() async {
      try {
        // Serialize aggregate to JSON
        final json = _serializer.toJson(aggregate);

        // Save aggregate root first (required for foreign key constraints)
        final rootData = _flattenForTable(json, [
          'uniqueItems',
          'uniqueItems',
          'itemsByCategory',
        ]);
        final columns = rootData.keys.toList();
        final values = columns.map((k) => _encodeValue(rootData[k])).toList();

        final placeholders = List.filled(columns.length, '?').join(', ');
        await _connection.execute(
          'INSERT OR REPLACE INTO "test_entity_collections" (${columns.map((c) => '"$c"').join(', ')}) VALUES ($placeholders)',
          values,
        );

        // Save collections to their junction tables
        await _saveUniqueItems(aggregate.id, json['uniqueItems']);
        await _saveItemsByCategory(aggregate.id, json['itemsByCategory']);
      } catch (e) {
        throw _mapSqliteException(e, 'save');
      }
    });
  }

  @override
  Future<void> deleteById(UuidValue id) async {
    await _connection.transaction(() async {
      try {
        // Check if aggregate exists
        final rows = await _connection.query(
          'SELECT "id" FROM "test_entity_collections" WHERE "id" = ?',
          [_dialect.encodeUuid(id)],
        );

        if (rows.isEmpty) {
          throw RepositoryException(
            'TestEntityCollections with ID $id not found',
            type: RepositoryExceptionType.notFound,
          );
        }

        // Delete aggregate (CASCADE will handle related entities)
        await _connection.execute(
          'DELETE FROM "test_entity_collections" WHERE "id" = ?',
          [_dialect.encodeUuid(id)],
        );
      } on RepositoryException {
        rethrow;
      } catch (e) {
        throw _mapSqliteException(e, 'deleteById');
      }
    });
  }

  /// Saves the uniqueItems collection.
  Future<void> _saveUniqueItems(
    UuidValue aggregateId,
    dynamic collectionValue,
  ) async {
    // Delete existing items
    await _connection.execute(
      'DELETE FROM "test_entity_collections_uniqueItems" WHERE "test_entity_collections_id" = ?',
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

      // Add entity fields
      if (item is Map<String, dynamic>) {
        // Flatten nested value objects in the entity
        final flattened = _flattenForTable(item, []);
        final columns = ['test_entity_collections_id'];
        for (final entry in flattened.entries) {
          columns.add(entry.key);
          values.add(_encodeValue(entry.value));
        }

        final placeholders = List.filled(columns.length, '?').join(', ');
        await _connection.execute(
          'INSERT INTO "test_entity_collections_uniqueItems" (${columns.map((c) => '"$c"').join(', ')}) VALUES ($placeholders)',
          values,
        );
      }
    }
  }

  /// Saves the itemsByCategory collection.
  Future<void> _saveItemsByCategory(
    UuidValue aggregateId,
    dynamic collectionValue,
  ) async {
    // Delete existing items
    await _connection.execute(
      'DELETE FROM "test_entity_collections_itemsByCategory" WHERE "test_entity_collections_id" = ?',
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

      // Add entity fields
      if (value is Map<String, dynamic>) {
        // Flatten nested value objects in the entity
        final flattened = _flattenForTable(value, []);
        final columns = ['test_entity_collections_id', 'map_key'];
        for (final valueEntry in flattened.entries) {
          columns.add(valueEntry.key);
          values.add(_encodeValue(valueEntry.value));
        }

        final placeholders = List.filled(columns.length, '?').join(', ');
        await _connection.execute(
          'INSERT INTO "test_entity_collections_itemsByCategory" (${columns.map((c) => '"$c"').join(', ')}) VALUES ($placeholders)',
          values,
        );
      }
    }
  }

  /// Loads the uniqueItems collection.
  Future<dynamic> _loadUniqueItems(UuidValue aggregateId) async {
    final rows = await _connection.query(
      'SELECT * FROM "test_entity_collections_uniqueItems" WHERE "test_entity_collections_id" = ?',
      [_dialect.encodeUuid(aggregateId)],
    );

    if (rows.isEmpty) {
      return <dynamic>[];
    }

    return rows.map((row) {
      // Filter out foreign key columns
      final filtered = <String, Object?>{};
      for (final entry in row.entries) {
        if (!entry.key.endsWith('_id')) {
          filtered[entry.key] = entry.value;
        }
      }
      // Reconstruct flattened value objects
      return _rowToJson(filtered);
    }).toList();
  }

  /// Loads the itemsByCategory collection.
  Future<dynamic> _loadItemsByCategory(UuidValue aggregateId) async {
    final rows = await _connection.query(
      'SELECT * FROM "test_entity_collections_itemsByCategory" WHERE "test_entity_collections_id" = ?',
      [_dialect.encodeUuid(aggregateId)],
    );

    if (rows.isEmpty) {
      return <dynamic, dynamic>{};
    }

    final map = <dynamic, dynamic>{};
    for (final row in rows) {
      final key = _decodeValue(row['map_key'], 'map_key');
      // Filter out map_key and foreign key columns
      final filtered = <String, Object?>{};
      for (final entry in row.entries) {
        if (entry.key != 'map_key' && !entry.key.endsWith('_id')) {
          filtered[entry.key] = entry.value;
        }
      }
      // Reconstruct flattened value objects
      map[key] = _rowToJson(filtered);
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

    // Decode UUIDs (BLOB)
    if (value is List<int> &&
        (dartType == 'UuidValue' ||
            fieldName == 'id' ||
            fieldName.endsWith('Id'))) {
      try {
        return _dialect.decodeUuid(value).toString();
      } catch (_) {
        return value;
      }
    }

    // Decode DateTimes (TEXT in ISO8601 format)
    if (dartType == 'DateTime' && value is String) {
      try {
        return _dialect.decodeDateTime(value).toIso8601String();
      } catch (_) {
        return value;
      }
    }

    // Decode booleans (INTEGER 0/1)
    if (dartType == 'bool' && value is int) {
      return value != 0;
    }

    return value;
  }

  /// Maps SQLite exceptions to RepositoryException types.
  RepositoryException _mapSqliteException(Object error, String operation) {
    final errorMessage = error.toString();

    // Map specific SQLite error patterns to RepositoryExceptionType
    if (errorMessage.contains('UNIQUE constraint')) {
      return RepositoryException(
        'Duplicate key error during $operation: $errorMessage',
        type: RepositoryExceptionType.duplicate,
        cause: error,
      );
    }

    if (errorMessage.contains('database is locked') ||
        errorMessage.contains('unable to open database')) {
      return RepositoryException(
        'Connection error during $operation: $errorMessage',
        type: RepositoryExceptionType.connection,
        cause: error,
      );
    }

    return RepositoryException(
      'SQLite error during $operation: $errorMessage',
      type: RepositoryExceptionType.unknown,
      cause: error,
    );
  }
}

/// Generated SQLite repository for [TestNullableCollections] aggregate.
///
/// This class provides CRUD operations with full normalization,
/// multi-table persistence, and value object embedding.
class TestNullableCollectionsSqliteRepository
    implements Repository<TestNullableCollections> {
  /// Creates a repository instance.
  ///
  /// [connection] - An open SQLite database connection.
  TestNullableCollectionsSqliteRepository(this._connection);

  /// The SQLite database connection.
  final SqliteConnection _connection;

  /// The SQL dialect for SQLite.
  final _dialect = SqliteDialect();

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
CREATE TABLE IF NOT EXISTS "test_nullable_collections" (
  "name" TEXT NOT NULL,
  "id" BLOB PRIMARY KEY NOT NULL,
  "createdAt" TEXT NOT NULL,
  "updatedAt" TEXT NOT NULL
)
        ''');

      // Create junction table for collection: optionalNumbers
      await _connection.execute('''
CREATE TABLE IF NOT EXISTS "test_nullable_collections_optionalNumbers" (
  "test_nullable_collections_id" BLOB NOT NULL,
  "position" INTEGER NOT NULL,
  "value" INTEGER NOT NULL,
  FOREIGN KEY ("test_nullable_collections_id") REFERENCES "test_nullable_collections"("id") ON DELETE CASCADE,
  UNIQUE (test_nullable_collections_id, position)
)
        ''');

      // Create junction table for collection: optionalTags
      await _connection.execute('''
CREATE TABLE IF NOT EXISTS "test_nullable_collections_optionalTags" (
  "test_nullable_collections_id" BLOB NOT NULL,
  "value" TEXT NOT NULL,
  FOREIGN KEY ("test_nullable_collections_id") REFERENCES "test_nullable_collections"("id") ON DELETE CASCADE,
  UNIQUE (test_nullable_collections_id, value)
)
        ''');

      // Create junction table for collection: optionalScores
      await _connection.execute('''
CREATE TABLE IF NOT EXISTS "test_nullable_collections_optionalScores" (
  "test_nullable_collections_id" BLOB NOT NULL,
  "map_key" TEXT NOT NULL,
  "value" INTEGER NOT NULL,
  FOREIGN KEY ("test_nullable_collections_id") REFERENCES "test_nullable_collections"("id") ON DELETE CASCADE,
  UNIQUE (test_nullable_collections_id, map_key)
)
        ''');
    });
  }

  @override
  Future<TestNullableCollections> getById(UuidValue id) async {
    return await _connection.transaction(() async {
      try {
        // Query the aggregate root table
        final rows = await _connection.query(
          'SELECT * FROM "test_nullable_collections" WHERE "id" = ?',
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
        throw _mapSqliteException(e, 'getById');
      }
    });
  }

  @override
  Future<void> save(TestNullableCollections aggregate) async {
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
        await _connection.execute(
          'INSERT OR REPLACE INTO "test_nullable_collections" (${columns.map((c) => '"$c"').join(', ')}) VALUES ($placeholders)',
          values,
        );

        // Save collections to their junction tables
        await _saveOptionalNumbers(aggregate.id, json['optionalNumbers']);
        await _saveOptionalTags(aggregate.id, json['optionalTags']);
        await _saveOptionalScores(aggregate.id, json['optionalScores']);
      } catch (e) {
        throw _mapSqliteException(e, 'save');
      }
    });
  }

  @override
  Future<void> deleteById(UuidValue id) async {
    await _connection.transaction(() async {
      try {
        // Check if aggregate exists
        final rows = await _connection.query(
          'SELECT "id" FROM "test_nullable_collections" WHERE "id" = ?',
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
          'DELETE FROM "test_nullable_collections" WHERE "id" = ?',
          [_dialect.encodeUuid(id)],
        );
      } on RepositoryException {
        rethrow;
      } catch (e) {
        throw _mapSqliteException(e, 'deleteById');
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
      'DELETE FROM "test_nullable_collections_optionalNumbers" WHERE "test_nullable_collections_id" = ?',
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
        'INSERT INTO "test_nullable_collections_optionalNumbers" ("test_nullable_collections_id", "position", "value") VALUES (?, ?, ?)',
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
      'DELETE FROM "test_nullable_collections_optionalTags" WHERE "test_nullable_collections_id" = ?',
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
        'INSERT INTO "test_nullable_collections_optionalTags" ("test_nullable_collections_id", "value") VALUES (?, ?)',
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
      'DELETE FROM "test_nullable_collections_optionalScores" WHERE "test_nullable_collections_id" = ?',
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
        'INSERT INTO "test_nullable_collections_optionalScores" ("test_nullable_collections_id", "map_key", "value") VALUES (?, ?, ?)',
        values,
      );
    }
  }

  /// Loads the optionalNumbers collection.
  Future<dynamic> _loadOptionalNumbers(UuidValue aggregateId) async {
    final rows = await _connection.query(
      'SELECT * FROM "test_nullable_collections_optionalNumbers" WHERE "test_nullable_collections_id" = ? ORDER BY position',
      [_dialect.encodeUuid(aggregateId)],
    );

    if (rows.isEmpty) {
      return <dynamic>[];
    }

    return rows.map((row) {
      return _decodeValue(row['value'], 'value');
    }).toList();
  }

  /// Loads the optionalTags collection.
  Future<dynamic> _loadOptionalTags(UuidValue aggregateId) async {
    final rows = await _connection.query(
      'SELECT * FROM "test_nullable_collections_optionalTags" WHERE "test_nullable_collections_id" = ?',
      [_dialect.encodeUuid(aggregateId)],
    );

    if (rows.isEmpty) {
      return <dynamic>[];
    }

    return rows.map((row) {
      return _decodeValue(row['value'], 'value');
    }).toList();
  }

  /// Loads the optionalScores collection.
  Future<dynamic> _loadOptionalScores(UuidValue aggregateId) async {
    final rows = await _connection.query(
      'SELECT * FROM "test_nullable_collections_optionalScores" WHERE "test_nullable_collections_id" = ?',
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

    // Decode UUIDs (BLOB)
    if (value is List<int> &&
        (dartType == 'UuidValue' ||
            fieldName == 'id' ||
            fieldName.endsWith('Id'))) {
      try {
        return _dialect.decodeUuid(value).toString();
      } catch (_) {
        return value;
      }
    }

    // Decode DateTimes (TEXT in ISO8601 format)
    if (dartType == 'DateTime' && value is String) {
      try {
        return _dialect.decodeDateTime(value).toIso8601String();
      } catch (_) {
        return value;
      }
    }

    // Decode booleans (INTEGER 0/1)
    if (dartType == 'bool' && value is int) {
      return value != 0;
    }

    return value;
  }

  /// Maps SQLite exceptions to RepositoryException types.
  RepositoryException _mapSqliteException(Object error, String operation) {
    final errorMessage = error.toString();

    // Map specific SQLite error patterns to RepositoryExceptionType
    if (errorMessage.contains('UNIQUE constraint')) {
      return RepositoryException(
        'Duplicate key error during $operation: $errorMessage',
        type: RepositoryExceptionType.duplicate,
        cause: error,
      );
    }

    if (errorMessage.contains('database is locked') ||
        errorMessage.contains('unable to open database')) {
      return RepositoryException(
        'Connection error during $operation: $errorMessage',
        type: RepositoryExceptionType.connection,
        cause: error,
      );
    }

    return RepositoryException(
      'SQLite error during $operation: $errorMessage',
      type: RepositoryExceptionType.unknown,
      cause: error,
    );
  }
}

/// Generated SQLite repository for [TestNullableElements] aggregate.
///
/// This class provides CRUD operations with full normalization,
/// multi-table persistence, and value object embedding.
class TestNullableElementsSqliteRepository
    implements Repository<TestNullableElements> {
  /// Creates a repository instance.
  ///
  /// [connection] - An open SQLite database connection.
  TestNullableElementsSqliteRepository(this._connection);

  /// The SQLite database connection.
  final SqliteConnection _connection;

  /// The SQL dialect for SQLite.
  final _dialect = SqliteDialect();

  /// The JSON serializer for TestNullableElements aggregates.
  final _serializer = TestNullableElementsJsonSerializer();

  /// The table name for TestNullableElements aggregates.
  String get tableName => 'test_nullable_elements';

  /// Creates all tables for this aggregate.
  ///
  /// This method should be called once during application
  /// initialization to ensure all required tables exist.
  ///
  /// Uses CREATE TABLE IF NOT EXISTS, so it is safe to call
  /// multiple times.
  Future<void> createTables() async {
    await _connection.transaction(() async {
      // Create table: test_nullable_elements
      await _connection.execute('''
CREATE TABLE IF NOT EXISTS "test_nullable_elements" (
  "name" TEXT NOT NULL,
  "id" BLOB PRIMARY KEY NOT NULL,
  "createdAt" TEXT NOT NULL,
  "updatedAt" TEXT NOT NULL
)
        ''');

      // Create junction table for collection: nullableNumbers
      await _connection.execute('''
CREATE TABLE IF NOT EXISTS "test_nullable_elements_nullableNumbers" (
  "test_nullable_elements_id" BLOB NOT NULL,
  "position" INTEGER NOT NULL,
  "value" INTEGER,
  FOREIGN KEY ("test_nullable_elements_id") REFERENCES "test_nullable_elements"("id") ON DELETE CASCADE,
  UNIQUE (test_nullable_elements_id, position)
)
        ''');
    });
  }

  @override
  Future<TestNullableElements> getById(UuidValue id) async {
    return await _connection.transaction(() async {
      try {
        // Query the aggregate root table
        final rows = await _connection.query(
          'SELECT * FROM "test_nullable_elements" WHERE "id" = ?',
          [_dialect.encodeUuid(id)],
        );

        if (rows.isEmpty) {
          throw RepositoryException(
            'TestNullableElements with ID $id not found',
            type: RepositoryExceptionType.notFound,
          );
        }

        final row = rows.first;
        final json = _rowToJson(row);

        // Load collections
        json['nullableNumbers'] = await _loadNullableNumbers(id);

        return _serializer.fromJson(json);
      } on RepositoryException {
        rethrow;
      } catch (e) {
        throw _mapSqliteException(e, 'getById');
      }
    });
  }

  @override
  Future<void> save(TestNullableElements aggregate) async {
    await _connection.transaction(() async {
      try {
        // Serialize aggregate to JSON
        final json = _serializer.toJson(aggregate);

        // Save aggregate root first (required for foreign key constraints)
        final rootData = _flattenForTable(json, ['nullableNumbers']);
        final columns = rootData.keys.toList();
        final values = columns.map((k) => _encodeValue(rootData[k])).toList();

        final placeholders = List.filled(columns.length, '?').join(', ');
        await _connection.execute(
          'INSERT OR REPLACE INTO "test_nullable_elements" (${columns.map((c) => '"$c"').join(', ')}) VALUES ($placeholders)',
          values,
        );

        // Save collections to their junction tables
        await _saveNullableNumbers(aggregate.id, json['nullableNumbers']);
      } catch (e) {
        throw _mapSqliteException(e, 'save');
      }
    });
  }

  @override
  Future<void> deleteById(UuidValue id) async {
    await _connection.transaction(() async {
      try {
        // Check if aggregate exists
        final rows = await _connection.query(
          'SELECT "id" FROM "test_nullable_elements" WHERE "id" = ?',
          [_dialect.encodeUuid(id)],
        );

        if (rows.isEmpty) {
          throw RepositoryException(
            'TestNullableElements with ID $id not found',
            type: RepositoryExceptionType.notFound,
          );
        }

        // Delete aggregate (CASCADE will handle related entities)
        await _connection.execute(
          'DELETE FROM "test_nullable_elements" WHERE "id" = ?',
          [_dialect.encodeUuid(id)],
        );
      } on RepositoryException {
        rethrow;
      } catch (e) {
        throw _mapSqliteException(e, 'deleteById');
      }
    });
  }

  /// Saves the nullableNumbers collection.
  Future<void> _saveNullableNumbers(
    UuidValue aggregateId,
    dynamic collectionValue,
  ) async {
    // Delete existing items
    await _connection.execute(
      'DELETE FROM "test_nullable_elements_nullableNumbers" WHERE "test_nullable_elements_id" = ?',
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
        'INSERT INTO "test_nullable_elements_nullableNumbers" ("test_nullable_elements_id", "position", "value") VALUES (?, ?, ?)',
        values,
      );
    }
  }

  /// Loads the nullableNumbers collection.
  Future<dynamic> _loadNullableNumbers(UuidValue aggregateId) async {
    final rows = await _connection.query(
      'SELECT * FROM "test_nullable_elements_nullableNumbers" WHERE "test_nullable_elements_id" = ? ORDER BY position',
      [_dialect.encodeUuid(aggregateId)],
    );

    if (rows.isEmpty) {
      return <dynamic>[];
    }

    return rows.map((row) {
      return _decodeValue(row['value'], 'value');
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

    // Decode UUIDs (BLOB)
    if (value is List<int> &&
        (dartType == 'UuidValue' ||
            fieldName == 'id' ||
            fieldName.endsWith('Id'))) {
      try {
        return _dialect.decodeUuid(value).toString();
      } catch (_) {
        return value;
      }
    }

    // Decode DateTimes (TEXT in ISO8601 format)
    if (dartType == 'DateTime' && value is String) {
      try {
        return _dialect.decodeDateTime(value).toIso8601String();
      } catch (_) {
        return value;
      }
    }

    // Decode booleans (INTEGER 0/1)
    if (dartType == 'bool' && value is int) {
      return value != 0;
    }

    return value;
  }

  /// Maps SQLite exceptions to RepositoryException types.
  RepositoryException _mapSqliteException(Object error, String operation) {
    final errorMessage = error.toString();

    // Map specific SQLite error patterns to RepositoryExceptionType
    if (errorMessage.contains('UNIQUE constraint')) {
      return RepositoryException(
        'Duplicate key error during $operation: $errorMessage',
        type: RepositoryExceptionType.duplicate,
        cause: error,
      );
    }

    if (errorMessage.contains('database is locked') ||
        errorMessage.contains('unable to open database')) {
      return RepositoryException(
        'Connection error during $operation: $errorMessage',
        type: RepositoryExceptionType.connection,
        cause: error,
      );
    }

    return RepositoryException(
      'SQLite error during $operation: $errorMessage',
      type: RepositoryExceptionType.unknown,
      cause: error,
    );
  }
}
