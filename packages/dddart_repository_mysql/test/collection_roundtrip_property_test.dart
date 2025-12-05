/// Property-based tests for collection round-trip preservation.
///
/// **Feature: mysql-driver-migration, Property 1: Collection round-trip
/// preservation**
/// **Validates: Requirements 1.3**
@Tags(['requires-mysql', 'property-test'])
library;

import 'dart:math';

import 'package:test/test.dart';

import 'integration_test_models.dart';
import 'test_helpers.dart';

void main() {
  group('Property 1: Collection round-trip preservation', () {
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
      'should preserve List collections through persist and retrieve cycles',
      () async {
        final repo = OrderMysqlRepository(helper!.connection);
        await repo.createTables();

        final random = Random(42);

        // Run 100 iterations with random data
        for (var i = 0; i < 100; i++) {
          // Generate random order with random number of items
          final itemCount = random.nextInt(10) + 1;
          final items = List.generate(
            itemCount,
            (index) => OrderItem(
              productName: 'Product ${random.nextInt(1000)}',
              quantity: random.nextInt(100) + 1,
              unitPrice: random.nextDouble() * 1000,
            ),
          );

          final order = Order(
            customerName: 'Customer ${random.nextInt(1000)}',
            items: items,
          );

          // Save
          await repo.save(order);

          // Retrieve
          final retrieved = await repo.getById(order.id);

          // Verify collection is a List
          expect(
            retrieved.items,
            isA<List<OrderItem>>(),
            reason: 'Iteration $i: items should be a List',
          );

          // Verify collection has same length
          expect(
            retrieved.items.length,
            equals(items.length),
            reason: 'Iteration $i: items length should match',
          );

          // Verify all items are preserved
          for (var j = 0; j < items.length; j++) {
            expect(
              retrieved.items[j].id,
              equals(items[j].id),
              reason: 'Iteration $i, item $j: ID should match',
            );
            expect(
              retrieved.items[j].productName,
              equals(items[j].productName),
              reason: 'Iteration $i, item $j: productName should match',
            );
            expect(
              retrieved.items[j].quantity,
              equals(items[j].quantity),
              reason: 'Iteration $i, item $j: quantity should match',
            );
            expect(
              retrieved.items[j].unitPrice,
              equals(items[j].unitPrice),
              reason: 'Iteration $i, item $j: unitPrice should match',
            );
          }

          // Clean up for next iteration
          await repo.deleteById(order.id);
        }
      },
    );

    test(
      'should handle empty List collections correctly',
      () async {
        final repo = OrderMysqlRepository(helper!.connection);
        await repo.createTables();

        // Create order with empty items list
        final order = Order(
          customerName: 'Customer with no items',
          items: [],
        );

        // Save
        await repo.save(order);

        // Retrieve
        final retrieved = await repo.getById(order.id);

        // Verify collection is a List
        expect(retrieved.items, isA<List<OrderItem>>());

        // Verify collection is empty
        expect(retrieved.items.length, equals(0));
      },
    );

    test(
      'should preserve List order through persist and retrieve cycles',
      () async {
        final repo = OrderMysqlRepository(helper!.connection);
        await repo.createTables();

        for (var i = 0; i < 50; i++) {
          // Generate items with specific order
          final items = List.generate(
            5,
            (index) => OrderItem(
              productName: 'Item $index',
              quantity: index + 1,
              unitPrice: (index + 1) * 10.0,
            ),
          );

          final order = Order(
            customerName: 'Customer $i',
            items: items,
          );

          // Save
          await repo.save(order);

          // Retrieve
          final retrieved = await repo.getById(order.id);

          // Verify order is preserved
          for (var j = 0; j < items.length; j++) {
            expect(
              retrieved.items[j].productName,
              equals('Item $j'),
              reason: 'Iteration $i: Item $j should be in correct position',
            );
            expect(
              retrieved.items[j].quantity,
              equals(j + 1),
              reason: 'Iteration $i: Item $j quantity should match position',
            );
          }

          // Clean up
          await repo.deleteById(order.id);
        }
      },
    );
  });
}
