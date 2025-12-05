/// Property-based tests for object graph persistence round-trip.
library;

import 'dart:math';

import 'package:test/test.dart';

import 'integration_test_models.dart';
import 'test_helpers.dart';

void main() {
  group(
    'Object Graph Property Tests',
    () {
      // Check MySQL availability once at the start
      var mysqlAvailable = false;

      setUpAll(() async {
        final helper = createTestHelper();
        try {
          await helper.connect();
          mysqlAvailable = true;
          await helper.disconnect();
        } catch (e) {
          // MySQL not available - tests will be skipped
          mysqlAvailable = false;
        }
      });

      setUp(() {
        if (!mysqlAvailable) {
          markTestSkipped('MySQL not available on localhost:3307');
        }
      });

      // **Feature: mysql-driver-migration, Property 2: Object graph**
      // **round-trip preservation**
      // **Validates: Requirements 1.4**
      group('Property 2: Object graph persistence round-trip', () {
        test(
          'should preserve aggregate with entities when saving then loading',
          () async {
            final helper = createTestHelper();
            await helper.connect();

            try {
              final repo = OrderMysqlRepository(helper.connection);
              await repo.createTables();

              final random = Random(42);

              // Test 100 random order configurations
              for (var i = 0; i < 100; i++) {
                // Generate random order with entities
                final order = _generateRandomOrder(random);

                // Save the order
                await repo.save(order);

                // Load the order back
                final retrieved = await repo.getById(order.id);

                // Verify aggregate root fields
                expect(
                  retrieved.id,
                  equals(order.id),
                  reason: 'Iteration $i: ID should be preserved',
                );
                expect(
                  retrieved.customerName,
                  equals(order.customerName),
                  reason: 'Iteration $i: Customer name should be preserved',
                );

                // Verify entity collection
                expect(
                  retrieved.items.length,
                  equals(order.items.length),
                  reason: 'Iteration $i: Number of items should be preserved',
                );

                // Verify each entity
                for (var j = 0; j < order.items.length; j++) {
                  final originalItem = order.items[j];
                  // Find matching item by product name (order may vary)
                  final retrievedItem = retrieved.items.firstWhere(
                    (item) => item.productName == originalItem.productName,
                    orElse: () => throw StateError(
                      'Item ${originalItem.productName} not found',
                    ),
                  );

                  expect(
                    retrievedItem.productName,
                    equals(originalItem.productName),
                    reason: 'Iteration $i, Item $j: Product name should be '
                        'preserved',
                  );
                  expect(
                    retrievedItem.quantity,
                    equals(originalItem.quantity),
                    reason:
                        'Iteration $i, Item $j: Quantity should be preserved',
                  );
                  expect(
                    retrievedItem.unitPrice,
                    equals(originalItem.unitPrice),
                    reason: 'Iteration $i, Item $j: Unit price should be '
                        'preserved',
                  );
                }

                // Clean up for next iteration
                await repo.deleteById(order.id);
              }
            } finally {
              await helper.dropAllTables();
              await helper.disconnect();
            }
          },
        );

        test(
          'should preserve aggregate with value objects when saving then '
          'loading',
          () async {
            final helper = createTestHelper();
            await helper.connect();

            try {
              final repo = CustomerMysqlRepository(helper.connection);
              await repo.createTables();

              final random = Random(43);

              // Test 100 random customer configurations
              for (var i = 0; i < 100; i++) {
                // Generate random customer with value objects
                final customer = _generateRandomCustomer(random);

                // Save the customer
                await repo.save(customer);

                // Load the customer back
                final retrieved = await repo.getById(customer.id);

                // Verify aggregate root fields
                expect(
                  retrieved.id,
                  equals(customer.id),
                  reason: 'Iteration $i: ID should be preserved',
                );
                expect(
                  retrieved.name,
                  equals(customer.name),
                  reason: 'Iteration $i: Name should be preserved',
                );

                // Verify email value object
                expect(
                  retrieved.email.value,
                  equals(customer.email.value),
                  reason: 'Iteration $i: Email should be preserved',
                );

                // Verify shipping address value object
                expect(
                  retrieved.shippingAddress.street,
                  equals(customer.shippingAddress.street),
                  reason: 'Iteration $i: Shipping street should be preserved',
                );
                expect(
                  retrieved.shippingAddress.city,
                  equals(customer.shippingAddress.city),
                  reason: 'Iteration $i: Shipping city should be preserved',
                );
                expect(
                  retrieved.shippingAddress.state,
                  equals(customer.shippingAddress.state),
                  reason: 'Iteration $i: Shipping state should be preserved',
                );
                expect(
                  retrieved.shippingAddress.zipCode,
                  equals(customer.shippingAddress.zipCode),
                  reason: 'Iteration $i: Shipping zip code should be preserved',
                );

                // Verify nullable billing address value object
                if (customer.billingAddress == null) {
                  expect(
                    retrieved.billingAddress,
                    isNull,
                    reason: 'Iteration $i: Billing address should be null',
                  );
                } else {
                  expect(
                    retrieved.billingAddress,
                    isNotNull,
                    reason: 'Iteration $i: Billing address should not be null',
                  );
                  expect(
                    retrieved.billingAddress!.street,
                    equals(customer.billingAddress!.street),
                    reason: 'Iteration $i: Billing street should be preserved',
                  );
                  expect(
                    retrieved.billingAddress!.city,
                    equals(customer.billingAddress!.city),
                    reason: 'Iteration $i: Billing city should be preserved',
                  );
                  expect(
                    retrieved.billingAddress!.state,
                    equals(customer.billingAddress!.state),
                    reason: 'Iteration $i: Billing state should be preserved',
                  );
                  expect(
                    retrieved.billingAddress!.zipCode,
                    equals(customer.billingAddress!.zipCode),
                    reason:
                        'Iteration $i: Billing zip code should be preserved',
                  );
                }

                // Clean up for next iteration
                await repo.deleteById(customer.id);
              }
            } finally {
              await helper.dropAllTables();
              await helper.disconnect();
            }
          },
        );

        test(
          'should preserve simple aggregate when saving then loading',
          () async {
            final helper = createTestHelper();
            await helper.connect();

            try {
              final repo = SimpleProductMysqlRepository(helper.connection);
              await repo.createTables();

              final random = Random(44);

              // Test 100 random simple product configurations
              for (var i = 0; i < 100; i++) {
                // Generate random simple product
                final product = _generateRandomSimpleProduct(random);

                // Save the product
                await repo.save(product);

                // Load the product back
                final retrieved = await repo.getById(product.id);

                // Verify all fields
                expect(
                  retrieved.id,
                  equals(product.id),
                  reason: 'Iteration $i: ID should be preserved',
                );
                expect(
                  retrieved.name,
                  equals(product.name),
                  reason: 'Iteration $i: Name should be preserved',
                );
                expect(
                  retrieved.price,
                  equals(product.price),
                  reason: 'Iteration $i: Price should be preserved',
                );

                // Clean up for next iteration
                await repo.deleteById(product.id);
              }
            } finally {
              await helper.dropAllTables();
              await helper.disconnect();
            }
          },
        );

        test(
          'should handle empty entity collections in round-trip',
          () async {
            final helper = createTestHelper();
            await helper.connect();

            try {
              final repo = OrderMysqlRepository(helper.connection);
              await repo.createTables();

              final random = Random(45);

              // Test 50 orders with empty item lists
              for (var i = 0; i < 50; i++) {
                // Generate order with no items
                final order = Order(
                  customerName: _generateRandomString(random, 10),
                  items: [],
                );

                // Save the order
                await repo.save(order);

                // Load the order back
                final retrieved = await repo.getById(order.id);

                // Verify empty collection is preserved
                expect(
                  retrieved.items,
                  isEmpty,
                  reason: 'Iteration $i: Empty items list should be preserved',
                );

                // Clean up for next iteration
                await repo.deleteById(order.id);
              }
            } finally {
              await helper.dropAllTables();
              await helper.disconnect();
            }
          },
        );

        test(
          'should handle updates to existing aggregates',
          () async {
            final helper = createTestHelper();
            await helper.connect();

            try {
              final repo = OrderMysqlRepository(helper.connection);
              await repo.createTables();

              final random = Random(46);

              // Test 50 update scenarios
              for (var i = 0; i < 50; i++) {
                // Generate initial order
                final initialOrder = _generateRandomOrder(random);

                // Save initial version
                await repo.save(initialOrder);

                // Generate updated version with same ID
                final updatedOrder = Order(
                  customerName: _generateRandomString(random, 15),
                  items: _generateRandomOrderItems(random),
                  id: initialOrder.id,
                );

                // Save updated version
                await repo.save(updatedOrder);

                // Load and verify updated version
                final retrieved = await repo.getById(initialOrder.id);

                expect(
                  retrieved.id,
                  equals(updatedOrder.id),
                  reason: 'Iteration $i: ID should remain the same',
                );
                expect(
                  retrieved.customerName,
                  equals(updatedOrder.customerName),
                  reason: 'Iteration $i: Updated customer name should be '
                      'preserved',
                );
                expect(
                  retrieved.items.length,
                  equals(updatedOrder.items.length),
                  reason:
                      'Iteration $i: Updated items count should be preserved',
                );

                // Clean up for next iteration
                await repo.deleteById(initialOrder.id);
              }
            } finally {
              await helper.dropAllTables();
              await helper.disconnect();
            }
          },
        );
      });
    },
    tags: ['requires-mysql', 'property-test'],
  );
}

// Generator functions

/// Generates a random Order with random items.
Order _generateRandomOrder(Random random) {
  return Order(
    customerName: _generateRandomString(random, 20),
    items: _generateRandomOrderItems(random),
  );
}

/// Generates a random list of OrderItems.
List<OrderItem> _generateRandomOrderItems(Random random) {
  final itemCount = random.nextInt(5); // 0-4 items

  return List.generate(
    itemCount,
    (i) => OrderItem(
      productName: _generateRandomString(random, 15),
      quantity: random.nextInt(10) + 1, // 1-10
      unitPrice: _generateRandomPrice(random),
    ),
  );
}

/// Generates a random Customer with value objects.
Customer _generateRandomCustomer(Random random) {
  return Customer(
    name: _generateRandomString(random, 20),
    email: Email(value: _generateRandomEmail(random)),
    shippingAddress: _generateRandomAddress(random),
    billingAddress: random.nextBool() ? _generateRandomAddress(random) : null,
  );
}

/// Generates a random SimpleProduct.
SimpleProduct _generateRandomSimpleProduct(Random random) {
  return SimpleProduct(
    name: _generateRandomString(random, 30),
    price: _generateRandomPrice(random),
  );
}

/// Generates a random Address value object.
Address _generateRandomAddress(Random random) {
  return Address(
    street: '${random.nextInt(9999) + 1} ${_generateRandomString(random, 10)} '
        '${_getRandomStreetSuffix(random)}',
    city: _generateRandomString(random, 15),
    state: _getRandomState(random),
    zipCode: _generateRandomZipCode(random),
  );
}

/// Generates a random string of specified length.
String _generateRandomString(Random random, int maxLength) {
  final length = random.nextInt(maxLength) + 1;
  const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';

  return String.fromCharCodes(
    Iterable.generate(
      length,
      (_) => chars.codeUnitAt(random.nextInt(chars.length)),
    ),
  );
}

/// Generates a random email address.
String _generateRandomEmail(Random random) {
  final username = _generateRandomString(random, 10).toLowerCase();
  final domains = ['example.com', 'test.com', 'demo.org', 'sample.net'];
  final domain = domains[random.nextInt(domains.length)];

  return '$username@$domain';
}

/// Generates a random price between 0.01 and 999.99.
double _generateRandomPrice(Random random) {
  return (random.nextInt(99999) + 1) / 100.0;
}

/// Gets a random street suffix.
String _getRandomStreetSuffix(Random random) {
  const suffixes = ['St', 'Ave', 'Rd', 'Blvd', 'Ln', 'Dr', 'Way'];
  return suffixes[random.nextInt(suffixes.length)];
}

/// Gets a random US state abbreviation.
String _getRandomState(Random random) {
  const states = [
    'AL',
    'AK',
    'AZ',
    'AR',
    'CA',
    'CO',
    'CT',
    'DE',
    'FL',
    'GA',
    'HI',
    'ID',
    'IL',
    'IN',
    'IA',
    'KS',
    'KY',
    'LA',
    'ME',
    'MD',
    'MA',
    'MI',
    'MN',
    'MS',
    'MO',
    'MT',
    'NE',
    'NV',
    'NH',
    'NJ',
    'NM',
    'NY',
    'NC',
    'ND',
    'OH',
    'OK',
    'OR',
    'PA',
    'RI',
    'SC',
    'SD',
    'TN',
    'TX',
    'UT',
    'VT',
    'VA',
    'WA',
    'WV',
    'WI',
    'WY',
  ];
  return states[random.nextInt(states.length)];
}

/// Generates a random 5-digit zip code.
String _generateRandomZipCode(Random random) {
  return (random.nextInt(90000) + 10000).toString();
}
