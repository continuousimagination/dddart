/// Property-based tests for SQLite repository operations.
@Tags(['property-test'])
library;

import 'dart:math';

import 'package:dddart/dddart.dart';
import 'package:dddart_repository_sqlite/dddart_repository_sqlite.dart';
import 'package:test/test.dart';

import 'test_helpers.dart';
import 'test_models.dart';

void main() {
  group('Repository Property Tests', () {
    late TestSqliteHelper helper;
    late SqliteConnection connection;

    setUp(() {
      helper = createTestHelper();
      connection = helper.connect();
    });

    tearDown(() {
      helper.disconnect();
    });

    // **Feature: sql-repository, Property 1: Aggregate round trip preserves all fields**
    // **Validates: Requirements 2.1, 2.2, 4.1, 4.3**
    group('Property 1: Aggregate round trip preserves all fields', () {
      test('should preserve all fields when saving and retrieving Order',
          () async {
        final repo = OrderSqliteRepository(connection);
        await repo.createTables();

        final random = Random(42);

        for (var i = 0; i < 100; i++) {
          // Generate random order with nested entities and value objects
          final order = _generateRandomOrder(random);

          // Save the order
          await repo.save(order);

          // Retrieve the order
          final retrieved = await repo.getById(order.id);

          // Verify all fields match
          expect(
            retrieved.id,
            equals(order.id),
            reason: 'Iteration $i: ID should match',
          );
          expect(
            retrieved.customerId,
            equals(order.customerId),
            reason: 'Iteration $i: Customer ID should match',
          );
          expect(
            retrieved.totalAmount.amount,
            equals(order.totalAmount.amount),
            reason: 'Iteration $i: Total amount should match',
          );
          expect(
            retrieved.totalAmount.currency,
            equals(order.totalAmount.currency),
            reason: 'Iteration $i: Total currency should match',
          );
          expect(
            retrieved.shippingAddress.street,
            equals(order.shippingAddress.street),
            reason: 'Iteration $i: Shipping street should match',
          );
          expect(
            retrieved.shippingAddress.city,
            equals(order.shippingAddress.city),
            reason: 'Iteration $i: Shipping city should match',
          );
          expect(
            retrieved.shippingAddress.country,
            equals(order.shippingAddress.country),
            reason: 'Iteration $i: Shipping country should match',
          );

          // Clean up for next iteration
          await repo.deleteById(order.id);
        }
      });
    });

    // **Feature: sql-repository, Property 2: Nested entities are preserved**
    // **Validates: Requirements 2.3, 2.4**
    group('Property 2: Nested entities are preserved', () {
      test('should preserve list order and entity fields', () async {
        final repo = OrderSqliteRepository(connection);
        await repo.createTables();

        final random = Random(43);

        for (var i = 0; i < 100; i++) {
          final order = _generateRandomOrder(random);

          await repo.save(order);
          final retrieved = await repo.getById(order.id);

          // Verify list length
          expect(
            retrieved.items.length,
            equals(order.items.length),
            reason: 'Iteration $i: Item count should match',
          );

          // Verify each item's fields
          for (var j = 0; j < order.items.length; j++) {
            expect(
              retrieved.items[j].productId,
              equals(order.items[j].productId),
              reason: 'Iteration $i, Item $j: Product ID should match',
            );
            expect(
              retrieved.items[j].quantity,
              equals(order.items[j].quantity),
              reason: 'Iteration $i, Item $j: Quantity should match',
            );
            expect(
              retrieved.items[j].price.amount,
              equals(order.items[j].price.amount),
              reason: 'Iteration $i, Item $j: Price amount should match',
            );
            expect(
              retrieved.items[j].price.currency,
              equals(order.items[j].price.currency),
              reason: 'Iteration $i, Item $j: Price currency should match',
            );
          }

          await repo.deleteById(order.id);
        }
      });
    });

    // **Feature: sql-repository, Property 3: Value objects are preserved**
    // **Validates: Requirements 12.1, 12.2, 12.4**
    group('Property 3: Value objects are preserved', () {
      test('should preserve embedded value object fields', () async {
        final repo = OrderSqliteRepository(connection);
        await repo.createTables();

        final random = Random(44);

        for (var i = 0; i < 100; i++) {
          final order = _generateRandomOrder(random);

          await repo.save(order);
          final retrieved = await repo.getById(order.id);

          // Verify Money value object (totalAmount)
          expect(
            retrieved.totalAmount.amount,
            equals(order.totalAmount.amount),
            reason: 'Iteration $i: Money amount should match',
          );
          expect(
            retrieved.totalAmount.currency,
            equals(order.totalAmount.currency),
            reason: 'Iteration $i: Money currency should match',
          );

          // Verify Address value object (shippingAddress)
          expect(
            retrieved.shippingAddress.street,
            equals(order.shippingAddress.street),
            reason: 'Iteration $i: Address street should match',
          );
          expect(
            retrieved.shippingAddress.city,
            equals(order.shippingAddress.city),
            reason: 'Iteration $i: Address city should match',
          );
          expect(
            retrieved.shippingAddress.country,
            equals(order.shippingAddress.country),
            reason: 'Iteration $i: Address country should match',
          );

          // Verify nested value objects in items
          for (var j = 0; j < order.items.length; j++) {
            expect(
              retrieved.items[j].price.amount,
              equals(order.items[j].price.amount),
              reason: 'Iteration $i, Item $j: Nested Money amount should match',
            );
            expect(
              retrieved.items[j].price.currency,
              equals(order.items[j].price.currency),
              reason:
                  'Iteration $i, Item $j: Nested Money currency should match',
            );
          }

          await repo.deleteById(order.id);
        }
      });
    });

    // **Feature: sql-repository, Property 4: Deleting aggregate cascades to entities**
    // **Validates: Requirements 4.5**
    group('Property 4: Deleting aggregate cascades to entities', () {
      test('should delete all entity rows when aggregate is deleted', () async {
        final repo = OrderSqliteRepository(connection);
        await repo.createTables();

        final random = Random(45);

        for (var i = 0; i < 100; i++) {
          final order = _generateRandomOrder(random);

          // Save order with items
          await repo.save(order);

          // Verify items exist by loading the order
          final loaded = await repo.getById(order.id);
          expect(loaded.items.length, greaterThan(0));

          // Delete the aggregate
          await repo.deleteById(order.id);

          // Verify aggregate is gone
          expect(
            () => repo.getById(order.id),
            throwsA(
              isA<RepositoryException>().having(
                (e) => e.type,
                'type',
                RepositoryExceptionType.notFound,
              ),
            ),
            reason: 'Iteration $i: Deleted aggregate should not be found',
          );

          // Verify entity rows are also deleted (cascade)
          // Query the order_item table directly
          final itemRows = await connection.query(
            'SELECT * FROM order_item WHERE orders_id = ?',
            [const SqliteDialect().encodeUuid(order.id)],
          );
          expect(
            itemRows.isEmpty,
            isTrue,
            reason:
                'Iteration $i: Entity rows should be deleted via CASCADE DELETE',
          );
        }
      });
    });

    // **Feature: sql-repository, Property 6: Non-existent ID throws notFound**
    // **Validates: Requirements 4.2**
    group('Property 6: Non-existent ID throws notFound', () {
      test('should throw notFound for random non-existent UUIDs', () async {
        final repo = OrderSqliteRepository(connection);
        await repo.createTables();

        for (var i = 0; i < 100; i++) {
          final randomId = UuidValue.generate();

          expect(
            () => repo.getById(randomId),
            throwsA(
              isA<RepositoryException>().having(
                (e) => e.type,
                'type',
                RepositoryExceptionType.notFound,
              ),
            ),
            reason: 'Iteration $i: Non-existent ID should throw notFound',
          );
        }
      });
    });

    // **Feature: sql-repository, Property 7: Update preserves relationships**
    // **Validates: Requirements 4.4**
    group('Property 7: Update preserves relationships', () {
      test('should preserve modified entity values after update', () async {
        final repo = OrderSqliteRepository(connection);
        await repo.createTables();

        final random = Random(47);

        for (var i = 0; i < 100; i++) {
          final order = _generateRandomOrder(random);

          // Save initial order
          await repo.save(order);

          // Modify a nested entity
          final modifiedOrder = Order(
            id: order.id,
            createdAt: order.createdAt,
            updatedAt: DateTime.now(),
            customerId: order.customerId,
            totalAmount: Money(
              amount: order.totalAmount.amount + 100.0,
              currency: order.totalAmount.currency,
            ),
            shippingAddress: order.shippingAddress,
            items: [
              ...order.items.sublist(0, order.items.length - 1),
              OrderItem(
                id: order.items.last.id,
                createdAt: order.items.last.createdAt,
                updatedAt: DateTime.now(),
                productId: order.items.last.productId,
                quantity: order.items.last.quantity + 5,
                price: order.items.last.price,
              ),
            ],
          );

          // Save modified order
          await repo.save(modifiedOrder);

          // Retrieve and verify
          final retrieved = await repo.getById(order.id);

          expect(
            retrieved.totalAmount.amount,
            equals(modifiedOrder.totalAmount.amount),
            reason: 'Iteration $i: Modified total amount should be preserved',
          );
          expect(
            retrieved.items.last.quantity,
            equals(modifiedOrder.items.last.quantity),
            reason: 'Iteration $i: Modified item quantity should be preserved',
          );

          await repo.deleteById(order.id);
        }
      });
    });

    // **Feature: sql-repository, Property 8: Concurrent saves maintain integrity**
    // **Validates: Requirements 4.3, 4.4**
    group('Property 8: Concurrent saves maintain integrity', () {
      test('should handle concurrent saves without corruption', () async {
        final repo = OrderSqliteRepository(connection);
        await repo.createTables();

        final random = Random(48);

        for (var i = 0; i < 100; i++) {
          // Generate two different orders
          final order1 = _generateRandomOrder(random);
          final order2 = _generateRandomOrder(random);

          // Save both concurrently
          await Future.wait([
            repo.save(order1),
            repo.save(order2),
          ]);

          // Verify both are fully persisted
          final retrieved1 = await repo.getById(order1.id);
          final retrieved2 = await repo.getById(order2.id);

          // Verify order1
          expect(retrieved1.id, equals(order1.id));
          expect(retrieved1.customerId, equals(order1.customerId));
          expect(retrieved1.items.length, equals(order1.items.length));

          // Verify order2
          expect(retrieved2.id, equals(order2.id));
          expect(retrieved2.customerId, equals(order2.customerId));
          expect(retrieved2.items.length, equals(order2.items.length));

          // Clean up
          await Future.wait([
            repo.deleteById(order1.id),
            repo.deleteById(order2.id),
          ]);
        }
      });
    });

    // **Feature: sql-repository, Property 9: UUID round trip**
    // **Validates: Requirements 10.1, 10.2**
    group('Property 9: UUID round trip', () {
      test('should preserve UUID values through BLOB encoding', () async {
        final repo = OrderSqliteRepository(connection);
        await repo.createTables();

        final random = Random(49);

        for (var i = 0; i < 100; i++) {
          final order = _generateRandomOrder(random);

          await repo.save(order);
          final retrieved = await repo.getById(order.id);

          // Verify all UUID fields
          expect(
            retrieved.id,
            equals(order.id),
            reason: 'Iteration $i: Order ID UUID should match',
          );
          expect(
            retrieved.customerId,
            equals(order.customerId),
            reason: 'Iteration $i: Customer ID UUID should match',
          );

          for (var j = 0; j < order.items.length; j++) {
            expect(
              retrieved.items[j].id,
              equals(order.items[j].id),
              reason: 'Iteration $i, Item $j: Item ID UUID should match',
            );
            expect(
              retrieved.items[j].productId,
              equals(order.items[j].productId),
              reason: 'Iteration $i, Item $j: Product ID UUID should match',
            );
          }

          await repo.deleteById(order.id);
        }
      });
    });

    // **Feature: sql-repository, Property 10: DateTime precision preserved**
    // **Validates: Requirements 3.6**
    group('Property 10: DateTime precision preserved', () {
      test('should preserve DateTime values within millisecond precision',
          () async {
        final repo = OrderSqliteRepository(connection);
        await repo.createTables();

        final random = Random(50);

        for (var i = 0; i < 100; i++) {
          final order = _generateRandomOrder(random);

          await repo.save(order);
          final retrieved = await repo.getById(order.id);

          // Verify DateTime fields (millisecond precision)
          expect(
            retrieved.createdAt.millisecondsSinceEpoch,
            equals(order.createdAt.millisecondsSinceEpoch),
            reason: 'Iteration $i: createdAt should match to millisecond',
          );
          expect(
            retrieved.updatedAt.millisecondsSinceEpoch,
            equals(order.updatedAt.millisecondsSinceEpoch),
            reason: 'Iteration $i: updatedAt should match to millisecond',
          );

          for (var j = 0; j < order.items.length; j++) {
            expect(
              retrieved.items[j].createdAt.millisecondsSinceEpoch,
              equals(order.items[j].createdAt.millisecondsSinceEpoch),
              reason:
                  'Iteration $i, Item $j: Item createdAt should match to millisecond',
            );
            expect(
              retrieved.items[j].updatedAt.millisecondsSinceEpoch,
              equals(order.items[j].updatedAt.millisecondsSinceEpoch),
              reason:
                  'Iteration $i, Item $j: Item updatedAt should match to millisecond',
            );
          }

          await repo.deleteById(order.id);
        }
      });
    });

    // **Feature: sql-repository, Property 11: Boolean values preserved**
    // **Validates: Requirements 3.7**
    group('Property 11: Boolean values preserved', () {
      test('should preserve boolean field values', () async {
        final userRepo = TestUserSqliteRepository(connection);
        await userRepo.createTables();

        final random = Random(51);

        for (var i = 0; i < 100; i++) {
          // Generate user with random boolean value
          final user = TestUser(
            id: UuidValue.generate(),
            createdAt: _generateRandomDateTime(random),
            updatedAt: _generateRandomDateTime(random),
            name: 'User $i',
            email: 'user$i@example.com',
            isActive: random.nextBool(),
          );

          await userRepo.save(user);
          final retrieved = await userRepo.getById(user.id);

          expect(
            retrieved.isActive,
            equals(user.isActive),
            reason: 'Iteration $i: Boolean isActive should match',
          );

          await userRepo.deleteById(user.id);
        }
      });
    });
  });
}

// Generator functions

/// Generates a random Order instance with nested entities and value objects.
Order _generateRandomOrder(Random random) {
  final itemCount = random.nextInt(5) + 1; // 1-5 items
  final items = List.generate(
    itemCount,
    (_) => OrderItem(
      productId: UuidValue.generate(),
      quantity: random.nextInt(10) + 1,
      price: _generateRandomMoney(random),
    ),
  );

  return Order(
    id: UuidValue.generate(),
    createdAt: _generateRandomDateTime(random),
    updatedAt: _generateRandomDateTime(random),
    customerId: UuidValue.generate(),
    totalAmount: _generateRandomMoney(random),
    shippingAddress: _generateRandomAddress(random),
    items: items,
  );
}

/// Generates a random Money value object.
Money _generateRandomMoney(Random random) {
  final currencies = ['USD', 'EUR', 'GBP', 'JPY'];
  return Money(
    amount: (random.nextInt(999999) + 1) / 100.0,
    currency: currencies[random.nextInt(currencies.length)],
  );
}

/// Generates a random Address value object.
Address _generateRandomAddress(Random random) {
  final streets = ['Main St', 'Oak Ave', 'Elm Rd', 'Pine Blvd'];
  final cities = ['New York', 'London', 'Tokyo', 'Paris'];
  final countries = ['USA', 'UK', 'Japan', 'France'];

  return Address(
    street:
        '${random.nextInt(9999) + 1} ${streets[random.nextInt(streets.length)]}',
    city: cities[random.nextInt(cities.length)],
    country: countries[random.nextInt(countries.length)],
  );
}

/// Generates a random DateTime within the last year.
DateTime _generateRandomDateTime(Random random) {
  final now = DateTime.now();
  final daysAgo = random.nextInt(365);
  return now.subtract(Duration(days: daysAgo));
}
