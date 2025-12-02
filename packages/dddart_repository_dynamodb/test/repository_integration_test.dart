/// Integration tests for generated DynamoDB repositories.
///
/// These tests require a running DynamoDB Local instance on localhost:8000.
/// To run these tests, ensure DynamoDB Local is running:
///   docker run -d -p 8000:8000 amazon/dynamodb-local
///
/// Or skip these tests if DynamoDB Local is not available:
///   dart test --exclude-tags=requires-dynamodb
@Tags(['requires-dynamodb'])
library;

import 'package:aws_dynamodb_api/dynamodb-2012-08-10.dart';
import 'package:dddart/dddart.dart';
import 'package:test/test.dart';

import 'test_helpers.dart';
import 'test_models.dart';

void main() {
  group('Generated DynamoDB Repository Integration Tests', () {
    late TestDynamoHelper helper;
    var dynamoAvailable = false;

    setUpAll(() async {
      helper = createTestHelper();
      try {
        helper.connect();
        // Try to list tables to verify connection
        await helper.listTables();
        dynamoAvailable = true;
      } catch (e) {
        // DynamoDB Local not available - tests will be skipped
        dynamoAvailable = false;
      }
    });

    setUp(() async {
      if (!dynamoAvailable) {
        markTestSkipped('DynamoDB Local not available on localhost:8000');
      }

      // Create test tables
      await helper.createTable('test_users');
      await helper.createTable('custom_products');
      await helper.createTable('test_orders');
      await helper.createTable('test_accounts');
    });

    tearDown(() async {
      if (dynamoAvailable && helper.isConnected) {
        // Clean up test tables
        await helper.clearTable('test_users');
        await helper.clearTable('custom_products');
        await helper.clearTable('test_orders');
        await helper.clearTable('test_accounts');
      }
    });

    tearDownAll(() async {
      if (dynamoAvailable && helper.isConnected) {
        helper.disconnect();
      }
    });

    group('CRUD operations', () {
      test('should save and retrieve an aggregate', () async {
        final repo = TestUserDynamoRepository(helper.connection);
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
        final repo = TestUserDynamoRepository(helper.connection);
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
        final repo = TestUserDynamoRepository(helper.connection);
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
        final repo = TestUserDynamoRepository(helper.connection);
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
          'should throw RepositoryException.notFound when deleting '
          'non-existent ID', () async {
        final repo = TestUserDynamoRepository(helper.connection);
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
      test('should store aggregate id as DynamoDB partition key', () async {
        final repo = TestUserDynamoRepository(helper.connection);
        final user = TestUser(
          name: 'Test User',
          email: 'test@example.com',
        );

        await repo.save(user);

        // Verify DynamoDB item has id field as partition key
        final item = await helper.getItemById(
          'test_users',
          user.id.toString(),
        );

        expect(item, isNotNull);
        expect(item!['id']?.s, equals(user.id.toString()));
      });

      test('should retrieve aggregate using partition key', () async {
        final repo = TestUserDynamoRepository(helper.connection);
        final userId = UuidValue.generate();

        // Insert item directly with id as partition key
        await helper.connection.client.putItem(
          tableName: 'test_users',
          item: {
            'id': AttributeValue(s: userId.toString()),
            'name': AttributeValue(s: 'Direct Insert'),
            'email': AttributeValue(s: 'direct@example.com'),
            'createdAt': AttributeValue(s: DateTime.now().toIso8601String()),
            'updatedAt': AttributeValue(s: DateTime.now().toIso8601String()),
          },
        );

        // Retrieve through repository
        final retrieved = await repo.getById(userId);

        expect(retrieved.id, equals(userId));
        expect(retrieved.name, equals('Direct Insert'));
        expect(retrieved.email, equals('direct@example.com'));
      });
    });

    group('custom table names', () {
      test('should use custom table name from annotation', () async {
        final repo = TestProductDynamoRepository(helper.connection);
        final product = TestProduct(
          name: 'Widget',
          price: 19.99,
        );

        await repo.save(product);

        // Verify item is in custom table
        final item = await helper.getItemById(
          'custom_products',
          product.id.toString(),
        );

        expect(item, isNotNull);
        expect(item!['name']?.s, equals('Widget'));
        expect(item['price']?.n, equals('19.99'));
      });

      test('should retrieve from custom table', () async {
        final repo = TestProductDynamoRepository(helper.connection);
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
      setUp(() async {
        // Ensure clean state for each test in this group
        await helper.clearTable('test_users');
        await helper.clearTable('custom_products');
      });

      test('should handle multiple aggregates independently', () async {
        final userRepo = TestUserDynamoRepository(helper.connection);
        final productRepo = TestProductDynamoRepository(helper.connection);

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

      test('should maintain separate tables', () async {
        final userRepo = TestUserDynamoRepository(helper.connection);
        final productRepo = TestProductDynamoRepository(helper.connection);

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

        final userCount = await helper.countItems('test_users');
        final productCount = await helper.countItems('custom_products');

        expect(userCount, equals(1));
        expect(productCount, equals(1));
      });
    });

    group('error handling', () {
      test('should handle serialization errors gracefully', () async {
        final repo = TestUserDynamoRepository(helper.connection);

        // Insert invalid item directly
        final invalidId = UuidValue.generate();
        await helper.connection.client.putItem(
          tableName: 'test_users',
          item: {
            'id': AttributeValue(s: invalidId.toString()),
            'name': AttributeValue(s: 'Invalid'),
            // Missing required 'email' field
          },
        );

        // Attempt to retrieve should throw
        expect(
          () => repo.getById(invalidId),
          throwsA(isA<RepositoryException>()),
        );
      });

      test('should include error details in exception', () async {
        final repo = TestUserDynamoRepository(helper.connection);
        final nonExistentId = UuidValue.generate();

        try {
          await repo.getById(nonExistentId);
          fail('Should have thrown RepositoryException');
        } on RepositoryException catch (e) {
          expect(e.message, contains('not found'));
          expect(e.message, contains(nonExistentId.toString()));
        }
      });

      test('should map ResourceNotFoundException to notFound', () async {
        final repo = TestUserDynamoRepository(helper.connection);
        final nonExistentId = UuidValue.generate();

        // Attempt to get non-existent item
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

      test('should preserve original error in cause field', () async {
        final repo = TestUserDynamoRepository(helper.connection);
        final invalidId = UuidValue.generate();

        await helper.connection.client.putItem(
          tableName: 'test_users',
          item: {
            'id': AttributeValue(s: invalidId.toString()),
            'name': AttributeValue(s: 'Invalid'),
            // Missing required 'email' field
          },
        );

        try {
          await repo.getById(invalidId);
          fail('Should have thrown RepositoryException');
        } on RepositoryException catch (e) {
          expect(e.cause, isNotNull);
          expect(e.type, equals(RepositoryExceptionType.unknown));
        }
      });

      test('should handle non-existent table gracefully', () async {
        // Create a connection but don't create the table
        final tempHelper = createTestHelper();
        final tempConnection = tempHelper.connect();

        try {
          final repo = TestUserDynamoRepository(tempConnection);
          final user = TestUser(
            name: 'Test',
            email: 'test@example.com',
          );

          // Attempt to save to non-existent table should throw
          expect(
            () => repo.save(user),
            throwsA(
              isA<RepositoryException>().having(
                (e) => e.type,
                'type',
                RepositoryExceptionType.unknown,
              ),
            ),
          );
        } finally {
          tempHelper.disconnect();
        }
      });
    });

    group('abstract base repository', () {
      test('should allow extending generated base class', () async {
        final repo = TestOrderDynamoRepositoryImpl(helper.connection);
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
        final repo = TestOrderDynamoRepositoryImpl(helper.connection);

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
        final repo = TestOrderDynamoRepositoryImpl(helper.connection);

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
        final repo = TestOrderDynamoRepositoryImpl(helper.connection);

        final found = await repo.findByOrderNumber('NON-EXISTENT');

        expect(found, isNull);
      });

      test('should expose protected members for custom implementations',
          () async {
        final repo = TestOrderDynamoRepositoryImpl(helper.connection);

        // Verify that custom implementation can access protected members
        // by successfully executing custom query methods that use them
        final order = TestOrder(
          orderNumber: 'ORD-TEST',
          customerId: 'CUST-TEST',
          total: 200,
        );

        await repo.save(order);
        final found = await repo.findByOrderNumber('ORD-TEST');

        expect(found, isNotNull);
        expect(found!.orderNumber, equals('ORD-TEST'));
      });
    });

    group('table creation utilities', () {
      test('should create table using createTable method', () async {
        final repo = TestUserDynamoRepository(helper.connection);

        // Table is already created in setUp, verify it exists
        final exists = await helper.tableExists('test_users');
        expect(exists, isTrue);

        // Test that we can use the table
        final user = TestUser(
          name: 'Table Test User',
          email: 'tabletest@example.com',
        );
        await repo.save(user);
        final retrieved = await repo.getById(user.id);
        expect(retrieved.name, equals('Table Test User'));
      });

      test('should generate valid AWS CLI command', () async {
        final command = TestUserDynamoRepository.getCreateTableCommand(
          'test_table',
        );

        expect(command, contains('aws dynamodb create-table'));
        expect(command, contains('--table-name test_table'));
        expect(command, contains('--attribute-definitions'));
        expect(command, contains('AttributeName=id,AttributeType=S'));
        expect(command, contains('--key-schema'));
        expect(command, contains('AttributeName=id,KeyType=HASH'));
        expect(command, contains('--billing-mode PAY_PER_REQUEST'));
      });

      test('should generate valid CloudFormation template', () async {
        final template = TestUserDynamoRepository.getCloudFormationTemplate(
          'test_table',
        );

        expect(template, contains('Type: AWS::DynamoDB::Table'));
        expect(template, contains('TableName: test_table'));
        expect(template, contains('AttributeName: id'));
        expect(template, contains('AttributeType: S'));
        expect(template, contains('KeyType: HASH'));
        expect(template, contains('BillingMode: PAY_PER_REQUEST'));
      });
    });

    group('concurrent operations', () {
      test('should handle concurrent saves', () async {
        final repo = TestUserDynamoRepository(helper.connection);

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
        final count = await helper.countItems('test_users');
        expect(count, equals(10));

        // Verify all can be retrieved
        for (final user in users) {
          final retrieved = await repo.getById(user.id);
          expect(retrieved.name, equals(user.name));
        }
      });

      test('should handle concurrent updates to same aggregate', () async {
        final repo = TestUserDynamoRepository(helper.connection);
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

    group('field serialization', () {
      test('should work with default SerializationConfig', () async {
        final repo = TestAccountDynamoRepository(helper.connection);
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

      test('should persist field names correctly in DynamoDB', () async {
        final repo = TestAccountDynamoRepository(helper.connection);
        final account = TestAccount(
          accountName: 'Checking',
          accountType: 'Business',
          balance: 5000,
        );

        await repo.save(account);

        // Verify field names in DynamoDB item
        final item = await helper.getItemById(
          'test_accounts',
          account.id.toString(),
        );

        expect(item, isNotNull);
        expect(item!['accountName']?.s, equals('Checking'));
        expect(item['accountType']?.s, equals('Business'));
        expect(item['balance']?.n, equals('5000'));
      });

      test('should handle camelCase field names', () async {
        final repo = TestAccountDynamoRepository(helper.connection);
        final account = TestAccount(
          accountName: 'Investment',
          accountType: 'Retirement',
          balance: 25000,
        );

        await repo.save(account);

        // Insert item with camelCase fields
        final directId = UuidValue.generate();
        await helper.connection.client.putItem(
          tableName: 'test_accounts',
          item: {
            'id': AttributeValue(s: directId.toString()),
            'accountName': AttributeValue(s: 'Direct Insert'),
            'accountType': AttributeValue(s: 'Savings'),
            'balance': AttributeValue(n: '500'),
            'createdAt': AttributeValue(s: DateTime.now().toIso8601String()),
            'updatedAt': AttributeValue(s: DateTime.now().toIso8601String()),
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
