/// Property-based tests for data type round-trip preservation.
///
/// **Feature: mysql-driver-migration, Property 3: Data type round-trip
/// preservation**
/// **Validates: Requirements 1.5**
@Tags(['requires-mysql', 'property-test'])
library;

import 'dart:math';

import 'package:dddart/dddart.dart';
import 'package:test/test.dart';

import 'integration_test_models.dart';
import 'test_helpers.dart';

void main() {
  group('Property 3: Data type round-trip preservation', () {
    TestMysqlHelper? helper;
    var mysqlAvailable = false;

    setUpAll(() async {
      // Test if MySQL is available
      final testHelper = createTestHelper();
      try {
        await testHelper.connect();
        mysqlAvailable = true;
        await testHelper.disconnect();
      } catch (e) {
        // MySQL not available - tests will be skipped
        mysqlAvailable = false;
      }
    });

    setUp(() async {
      if (!mysqlAvailable) {
        markTestSkipped('MySQL not available on localhost:3307');
        return;
      }
      helper = createTestHelper();
      await helper!.connect();
    });

    tearDown(() async {
      if (helper != null && helper!.isConnected) {
        try {
          await helper!.dropAllTables();
        } catch (e) {
          // Ignore cleanup errors
        }
        await helper!.disconnect();
      }
    });

    test(
      'should preserve String values through persist and retrieve cycles',
      () async {
        final repo = SimpleProductMysqlRepository(helper!.connection);
        await repo.createTables();

        final random = Random(50);

        for (var i = 0; i < 100; i++) {
          // Generate random string with various characteristics
          final name = _generateRandomString(random);

          final product = SimpleProduct(
            name: name,
            price: 10,
          );

          // Save
          await repo.save(product);

          // Retrieve
          final retrieved = await repo.getById(product.id);

          // Verify String is preserved exactly
          expect(
            retrieved.name,
            equals(name),
            reason: 'Iteration $i: String should be preserved exactly',
          );

          // Clean up
          await repo.deleteById(product.id);
        }
      },
    );

    test(
      'should preserve double values through persist and retrieve cycles',
      () async {
        final repo = SimpleProductMysqlRepository(helper!.connection);
        await repo.createTables();

        final random = Random(51);

        for (var i = 0; i < 100; i++) {
          // Generate random double with various ranges
          final price = _generateRandomDouble(random);

          final product = SimpleProduct(
            name: 'Product $i',
            price: price,
          );

          // Save
          await repo.save(product);

          // Retrieve
          final retrieved = await repo.getById(product.id);

          // Verify double is preserved (with small tolerance for floating point)
          expect(
            retrieved.price,
            closeTo(price, 0.0001),
            reason: 'Iteration $i: double should be preserved',
          );

          // Clean up
          await repo.deleteById(product.id);
        }
      },
    );

    test(
      'should preserve int values through persist and retrieve cycles',
      () async {
        final repo = OrderMysqlRepository(helper!.connection);
        await repo.createTables();

        final random = Random(52);

        for (var i = 0; i < 100; i++) {
          // Generate random int values
          final quantity = random.nextInt(1000000);

          final order = Order(
            customerName: 'Customer $i',
            items: [
              OrderItem(
                productName: 'Product',
                quantity: quantity,
                unitPrice: 10,
              ),
            ],
          );

          // Save
          await repo.save(order);

          // Retrieve
          final retrieved = await repo.getById(order.id);

          // Verify int is preserved exactly
          expect(
            retrieved.items[0].quantity,
            equals(quantity),
            reason: 'Iteration $i: int should be preserved exactly',
          );

          // Clean up
          await repo.deleteById(order.id);
        }
      },
    );

    test(
      'should preserve DateTime values through persist and retrieve cycles',
      () async {
        final repo = SimpleProductMysqlRepository(helper!.connection);
        await repo.createTables();

        final random = Random(53);

        for (var i = 0; i < 100; i++) {
          // Generate random DateTime
          final createdAt = _generateRandomDateTime(random);

          final product = SimpleProduct(
            name: 'Product $i',
            price: 10,
            createdAt: createdAt,
          );

          // Save
          await repo.save(product);

          // Retrieve
          final retrieved = await repo.getById(product.id);

          // Verify DateTime is preserved (millisecond precision)
          expect(
            retrieved.createdAt.millisecondsSinceEpoch,
            equals(createdAt.millisecondsSinceEpoch),
            reason: 'Iteration $i: DateTime should be preserved',
          );

          // Clean up
          await repo.deleteById(product.id);
        }
      },
    );

    test(
      'should preserve UuidValue (ID) through persist and retrieve cycles',
      () async {
        final repo = SimpleProductMysqlRepository(helper!.connection);
        await repo.createTables();

        for (var i = 0; i < 100; i++) {
          // Generate product with random UUID
          final id = UuidValue.generate();

          final product = SimpleProduct(
            name: 'Product $i',
            price: 10,
            id: id,
          );

          // Save
          await repo.save(product);

          // Retrieve
          final retrieved = await repo.getById(id);

          // Verify UUID is preserved exactly
          expect(
            retrieved.id,
            equals(id),
            reason: 'Iteration $i: UuidValue should be preserved exactly',
          );

          // Clean up
          await repo.deleteById(id);
        }
      },
    );

    test(
      'should preserve nullable values through persist and retrieve cycles',
      () async {
        final repo = CustomerMysqlRepository(helper!.connection);
        await repo.createTables();

        final random = Random(54);

        for (var i = 0; i < 100; i++) {
          // Randomly include or exclude billing address
          final includeBilling = random.nextBool();

          final customer = Customer(
            name: 'Customer $i',
            email: Email(value: 'test$i@example.com'),
            shippingAddress: const Address(
              street: '123 Main St',
              city: 'City',
              state: 'CA',
              zipCode: '12345',
            ),
            billingAddress: includeBilling
                ? const Address(
                    street: '456 Oak Ave',
                    city: 'Town',
                    state: 'NY',
                    zipCode: '67890',
                  )
                : null,
          );

          // Save
          await repo.save(customer);

          // Retrieve
          final retrieved = await repo.getById(customer.id);

          // Verify nullable field is preserved correctly
          if (includeBilling) {
            expect(
              retrieved.billingAddress,
              isNotNull,
              reason: 'Iteration $i: Non-null value should be preserved',
            );
            expect(
              retrieved.billingAddress!.street,
              equals('456 Oak Ave'),
              reason:
                  'Iteration $i: Nullable object fields should be preserved',
            );
          } else {
            expect(
              retrieved.billingAddress,
              isNull,
              reason: 'Iteration $i: Null value should be preserved',
            );
          }

          // Clean up
          await repo.deleteById(customer.id);
        }
      },
    );

    test(
      'should handle edge case values correctly',
      () async {
        final repo = SimpleProductMysqlRepository(helper!.connection);
        await repo.createTables();

        // Test edge cases
        final edgeCases = [
          ('Empty string', '', 0.0),
          ('Very long string', 'a' * 1000, 0.0),
          ('String with special chars', 'Test\n\t\r"\'\\', 0.0),
          ('Zero price', 'Product', 0.0),
          ('Very large price', 'Product', 999999999.99),
          ('Very small price', 'Product', 0.01),
          ('Negative price', 'Product', -100.0),
        ];

        for (var i = 0; i < edgeCases.length; i++) {
          final (description, name, price) = edgeCases[i];

          final product = SimpleProduct(
            name: name,
            price: price,
          );

          // Save
          await repo.save(product);

          // Retrieve
          final retrieved = await repo.getById(product.id);

          // Verify edge case is handled
          expect(
            retrieved.name,
            equals(name),
            reason: '$description: name should be preserved',
          );
          expect(
            retrieved.price,
            closeTo(price, 0.0001),
            reason: '$description: price should be preserved',
          );

          // Clean up
          await repo.deleteById(product.id);
        }
      },
    );
  });
}

// Generator functions

/// Generates a random string with various characteristics.
String _generateRandomString(Random random) {
  final types = [
    // Short strings
    () => 'a' * (random.nextInt(10) + 1),
    // Medium strings
    () => 'Test ${random.nextInt(1000)}',
    // Strings with spaces
    () => 'Product Name ${random.nextInt(100)}',
    // Strings with special characters
    () => 'Test-${random.nextInt(100)}_Product',
    // Unicode strings
    () => 'Tëst Prödüct ${random.nextInt(100)}',
  ];

  return types[random.nextInt(types.length)]();
}

/// Generates a random double with various ranges.
double _generateRandomDouble(Random random) {
  final types = [
    // Small values
    () => random.nextDouble() * 10,
    // Medium values
    () => random.nextDouble() * 1000,
    // Large values
    () => random.nextDouble() * 1000000,
    // Very precise values
    () => random.nextDouble() * 100,
    // Negative values
    () => -random.nextDouble() * 100,
  ];

  return types[random.nextInt(types.length)]();
}

/// Generates a random DateTime.
DateTime _generateRandomDateTime(Random random) {
  // Generate dates between 2000 and 2030
  final year = 2000 + random.nextInt(30);
  final month = 1 + random.nextInt(12);
  final day = 1 + random.nextInt(28); // Safe for all months
  final hour = random.nextInt(24);
  final minute = random.nextInt(60);
  final second = random.nextInt(60);
  final millisecond = random.nextInt(1000);

  return DateTime(year, month, day, hour, minute, second, millisecond);
}
