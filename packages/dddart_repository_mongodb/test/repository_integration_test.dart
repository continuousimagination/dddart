/// Integration tests for generated MongoDB repositories.
///
/// These tests require a running MongoDB instance on localhost:27017.
/// To run these tests, ensure MongoDB is running:
///   docker run -d -p 27017:27017 mongo:latest
///
/// Or skip these tests if MongoDB is not available:
///   dart test --exclude-tags=requires-mongo
@Tags(['requires-mongo'])
library;

import 'package:dddart/dddart.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:test/test.dart';

import 'test_helpers.dart';
import 'test_models.dart';

void main() {
  group('Generated MongoDB Repository Integration Tests', () {
    late TestMongoHelper helper;
    var mongoAvailable = false;

    setUpAll(() async {
      helper = createTestHelper();
      try {
        await helper.connect();
        mongoAvailable = true;
      } catch (e) {
        // MongoDB not available - tests will be skipped
        mongoAvailable = false;
      }
    });

    setUp(() {
      if (!mongoAvailable) {
        markTestSkipped('MongoDB not available on localhost:27017');
      }
    });

    tearDown(() async {
      if (mongoAvailable && helper.isConnected) {
        // Clean up test collections
        await helper.clearCollection('test_users');
        await helper.clearCollection('custom_products');
        await helper.clearCollection('test_orders');
        await helper.clearCollection('test_accounts');
      }
    });

    tearDownAll(() async {
      if (mongoAvailable && helper.isConnected) {
        await helper.disconnect();
      }
    });

    group('CRUD operations', () {
      test('should save and retrieve an aggregate', () async {
        final repo = TestUserMongoRepository(helper.database);
        final user = TestUser(
          name: 'John Doe',
          email: 'john@example.com',
        );

        // Save
        await repo.save(user);

        // Retrieve
        final retrieved = await repo.getById(user.id);

        expect(retrieved.id, equals(user.id));
        expect(retrieved.name, equals('John Doe'));
        expect(retrieved.email, equals('john@example.com'));
      });

      test('should update an existing aggregate', () async {
        final repo = TestUserMongoRepository(helper.database);
        final user = TestUser(
          name: 'Jane Doe',
          email: 'jane@example.com',
        );

        // Save initial version
        await repo.save(user);

        // Create updated version with same ID
        final updated = TestUser(
          name: 'Jane Smith',
          email: 'jane.smith@example.com',
          id: user.id,
        );

        // Save updated version
        await repo.save(updated);

        // Retrieve and verify
        final retrieved = await repo.getById(user.id);
        expect(retrieved.id, equals(user.id));
        expect(retrieved.name, equals('Jane Smith'));
        expect(retrieved.email, equals('jane.smith@example.com'));
      });

      test('should delete an aggregate by ID', () async {
        final repo = TestUserMongoRepository(helper.database);
        final user = TestUser(
          name: 'Bob Smith',
          email: 'bob@example.com',
        );

        // Save
        await repo.save(user);

        // Verify it exists
        final retrieved = await repo.getById(user.id);
        expect(retrieved.id, equals(user.id));

        // Delete
        await repo.deleteById(user.id);

        // Verify it's gone
        expect(
          () => repo.getById(user.id),
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
        final repo = TestUserMongoRepository(helper.database);
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

      test(
          'should throw RepositoryException.notFound when deleting non-existent ID',
          () async {
        final repo = TestUserMongoRepository(helper.database);
        final nonExistentId = UuidValue.generate();

        expect(
          () => repo.deleteById(nonExistentId),
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

    group('ID mapping', () {
      test('should map aggregate id to MongoDB _id on save', () async {
        final repo = TestUserMongoRepository(helper.database);
        final user = TestUser(
          name: 'Test User',
          email: 'test@example.com',
        );

        await repo.save(user);

        // Verify MongoDB document has _id field
        final doc = await helper.findDocumentById(
          'test_users',
          user.id.toString(),
        );

        expect(doc, isNotNull);
        expect(doc!['_id'], equals(user.id.toString()));
        expect(doc.containsKey('id'), isFalse);
      });

      test('should map MongoDB _id to aggregate id on retrieve', () async {
        final repo = TestUserMongoRepository(helper.database);
        final userId = UuidValue.generate();

        // Insert document directly with _id
        await helper.insertDocument('test_users', {
          '_id': userId.toString(),
          'name': 'Direct Insert',
          'email': 'direct@example.com',
        });

        // Retrieve through repository
        final retrieved = await repo.getById(userId);

        expect(retrieved.id, equals(userId));
        expect(retrieved.name, equals('Direct Insert'));
        expect(retrieved.email, equals('direct@example.com'));
      });
    });

    group('custom collection names', () {
      test('should use custom collection name from annotation', () async {
        final repo = TestProductMongoRepository(helper.database);
        final product = TestProduct(
          name: 'Widget',
          price: 19.99,
        );

        await repo.save(product);

        // Verify document is in custom collection
        final doc = await helper.findDocumentById(
          'custom_products',
          product.id.toString(),
        );

        expect(doc, isNotNull);
        expect(doc!['name'], equals('Widget'));
        expect(doc['price'], equals(19.99));
      });

      test('should retrieve from custom collection', () async {
        final repo = TestProductMongoRepository(helper.database);
        final product = TestProduct(
          name: 'Gadget',
          price: 29.99,
        );

        await repo.save(product);
        final retrieved = await repo.getById(product.id);

        expect(retrieved.id, equals(product.id));
        expect(retrieved.name, equals('Gadget'));
        expect(retrieved.price, equals(29.99));
      });
    });

    group('multiple aggregates', () {
      test('should handle multiple aggregates independently', () async {
        final userRepo = TestUserMongoRepository(helper.database);
        final productRepo = TestProductMongoRepository(helper.database);

        final user = TestUser(
          name: 'Alice',
          email: 'alice@example.com',
        );
        final product = TestProduct(
          name: 'Book',
          price: 15.99,
        );

        await userRepo.save(user);
        await productRepo.save(product);

        final retrievedUser = await userRepo.getById(user.id);
        final retrievedProduct = await productRepo.getById(product.id);

        expect(retrievedUser.name, equals('Alice'));
        expect(retrievedProduct.name, equals('Book'));
      });

      test('should maintain separate collections', () async {
        final userRepo = TestUserMongoRepository(helper.database);
        final productRepo = TestProductMongoRepository(helper.database);

        final user = TestUser(
          name: 'Bob',
          email: 'bob@example.com',
        );
        final product = TestProduct(
          name: 'Pen',
          price: 2.99,
        );

        await userRepo.save(user);
        await productRepo.save(product);

        final userCount = await helper.countDocuments('test_users');
        final productCount = await helper.countDocuments('custom_products');

        expect(userCount, equals(1));
        expect(productCount, equals(1));
      });
    });

    group('error handling', () {
      test('should handle serialization errors gracefully', () async {
        final repo = TestUserMongoRepository(helper.database);

        // Insert invalid document directly
        final invalidId = UuidValue.generate();
        await helper.insertDocument('test_users', {
          '_id': invalidId.toString(),
          'name': 'Invalid',
          // Missing required 'email' field
        });

        // Attempt to retrieve should throw
        expect(
          () => repo.getById(invalidId),
          throwsA(isA<RepositoryException>()),
        );
      });

      test('should include error details in exception', () async {
        final repo = TestUserMongoRepository(helper.database);
        final nonExistentId = UuidValue.generate();

        try {
          await repo.getById(nonExistentId);
          fail('Should have thrown RepositoryException');
        } on RepositoryException catch (e) {
          expect(e.message, contains('not found'));
          expect(e.message, contains(nonExistentId.toString()));
        }
      });

      test('should map connection errors to RepositoryException.connection',
          () async {
        // Create a repository with a closed connection
        final closedDb = await Db.create('mongodb://localhost:27017/closed_db');
        try {
          await closedDb.open();
          await closedDb.close();

          final repo = TestUserMongoRepository(closedDb);
          final user = TestUser(
            name: 'Test',
            email: 'test@example.com',
          );

          // Attempt to save should throw connection error
          expect(
            () => repo.save(user),
            throwsA(
              isA<RepositoryException>().having(
                (e) => e.type,
                'type',
                anyOf(
                  RepositoryExceptionType.connection,
                  RepositoryExceptionType.unknown,
                ),
              ),
            ),
          );
        } catch (e) {
          // If we can't connect to MongoDB, skip this test
          markTestSkipped('MongoDB not available for connection test');
        }
      });

      test('should preserve original error in cause field', () async {
        final repo = TestUserMongoRepository(helper.database);
        final invalidId = UuidValue.generate();

        await helper.insertDocument('test_users', {
          '_id': invalidId.toString(),
          'name': 'Invalid',
          // Missing required 'email' field
        });

        try {
          await repo.getById(invalidId);
          fail('Should have thrown RepositoryException');
        } on RepositoryException catch (e) {
          expect(e.cause, isNotNull);
          expect(e.type, equals(RepositoryExceptionType.unknown));
        }
      });
    });

    group('abstract base repository', () {
      test('should allow extending generated base class', () async {
        final repo = TestOrderMongoRepositoryImpl(helper.database);
        final order = TestOrder(
          orderNumber: 'ORD-001',
          customerId: 'CUST-123',
          total: 99.99,
        );

        // Test base CRUD methods work
        await repo.save(order);
        final retrieved = await repo.getById(order.id);

        expect(retrieved.id, equals(order.id));
        expect(retrieved.orderNumber, equals('ORD-001'));
        expect(retrieved.customerId, equals('CUST-123'));
        expect(retrieved.total, equals(99.99));
      });

      test('should support custom query methods', () async {
        final repo = TestOrderMongoRepositoryImpl(helper.database);

        // Create multiple orders
        final order1 = TestOrder(
          orderNumber: 'ORD-001',
          customerId: 'CUST-123',
          total: 50,
        );
        final order2 = TestOrder(
          orderNumber: 'ORD-002',
          customerId: 'CUST-123',
          total: 75,
        );
        final order3 = TestOrder(
          orderNumber: 'ORD-003',
          customerId: 'CUST-456',
          total: 100,
        );

        await repo.save(order1);
        await repo.save(order2);
        await repo.save(order3);

        // Test custom query method
        final customerOrders = await repo.findByCustomerId('CUST-123');

        expect(customerOrders.length, equals(2));
        expect(
          customerOrders.every((o) => o.customerId == 'CUST-123'),
          isTrue,
        );
      });

      test('should support custom single-result query methods', () async {
        final repo = TestOrderMongoRepositoryImpl(helper.database);

        final order = TestOrder(
          orderNumber: 'ORD-UNIQUE',
          customerId: 'CUST-789',
          total: 150,
        );

        await repo.save(order);

        // Test custom query method
        final found = await repo.findByOrderNumber('ORD-UNIQUE');

        expect(found, isNotNull);
        expect(found!.orderNumber, equals('ORD-UNIQUE'));
        expect(found.customerId, equals('CUST-789'));
      });

      test('should return null for non-existent custom query', () async {
        final repo = TestOrderMongoRepositoryImpl(helper.database);

        final found = await repo.findByOrderNumber('NON-EXISTENT');

        expect(found, isNull);
      });
    });

    group('concurrent operations', () {
      test('should handle concurrent saves', () async {
        final repo = TestUserMongoRepository(helper.database);

        final users = List.generate(
          10,
          (i) => TestUser(
            name: 'User $i',
            email: 'user$i@example.com',
          ),
        );

        // Save all users concurrently
        await Future.wait(users.map(repo.save));

        // Verify all were saved
        final count = await helper.countDocuments('test_users');
        expect(count, equals(10));

        // Verify all can be retrieved
        for (final user in users) {
          final retrieved = await repo.getById(user.id);
          expect(retrieved.name, equals(user.name));
        }
      });

      test('should handle concurrent updates to same aggregate', () async {
        final repo = TestUserMongoRepository(helper.database);
        final userId = UuidValue.generate();

        // Create initial user
        final initial = TestUser(
          name: 'Initial',
          email: 'initial@example.com',
          id: userId,
        );
        await repo.save(initial);

        // Perform concurrent updates
        await Future.wait([
          repo.save(
            TestUser(
              name: 'Update 1',
              email: 'update1@example.com',
              id: userId,
            ),
          ),
          repo.save(
            TestUser(
              name: 'Update 2',
              email: 'update2@example.com',
              id: userId,
            ),
          ),
        ]);

        // Verify one of the updates won (last write wins)
        final final_ = await repo.getById(userId);
        expect(final_.id, equals(userId));
        expect(
          ['Update 1', 'Update 2'].contains(final_.name),
          isTrue,
        );
      });
    });

    group('SerializationConfig options', () {
      test('should work with default SerializationConfig', () async {
        final repo = TestAccountMongoRepository(helper.database);
        final account = TestAccount(
          accountName: 'Savings',
          accountType: 'Personal',
          balance: 1000,
        );

        await repo.save(account);
        final retrieved = await repo.getById(account.id);

        expect(retrieved.accountName, equals('Savings'));
        expect(retrieved.accountType, equals('Personal'));
        expect(retrieved.balance, equals(1000));
      });

      test('should persist field names correctly in MongoDB', () async {
        final repo = TestAccountMongoRepository(helper.database);
        final account = TestAccount(
          accountName: 'Checking',
          accountType: 'Business',
          balance: 5000,
        );

        await repo.save(account);

        // Verify field names in MongoDB document
        final doc = await helper.findDocumentById(
          'test_accounts',
          account.id.toString(),
        );

        expect(doc, isNotNull);
        expect(doc!['accountName'], equals('Checking'));
        expect(doc['accountType'], equals('Business'));
        expect(doc['balance'], equals(5000));
      });

      test('should handle camelCase field names', () async {
        final repo = TestAccountMongoRepository(helper.database);
        final account = TestAccount(
          accountName: 'Investment',
          accountType: 'Retirement',
          balance: 25000,
        );

        await repo.save(account);

        // Insert document with camelCase fields
        final directId = UuidValue.generate();
        await helper.insertDocument(
          'test_accounts',
          {
            '_id': directId.toString(),
            'accountName': 'Direct Insert',
            'accountType': 'Savings',
            'balance': 500,
            'createdAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
          },
        );

        // Retrieve and verify
        final retrieved = await repo.getById(directId);
        expect(retrieved.accountName, equals('Direct Insert'));
        expect(retrieved.accountType, equals('Savings'));
        expect(retrieved.balance, equals(500));
      });
    });
  });
}
