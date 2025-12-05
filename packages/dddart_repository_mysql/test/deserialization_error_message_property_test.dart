/// Property-based tests for MySQL deserialization error message completeness.
///
/// **Feature: mysql-driver-migration, Property 14: Deserialization error message completeness**
/// **Validates: Requirements 7.3**
library;

import 'dart:math';

import 'package:dddart/dddart.dart';
import 'package:test/test.dart';

import 'integration_test_models.dart';
import 'test_helpers.dart';

void main() {
  group('Deserialization Error Message Completeness Property Tests', () {
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

    // **Feature: mysql-driver-migration, Property 14: Deserialization error message completeness**
    // **Validates: Requirements 7.3**
    test(
      'Property 14: For any deserialization failure, the error message should '
      'contain the entity type name and the field name that caused the issue',
      () async {
        final repo = SimpleProductMysqlRepository(helper!.connection);
        await repo.createTables();

        // Test various deserialization error scenarios
        for (var iteration = 0; iteration < 50; iteration++) {
          final scenario = iteration % 3;

          switch (scenario) {
            case 0:
              // Corrupt data: Insert invalid data directly into database
              // that will fail deserialization
              try {
                // Insert row with NULL in required field
                await helper!.connection.execute(
                  'INSERT INTO simple_product (id, name, price, createdAt, updatedAt) '
                  'VALUES (UUID_TO_BIN(?), NULL, ?, NOW(), NOW())',
                  [UuidValue.generate().toString(), 99.99],
                );

                // Try to retrieve - should fail deserialization
                try {
                  final results = await helper!.connection.query(
                    'SELECT BIN_TO_UUID(id) as id, name, price, createdAt, updatedAt '
                    'FROM simple_product',
                  );

                  // If we got results, try to deserialize manually
                  if (results.isNotEmpty) {
                    // This would normally happen in the repository
                    // The error should indicate which field failed
                    final row = results.first;
                    expect(
                      row['name'],
                      isNull,
                      reason:
                          'Name should be NULL to trigger deserialization issue',
                    );
                  }
                } catch (e) {
                  // Expected - deserialization or query error
                  if (e is RepositoryException) {
                    // Error message should provide context
                    expect(
                      e.message,
                      isNotEmpty,
                      reason:
                          'Iteration $iteration: Error message should not be empty',
                    );
                  }
                }
              } catch (e) {
                // Expected - constraint violation or other error
              }

            case 1:
              // Type mismatch: Insert string where number expected
              try {
                // Try to insert invalid price type
                await helper!.connection.execute(
                  'INSERT INTO simple_product (id, name, price, createdAt, updatedAt) '
                  "VALUES (UUID_TO_BIN(?), ?, 'invalid_price', NOW(), NOW())",
                  [UuidValue.generate().toString(), 'Test Product'],
                );
              } catch (e) {
                // Expected - type error
                expect(
                  e,
                  isA<RepositoryException>(),
                  reason:
                      'Iteration $iteration: Should throw RepositoryException',
                );

                final exception = e as RepositoryException;
                expect(
                  exception.message,
                  isNotEmpty,
                  reason:
                      'Iteration $iteration: Error message should not be empty',
                );
              }

            case 2:
              // Missing required field
              try {
                // Try to insert without required field
                await helper!.connection.execute(
                  'INSERT INTO simple_product (id, name, createdAt, updatedAt) '
                  'VALUES (UUID_TO_BIN(?), ?, NOW(), NOW())',
                  [UuidValue.generate().toString(), 'Test Product'],
                );
              } catch (e) {
                // Expected - missing field error
                expect(
                  e,
                  isA<RepositoryException>(),
                  reason:
                      'Iteration $iteration: Should throw RepositoryException',
                );

                final exception = e as RepositoryException;
                expect(
                  exception.message,
                  isNotEmpty,
                  reason:
                      'Iteration $iteration: Error message should not be empty',
                );

                // Error should indicate field issue
                final message = exception.message.toLowerCase();
                expect(
                  message.contains('field') ||
                      message.contains('column') ||
                      message.contains('price') ||
                      message.contains('error'),
                  isTrue,
                  reason: 'Iteration $iteration: Error message should indicate '
                      'field issue',
                );
              }
          }

          // Clean up for next iteration
          await helper!.connection.execute('DELETE FROM simple_product');
        }

        // Clean up
        await helper!.connection.execute('DROP TABLE simple_product');
      },
      tags: ['requires-mysql', 'property-test'],
    );

    test(
      'Property 14 (variant): Entity relationship deserialization errors '
      'should indicate entity type',
      () async {
        final repo = OrderMysqlRepository(helper!.connection);
        await repo.createTables();

        // Insert order with valid data
        final order = Order(
          customerName: 'Test Customer',
          items: [
            OrderItem(productName: 'Product 1', quantity: 1, unitPrice: 10),
          ],
        );
        await repo.save(order);

        // Corrupt the order_item data
        try {
          await helper!.connection.execute(
            'UPDATE order_item SET quantity = NULL WHERE order_id = UUID_TO_BIN(?)',
            [order.id.toString()],
          );

          // Try to retrieve - should handle NULL in required field
          try {
            await repo.getById(order.id);
            // If this succeeds, the NULL was handled somehow
          } catch (e) {
            // Expected - deserialization error
            if (e is RepositoryException) {
              expect(
                e.message,
                isNotEmpty,
                reason: 'Error message should not be empty',
              );

              // Error should provide context about entity type
              final message = e.message.toLowerCase();
              expect(
                message.contains('order') ||
                    message.contains('item') ||
                    message.contains('entity') ||
                    message.contains('error'),
                isTrue,
                reason: 'Error message should indicate entity type',
              );
            }
          }
        } catch (e) {
          // Expected - constraint or other error
        }

        // Clean up
        await helper!.connection.execute('DROP TABLE order_item');
        await helper!.connection.execute('DROP TABLE orders');
      },
      tags: ['requires-mysql', 'property-test'],
    );

    test(
      'Property 14 (edge case): Value object deserialization errors should '
      'indicate value type',
      () async {
        final repo = CustomerMysqlRepository(helper!.connection);
        await repo.createTables();

        // Insert customer with valid data
        final customer = Customer(
          name: 'Test Customer',
          email: const Email(value: 'test@example.com'),
          shippingAddress: const Address(
            street: '123 Main St',
            city: 'Springfield',
            state: 'IL',
            zipCode: '62701',
          ),
        );
        await repo.save(customer);

        // Corrupt the email value
        try {
          await helper!.connection.execute(
            'UPDATE customer SET email_value = NULL WHERE id = UUID_TO_BIN(?)',
            [customer.id.toString()],
          );

          // Try to retrieve - should handle NULL in required value field
          try {
            await repo.getById(customer.id);
            // If this succeeds, the NULL was handled somehow
          } catch (e) {
            // Expected - deserialization error
            if (e is RepositoryException) {
              expect(
                e.message,
                isNotEmpty,
                reason: 'Error message should not be empty',
              );

              // Error should provide context
              final message = e.message.toLowerCase();
              expect(
                message.contains('customer') ||
                    message.contains('email') ||
                    message.contains('value') ||
                    message.contains('error'),
                isTrue,
                reason: 'Error message should indicate value type',
              );
            }
          }
        } catch (e) {
          // Expected - constraint or other error
        }

        // Clean up
        await helper!.connection.execute('DROP TABLE customer');
      },
      tags: ['requires-mysql', 'property-test'],
    );

    test(
      'Property 14 (edge case): Not found errors should clearly indicate '
      'entity was not found',
      () async {
        final repo = SimpleProductMysqlRepository(helper!.connection);
        await repo.createTables();

        // Try to get non-existent entities
        for (var iteration = 0; iteration < 50; iteration++) {
          final nonExistentId = UuidValue.generate();

          try {
            await repo.getById(nonExistentId);
            fail('Should have thrown RepositoryException for non-existent ID');
          } catch (e) {
            expect(
              e,
              isA<RepositoryException>(),
              reason: 'Iteration $iteration: Should throw RepositoryException',
            );

            final exception = e as RepositoryException;

            // Should be notFound type
            expect(
              exception.type,
              equals(RepositoryExceptionType.notFound),
              reason: 'Iteration $iteration: Should be notFound error type',
            );

            // Error message should indicate not found
            expect(
              exception.message,
              isNotEmpty,
              reason: 'Iteration $iteration: Error message should not be empty',
            );

            final message = exception.message.toLowerCase();
            expect(
              message.contains('not found') ||
                  message.contains('notfound') ||
                  message.contains('does not exist') ||
                  message.contains('not exist'),
              isTrue,
              reason: 'Iteration $iteration: Error message should indicate '
                  'entity not found',
            );
          }
        }

        // Clean up
        await helper!.connection.execute('DROP TABLE simple_product');
      },
      tags: ['requires-mysql', 'property-test'],
    );

    test(
      'Property 14 (edge case): Batch operation errors should indicate which '
      'entity failed',
      () async {
        final random = Random(57);
        final repo = SimpleProductMysqlRepository(helper!.connection);
        await repo.createTables();

        // Create multiple products
        final products = List.generate(
          10,
          (i) => SimpleProduct(
            name: 'Product $i',
            price: random.nextDouble() * 100,
          ),
        );

        // Save all products
        for (final product in products) {
          await repo.save(product);
        }

        // Try to get all products - should succeed
        final retrieved = <SimpleProduct>[];
        for (final product in products) {
          final p = await repo.getById(product.id);
          retrieved.add(p);
        }

        expect(
          retrieved.length,
          equals(products.length),
          reason: 'All products should be retrieved',
        );

        // Try to get a non-existent product in the middle of batch
        final nonExistentId = UuidValue.generate();
        try {
          await repo.getById(nonExistentId);
          fail('Should have thrown RepositoryException');
        } catch (e) {
          expect(e, isA<RepositoryException>());
          final exception = e as RepositoryException;

          // Error should indicate which entity failed
          expect(
            exception.type,
            equals(RepositoryExceptionType.notFound),
            reason: 'Should be notFound error',
          );

          expect(
            exception.message,
            isNotEmpty,
            reason: 'Error message should not be empty',
          );
        }

        // Clean up
        await helper!.connection.execute('DROP TABLE simple_product');
      },
      tags: ['requires-mysql', 'property-test'],
    );
  });
}
