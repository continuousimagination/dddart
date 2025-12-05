/// Property-based tests for MySQL nested transaction correctness.
///
/// **Feature: mysql-driver-migration, Property 11: Nested transaction correctness**
/// **Validates: Requirements 6.3**
library;

import 'dart:math';

import 'package:test/test.dart';

import 'test_helpers.dart';

void main() {
  group('Nested Transaction Correctness Property Tests', () {
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

    // **Feature: mysql-driver-migration, Property 11: Nested transaction correctness**
    // **Validates: Requirements 6.3**
    test(
      'Property 11: For any nested transaction structure, operations should '
      'execute correctly with proper commit/rollback behavior at each '
      'nesting level',
      () async {
        final random = Random(48);

        // Create test table
        await helper!.connection.execute('''
          CREATE TABLE IF NOT EXISTS test_nested (
            id INT PRIMARY KEY,
            value VARCHAR(255),
            level INT
          ) ENGINE=InnoDB
        ''');

        // Run property test with multiple iterations
        for (var iteration = 0; iteration < 100; iteration++) {
          // Clean up before each iteration
          await helper!.connection.execute('DELETE FROM test_nested');

          // Generate random nesting depth (1-5 levels)
          final nestingDepth = random.nextInt(5) + 1;
          final expectedIds = <int>[];

          // Execute nested transactions
          await _executeNestedTransaction(
            helper!,
            iteration,
            0,
            nestingDepth,
            expectedIds,
          );

          // Verify all operations were committed
          final results = await helper!.connection.query(
            'SELECT id, level FROM test_nested ORDER BY id',
          );

          expect(
            results.length,
            equals(expectedIds.length),
            reason: 'Iteration $iteration: All operations across $nestingDepth '
                'levels should be committed',
          );

          final actualIds = results.map((row) => row['id']! as int).toList();
          expect(
            actualIds,
            equals(expectedIds),
            reason: 'Iteration $iteration: All inserted IDs should be present',
          );

          // Verify level information is correct
          for (var i = 0; i < results.length; i++) {
            final level = results[i]['level']! as int;
            expect(
              level,
              greaterThanOrEqualTo(0),
              reason: 'Iteration $iteration: Level should be non-negative',
            );
            expect(
              level,
              lessThan(nestingDepth),
              reason: 'Iteration $iteration: Level should be less than depth',
            );
          }
        }

        // Clean up
        await helper!.connection.execute('DROP TABLE test_nested');
      },
      tags: ['requires-mysql', 'property-test'],
    );

    test(
      'Property 11 (variant): Nested transaction failure should rollback '
      'entire transaction tree',
      () async {
        final random = Random(49);

        // Create test table
        await helper!.connection.execute('''
          CREATE TABLE IF NOT EXISTS test_nested_rollback (
            id INT PRIMARY KEY,
            value VARCHAR(255)
          ) ENGINE=InnoDB
        ''');

        for (var iteration = 0; iteration < 50; iteration++) {
          // Clean up
          await helper!.connection.execute('DELETE FROM test_nested_rollback');

          // Generate random nesting depth (2-4 levels)
          final nestingDepth = random.nextInt(3) + 2;
          // Choose random level to fail at (1 to nestingDepth-1)
          final failAtLevel = random.nextInt(nestingDepth - 1) + 1;

          // Execute nested transactions with failure
          var exceptionThrown = false;
          try {
            await _executeNestedTransactionWithFailure(
              helper!,
              iteration,
              0,
              nestingDepth,
              failAtLevel,
            );
          } catch (e) {
            exceptionThrown = true;
          }

          expect(
            exceptionThrown,
            isTrue,
            reason: 'Iteration $iteration: Transaction should fail at level '
                '$failAtLevel',
          );

          // Verify complete rollback - no rows should exist
          final results = await helper!.connection.query(
            'SELECT COUNT(*) as count FROM test_nested_rollback',
          );
          expect(
            results[0]['count'],
            equals(0),
            reason: 'Iteration $iteration: All operations should be rolled '
                'back when nested transaction fails',
          );
        }

        // Clean up
        await helper!.connection.execute('DROP TABLE test_nested_rollback');
      },
      tags: ['requires-mysql', 'property-test'],
    );

    test(
      'Property 11 (edge case): Single-level nested transaction should '
      'behave like regular transaction',
      () async {
        // Create test table
        await helper!.connection.execute('''
          CREATE TABLE IF NOT EXISTS test_single_nested (
            id INT PRIMARY KEY,
            value VARCHAR(255)
          ) ENGINE=InnoDB
        ''');

        // Execute single-level nested transaction
        await helper!.connection.transaction(() async {
          await helper!.connection.transaction(() async {
            await helper!.connection.execute(
              'INSERT INTO test_single_nested (id, value) VALUES (?, ?)',
              [1, 'test'],
            );
          });
        });

        // Verify operation was committed
        final results = await helper!.connection.query(
          'SELECT COUNT(*) as count FROM test_single_nested',
        );
        expect(
          results[0]['count'],
          equals(1),
          reason: 'Single-level nested transaction should commit',
        );

        // Clean up
        await helper!.connection.execute('DROP TABLE test_single_nested');
      },
      tags: ['requires-mysql', 'property-test'],
    );

    test(
      'Property 11 (edge case): Deeply nested transactions should maintain '
      'consistency',
      () async {
        // Create test table
        await helper!.connection.execute('''
          CREATE TABLE IF NOT EXISTS test_deep_nested (
            id INT PRIMARY KEY,
            depth INT
          ) ENGINE=InnoDB
        ''');

        // Execute deeply nested transaction (10 levels)
        const maxDepth = 10;
        await _executeDeepNestedTransaction(helper!, 0, maxDepth);

        // Verify all operations were committed
        final results = await helper!.connection.query(
          'SELECT COUNT(*) as count FROM test_deep_nested',
        );
        expect(
          results[0]['count'],
          equals(maxDepth),
          reason: 'All operations in deeply nested transaction should commit',
        );

        // Verify depth values
        final depthResults = await helper!.connection.query(
          'SELECT depth FROM test_deep_nested ORDER BY depth',
        );
        for (var i = 0; i < maxDepth; i++) {
          expect(
            depthResults[i]['depth'],
            equals(i),
            reason: 'Depth $i should be recorded correctly',
          );
        }

        // Clean up
        await helper!.connection.execute('DROP TABLE test_deep_nested');
      },
      tags: ['requires-mysql', 'property-test'],
    );

    test(
      'Property 11 (edge case): Nested transaction with mixed operations '
      'should maintain atomicity',
      () async {
        // Create test table
        await helper!.connection.execute('''
          CREATE TABLE IF NOT EXISTS test_nested_mixed (
            id INT PRIMARY KEY,
            value VARCHAR(255)
          ) ENGINE=InnoDB
        ''');

        for (var iteration = 0; iteration < 50; iteration++) {
          // Clean up
          await helper!.connection.execute('DELETE FROM test_nested_mixed');

          // Insert initial data
          await helper!.connection.execute(
            'INSERT INTO test_nested_mixed (id, value) VALUES (?, ?)',
            [0, 'initial'],
          );

          // Execute nested transaction with mixed operations
          await helper!.connection.transaction(() async {
            // Outer level: insert
            await helper!.connection.execute(
              'INSERT INTO test_nested_mixed (id, value) VALUES (?, ?)',
              [1, 'outer'],
            );

            await helper!.connection.transaction(() async {
              // Inner level: update and insert
              await helper!.connection.execute(
                'UPDATE test_nested_mixed SET value = ? WHERE id = ?',
                ['updated', 0],
              );

              await helper!.connection.execute(
                'INSERT INTO test_nested_mixed (id, value) VALUES (?, ?)',
                [2, 'inner'],
              );
            });

            // Outer level: another insert
            await helper!.connection.execute(
              'INSERT INTO test_nested_mixed (id, value) VALUES (?, ?)',
              [3, 'outer2'],
            );
          });

          // Verify all operations were committed
          final results = await helper!.connection.query(
            'SELECT id, value FROM test_nested_mixed ORDER BY id',
          );

          expect(
            results.length,
            equals(4),
            reason: 'Iteration $iteration: All 4 rows should exist',
          );

          expect(
            results[0]['value'],
            equals('updated'),
            reason: 'Iteration $iteration: Initial row should be updated',
          );
          expect(
            results[1]['value'],
            equals('outer'),
            reason: 'Iteration $iteration: Outer insert should exist',
          );
          expect(
            results[2]['value'],
            equals('inner'),
            reason: 'Iteration $iteration: Inner insert should exist',
          );
          expect(
            results[3]['value'],
            equals('outer2'),
            reason: 'Iteration $iteration: Second outer insert should exist',
          );
        }

        // Clean up
        await helper!.connection.execute('DROP TABLE test_nested_mixed');
      },
      tags: ['requires-mysql', 'property-test'],
    );
  });
}

/// Recursively executes nested transactions.
Future<void> _executeNestedTransaction(
  TestMysqlHelper helper,
  int iteration,
  int currentLevel,
  int maxLevel,
  List<int> expectedIds,
) async {
  if (currentLevel >= maxLevel) {
    return;
  }

  await helper.connection.transaction(() async {
    // Insert a row at this level
    final id = iteration * 1000 + currentLevel;
    expectedIds.add(id);

    await helper.connection.execute(
      'INSERT INTO test_nested (id, value, level) VALUES (?, ?, ?)',
      [id, 'level_$currentLevel', currentLevel],
    );

    // Recurse to next level
    await _executeNestedTransaction(
      helper,
      iteration,
      currentLevel + 1,
      maxLevel,
      expectedIds,
    );
  });
}

/// Recursively executes nested transactions with failure at specified level.
Future<void> _executeNestedTransactionWithFailure(
  TestMysqlHelper helper,
  int iteration,
  int currentLevel,
  int maxLevel,
  int failAtLevel,
) async {
  if (currentLevel >= maxLevel) {
    return;
  }

  await helper.connection.transaction(() async {
    // Insert a row at this level
    final id = iteration * 1000 + currentLevel;
    await helper.connection.execute(
      'INSERT INTO test_nested_rollback (id, value) VALUES (?, ?)',
      [id, 'level_$currentLevel'],
    );

    // Fail at specified level
    if (currentLevel == failAtLevel) {
      throw Exception('Forced failure at level $currentLevel');
    }

    // Recurse to next level
    await _executeNestedTransactionWithFailure(
      helper,
      iteration,
      currentLevel + 1,
      maxLevel,
      failAtLevel,
    );
  });
}

/// Recursively executes deeply nested transactions.
Future<void> _executeDeepNestedTransaction(
  TestMysqlHelper helper,
  int currentDepth,
  int maxDepth,
) async {
  if (currentDepth >= maxDepth) {
    return;
  }

  await helper.connection.transaction(() async {
    await helper.connection.execute(
      'INSERT INTO test_deep_nested (id, depth) VALUES (?, ?)',
      [currentDepth, currentDepth],
    );

    await _executeDeepNestedTransaction(helper, currentDepth + 1, maxDepth);
  });
}
