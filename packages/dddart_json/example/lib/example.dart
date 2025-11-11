import 'dart:convert';
import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

import 'domain/address.dart';
import 'domain/customer.dart';
import 'domain/money.dart';
import 'domain/order.dart';
import 'domain/order_item.dart';
import 'domain/product_info.dart';

/// Comprehensive example demonstrating DDDart serialization features.
class SerializationExample {
  /// Run all example scenarios
  void runAll() {
    print('🚀 DDDart Serialization Example\n');

    _basicSerialization();
    _fieldNamingStrategies();
    _constructorConfiguration();
    _complexObjectGraphs();
    _errorHandling();
    _performanceDemo();

    print('\n✅ All examples completed successfully!');
  }

  /// Demonstrate basic serialization and deserialization
  void _basicSerialization() {
    print('📦 Basic Serialization Example');
    print('=' * 40);

    // Create domain objects
    final address = Address(
      street: '123 Main Street',
      city: 'San Francisco',
      state: 'CA',
      zipCode: '94105',
      country: 'USA',
    );

    final customer = Customer(
      firstName: 'John',
      lastName: 'Doe',
      email: 'john.doe@example.com',
      defaultShippingAddress: address,
    );

    // Serialize to JSON
    final addressSerializer = AddressJsonSerializer();
    final customerSerializer = CustomerJsonSerializer();

    final addressJson = addressSerializer.toJson(address);
    final customerJson = customerSerializer.toJson(customer);

    print('Address JSON:');
    print(JsonEncoder.withIndent('  ').convert(addressJson));

    print('\nCustomer JSON:');
    print(JsonEncoder.withIndent('  ').convert(customerJson));

    // Deserialize back
    final restoredAddress = addressSerializer.fromJson(addressJson);
    final restoredCustomer = customerSerializer.fromJson(customerJson);

    // Verify round-trip integrity
    assert(restoredAddress == address, 'Address round-trip failed');
    assert(restoredCustomer == customer, 'Customer round-trip failed');

    print('\n✅ Round-trip serialization successful!\n');
  }

  /// Demonstrate different field naming strategies
  void _fieldNamingStrategies() {
    print('🏷️  Field Naming Strategies Example');
    print('=' * 40);

    final customer = Customer(
      firstName: 'Jane',
      lastName: 'Smith',
      email: 'jane.smith@example.com',
      defaultShippingAddress: Address(
        street: '456 Oak Avenue',
        city: 'Portland',
        state: 'OR',
        zipCode: '97201',
        country: 'USA',
      ),
    );

    final serializer = CustomerJsonSerializer();

    // Default (camelCase)
    final camelJson = serializer.toJson(customer);
    print('CamelCase JSON:');
    print(JsonEncoder.withIndent('  ').convert(camelJson));

    // Snake case
    final snakeConfig = SerializationConfig(fieldRename: FieldRename.snake);
    final snakeJson = serializer.toJson(customer, snakeConfig);
    print('\nSnake_case JSON:');
    print(JsonEncoder.withIndent('  ').convert(snakeJson));

    // Kebab case
    final kebabConfig = SerializationConfig(fieldRename: FieldRename.kebab);
    final kebabJson = serializer.toJson(customer, kebabConfig);
    print('\nKebab-case JSON:');
    print(JsonEncoder.withIndent('  ').convert(kebabJson));

    // Verify all can be deserialized back
    final fromCamel = serializer.fromJson(camelJson);
    print('✅ CamelCase deserialization successful');

    Customer? fromSnake;
    try {
      fromSnake = serializer.fromJson(snakeJson, snakeConfig);
      print('✅ Snake_case deserialization successful');
    } catch (e) {
      print('❌ Snake_case deserialization failed: $e');
      print('Snake JSON keys: ${snakeJson.keys}');
      if (snakeJson['default_shipping_address'] != null) {
        print(
            'Address keys: ${(snakeJson['default_shipping_address'] as Map).keys}');
      }
      rethrow;
    }

    final fromKebab = serializer.fromJson(kebabJson, kebabConfig);

    assert(fromCamel == customer, 'CamelCase deserialization failed');
    assert(fromSnake == customer, 'Snake_case deserialization failed');
    assert(fromKebab == customer, 'Kebab-case deserialization failed');

    print('\n✅ All naming strategies work correctly!\n');
  }

  /// Demonstrate constructor configuration with method overrides
  void _constructorConfiguration() {
    print('⚙️  Constructor Configuration Example');
    print('=' * 40);

    final address = Address(
      street: '789 Pine Street',
      city: 'Seattle',
      state: 'WA',
      zipCode: '98101',
      country: 'USA',
    );

    // Create serializer with default snake_case configuration
    final snakeConfig = SerializationConfig(fieldRename: FieldRename.snake);
    final serializer = AddressJsonSerializer(snakeConfig);

    // Uses constructor config (snake_case)
    final defaultJson = serializer.toJson(address);
    print('Default (constructor config - snake_case):');
    print(JsonEncoder.withIndent('  ').convert(defaultJson));

    // Override with camelCase for specific operation
    final camelConfig = SerializationConfig(fieldRename: FieldRename.none);
    final overrideJson = serializer.toJson(address, camelConfig);
    print('\nMethod override (camelCase):');
    print(JsonEncoder.withIndent('  ').convert(overrideJson));

    // Perfect for dependency injection scenarios
    print('\n🔧 DI Container Simulation:');

    // API serializer (always snake_case)
    final apiSerializer = AddressJsonSerializer(
        SerializationConfig(fieldRename: FieldRename.snake));

    // Database serializer (always camelCase)
    final dbSerializer = AddressJsonSerializer(
        SerializationConfig(fieldRename: FieldRename.none));

    final apiJson = apiSerializer.toJson(address);
    final dbJson = dbSerializer.toJson(address);

    print('API JSON (snake_case): ${apiJson.keys.first}');
    print('DB JSON (camelCase): ${dbJson.keys.first}');

    print('\n✅ Constructor configuration works perfectly!\n');
  }

  /// Demonstrate complex object graph serialization
  void _complexObjectGraphs() {
    print('🕸️  Complex Object Graph Example');
    print('=' * 40);

    // Create a complex order with multiple items
    final order = _createSampleOrder();

    final serializer = OrderJsonSerializer();

    // Serialize the entire object graph
    final json = serializer.toJson(order);
    print('Complete Order JSON:');
    print(JsonEncoder.withIndent('  ').convert(json));

    // Deserialize back
    final restoredOrder = serializer.fromJson(json);

    // Verify complex object integrity
    assert(restoredOrder == order, 'Order round-trip failed');
    assert(restoredOrder.items.length == order.items.length,
        'Items count mismatch');
    assert(restoredOrder.total == order.total, 'Total calculation mismatch');

    print('\n📊 Order Summary:');
    print('Customer ID: ${restoredOrder.customerId}');
    print('Items: ${restoredOrder.items.length}');
    print('Total: ${restoredOrder.total}');
    print('Status: ${restoredOrder.status}');
    print('Shipping: ${restoredOrder.shippingAddress.cityStateZip}');

    print('\n✅ Complex object graph serialization successful!\n');
  }

  /// Demonstrate error handling scenarios
  void _errorHandling() {
    print('🚨 Error Handling Example');
    print('=' * 40);

    final serializer = CustomerJsonSerializer();

    // Test various error scenarios
    final errorCases = [
      {
        'name': 'Missing required field',
        'json': {
          'firstName': 'John',
          // Missing lastName, email, defaultShippingAddress
          'id': '550e8400-e29b-41d4-a716-446655440000',
          'createdAt': '2024-01-01T12:00:00.000Z',
          'updatedAt': '2024-01-01T12:00:00.000Z',
        }
      },
      {
        'name': 'Wrong field type',
        'json': {
          'firstName': 123, // Should be String
          'lastName': 'Doe',
          'email': 'john@example.com',
          'defaultShippingAddress': {
            'street': '123 Main St',
            'city': 'Anytown',
            'state': 'CA',
            'zipCode': '12345',
            'country': 'USA',
          },
          'id': '550e8400-e29b-41d4-a716-446655440000',
          'createdAt': '2024-01-01T12:00:00.000Z',
          'updatedAt': '2024-01-01T12:00:00.000Z',
        }
      },
      {
        'name': 'Invalid UUID format',
        'json': {
          'firstName': 'John',
          'lastName': 'Doe',
          'email': 'john@example.com',
          'defaultShippingAddress': {
            'street': '123 Main St',
            'city': 'Anytown',
            'state': 'CA',
            'zipCode': '12345',
            'country': 'USA',
          },
          'id': 'invalid-uuid',
          'createdAt': '2024-01-01T12:00:00.000Z',
          'updatedAt': '2024-01-01T12:00:00.000Z',
        }
      },
    ];

    for (final errorCase in errorCases) {
      try {
        serializer.fromJson(errorCase['json'] as Map<String, dynamic>);
        print('❌ Expected error for: ${errorCase['name']}');
      } on DeserializationException catch (e) {
        print('✅ Caught expected error for ${errorCase['name']}:');
        print('   Message: ${e.message}');
        print('   Type: ${e.expectedType}');
        if (e.field != null) print('   Field: ${e.field}');
      } catch (e) {
        print('⚠️  Unexpected error type for ${errorCase['name']}: $e');
      }
    }

    print('\n✅ Error handling works correctly!\n');
  }

  /// Demonstrate performance characteristics
  void _performanceDemo() {
    print('⚡ Performance Demo');
    print('=' * 40);

    final orders = List.generate(1000, (i) => _createSampleOrder());
    final serializer = OrderJsonSerializer();

    // Measure serialization performance
    final serializeStart = DateTime.now();
    final jsonList = orders.map((order) => serializer.toJson(order)).toList();
    final serializeEnd = DateTime.now();
    final serializeDuration = serializeEnd.difference(serializeStart);

    // Measure deserialization performance
    final deserializeStart = DateTime.now();
    final restoredOrders =
        jsonList.map((json) => serializer.fromJson(json)).toList();
    final deserializeEnd = DateTime.now();
    final deserializeDuration = deserializeEnd.difference(deserializeStart);

    print(
        'Serialized ${orders.length} complex orders in ${serializeDuration.inMilliseconds}ms');
    print(
        'Deserialized ${restoredOrders.length} complex orders in ${deserializeDuration.inMilliseconds}ms');

    final avgSerialize = serializeDuration.inMicroseconds / orders.length;
    final avgDeserialize = deserializeDuration.inMicroseconds / orders.length;

    print(
        'Average serialization: ${avgSerialize.toStringAsFixed(1)}μs per order');
    print(
        'Average deserialization: ${avgDeserialize.toStringAsFixed(1)}μs per order');

    // Verify integrity
    for (int i = 0; i < orders.length; i++) {
      assert(restoredOrders[i] == orders[i], 'Order $i integrity check failed');
    }

    print('\n✅ Performance test completed with full integrity!\n');
  }

  /// Create a sample order for testing
  Order _createSampleOrder() {
    final customerId = UuidValue.generate();

    final items = [
      OrderItem(
        product: ProductInfo(
          name: 'MacBook Pro',
          sku: 'MBP-16-2024',
          category: 'Electronics',
          description: '16-inch MacBook Pro with M3 chip',
        ),
        quantity: 1,
        unitPrice: Money(amount: 2499.99, currency: 'USD'),
      ),
      OrderItem(
        product: ProductInfo(
          name: 'USB-C Cable',
          sku: 'USBC-2M',
          category: 'Accessories',
          description: '2-meter USB-C charging cable',
        ),
        quantity: 2,
        unitPrice: Money(amount: 29.99, currency: 'USD'),
      ),
      OrderItem(
        product: ProductInfo(
          name: 'Laptop Stand',
          sku: 'STAND-ALU',
          category: 'Accessories',
          description: 'Aluminum adjustable laptop stand',
        ),
        quantity: 1,
        unitPrice: Money(amount: 89.99, currency: 'USD'),
      ),
    ];

    final shippingAddress = Address(
      street: '1600 Amphitheatre Parkway',
      city: 'Mountain View',
      state: 'CA',
      zipCode: '94043',
      country: 'USA',
    );

    return Order(
      customerId: customerId,
      items: items,
      shippingAddress: shippingAddress,
      status: OrderStatus.pending,
      notes: 'Please handle with care - contains electronics',
    );
  }
}
