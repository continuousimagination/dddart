/// Property-based tests for MySQL error type mapping consistency.
///
/// **Feature: mysql-driver-migration, Property 8: Error type mapping consistency**
/// **Validates: Requirements 4.4, 7.4**
library;

import 'dart:math';

import 'package:dddart/dddart.dart';
import 'package:dddart_repository_mysql/dddart_repository_mysql.dart';
import 'package:test/test.dart';

import 'integration_test_models.dart';
import 'test_helpers.dart';

void main() {
  group('Error Type Mapping Consistency Property Tests', () {
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

    // **Feature: mysql-driver-migration, Property 8: Error type mapping consistency**
    // **Validates: Requirements 4.4, 7.4**
    test(
      'Property 8: For any database error condition (duplicate key, '
      'connection failure, timeout, constraint violation), the system should '
      'map it to the appropriate RepositoryException type with equivalent '
      'error information',
      () async {
        final random = Random(58);
        final repo = SimpleProductMysqlRepository(helper!.connection);
        await repo.createTables();

        // Test various error type mappings
        for (var iteration = 0; iteration < 100; iteration++) {
          final scenario = iteration % 4;

          switch (scenario) {
            case 0:
              // Duplicate key error -> RepositoryExceptionType.duplicate
              final product = SimpleProduct(
                name: 'Test Product',
                price: random.nextDouble() * 100,
              );

              // Insert first time
              await repo.save(product);

              // Try to insert again with same ID
              try {
                await helper!.connection.execute(
                  'INSERT INTO simple_product (id, name, price, createdAt, updatedAt) '
                  'VALUES (UUID_TO_BIN(?), ?, ?, NOW(), NOW())',
                  [product.id.toString(), 'Duplicate', 99.99],
                );
                fail('Should have thrown exception for duplicate key');
              } catch (e) {
                expect(
                  e,
                  isA<RepositoryException>(),
                  reason:
                      'Iteration $iteration: Should throw RepositoryException',
                );

                final exception = e as RepositoryException;
                expect(
                  exception.type,
                  equals(RepositoryExceptionType.duplicate),
                  reason: 'Iteration $iteration: Should map to duplicate type',
                );

                expect(
                  exception.message,
                  isNotEmpty,
                  reason:
                      'Iteration $iteration: Error message should not be empty',
                );

                expect(
                  exception.cause,
                  isNotNull,
                  reason:
                      'Iteration $iteration: Original cause should be preserved',
                );
              }

              // Clean up
              await helper!.connection.execute('DELETE FROM simple_product');

            case 1:
              // Not found error -> RepositoryExceptionType.notFound
              final nonExistentId = UuidValue.generate();

              try {
                await repo.getById(nonExistentId);
                fail('Should have thrown exception for non-existent ID');
              } catch (e) {
                expect(
                  e,
                  isA<RepositoryException>(),
                  reason:
                      'Iteration $iteration: Should throw RepositoryException',
                );

                final exception = e as RepositoryException;
                expect(
                  exception.type,
                  equals(RepositoryExceptionType.notFound),
                  reason: 'Iteration $iteration: Should map to notFound type',
                );

                expect(
                  exception.message,
                  isNotEmpty,
                  reason:
                      'Iteration $iteration: Error message should not be empty',
                );
              }

            case 2:
              // Query error -> RepositoryExceptionType.unknown (or specific type)
              try {
                await helper!.connection.query(
                  'SELECT * FROM nonexistent_table_${random.nextInt(10000)}',
                );
                fail('Should have thrown exception for non-existent table');
              } catch (e) {
                expect(
                  e,
                  isA<RepositoryException>(),
                  reason:
                      'Iteration $iteration: Should throw RepositoryException',
                );

                final exception = e as RepositoryException;
                // Query errors typically map to unknown type
                expect(
                  exception.type,
                  isIn([
                    RepositoryExceptionType.unknown,
                    RepositoryExceptionType.connection,
                  ]),
                  reason: 'Iteration $iteration: Should map to unknown or '
                      'connection type',
                );

                expect(
                  exception.message,
                  isNotEmpty,
                  reason:
                      'Iteration $iteration: Error message should not be empty',
                );

                expect(
                  exception.cause,
                  isNotNull,
                  reason:
                      'Iteration $iteration: Original cause should be preserved',
                );
              }

            case 3:
              // Constraint violation -> RepositoryExceptionType.duplicate or unknown
              // Create table with foreign key constraint
              await helper!.connection.execute('''
                CREATE TABLE IF NOT EXISTS test_parent_$iteration (
                  id INT PRIMARY KEY
                ) ENGINE=InnoDB
              ''');

              await helper!.connection.execute('''
                CREATE TABLE IF NOT EXISTS test_child_$iteration (
                  id INT PRIMARY KEY,
                  parent_id INT NOT NULL,
                  FOREIGN KEY (parent_id) REFERENCES test_parent_$iteration(id)
                ) ENGINE=InnoDB
              ''');

              // Try to insert child with non-existent parent
              try {
                await helper!.connection.execute(
                  'INSERT INTO test_child_$iteration (id, parent_id) VALUES (?, ?)',
                  [1, 999],
                );
                fail('Should have thrown exception for constraint violation');
              } catch (e) {
                expect(
                  e,
                  isA<RepositoryException>(),
                  reason:
                      'Iteration $iteration: Should throw RepositoryException',
                );

                final exception = e as RepositoryException;
                // Constraint violations can map to different types
                expect(
                  exception.type,
                  isIn([
                    RepositoryExceptionType.unknown,
                    RepositoryExceptionType.constraint,
                  ]),
                  reason:
                      'Iteration $iteration: Should map to appropriate type',
                );

                expect(
                  exception.message,
                  isNotEmpty,
                  reason:
                      'Iteration $iteration: Error message should not be empty',
                );

                expect(
                  exception.cause,
                  isNotNull,
                  reason:
                      'Iteration $iteration: Original cause should be preserved',
                );
              }

              // Clean up
              await helper!.connection
                  .execute('DROP TABLE test_child_$iteration');
              await helper!.connection
                  .execute('DROP TABLE test_parent_$iteration');
          }
        }

        // Clean up
        await helper!.connection.execute('DROP TABLE simple_product');
      },
      tags: ['requires-mysql', 'property-test'],
    );

    test(
      'Property 8 (variant): Connection errors should consistently map to '
      'connection type',
      () async {
        // Test various connection error scenarios
        final connectionErrors = [
          // Invalid host
          () => MysqlConnection(
                host: 'invalid-host-12345',
                port: 3306,
                database: 'test_db',
                user: 'root',
                password: 'password',
              ),
          // Invalid port
          () => MysqlConnection(
                host: 'localhost',
                port: 9999,
                database: 'test_db',
                user: 'root',
                password: 'password',
              ),
          // Invalid credentials
          () => MysqlConnection(
                host: 'localhost',
                port: 3307,
                database: 'test_db',
                user: 'invalid_user',
                password: 'invalid_password',
              ),
        ];

        for (var i = 0; i < connectionErrors.length; i++) {
          final connection = connectionErrors[i]();

          try {
            await connection.open();
            // If connection succeeds, skip this test
            await connection.close();
            continue;
          } catch (e) {
            expect(
              e,
              isA<RepositoryException>(),
              reason: 'Error $i: Should throw RepositoryException',
            );

            final exception = e as RepositoryException;
            expect(
              exception.type,
              equals(RepositoryExceptionType.connection),
              reason: 'Error $i: Should consistently map to connection type',
            );

            expect(
              exception.message,
              isNotEmpty,
              reason: 'Error $i: Error message should not be empty',
            );

            expect(
              exception.cause,
              isNotNull,
              reason: 'Error $i: Original cause should be preserved',
            );
          }
        }
      },
      tags: ['property-test'],
    );

    test(
      'Property 8 (edge case): Multiple errors of same type should map '
      'consistently',
      () async {
        final random = Random(59);
        final repo = SimpleProductMysqlRepository(helper!.connection);
        await repo.createTables();

        // Test multiple duplicate key errors
        for (var iteration = 0; iteration < 50; iteration++) {
          final product = SimpleProduct(
            name: 'Product $iteration',
            price: random.nextDouble() * 100,
          );

          // Insert first time
          await repo.save(product);

          // Try to insert duplicate
          try {
            await helper!.connection.execute(
              'INSERT INTO simple_product (id, name, price, createdAt, updatedAt) '
              'VALUES (UUID_TO_BIN(?), ?, ?, NOW(), NOW())',
              [product.id.toString(), 'Duplicate', 99.99],
            );
            fail('Should have thrown exception');
          } catch (e) {
            expect(e, isA<RepositoryException>());
            final exception = e as RepositoryException;

            // Should consistently map to duplicate type
            expect(
              exception.type,
              equals(RepositoryExceptionType.duplicate),
              reason: 'Iteration $iteration: Should consistently map to '
                  'duplicate type',
            );
          }

          // Clean up
          await helper!.connection.execute('DELETE FROM simple_product');
        }

        // Test multiple not found errors
        for (var iteration = 0; iteration < 50; iteration++) {
          final nonExistentId = UuidValue.generate();

          try {
            await repo.getById(nonExistentId);
            fail('Should have thrown exception');
          } catch (e) {
            expect(e, isA<RepositoryException>());
            final exception = e as RepositoryException;

            // Should consistently map to notFound type
            expect(
              exception.type,
              equals(RepositoryExceptionType.notFound),
              reason: 'Iteration $iteration: Should consistently map to '
                  'notFound type',
            );
          }
        }

        // Clean up
        await helper!.connection.execute('DROP TABLE simple_product');
      },
      tags: ['requires-mysql', 'property-test'],
    );

    test(
      'Property 8 (edge case): Error information should be preserved across '
      'exception mapping',
      () async {
        final random = Random(60);
        final repo = SimpleProductMysqlRepository(helper!.connection);
        await repo.createTables();

        // Test that error details are preserved
        for (var iteration = 0; iteration < 50; iteration++) {
          final product = SimpleProduct(
            name: 'Product $iteration',
            price: random.nextDouble() * 100,
          );

          await repo.save(product);

          // Try to insert duplicate
          try {
            await helper!.connection.execute(
              'INSERT INTO simple_product (id, name, price, createdAt, updatedAt) '
              'VALUES (UUID_TO_BIN(?), ?, ?, NOW(), NOW())',
              [product.id.toString(), 'Duplicate', 99.99],
            );
            fail('Should have thrown exception');
          } catch (e) {
            expect(e, isA<RepositoryException>());
            final exception = e as RepositoryException;

            // Verify error information is preserved
            expect(
              exception.type,
              equals(RepositoryExceptionType.duplicate),
              reason: 'Iteration $iteration: Type should be preserved',
            );

            expect(
              exception.message,
              isNotEmpty,
              reason: 'Iteration $iteration: Message should be preserved',
            );

            expect(
              exception.cause,
              isNotNull,
              reason:
                  'Iteration $iteration: Original cause should be preserved',
            );

            // Message should contain relevant information
            final message = exception.message.toLowerCase();
            expect(
              message.contains('duplicate') ||
                  message.contains('key') ||
                  message.contains('error'),
              isTrue,
              reason:
                  'Iteration $iteration: Message should contain error details',
            );
          }

          // Clean up
          await helper!.connection.execute('DELETE FROM simple_product');
        }

        // Clean up
        await helper!.connection.execute('DROP TABLE simple_product');
      },
      tags: ['requires-mysql', 'property-test'],
    );
  });
}
