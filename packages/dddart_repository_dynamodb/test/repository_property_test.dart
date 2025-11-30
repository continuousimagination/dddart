/// Property-based tests for DynamoDB repository operations.
@Tags(['property', 'requires-dynamodb-local'])
library;

import 'dart:math';

import 'package:aws_dynamodb_api/dynamodb-2012-08-10.dart';
import 'package:dddart/dddart.dart';
import 'package:dddart_repository_dynamodb/dddart_repository_dynamodb.dart';
import 'package:test/test.dart';

import 'test_helpers.dart';
import 'test_models.dart';

void main() {
  group('Repository Property Tests', () {
    late TestDynamoHelper helper;
    late DynamoConnection connection;

    setUp(() async {
      helper = createTestHelper();
      connection = helper.connect();
      
      // Create test tables
      await helper.createTable('test_users');
      await helper.createTable('custom_products');
      await helper.createTable('test_accounts');
    });

    tearDown(() async {
      // Clean up tables
      await helper.clearTable('test_users');
      await helper.clearTable('custom_products');
      await helper.clearTable('test_accounts');
      helper.disconnect();
    });

    // **Feature: dynamodb-repository, Property 1: Repository round-trip persistence**
    // **Validates: Requirements 2.1, 2.3**
    group('Property 1: Repository round-trip persistence', () {
      test('should preserve all fields when saving and retrieving TestUser', () async {
        final repo = TestUserDynamoRepository(connection);
        final random = Random(42);

        for (var i = 0; i < 100; i++) {
          // Generate random user
          final user = _generateRandomTestUser(random);
          
          // Save the user
          await repo.save(user);
          
          // Retrieve the user
          final retrieved = await repo.getById(user.id);
          
          // Verify all fields match
          expect(retrieved.id, equals(user.id),
              reason: 'Iteration $i: ID should match');
          expect(retrieved.name, equals(user.name),
              reason: 'Iteration $i: Name should match');
          expect(retrieved.email, equals(user.email),
              reason: 'Iteration $i: Email should match');
          expect(retrieved.createdAt, equals(user.createdAt),
              reason: 'Iteration $i: CreatedAt should match');
          expect(retrieved.updatedAt, equals(user.updatedAt),
              reason: 'Iteration $i: UpdatedAt should match');
        }
      });

      test('should preserve all fields when saving and retrieving TestProduct', () async {
        final repo = TestProductDynamoRepository(connection);
        final random = Random(43);

        for (var i = 0; i < 100; i++) {
          // Generate random product
          final product = _generateRandomTestProduct(random);
          
          // Save the product
          await repo.save(product);
          
          // Retrieve the product
          final retrieved = await repo.getById(product.id);
          
          // Verify all fields match
          expect(retrieved.id, equals(product.id),
              reason: 'Iteration $i: ID should match');
          expect(retrieved.name, equals(product.name),
              reason: 'Iteration $i: Name should match');
          expect(retrieved.price, equals(product.price),
              reason: 'Iteration $i: Price should match');
          expect(retrieved.createdAt, equals(product.createdAt),
              reason: 'Iteration $i: CreatedAt should match');
          expect(retrieved.updatedAt, equals(product.updatedAt),
              reason: 'Iteration $i: UpdatedAt should match');
        }
      });

      test('should preserve all fields when saving and retrieving TestAccount', () async {
        final repo = TestAccountDynamoRepository(connection);
        final random = Random(44);

        for (var i = 0; i < 100; i++) {
          // Generate random account
          final account = _generateRandomTestAccount(random);
          
          // Save the account
          await repo.save(account);
          
          // Retrieve the account
          final retrieved = await repo.getById(account.id);
          
          // Verify all fields match
          expect(retrieved.id, equals(account.id),
              reason: 'Iteration $i: ID should match');
          expect(retrieved.accountName, equals(account.accountName),
              reason: 'Iteration $i: Account name should match');
          expect(retrieved.accountType, equals(account.accountType),
              reason: 'Iteration $i: Account type should match');
          expect(retrieved.balance, equals(account.balance),
              reason: 'Iteration $i: Balance should match');
          expect(retrieved.createdAt, equals(account.createdAt),
              reason: 'Iteration $i: CreatedAt should match');
          expect(retrieved.updatedAt, equals(account.updatedAt),
              reason: 'Iteration $i: UpdatedAt should match');
        }
      });
    });

    // **Feature: dynamodb-repository, Property 2: Repository upsert behavior**
    // **Validates: Requirements 2.4**
    group('Property 2: Repository upsert behavior', () {
      test('should replace existing item when saving with same ID', () async {
        final repo = TestUserDynamoRepository(connection);
        final random = Random(45);

        for (var i = 0; i < 100; i++) {
          // Generate random user
          final user1 = _generateRandomTestUser(random);
          
          // Save the user
          await repo.save(user1);
          
          // Create modified version with same ID
          final user2 = TestUser(
            id: user1.id,
            name: _generateRandomString(random, maxLength: 20),
            email: _generateRandomEmail(random),
            createdAt: user1.createdAt,
            updatedAt: DateTime.now(),
          );
          
          // Save the modified user
          await repo.save(user2);
          
          // Retrieve the user
          final retrieved = await repo.getById(user1.id);
          
          // Verify it has the updated values, not the original
          expect(retrieved.name, equals(user2.name),
              reason: 'Iteration $i: Name should be updated');
          expect(retrieved.email, equals(user2.email),
              reason: 'Iteration $i: Email should be updated');
          
          // Verify only one item exists in the table
          final count = await helper.countItems('test_users');
          expect(count, equals(1),
              reason: 'Iteration $i: Should only have one item after upsert');
          
          // Clean up for next iteration
          await repo.deleteById(user1.id);
        }
      });

      test('should replace existing product when saving with same ID', () async {
        final repo = TestProductDynamoRepository(connection);
        final random = Random(46);

        for (var i = 0; i < 100; i++) {
          // Generate random product
          final product1 = _generateRandomTestProduct(random);
          
          // Save the product
          await repo.save(product1);
          
          // Create modified version with same ID
          final product2 = TestProduct(
            id: product1.id,
            name: _generateRandomString(random, maxLength: 20),
            price: _generateRandomPrice(random),
            createdAt: product1.createdAt,
            updatedAt: DateTime.now(),
          );
          
          // Save the modified product
          await repo.save(product2);
          
          // Retrieve the product
          final retrieved = await repo.getById(product1.id);
          
          // Verify it has the updated values
          expect(retrieved.name, equals(product2.name),
              reason: 'Iteration $i: Name should be updated');
          expect(retrieved.price, equals(product2.price),
              reason: 'Iteration $i: Price should be updated');
          
          // Verify only one item exists
          final count = await helper.countItems('custom_products');
          expect(count, equals(1),
              reason: 'Iteration $i: Should only have one item after upsert');
          
          // Clean up for next iteration
          await repo.deleteById(product1.id);
        }
      });
    });

    // **Feature: dynamodb-repository, Property 3: Repository deletion removes items**
    // **Validates: Requirements 2.5, 2.2, 2.6**
    group('Property 3: Repository deletion removes items', () {
      test('should throw notFound exception after deleting TestUser', () async {
        final repo = TestUserDynamoRepository(connection);
        final random = Random(47);

        for (var i = 0; i < 100; i++) {
          // Generate random user
          final user = _generateRandomTestUser(random);
          
          // Save the user
          await repo.save(user);
          
          // Verify it exists
          final retrieved = await repo.getById(user.id);
          expect(retrieved.id, equals(user.id),
              reason: 'Iteration $i: User should exist before deletion');
          
          // Delete the user
          await repo.deleteById(user.id);
          
          // Verify getById throws notFound exception
          try {
            await repo.getById(user.id);
            fail('Iteration $i: Should have thrown RepositoryException');
          } on RepositoryException catch (e) {
            expect(e.type, equals(RepositoryExceptionType.notFound),
                reason: 'Iteration $i: Should throw notFound exception');
          }
        }
      });

      test('should throw notFound exception after deleting TestProduct', () async {
        final repo = TestProductDynamoRepository(connection);
        final random = Random(48);

        for (var i = 0; i < 100; i++) {
          // Generate random product
          final product = _generateRandomTestProduct(random);
          
          // Save the product
          await repo.save(product);
          
          // Verify it exists
          final retrieved = await repo.getById(product.id);
          expect(retrieved.id, equals(product.id),
              reason: 'Iteration $i: Product should exist before deletion');
          
          // Delete the product
          await repo.deleteById(product.id);
          
          // Verify getById throws notFound exception
          try {
            await repo.getById(product.id);
            fail('Iteration $i: Should have thrown RepositoryException');
          } on RepositoryException catch (e) {
            expect(e.type, equals(RepositoryExceptionType.notFound),
                reason: 'Iteration $i: Should throw notFound exception');
          }
        }
      });

      test('should throw notFound exception after deleting TestAccount', () async {
        final repo = TestAccountDynamoRepository(connection);
        final random = Random(49);

        for (var i = 0; i < 100; i++) {
          // Generate random account
          final account = _generateRandomTestAccount(random);
          
          // Save the account
          await repo.save(account);
          
          // Verify it exists
          final retrieved = await repo.getById(account.id);
          expect(retrieved.id, equals(account.id),
              reason: 'Iteration $i: Account should exist before deletion');
          
          // Delete the account
          await repo.deleteById(account.id);
          
          // Verify getById throws notFound exception
          try {
            await repo.getById(account.id);
            fail('Iteration $i: Should have thrown RepositoryException');
          } on RepositoryException catch (e) {
            expect(e.type, equals(RepositoryExceptionType.notFound),
                reason: 'Iteration $i: Should throw notFound exception');
          }
        }
      });

      test('should throw notFound when deleting non-existent item', () async {
        final repo = TestUserDynamoRepository(connection);
        final random = Random(50);

        for (var i = 0; i < 100; i++) {
          // Generate random ID that doesn't exist
          final nonExistentId = UuidValue.generate();
          
          // Verify deleteById throws notFound exception
          try {
            await repo.deleteById(nonExistentId);
            fail('Iteration $i: Should have thrown RepositoryException');
          } on RepositoryException catch (e) {
            expect(e.type, equals(RepositoryExceptionType.notFound),
                reason: 'Iteration $i: Should throw notFound exception for non-existent item');
          }
        }
      });
    });
  });
}

// Generator functions

/// Generates a random TestUser instance.
TestUser _generateRandomTestUser(Random random) {
  return TestUser(
    id: UuidValue.generate(),
    name: _generateRandomString(random, maxLength: 20),
    email: _generateRandomEmail(random),
    createdAt: _generateRandomDateTime(random),
    updatedAt: _generateRandomDateTime(random),
  );
}

/// Generates a random TestProduct instance.
TestProduct _generateRandomTestProduct(Random random) {
  return TestProduct(
    id: UuidValue.generate(),
    name: _generateRandomString(random, maxLength: 30),
    price: _generateRandomPrice(random),
    createdAt: _generateRandomDateTime(random),
    updatedAt: _generateRandomDateTime(random),
  );
}

/// Generates a random TestAccount instance.
TestAccount _generateRandomTestAccount(Random random) {
  final accountTypes = ['checking', 'savings', 'investment', 'credit'];
  
  return TestAccount(
    id: UuidValue.generate(),
    accountName: _generateRandomString(random, maxLength: 25),
    accountType: accountTypes[random.nextInt(accountTypes.length)],
    balance: _generateRandomBalance(random),
    createdAt: _generateRandomDateTime(random),
    updatedAt: _generateRandomDateTime(random),
  );
}

/// Generates a random string of variable length.
String _generateRandomString(Random random, {int maxLength = 50}) {
  final length = random.nextInt(maxLength) + 1;
  const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ';
  return String.fromCharCodes(
    Iterable.generate(
      length,
      (_) => chars.codeUnitAt(random.nextInt(chars.length)),
    ),
  ).trim();
}

/// Generates a random email address.
String _generateRandomEmail(Random random) {
  final username = _generateRandomString(random, maxLength: 15).replaceAll(' ', '');
  final domains = ['example.com', 'test.com', 'demo.org', 'sample.net'];
  final domain = domains[random.nextInt(domains.length)];
  return '${username.toLowerCase()}@$domain';
}

/// Generates a random DateTime within the last year.
DateTime _generateRandomDateTime(Random random) {
  final now = DateTime.now();
  final daysAgo = random.nextInt(365);
  return now.subtract(Duration(days: daysAgo));
}

/// Generates a random price between 0.01 and 9999.99.
double _generateRandomPrice(Random random) {
  return (random.nextInt(999999) + 1) / 100.0;
}

/// Generates a random balance between -10000.00 and 100000.00.
double _generateRandomBalance(Random random) {
  return (random.nextInt(1100000) - 100000) / 100.0;
}
