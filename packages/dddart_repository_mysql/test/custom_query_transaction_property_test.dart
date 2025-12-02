/// Property-based tests for custom query transaction context.
library;

import 'dart:math';

import 'package:test/test.dart';

import 'integration_test_models.dart';
import 'test_helpers.dart';

void main() {
  group('Custom Query Transaction Property Tests', () {
    TestMysqlHelper? helper;
    var mysqlAvailable = false;

    setUpAll(() async {
      final testHelper = createTestHelper();
      try {
        await testHelper.connect();
        mysqlAvailable = true;
        helper = testHelper;
      } catch (e) {
        // MySQL not available - tests will be skipped
        mysqlAvailable = false;
      }
    });

    setUp(() {
      if (!mysqlAvailable) {
        markTestSkipped('MySQL not available on localhost:3307');
      }
    });

    tearDown(() async {
      if (mysqlAvailable && helper != null && helper!.isConnected) {
        // Clean up all tables
        await helper!.dropAllTables();
      }
    });

    tearDownAll(() async {
      if (mysqlAvailable && helper != null && helper!.isConnected) {
        await helper!.disconnect();
      }
    });

    // **Feature: mysql-repository, Property 18: Custom query transaction
    // context**
    // **Validates: Requirements 5.5, 8.4**
    group('Property 18: Custom query transaction context', () {
      test(
        'should commit custom query changes when transaction succeeds',
        () async {
          final random = Random(100);

          for (var i = 0; i < 10; i++) {
            final repo = CustomProductRepositoryImpl(helper!.connection);
            await repo.createTables();

            // Generate random products
            final products = List.generate(
              random.nextInt(5) + 1,
              (_) => Product(
                name: 'Product${random.nextInt(1000)}',
                price: random.nextDouble() * 100,
              ),
            );

            // Execute within transaction
            await helper!.connection.transaction(() async {
              // Save products using standard method
              for (final product in products) {
                await repo.save(product);
              }

              // Use custom query within same transaction
              final count = await repo.countProducts();
              expect(
                count,
                equals(products.length),
                reason: 'Iteration $i: Custom query should see uncommitted '
                    'changes within transaction',
              );
            });

            // After transaction commits, custom query should still see the data
            final countAfterCommit = await repo.countProducts();
            expect(
              countAfterCommit,
              equals(products.length),
              reason: 'Iteration $i: Custom query should see committed changes '
                  'after transaction',
            );

            // Clean up for next iteration
            await helper!.dropAllTables();
          }
        },
        tags: ['requires-mysql', 'property-test'],
      );

      test(
        'should rollback custom query changes when transaction fails',
        () async {
          final random = Random(101);

          for (var i = 0; i < 10; i++) {
            final repo = CustomProductRepositoryImpl(helper!.connection);
            await repo.createTables();

            // Generate random products
            final products = List.generate(
              random.nextInt(5) + 1,
              (_) => Product(
                name: 'Product${random.nextInt(1000)}',
                price: random.nextDouble() * 100,
              ),
            );

            // Execute transaction that will fail
            var exceptionThrown = false;
            try {
              await helper!.connection.transaction(() async {
                // Save products using standard method
                for (final product in products) {
                  await repo.save(product);
                }

                // Verify custom query sees the changes within transaction
                final countDuringTransaction = await repo.countProducts();
                expect(
                  countDuringTransaction,
                  equals(products.length),
                  reason: 'Iteration $i: Custom query should see changes '
                      'within transaction',
                );

                // Force transaction to fail
                throw Exception('Forced transaction failure');
              });
            } catch (e) {
              exceptionThrown = true;
            }

            expect(
              exceptionThrown,
              isTrue,
              reason: 'Iteration $i: Transaction should fail',
            );

            // After rollback, custom query should see no data
            final countAfterRollback = await repo.countProducts();
            expect(
              countAfterRollback,
              equals(0),
              reason: 'Iteration $i: Custom query should see no data after '
                  'rollback',
            );

            // Clean up for next iteration
            await helper!.dropAllTables();
          }
        },
        tags: ['requires-mysql', 'property-test'],
      );

      test(
        'should handle mixed standard and custom operations in transaction',
        () async {
          final random = Random(102);

          for (var i = 0; i < 10; i++) {
            final repo = CustomProductRepositoryImpl(helper!.connection);
            await repo.createTables();

            // Generate random products with varying prices
            final lowPriceProducts = List.generate(
              random.nextInt(3) + 1,
              (_) => Product(
                name: 'LowPrice${random.nextInt(1000)}',
                price: random.nextDouble() * 50, // 0-50
              ),
            );

            final highPriceProducts = List.generate(
              random.nextInt(3) + 1,
              (_) => Product(
                name: 'HighPrice${random.nextInt(1000)}',
                price: 50 + random.nextDouble() * 50, // 50-100
              ),
            );

            final allProducts = [...lowPriceProducts, ...highPriceProducts];

            // Execute transaction with mixed operations
            await helper!.connection.transaction(() async {
              // Save all products using standard method
              for (final product in allProducts) {
                await repo.save(product);
              }

              // Use custom query to count total products
              final totalCount = await repo.countProducts();
              expect(
                totalCount,
                equals(allProducts.length),
                reason: 'Iteration $i: Should see all products',
              );

              // Use custom query to find high-price products
              final highPriceFound = await repo.findByMinPrice(50);
              expect(
                highPriceFound.length,
                equals(highPriceProducts.length),
                reason: 'Iteration $i: Should find correct number of '
                    'high-price products',
              );

              // Verify all high-price products are found
              for (final product in highPriceProducts) {
                expect(
                  highPriceFound.any((p) => p.id == product.id),
                  isTrue,
                  reason: 'Iteration $i: Should find product ${product.id}',
                );
              }
            });

            // After commit, custom queries should still work correctly
            final totalCountAfter = await repo.countProducts();
            expect(
              totalCountAfter,
              equals(allProducts.length),
              reason: 'Iteration $i: Should see all products after commit',
            );

            final highPriceFoundAfter = await repo.findByMinPrice(50);
            expect(
              highPriceFoundAfter.length,
              equals(highPriceProducts.length),
              reason: 'Iteration $i: Should find correct number of high-price '
                  'products after commit',
            );

            // Clean up for next iteration
            await helper!.dropAllTables();
          }
        },
        tags: ['requires-mysql', 'property-test'],
      );

      test(
        'should handle nested transactions with custom queries',
        () async {
          final random = Random(103);

          for (var i = 0; i < 10; i++) {
            final repo = CustomProductRepositoryImpl(helper!.connection);
            await repo.createTables();

            final outerProducts = List.generate(
              random.nextInt(3) + 1,
              (_) => Product(
                name: 'Outer${random.nextInt(1000)}',
                price: random.nextDouble() * 100,
              ),
            );

            final innerProducts = List.generate(
              random.nextInt(3) + 1,
              (_) => Product(
                name: 'Inner${random.nextInt(1000)}',
                price: random.nextDouble() * 100,
              ),
            );

            // Execute nested transactions
            await helper!.connection.transaction(() async {
              // Save outer products
              for (final product in outerProducts) {
                await repo.save(product);
              }

              // Custom query in outer transaction
              final countOuter = await repo.countProducts();
              expect(
                countOuter,
                equals(outerProducts.length),
                reason: 'Iteration $i: Should see outer products',
              );

              // Inner transaction
              await helper!.connection.transaction(() async {
                // Save inner products
                for (final product in innerProducts) {
                  await repo.save(product);
                }

                // Custom query in inner transaction should see all products
                final countInner = await repo.countProducts();
                expect(
                  countInner,
                  equals(outerProducts.length + innerProducts.length),
                  reason: 'Iteration $i: Should see all products in inner '
                      'transaction',
                );
              });

              // Custom query after inner transaction should still see all
              final countAfterInner = await repo.countProducts();
              expect(
                countAfterInner,
                equals(outerProducts.length + innerProducts.length),
                reason: 'Iteration $i: Should see all products after inner '
                    'transaction',
              );
            });

            // After outer transaction commits, all should be visible
            final countFinal = await repo.countProducts();
            expect(
              countFinal,
              equals(outerProducts.length + innerProducts.length),
              reason: 'Iteration $i: Should see all products after commit',
            );

            // Clean up for next iteration
            await helper!.dropAllTables();
          }
        },
        tags: ['requires-mysql', 'property-test'],
      );

      test(
        'should rollback all changes including custom queries on nested '
        'transaction failure',
        () async {
          final random = Random(104);

          for (var i = 0; i < 10; i++) {
            final repo = CustomProductRepositoryImpl(helper!.connection);
            await repo.createTables();

            final outerProducts = List.generate(
              random.nextInt(3) + 1,
              (_) => Product(
                name: 'Outer${random.nextInt(1000)}',
                price: random.nextDouble() * 100,
              ),
            );

            final innerProducts = List.generate(
              random.nextInt(3) + 1,
              (_) => Product(
                name: 'Inner${random.nextInt(1000)}',
                price: random.nextDouble() * 100,
              ),
            );

            // Execute nested transactions with failure
            var exceptionThrown = false;
            try {
              await helper!.connection.transaction(() async {
                // Save outer products
                for (final product in outerProducts) {
                  await repo.save(product);
                }

                // Custom query should see outer products
                final countOuter = await repo.countProducts();
                expect(
                  countOuter,
                  equals(outerProducts.length),
                  reason: 'Iteration $i: Should see outer products',
                );

                // Inner transaction that fails
                await helper!.connection.transaction(() async {
                  // Save inner products
                  for (final product in innerProducts) {
                    await repo.save(product);
                  }

                  // Custom query should see all products
                  final countInner = await repo.countProducts();
                  expect(
                    countInner,
                    equals(outerProducts.length + innerProducts.length),
                    reason: 'Iteration $i: Should see all products',
                  );

                  // Force failure
                  throw Exception('Inner transaction failed');
                });
              });
            } catch (e) {
              exceptionThrown = true;
            }

            expect(
              exceptionThrown,
              isTrue,
              reason: 'Iteration $i: Transaction should fail',
            );

            // After rollback, custom query should see no data
            final countAfterRollback = await repo.countProducts();
            expect(
              countAfterRollback,
              equals(0),
              reason: 'Iteration $i: All changes should be rolled back',
            );

            // Clean up for next iteration
            await helper!.dropAllTables();
          }
        },
        tags: ['requires-mysql', 'property-test'],
      );
    });
  });
}
