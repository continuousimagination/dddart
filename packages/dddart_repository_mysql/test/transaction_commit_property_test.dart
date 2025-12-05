/// Property-based tests for MySQL transaction commit atomicity.
///
/// **Feature: mysql-driver-migration, Property 9: Transaction commit atomicity**
/// **Validates: Requirements 6.1**
library;

import 'dart:math';

import 'package:test/test.dart';

import 'test_helpers.dart';

void main() {
  group('Transaction Commit Atomicity Property Tests', () {
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

    // **Feature: mysql-driver-migration, Property 9: Transaction commit atomicity**
    // **Validates: Requirements 6.1**
    test(
      'Property 9: For any set of operations executed within a transaction, '
      'if the transaction succeeds, all operations should be committed and '
      'visible in subsequent queries',
      () async {
        final random = Random(42);

        // Create test table
        await helper!.connection.execute('''
          CREATE TABLE IF NOT EXISTS test_commit (
            id INT PRIMARY KEY,
            value VARCHAR(255)
          ) ENGINE=InnoDB
        ''');

        // Run property test with multiple iterations
        for (var iteration = 0; iteration < 100; iteration++) {
          // Clean up before each iteration
          await helper!.connection.execute('DELETE FROM test_commit');

          // Generate random number of operations (1-10)
          final numOperations = random.nextInt(10) + 1;
          final expectedIds = <int>[];

          // Execute transaction with multiple operations
          await helper!.connection.transaction(() async {
            for (var i = 0; i < numOperations; i++) {
              final id = iteration * 100 + i;
              final value = 'value_${iteration}_$i';
              expectedIds.add(id);

              await helper!.connection.execute(
                'INSERT INTO test_commit (id, value) VALUES (?, ?)',
                [id, value],
              );
            }
          });

          // Verify all operations were committed
          final results = await helper!.connection.query(
            'SELECT id FROM test_commit ORDER BY id',
          );

          expect(
            results.length,
            equals(numOperations),
            reason: 'Iteration $iteration: All $numOperations operations '
                'should be committed',
          );

          final actualIds = results.map((row) => row['id']! as int).toList();
          expect(
            actualIds,
            equals(expectedIds),
            reason: 'Iteration $iteration: All inserted IDs should be present',
          );

          // Verify values are correct
          for (var i = 0; i < numOperations; i++) {
            final expectedValue = 'value_${iteration}_$i';
            final result = await helper!.connection.query(
              'SELECT value FROM test_commit WHERE id = ?',
              [expectedIds[i]],
            );

            expect(
              result.length,
              equals(1),
              reason: 'Iteration $iteration: Row $i should exist',
            );
            expect(
              result[0]['value'],
              equals(expectedValue),
              reason: 'Iteration $iteration: Row $i should have correct value',
            );
          }
        }

        // Clean up
        await helper!.connection.execute('DROP TABLE test_commit');
      },
      tags: ['requires-mysql', 'property-test'],
    );

    test(
      'Property 9 (variant): Transaction commit should be visible across '
      'different connection queries',
      () async {
        final random = Random(43);

        // Create test table
        await helper!.connection.execute('''
          CREATE TABLE IF NOT EXISTS test_commit_visibility (
            id INT PRIMARY KEY,
            value VARCHAR(255)
          ) ENGINE=InnoDB
        ''');

        // Run property test with multiple iterations
        for (var iteration = 0; iteration < 50; iteration++) {
          // Clean up before each iteration
          await helper!.connection
              .execute('DELETE FROM test_commit_visibility');

          // Generate random data
          final numRows = random.nextInt(5) + 1;
          final expectedCount = numRows;

          // Execute transaction
          await helper!.connection.transaction(() async {
            for (var i = 0; i < numRows; i++) {
              await helper!.connection.execute(
                'INSERT INTO test_commit_visibility (id, value) VALUES (?, ?)',
                [iteration * 100 + i, 'test_${iteration}_$i'],
              );
            }
          });

          // Verify commit is visible in subsequent query
          final countResult = await helper!.connection.query(
            'SELECT COUNT(*) as count FROM test_commit_visibility',
          );

          expect(
            countResult[0]['count'],
            equals(expectedCount),
            reason: 'Iteration $iteration: Committed rows should be visible',
          );

          // Verify all rows are accessible
          final allRows = await helper!.connection.query(
            'SELECT id, value FROM test_commit_visibility ORDER BY id',
          );

          expect(
            allRows.length,
            equals(expectedCount),
            reason: 'Iteration $iteration: All committed rows should be '
                'queryable',
          );
        }

        // Clean up
        await helper!.connection.execute('DROP TABLE test_commit_visibility');
      },
      tags: ['requires-mysql', 'property-test'],
    );

    test(
      'Property 9 (edge case): Empty transaction should commit successfully',
      () async {
        // Create test table
        await helper!.connection.execute('''
          CREATE TABLE IF NOT EXISTS test_empty_commit (
            id INT PRIMARY KEY
          ) ENGINE=InnoDB
        ''');

        // Execute empty transaction
        var transactionCompleted = false;
        await helper!.connection.transaction(() async {
          // No operations
          transactionCompleted = true;
        });

        expect(
          transactionCompleted,
          isTrue,
          reason: 'Empty transaction should complete successfully',
        );

        // Verify table is still empty
        final results = await helper!.connection.query(
          'SELECT COUNT(*) as count FROM test_empty_commit',
        );
        expect(
          results[0]['count'],
          equals(0),
          reason: 'Table should remain empty after empty transaction',
        );

        // Clean up
        await helper!.connection.execute('DROP TABLE test_empty_commit');
      },
      tags: ['requires-mysql', 'property-test'],
    );

    test(
      'Property 9 (edge case): Transaction with updates should commit all '
      'changes',
      () async {
        final random = Random(44);

        // Create test table
        await helper!.connection.execute('''
          CREATE TABLE IF NOT EXISTS test_update_commit (
            id INT PRIMARY KEY,
            value VARCHAR(255)
          ) ENGINE=InnoDB
        ''');

        for (var iteration = 0; iteration < 50; iteration++) {
          // Clean up
          await helper!.connection.execute('DELETE FROM test_update_commit');

          // Insert initial data
          final numRows = random.nextInt(5) + 1;
          for (var i = 0; i < numRows; i++) {
            await helper!.connection.execute(
              'INSERT INTO test_update_commit (id, value) VALUES (?, ?)',
              [i, 'initial_$i'],
            );
          }

          // Execute transaction with updates
          await helper!.connection.transaction(() async {
            for (var i = 0; i < numRows; i++) {
              await helper!.connection.execute(
                'UPDATE test_update_commit SET value = ? WHERE id = ?',
                ['updated_${iteration}_$i', i],
              );
            }
          });

          // Verify all updates were committed
          for (var i = 0; i < numRows; i++) {
            final result = await helper!.connection.query(
              'SELECT value FROM test_update_commit WHERE id = ?',
              [i],
            );

            expect(
              result[0]['value'],
              equals('updated_${iteration}_$i'),
              reason: 'Iteration $iteration: Row $i should have updated value',
            );
          }
        }

        // Clean up
        await helper!.connection.execute('DROP TABLE test_update_commit');
      },
      tags: ['requires-mysql', 'property-test'],
    );
  });
}
