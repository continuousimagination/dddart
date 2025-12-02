/// Integration tests for generated MySQL repositories.
///
/// These tests require a running MySQL instance on localhost:3307.
/// You can use Docker to run MySQL:
///   docker run -d -p 3307:3306 -e MYSQL_ROOT_PASSWORD=test_password \
///     -e MYSQL_DATABASE=test_db mysql:8.0
///
/// Or skip these tests if MySQL is not available:
///   dart test --exclude-tags=requires-mysql
@Tags(['requires-mysql', 'integration'])
library;

import 'package:dddart/dddart.dart';
import 'package:test/test.dart';

import 'integration_test_models.dart';
import 'test_helpers.dart';

void main() {
  group('Generated MySQL Repository Integration Tests', () {
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
      // Create fresh connection for each test
      helper = createTestHelper();
      await helper!.connect();
    });

    tearDown(() async {
      if (helper != null && helper!.isConnected) {
        try {
          // Clean up all tables
          await helper!.dropAllTables();
        } catch (e) {
          // Ignore cleanup errors
        }
        // Always disconnect to avoid connection leaks
        await helper!.disconnect();
      }
    });

    group('CRUD operations', () {
      test('should save and retrieve an aggregate', () async {
        final repo = SimpleProductMysqlRepository(helper!.connection);
        await repo.createTables();

        final product = SimpleProduct(
          name: 'Test Product',
          price: 99.99,
        );

        // Save
        await repo.save(product);

        // Retrieve
        final retrieved = await repo.getById(product.id);

        expect(retrieved.id, equals(product.id));
        expect(retrieved.name, equals('Test Product'));
        expect(retrieved.price, equals(99.99));
      });

      test('should update an existing aggregate', () async {
        final repo = SimpleProductMysqlRepository(helper!.connection);
        await repo.createTables();

        final product = SimpleProduct(
          name: 'Original',
          price: 50,
        );

        // Save initial version
        await repo.save(product);

        // Create updated version with same ID
        final updated = SimpleProduct(
          name: 'Updated',
          price: 75,
          id: product.id,
        );

        // Save updated version
        await repo.save(updated);

        // Retrieve and verify
        final retrieved = await repo.getById(product.id);
        expect(retrieved.id, equals(product.id));
        expect(retrieved.name, equals('Updated'));
        expect(retrieved.price, equals(75.0));
      });

      test('should delete an aggregate by ID', () async {
        final repo = SimpleProductMysqlRepository(helper!.connection);
        await repo.createTables();

        final product = SimpleProduct(
          name: 'To Delete',
          price: 10,
        );

        // Save
        await repo.save(product);

        // Verify it exists
        final retrieved = await repo.getById(product.id);
        expect(retrieved.id, equals(product.id));

        // Delete
        await repo.deleteById(product.id);

        // Verify it's gone
        expect(
          () => repo.getById(product.id),
          throwsA(
            isA<RepositoryException>().having(
              (e) => e.type,
              'type',
              RepositoryExceptionType.notFound,
            ),
          ),
        );
      });

      test('should throw RepositoryException.notFound for non-existent ID',
          () async {
        final repo = SimpleProductMysqlRepository(helper!.connection);
        await repo.createTables();

        final nonExistentId = UuidValue.generate();

        expect(
          () => repo.getById(nonExistentId),
          throwsA(
            isA<RepositoryException>().having(
              (e) => e.type,
              'type',
              RepositoryExceptionType.notFound,
            ),
          ),
        );
      });
    });

    group('complex object graphs with entities', () {
      test('should save and retrieve aggregate with entities', () async {
        final repo = OrderMysqlRepository(helper!.connection);
        await repo.createTables();

        final order = Order(
          customerName: 'John Doe',
          items: [
            OrderItem(productName: 'Widget', quantity: 2, unitPrice: 10),
            OrderItem(productName: 'Gadget', quantity: 1, unitPrice: 25),
          ],
        );

        await repo.save(order);

        // Retrieve
        final retrieved = await repo.getById(order.id);

        expect(retrieved.id, equals(order.id));
        expect(retrieved.customerName, equals('John Doe'));
        expect(retrieved.items, hasLength(2));

        // Check that both items are present (order may vary)
        final productNames = retrieved.items.map((i) => i.productName).toList();
        expect(productNames, containsAll(['Widget', 'Gadget']));

        final widget =
            retrieved.items.firstWhere((i) => i.productName == 'Widget');
        expect(widget.quantity, equals(2));
        expect(widget.unitPrice, equals(10.0));

        final gadget =
            retrieved.items.firstWhere((i) => i.productName == 'Gadget');
        expect(gadget.quantity, equals(1));
        expect(gadget.unitPrice, equals(25.0));
      });

      test('should update entities in aggregate', () async {
        final repo = OrderMysqlRepository(helper!.connection);
        await repo.createTables();

        final order = Order(
          customerName: 'Jane Doe',
          items: [
            OrderItem(productName: 'Item1', quantity: 1, unitPrice: 10),
          ],
        );
        await repo.save(order);

        // Create updated version with same ID
        final updated = Order(
          customerName: 'Jane Doe',
          items: [
            OrderItem(productName: 'Item2', quantity: 3, unitPrice: 15),
            OrderItem(productName: 'Item3', quantity: 2, unitPrice: 20),
          ],
          id: order.id,
        );

        await repo.save(updated);

        // Retrieve
        final retrieved = await repo.getById(order.id);
        expect(retrieved.items, hasLength(2));

        // Check that both items exist (order may vary)
        final itemNames = retrieved.items.map((i) => i.productName).toList();
        expect(itemNames, containsAll(['Item2', 'Item3']));
      });

      test('should handle empty entity collections', () async {
        final repo = OrderMysqlRepository(helper!.connection);
        await repo.createTables();

        final order = Order(
          customerName: 'Empty Order',
          items: [],
        );

        await repo.save(order);

        // Retrieve
        final retrieved = await repo.getById(order.id);
        expect(retrieved.items, isEmpty);
      });
    });

    group('value object embedding', () {
      test('should embed and reconstruct value objects', () async {
        final repo = CustomerMysqlRepository(helper!.connection);
        await repo.createTables();

        final customer = Customer(
          name: 'Alice Smith',
          email: const Email(value: 'alice@example.com'),
          shippingAddress: const Address(
            street: '123 Main St',
            city: 'Springfield',
            state: 'IL',
            zipCode: '62701',
          ),
        );

        await repo.save(customer);

        // Retrieve
        final retrieved = await repo.getById(customer.id);

        expect(retrieved.name, equals('Alice Smith'));
        expect(retrieved.email.value, equals('alice@example.com'));
        expect(retrieved.shippingAddress.street, equals('123 Main St'));
        expect(retrieved.shippingAddress.city, equals('Springfield'));
        expect(retrieved.shippingAddress.state, equals('IL'));
        expect(retrieved.shippingAddress.zipCode, equals('62701'));
      });

      test('should handle nullable value objects', () async {
        final repo = CustomerMysqlRepository(helper!.connection);
        await repo.createTables();

        final customer = Customer(
          name: 'Bob Jones',
          email: const Email(value: 'bob@example.com'),
          shippingAddress: const Address(
            street: '456 Oak Ave',
            city: 'Portland',
            state: 'OR',
            zipCode: '97201',
          ),
        );

        await repo.save(customer);

        // Retrieve
        final retrieved = await repo.getById(customer.id);

        expect(retrieved.billingAddress, isNull);
        expect(retrieved.shippingAddress.street, equals('456 Oak Ave'));
      });

      test('should handle non-null nullable value objects', () async {
        final repo = CustomerMysqlRepository(helper!.connection);
        await repo.createTables();

        final customer = Customer(
          name: 'Carol White',
          email: const Email(value: 'carol@example.com'),
          shippingAddress: const Address(
            street: '789 Pine Rd',
            city: 'Seattle',
            state: 'WA',
            zipCode: '98101',
          ),
          billingAddress: const Address(
            street: '321 Elm St',
            city: 'Tacoma',
            state: 'WA',
            zipCode: '98401',
          ),
        );

        await repo.save(customer);

        // Retrieve
        final retrieved = await repo.getById(customer.id);

        expect(retrieved.billingAddress, isNotNull);
        expect(retrieved.billingAddress!.street, equals('321 Elm St'));
        expect(retrieved.billingAddress!.city, equals('Tacoma'));
      });
    });

    group('foreign key CASCADE DELETE', () {
      test('should cascade delete entities when aggregate is deleted',
          () async {
        final repo = OrderMysqlRepository(helper!.connection);
        await repo.createTables();

        final order = Order(
          customerName: 'Test Customer',
          items: [
            OrderItem(productName: 'Item1', quantity: 1, unitPrice: 10),
            OrderItem(productName: 'Item2', quantity: 2, unitPrice: 20),
          ],
        );

        await repo.save(order);

        // Verify items exist in database
        final itemCount = await helper!.countRows('order_item');
        expect(itemCount, equals(2));

        // Delete order
        await repo.deleteById(order.id);

        // Verify items were cascade deleted
        final itemCountAfter = await helper!.countRows('order_item');
        expect(itemCountAfter, equals(0));
      });

      test('should not affect other aggregates when deleting one', () async {
        final repo = OrderMysqlRepository(helper!.connection);
        await repo.createTables();

        final order1 = Order(
          customerName: 'Customer 1',
          items: [
            OrderItem(productName: 'Item1', quantity: 1, unitPrice: 10),
          ],
        );

        final order2 = Order(
          customerName: 'Customer 2',
          items: [
            OrderItem(productName: 'Item2', quantity: 2, unitPrice: 20),
          ],
        );

        await repo.save(order1);
        await repo.save(order2);

        // Delete first order
        await repo.deleteById(order1.id);

        // Verify second order still exists
        final retrieved = await repo.getById(order2.id);
        expect(retrieved.id, equals(order2.id));
        expect(retrieved.items, hasLength(1));
      });
    });

    group('custom repository interfaces', () {
      test('should support custom repository methods', () async {
        final repo = CustomProductRepositoryImpl(helper!.connection);
        await repo.createTables();

        // Save products
        final product1 = Product(name: 'Expensive', price: 100);
        final product2 = Product(name: 'Cheap', price: 10);
        final product3 = Product(name: 'Medium', price: 50);

        await repo.save(product1);
        await repo.save(product2);
        await repo.save(product3);

        // Use custom method
        final expensive = await repo.findByMinPrice(75);

        expect(expensive, hasLength(1));
        expect(expensive.first.name, equals('Expensive'));
      });

      test('should use same transaction context for custom queries', () async {
        final repo = CustomProductRepositoryImpl(helper!.connection);
        await repo.createTables();

        // Save a product
        final product = Product(name: 'Test', price: 50);
        await repo.save(product);

        // Use custom method that queries within transaction
        final count = await repo.countProducts();
        expect(count, equals(1));
      });
    });
  });
}
