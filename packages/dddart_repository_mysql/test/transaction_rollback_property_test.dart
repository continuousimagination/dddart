/// Property-based tests for MySQL transaction rollback atomicity.
///
/// **Feature: mysql-driver-migration, Property 10: Transaction rollback atomicity**
/// **Validates: Requirements 6.2**
library;

import 'dart:math';

import 'package:dddart/dddart.dart';
import 'package:test/test.dart';

import 'test_helpers.dart';

void main() {
  group('Transaction Rollback Atomicity Property Tests', () {
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

    // **Feature: mysql-driver-migration, Property 10: Transaction rollback atomicity**
    // **Validates: Requirements 6.2**
    test(
      'Property 10: For any set of operations executed within a transaction '
      'that encounters an error, all operations should be rolled back and '
      'the database should return to its pre-transaction state',
      () async {
        final random = Random(45);

        // Create test table
        await helper!.connection.execute('''
          CREATE TABLE IF NOT EXISTS test_rollback (
            id INT PRIMARY KEY,
            value VARCHAR(255)
          ) ENGINE=InnoDB
        ''');

        // Run property test with multiple iterations
        for (var iteration = 0; iteration < 100; iteration++) {
          // Clean up before each iteration
          await helper!.connection.execute('DELETE FROM test_rollback');

          // Insert some initial data to verify pre-transaction state
          final initialId = iteration * 1000;
          await helper!.connection.execute(
            'INSERT INTO test_rollback (id, value) VALUES (?, ?)',
            [initialId, 'initial_$iteration'],
          );

          // Verify initial state
          var countResult = await helper!.connection.query(
            'SELECT COUNT(*) as count FROM test_rollback',
          );
          expect(countResult[0]['count'], equals(1));

          // Generate random number of operations before failure (1-10)
          final numOperations = random.nextInt(10) + 1;

          // Execute transaction that will fail
          var exceptionThrown = false;
          try {
            await helper!.connection.transaction(() async {
              // Insert multiple rows
              for (var i = 0; i < numOperations; i++) {
                await helper!.connection.execute(
                  'INSERT INTO test_rollback (id, value) VALUES (?, ?)',
                  [iteration * 1000 + i + 1, 'temp_${iteration}_$i'],
                );
              }

              // Force a failure by trying to insert duplicate key
              await helper!.connection.execute(
                'INSERT INTO test_rollback (id, value) VALUES (?, ?)',
                [initialId, 'duplicate'],
              );
            });
          } catch (e) {
            exceptionThrown = true;
            expect(
              e,
              isA<RepositoryException>(),
              reason: 'Iteration $iteration: Should throw RepositoryException',
            );
          }

          expect(
            exceptionThrown,
            isTrue,
            reason: 'Iteration $iteration: Transaction should fail',
          );

          // Verify rollback occurred - only initial row should exist
          countResult = await helper!.connection.query(
            'SELECT COUNT(*) as count FROM test_rollback',
          );
          expect(
            countResult[0]['count'],
            equals(1),
            reason: 'Iteration $iteration: All $numOperations operations '
                'should be rolled back',
          );

          // Verify initial data is still present
          final result = await helper!.connection.query(
            'SELECT value FROM test_rollback WHERE id = ?',
            [initialId],
          );
          expect(
            result.length,
            equals(1),
            reason: 'Iteration $iteration: Initial row should still exist',
          );
          expect(
            result[0]['value'],
            equals('initial_$iteration'),
            reason: 'Iteration $iteration: Initial row should be unchanged',
          );
        }

        // Clean up
        await helper!.connection.execute('DROP TABLE test_rollback');
      },
      tags: ['requires-mysql', 'property-test'],
    );

    test(
      'Property 10 (variant): Rollback should restore state even with '
      'multiple operation types',
      () async {
        final random = Random(46);

        // Create test table
        await helper!.connection.execute('''
          CREATE TABLE IF NOT EXISTS test_rollback_mixed (
            id INT PRIMARY KEY,
            value VARCHAR(255)
          ) ENGINE=InnoDB
        ''');

        for (var iteration = 0; iteration < 50; iteration++) {
          // Clean up
          await helper!.connection.execute('DELETE FROM test_rollback_mixed');

          // Insert initial data
          final numInitialRows = random.nextInt(5) + 1;
          for (var i = 0; i < numInitialRows; i++) {
            await helper!.connection.execute(
              'INSERT INTO test_rollback_mixed (id, value) VALUES (?, ?)',
              [i, 'initial_$i'],
            );
          }

          // Capture initial state
          final initialRows = await helper!.connection.query(
            'SELECT id, value FROM test_rollback_mixed ORDER BY id',
          );

          // Execute transaction with mixed operations that will fail
          try {
            await helper!.connection.transaction(() async {
              // Insert new rows
              await helper!.connection.execute(
                'INSERT INTO test_rollback_mixed (id, value) VALUES (?, ?)',
                [100, 'new_row'],
              );

              // Update existing rows
              await helper!.connection.execute(
                'UPDATE test_rollback_mixed SET value = ? WHERE id = ?',
                ['updated', 0],
              );

              // Delete a row
              if (numInitialRows > 1) {
                await helper!.connection.execute(
                  'DELETE FROM test_rollback_mixed WHERE id = ?',
                  [1],
                );
              }

              // Force failure
              throw Exception('Forced rollback');
            });
          } catch (e) {
            // Expected to fail
          }

          // Verify state was restored
          final finalRows = await helper!.connection.query(
            'SELECT id, value FROM test_rollback_mixed ORDER BY id',
          );

          expect(
            finalRows.length,
            equals(initialRows.length),
            reason: 'Iteration $iteration: Row count should be restored',
          );

          for (var i = 0; i < initialRows.length; i++) {
            expect(
              finalRows[i]['id'],
              equals(initialRows[i]['id']),
              reason: 'Iteration $iteration: Row $i ID should be restored',
            );
            expect(
              finalRows[i]['value'],
              equals(initialRows[i]['value']),
              reason: 'Iteration $iteration: Row $i value should be restored',
            );
          }
        }

        // Clean up
        await helper!.connection.execute('DROP TABLE test_rollback_mixed');
      },
      tags: ['requires-mysql', 'property-test'],
    );

    test(
      'Property 10 (edge case): Rollback on exception should work even with '
      'no prior operations',
      () async {
        // Create test table
        await helper!.connection.execute('''
          CREATE TABLE IF NOT EXISTS test_rollback_empty (
            id INT PRIMARY KEY
          ) ENGINE=InnoDB
        ''');

        // Execute transaction that fails immediately
        var exceptionThrown = false;
        try {
          await helper!.connection.transaction(() async {
            throw Exception('Immediate failure');
          });
        } catch (e) {
          exceptionThrown = true;
        }

        expect(
          exceptionThrown,
          isTrue,
          reason: 'Transaction should fail',
        );

        // Verify table is still empty
        final results = await helper!.connection.query(
          'SELECT COUNT(*) as count FROM test_rollback_empty',
        );
        expect(
          results[0]['count'],
          equals(0),
          reason: 'Table should remain empty after failed transaction',
        );

        // Clean up
        await helper!.connection.execute('DROP TABLE test_rollback_empty');
      },
      tags: ['requires-mysql', 'property-test'],
    );

    test(
      'Property 10 (edge case): Rollback should work with constraint '
      'violations',
      () async {
        // Create test table with foreign key constraint
        await helper!.connection.execute('''
          CREATE TABLE IF NOT EXISTS test_parent (
            id INT PRIMARY KEY
          ) ENGINE=InnoDB
        ''');

        await helper!.connection.execute('''
          CREATE TABLE IF NOT EXISTS test_child (
            id INT PRIMARY KEY,
            parent_id INT NOT NULL,
            FOREIGN KEY (parent_id) REFERENCES test_parent(id)
          ) ENGINE=InnoDB
        ''');

        for (var iteration = 0; iteration < 50; iteration++) {
          // Clean up
          await helper!.connection.execute('DELETE FROM test_child');
          await helper!.connection.execute('DELETE FROM test_parent');

          // Insert parent
          await helper!.connection.execute(
            'INSERT INTO test_parent (id) VALUES (?)',
            [1],
          );

          // Try to insert child with non-existent parent in transaction
          var exceptionThrown = false;
          try {
            await helper!.connection.transaction(() async {
              // Insert valid child
              await helper!.connection.execute(
                'INSERT INTO test_child (id, parent_id) VALUES (?, ?)',
                [1, 1],
              );

              // Try to insert child with invalid parent (should fail)
              await helper!.connection.execute(
                'INSERT INTO test_child (id, parent_id) VALUES (?, ?)',
                [2, 999],
              );
            });
          } catch (e) {
            exceptionThrown = true;
          }

          expect(
            exceptionThrown,
            isTrue,
            reason: 'Iteration $iteration: Transaction should fail on '
                'constraint violation',
          );

          // Verify rollback - no children should exist
          final childCount = await helper!.connection.query(
            'SELECT COUNT(*) as count FROM test_child',
          );
          expect(
            childCount[0]['count'],
            equals(0),
            reason: 'Iteration $iteration: All child inserts should be '
                'rolled back',
          );

          // Verify parent still exists
          final parentCount = await helper!.connection.query(
            'SELECT COUNT(*) as count FROM test_parent',
          );
          expect(
            parentCount[0]['count'],
            equals(1),
            reason: 'Iteration $iteration: Parent should still exist',
          );
        }

        // Clean up
        await helper!.connection.execute('DROP TABLE test_child');
        await helper!.connection.execute('DROP TABLE test_parent');
      },
      tags: ['requires-mysql', 'property-test'],
    );
  });
}
