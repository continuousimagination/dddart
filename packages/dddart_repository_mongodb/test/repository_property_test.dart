/// Property-based tests for MongoDB repository operations.
library;

import 'dart:math';

import 'package:dddart/dddart.dart';
import 'package:test/test.dart';

import 'test_helpers.dart';
import 'test_models.dart';

void main() {
  group('MongoDB Repository Property Tests', () {
    late TestMongoHelper helper;
    late TestUserMongoRepository repository;
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

    setUp(() async {
      if (!mongoAvailable) {
        markTestSkipped('MongoDB not available on localhost:27017');
        return;
      }
      repository = TestUserMongoRepository(helper.database);
      // Clear any existing test data
      await helper.clearCollection('test_user');
    });

    tearDown(() async {
      if (mongoAvailable && helper.isConnected) {
        // Clean up test data
        await helper.clearCollection('test_user');
      }
    });

    tearDownAll(() async {
      if (mongoAvailable && helper.isConnected) {
        await helper.disconnect();
      }
    });

    // Property: Round-trip persistence
    // Validates: Data saved can be retrieved unchanged
    group('Property: Round-trip persistence', () {
      test(
        'should preserve aggregate data through save and retrieve cycle',
        () async {
          if (!mongoAvailable) {
            markTestSkipped('MongoDB not available');
            return;
          }

          final random = Random(100);

          for (var i = 0; i < 20; i++) {
            // Generate random aggregate
            final original = _generateRandomUser(random);

            // Save and retrieve
            await repository.save(original);
            final retrieved = await repository.getById(original.id);

            // Verify all fields match
            expect(retrieved.id, equals(original.id));
            expect(retrieved.name, equals(original.name));
            expect(retrieved.email, equals(original.email));
            expect(retrieved.createdAt, equals(original.createdAt));
            expect(retrieved.updatedAt, equals(original.updatedAt));
          }
        },
        tags: ['requires-mongo', 'property-test'],
      );

      test(
        'should handle updates correctly',
        () async {
          if (!mongoAvailable) {
            markTestSkipped('MongoDB not available');
            return;
          }

          final random = Random(101);

          for (var i = 0; i < 10; i++) {
            // Create and save initial version
            final original = _generateRandomUser(random);
            await repository.save(original);

            // Update and save again
            final updated = TestUser(
              id: original.id,
              name: 'Updated ${original.name}',
              email: 'updated_${original.email}',
              createdAt: original.createdAt,
              updatedAt: DateTime.now(),
            );
            await repository.save(updated);

            // Retrieve and verify update
            final retrieved = await repository.getById(original.id);
            expect(retrieved.name, equals(updated.name));
            expect(retrieved.email, equals(updated.email));
            expect(retrieved.id, equals(original.id));
          }
        },
        tags: ['requires-mongo', 'property-test'],
      );
    });

    // Property: CRUD operation correctness
    // Validates: All CRUD operations work as expected
    group('Property: CRUD operation correctness', () {
      test(
        'should throw RepositoryException.notFound for non-existent IDs',
        () async {
          if (!mongoAvailable) {
            markTestSkipped('MongoDB not available');
            return;
          }

          for (var i = 0; i < 10; i++) {
            final nonExistentId = UuidValue.generate();

            await expectLater(
              repository.getById(nonExistentId),
              throwsA(
                isA<RepositoryException>().having(
                  (e) => e.type,
                  'type',
                  equals(RepositoryExceptionType.notFound),
                ),
              ),
              reason: 'Iteration $i: Should throw notFound exception',
            );
          }
        },
        tags: ['requires-mongo', 'property-test'],
      );

      test(
        'should successfully delete existing aggregates',
        () async {
          if (!mongoAvailable) {
            markTestSkipped('MongoDB not available');
            return;
          }

          final random = Random(103);

          for (var i = 0; i < 10; i++) {
            // Create and save
            final user = _generateRandomUser(random);
            await repository.save(user);

            // Verify exists
            final retrieved = await repository.getById(user.id);
            expect(retrieved.id, equals(user.id));

            // Delete
            await repository.deleteById(user.id);

            // Verify deleted
            await expectLater(
              repository.getById(user.id),
              throwsA(isA<RepositoryException>()),
              reason: 'Iteration $i: Should not find deleted aggregate',
            );
          }
        },
        tags: ['requires-mongo', 'property-test'],
      );

      test(
        'should throw RepositoryException.notFound when deleting non-existent ID',
        () async {
          if (!mongoAvailable) {
            markTestSkipped('MongoDB not available');
            return;
          }

          for (var i = 0; i < 10; i++) {
            final nonExistentId = UuidValue.generate();

            await expectLater(
              repository.deleteById(nonExistentId),
              throwsA(
                isA<RepositoryException>().having(
                  (e) => e.type,
                  'type',
                  equals(RepositoryExceptionType.notFound),
                ),
              ),
              reason: 'Iteration $i: Should throw notFound exception',
            );
          }
        },
        tags: ['requires-mongo', 'property-test'],
      );
    });

    // Property: ID uniqueness
    // Validates: Each aggregate has a unique ID
    group('Property: ID uniqueness', () {
      test(
        'should handle multiple aggregates with different IDs',
        () async {
          if (!mongoAvailable) {
            markTestSkipped('MongoDB not available');
            return;
          }

          final random = Random(105);
          final users = <TestUser>[];

          // Create multiple users
          for (var i = 0; i < 20; i++) {
            final user = _generateRandomUser(random);
            users.add(user);
            await repository.save(user);
          }

          // Verify all can be retrieved independently
          for (final user in users) {
            final retrieved = await repository.getById(user.id);
            expect(retrieved.id, equals(user.id));
            expect(retrieved.name, equals(user.name));
          }
        },
        tags: ['requires-mongo', 'property-test'],
      );

      test(
        'should handle save with same ID as update (upsert behavior)',
        () async {
          if (!mongoAvailable) {
            markTestSkipped('MongoDB not available');
            return;
          }

          final random = Random(106);

          for (var i = 0; i < 10; i++) {
            final id = UuidValue.generate();

            // First save
            final user1 = TestUser(
              id: id,
              name: 'User ${random.nextInt(1000)}',
              email: 'user${random.nextInt(1000)}@test.com',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
            await repository.save(user1);

            // Second save with same ID (should update)
            final user2 = TestUser(
              id: id,
              name: 'Updated User ${random.nextInt(1000)}',
              email: 'updated${random.nextInt(1000)}@test.com',
              createdAt: user1.createdAt,
              updatedAt: DateTime.now(),
            );
            await repository.save(user2);

            // Verify only one exists with updated data
            final retrieved = await repository.getById(id);
            expect(retrieved.name, equals(user2.name));
            expect(retrieved.email, equals(user2.email));
          }
        },
        tags: ['requires-mongo', 'property-test'],
      );
    });

    // Property: Error handling consistency
    // Validates: Errors are mapped to appropriate exception types
    group('Property: Error handling consistency', () {
      test(
        'should wrap MongoDB errors in RepositoryException',
        () async {
          if (!mongoAvailable) {
            markTestSkipped('MongoDB not available');
            return;
          }

          // Create a separate helper for this test to avoid affecting others
          final testHelper = createTestHelper();
          await testHelper.connect();
          final testRepo = TestUserMongoRepository(testHelper.database);

          // Close connection to force error
          await testHelper.disconnect();

          final user = TestUser(
            id: UuidValue.generate(),
            name: 'Test User',
            email: 'test@test.com',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          // Operations should throw RepositoryException
          await expectLater(
            testRepo.save(user),
            throwsA(isA<RepositoryException>()),
          );

          await expectLater(
            testRepo.getById(user.id),
            throwsA(isA<RepositoryException>()),
          );

          await expectLater(
            testRepo.deleteById(user.id),
            throwsA(isA<RepositoryException>()),
          );
        },
        tags: ['requires-mongo', 'property-test'],
      );
    });

    // Property: Data type preservation
    // Validates: Different data types are preserved correctly
    group('Property: Data type preservation', () {
      test(
        'should preserve string fields correctly',
        () async {
          if (!mongoAvailable) {
            markTestSkipped('MongoDB not available');
            return;
          }

          final testStrings = [
            'simple',
            'with spaces',
            'with-dashes',
            'with_underscores',
            'with.dots',
            'with@symbols',
            'UPPERCASE',
            'MixedCase',
            '123numbers',
            'unicode: 你好世界',
            'emoji: 😀🎉',
            '',
          ];

          for (final testString in testStrings) {
            final now = DateTime.now();
            final user = TestUser(
              id: UuidValue.generate(),
              name: testString,
              email: '$testString@test.com',
              createdAt: now,
              updatedAt: now,
            );

            await repository.save(user);
            final retrieved = await repository.getById(user.id);

            expect(retrieved.name, equals(testString));
            expect(retrieved.email, equals('$testString@test.com'));
          }
        },
        tags: ['requires-mongo', 'property-test'],
      );

      test(
        'should preserve DateTime fields correctly',
        () async {
          if (!mongoAvailable) {
            markTestSkipped('MongoDB not available');
            return;
          }

          final testDates = [
            DateTime(2020),
            DateTime(2024, 12, 31, 23, 59, 59),
            DateTime.now(),
            DateTime.now().subtract(const Duration(days: 365)),
            DateTime.now().add(const Duration(days: 365)),
          ];

          for (final testDate in testDates) {
            final user = TestUser(
              id: UuidValue.generate(),
              name: 'Test User',
              email: 'test@test.com',
              createdAt: testDate,
              updatedAt: testDate,
            );

            await repository.save(user);
            final retrieved = await repository.getById(user.id);

            // MongoDB stores dates with millisecond precision
            expect(
              retrieved.createdAt.millisecondsSinceEpoch,
              equals(testDate.millisecondsSinceEpoch),
            );
            expect(
              retrieved.updatedAt.millisecondsSinceEpoch,
              equals(testDate.millisecondsSinceEpoch),
            );
          }
        },
        tags: ['requires-mongo', 'property-test'],
      );
    });
  });
}

// Generator functions

/// Generates a random TestUser for property testing.
TestUser _generateRandomUser(Random random) {
  return TestUser(
    id: UuidValue.generate(),
    name: 'User ${random.nextInt(10000)}',
    email: 'user${random.nextInt(10000)}@test.com',
    createdAt: DateTime.now().subtract(
      Duration(days: random.nextInt(365)),
    ),
    updatedAt: DateTime.now(),
  );
}
