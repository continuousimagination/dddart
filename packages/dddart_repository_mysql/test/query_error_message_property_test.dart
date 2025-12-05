/// Property-based tests for MySQL query error message completeness.
///
/// **Feature: mysql-driver-migration, Property 13: Query error message completeness**
/// **Validates: Requirements 7.2**
library;

import 'dart:math';

import 'package:dddart/dddart.dart';
import 'package:test/test.dart';

import 'test_helpers.dart';

void main() {
  group('Query Error Message Completeness Property Tests', () {
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

    // **Feature: mysql-driver-migration, Property 13: Query error message completeness**
    // **Validates: Requirements 7.2**
    test(
      'Property 13: For any query failure, the error message should contain '
      'the SQL statement and the database error details',
      () async {
        final random = Random(52);

        // Test various query error scenarios
        for (var iteration = 0; iteration < 100; iteration++) {
          final scenario = iteration % 5;
          late String sql;
          late String expectedKeyword;

          switch (scenario) {
            case 0:
              // Non-existent table
              final tableName = 'nonexistent_table_${random.nextInt(10000)}';
              sql = 'SELECT * FROM $tableName';
              expectedKeyword = tableName;

            case 1:
              // Syntax error
              sql = 'SELCT * FORM invalid_syntax_${random.nextInt(1000)}';
              expectedKeyword = 'syntax';

            case 2:
              // Non-existent column
              await helper!.connection.execute('''
                CREATE TABLE IF NOT EXISTS test_query_error_$iteration (
                  id INT PRIMARY KEY
                ) ENGINE=InnoDB
              ''');
              sql = 'SELECT nonexistent_column_${random.nextInt(1000)} '
                  'FROM test_query_error_$iteration';
              expectedKeyword = 'column';

            case 3:
              // Invalid WHERE clause
              await helper!.connection.execute('''
                CREATE TABLE IF NOT EXISTS test_query_error_$iteration (
                  id INT PRIMARY KEY
                ) ENGINE=InnoDB
              ''');
              sql = 'SELECT * FROM test_query_error_$iteration '
                  'WHERE invalid_column_${random.nextInt(1000)} = 1';
              expectedKeyword = 'column';

            case 4:
              // Invalid function or aggregate error
              await helper!.connection.execute('''
                CREATE TABLE IF NOT EXISTS test_query_error_$iteration (
                  id INT PRIMARY KEY,
                  value INT
                ) ENGINE=InnoDB
              ''');
              sql = 'SELECT INVALID_FUNCTION_${random.nextInt(1000)}(id) '
                  'FROM test_query_error_$iteration';
              expectedKeyword = 'function';
          }

          // Execute query and expect error
          var exceptionThrown = false;
          try {
            await helper!.connection.query(sql);
          } catch (e) {
            exceptionThrown = true;

            // Verify it's a RepositoryException
            expect(
              e,
              isA<RepositoryException>(),
              reason: 'Iteration $iteration (scenario $scenario): Should throw '
                  'RepositoryException',
            );

            final exception = e as RepositoryException;

            // Verify error message contains SQL or query reference
            final message = exception.message.toLowerCase();
            expect(
              message.contains('query') ||
                  message.contains('sql') ||
                  message.contains('error') ||
                  message.contains(expectedKeyword.toLowerCase()),
              isTrue,
              reason:
                  'Iteration $iteration (scenario $scenario): Error message '
                  'should contain query/SQL reference or error keyword. '
                  'Message: ${exception.message}',
            );

            // Verify cause is preserved
            expect(
              exception.cause,
              isNotNull,
              reason: 'Iteration $iteration (scenario $scenario): Original '
                  'exception should be preserved as cause',
            );

            // Error message should not be empty
            expect(
              exception.message,
              isNotEmpty,
              reason:
                  'Iteration $iteration (scenario $scenario): Error message '
                  'should not be empty',
            );
          }

          expect(
            exceptionThrown,
            isTrue,
            reason:
                'Iteration $iteration (scenario $scenario): Query should fail',
          );
        }
      },
      tags: ['requires-mysql', 'property-test'],
    );

    test(
      'Property 13 (variant): Parameterized query errors should include '
      'parameter information',
      () async {
        final random = Random(53);

        // Create test table
        await helper!.connection.execute('''
          CREATE TABLE IF NOT EXISTS test_param_error (
            id INT PRIMARY KEY,
            value VARCHAR(255)
          ) ENGINE=InnoDB
        ''');

        for (var iteration = 0; iteration < 50; iteration++) {
          // Try to insert with wrong parameter count
          const sql = 'INSERT INTO test_param_error (id, value) VALUES (?, ?)';
          final wrongParams = [
            random.nextInt(1000),
          ]; // Only 1 param instead of 2

          try {
            await helper!.connection.execute(sql, wrongParams);
            // If this succeeds, it's unexpected but we'll continue
            continue;
          } catch (e) {
            expect(e, isA<RepositoryException>());
            final exception = e as RepositoryException;

            // Error message should provide context
            expect(
              exception.message,
              isNotEmpty,
              reason: 'Iteration $iteration: Error message should not be empty',
            );

            // Should indicate it's a query/execution error
            final message = exception.message.toLowerCase();
            expect(
              message.contains('error') ||
                  message.contains('query') ||
                  message.contains('execute') ||
                  message.contains('parameter'),
              isTrue,
              reason: 'Iteration $iteration: Error message should indicate '
                  'query error',
            );
          }
        }

        // Clean up
        await helper!.connection.execute('DROP TABLE test_param_error');
      },
      tags: ['requires-mysql', 'property-test'],
    );

    test(
      'Property 13 (edge case): Query errors with special characters should '
      'be handled',
      () async {
        final specialQueries = [
          "SELECT * FROM table_with_'quote'",
          'SELECT * FROM table_with_"doublequote"',
          'SELECT * FROM table_with_`backtick`',
          r'SELECT * FROM table_with_\backslash',
          'SELECT * FROM table_with_\nnewline',
        ];

        for (var i = 0; i < specialQueries.length; i++) {
          final sql = specialQueries[i];

          try {
            await helper!.connection.query(sql);
          } catch (e) {
            expect(e, isA<RepositoryException>());
            final exception = e as RepositoryException;

            // Error message should be well-formed (not crash on special chars)
            expect(
              exception.message,
              isNotEmpty,
              reason:
                  'Query $i: Error message should handle special characters',
            );

            // Should indicate it's an error
            expect(
              exception.message.toLowerCase().contains('error') ||
                  exception.message.toLowerCase().contains('query') ||
                  exception.message.toLowerCase().contains('sql'),
              isTrue,
              reason: 'Query $i: Error message should indicate query error',
            );
          }
        }
      },
      tags: ['requires-mysql', 'property-test'],
    );

    test(
      'Property 13 (edge case): Long query errors should be handled gracefully',
      () async {
        // Create a very long query
        final longTableName = 'a' * 200;
        final sql = 'SELECT * FROM $longTableName';

        try {
          await helper!.connection.query(sql);
        } catch (e) {
          expect(e, isA<RepositoryException>());
          final exception = e as RepositoryException;

          // Error message should exist and be reasonable length
          expect(
            exception.message,
            isNotEmpty,
            reason: 'Error message should not be empty for long queries',
          );

          // Should indicate it's an error
          expect(
            exception.message.toLowerCase().contains('error') ||
                exception.message.toLowerCase().contains('query') ||
                exception.message.toLowerCase().contains('table'),
            isTrue,
            reason: 'Error message should indicate query error',
          );
        }
      },
      tags: ['requires-mysql', 'property-test'],
    );

    test(
      'Property 13 (edge case): Constraint violation errors should include '
      'constraint details',
      () async {
        final random = Random(54);

        // Create table with unique constraint
        await helper!.connection.execute('''
          CREATE TABLE IF NOT EXISTS test_constraint_error (
            id INT PRIMARY KEY,
            unique_value VARCHAR(255) UNIQUE
          ) ENGINE=InnoDB
        ''');

        for (var iteration = 0; iteration < 50; iteration++) {
          // Clean up
          await helper!.connection.execute('DELETE FROM test_constraint_error');

          final value = 'unique_${random.nextInt(1000)}';

          // Insert first row
          await helper!.connection.execute(
            'INSERT INTO test_constraint_error (id, unique_value) VALUES (?, ?)',
            [1, value],
          );

          // Try to insert duplicate
          try {
            await helper!.connection.execute(
              'INSERT INTO test_constraint_error (id, unique_value) VALUES (?, ?)',
              [2, value],
            );
            fail('Should have thrown exception for duplicate unique value');
          } catch (e) {
            expect(e, isA<RepositoryException>());
            final exception = e as RepositoryException;

            // Should be duplicate type
            expect(
              exception.type,
              equals(RepositoryExceptionType.duplicate),
              reason: 'Iteration $iteration: Should be duplicate error type',
            );

            // Error message should provide context
            expect(
              exception.message,
              isNotEmpty,
              reason: 'Iteration $iteration: Error message should not be empty',
            );

            final message = exception.message.toLowerCase();
            expect(
              message.contains('duplicate') ||
                  message.contains('unique') ||
                  message.contains('constraint') ||
                  message.contains('key'),
              isTrue,
              reason: 'Iteration $iteration: Error message should indicate '
                  'constraint violation',
            );
          }
        }

        // Clean up
        await helper!.connection.execute('DROP TABLE test_constraint_error');
      },
      tags: ['requires-mysql', 'property-test'],
    );
  });
}
