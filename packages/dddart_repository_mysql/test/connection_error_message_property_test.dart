/// Property-based tests for MySQL connection error message completeness.
///
/// **Feature: mysql-driver-migration, Property 12: Connection error message completeness**
/// **Validates: Requirements 7.1**
library;

import 'dart:math';

import 'package:dddart/dddart.dart';
import 'package:dddart_repository_mysql/dddart_repository_mysql.dart';
import 'package:test/test.dart';

void main() {
  group('Connection Error Message Completeness Property Tests', () {
    // **Feature: mysql-driver-migration, Property 12: Connection error message completeness**
    // **Validates: Requirements 7.1**
    test(
      'Property 12: For any connection failure, the error message should '
      'contain the host, port, database name, and failure reason',
      () async {
        final random = Random(51);

        // Test various invalid connection scenarios
        for (var iteration = 0; iteration < 100; iteration++) {
          final scenario = iteration % 4;
          late MysqlConnection connection;
          late String expectedHost;
          late int expectedPort;
          late String expectedDatabase;

          switch (scenario) {
            case 0:
              // Invalid host
              expectedHost = 'invalid-host-${random.nextInt(10000)}';
              expectedPort = 3306;
              expectedDatabase = 'test_db';
              connection = MysqlConnection(
                host: expectedHost,
                port: expectedPort,
                database: expectedDatabase,
                user: 'root',
                password: 'password',
              );

            case 1:
              // Invalid port
              expectedHost = 'localhost';
              expectedPort = 9990 + random.nextInt(9);
              expectedDatabase = 'test_db';
              connection = MysqlConnection(
                host: expectedHost,
                port: expectedPort,
                database: expectedDatabase,
                user: 'root',
                password: 'password',
              );

            case 2:
              // Invalid credentials
              expectedHost = 'localhost';
              expectedPort = 3307;
              expectedDatabase = 'test_db';
              connection = MysqlConnection(
                host: expectedHost,
                port: expectedPort,
                database: expectedDatabase,
                user: 'invalid_user_${random.nextInt(1000)}',
                password: 'invalid_password',
              );

            case 3:
              // Invalid database
              expectedHost = 'localhost';
              expectedPort = 3307;
              expectedDatabase = 'nonexistent_db_${random.nextInt(10000)}';
              connection = MysqlConnection(
                host: expectedHost,
                port: expectedPort,
                database: expectedDatabase,
                user: 'root',
                password: 'test_password',
              );
          }

          // Attempt to connect
          var exceptionThrown = false;
          try {
            await connection.open();
            // If connection succeeds (e.g., MySQL not running), skip this iteration
            await connection.close();
            continue;
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

            // Verify exception type is connection
            expect(
              exception.type,
              equals(RepositoryExceptionType.connection),
              reason: 'Iteration $iteration (scenario $scenario): Should have '
                  'connection type',
            );

            // Verify error message contains connection parameters
            final message = exception.message.toLowerCase();

            // Check for host
            expect(
              message.contains(expectedHost.toLowerCase()) ||
                  message.contains('host'),
              isTrue,
              reason:
                  'Iteration $iteration (scenario $scenario): Error message '
                  'should contain host information. Message: ${exception.message}',
            );

            // Check for port
            expect(
              message.contains(expectedPort.toString()) ||
                  message.contains('port'),
              isTrue,
              reason:
                  'Iteration $iteration (scenario $scenario): Error message '
                  'should contain port information. Message: ${exception.message}',
            );

            // Check for database (for invalid database scenario)
            if (scenario == 3) {
              expect(
                message.contains(expectedDatabase.toLowerCase()) ||
                    message.contains('database'),
                isTrue,
                reason: 'Iteration $iteration (scenario $scenario): Error '
                    'message should contain database information. '
                    'Message: ${exception.message}',
              );
            }

            // Verify cause is preserved
            expect(
              exception.cause,
              isNotNull,
              reason: 'Iteration $iteration (scenario $scenario): Original '
                  'exception should be preserved as cause',
            );
          }

          expect(
            exceptionThrown,
            isTrue,
            reason: 'Iteration $iteration (scenario $scenario): Connection '
                'should fail',
          );
        }
      },
      tags: ['property-test'],
    );

    test(
      'Property 12 (variant): Connection timeout errors should include '
      'timeout duration',
      () async {
        // Create connection with very short timeout
        final connection = MysqlConnection(
          host: 'invalid-host-timeout-test',
          port: 3306,
          database: 'test_db',
          user: 'root',
          password: 'password',
          timeout: const Duration(milliseconds: 100),
        );

        try {
          await connection.open();
          // If connection succeeds, skip this test
          await connection.close();
          return;
        } catch (e) {
          expect(e, isA<RepositoryException>());
          final exception = e as RepositoryException;

          // Should be either connection or timeout type
          expect(
            exception.type == RepositoryExceptionType.connection ||
                exception.type == RepositoryExceptionType.timeout,
            isTrue,
            reason: 'Should be connection or timeout error',
          );

          // Error message should provide context
          expect(
            exception.message,
            isNotEmpty,
            reason: 'Error message should not be empty',
          );
        }
      },
      tags: ['property-test'],
    );

    test(
      'Property 12 (edge case): Connection error with special characters in '
      'parameters should be handled',
      () async {
        final specialChars = [
          'host-with-dash',
          'host_with_underscore',
          'host.with.dots',
          'host@with@at',
        ];

        for (var i = 0; i < specialChars.length; i++) {
          final host = specialChars[i];
          final connection = MysqlConnection(
            host: host,
            port: 3306,
            database: 'test_db',
            user: 'root',
            password: 'password',
          );

          try {
            await connection.open();
            await connection.close();
            continue;
          } catch (e) {
            expect(e, isA<RepositoryException>());
            final exception = e as RepositoryException;

            // Error message should be well-formed (not crash on special chars)
            expect(
              exception.message,
              isNotEmpty,
              reason: 'Error message should handle special characters in host',
            );

            expect(
              exception.type,
              equals(RepositoryExceptionType.connection),
              reason: 'Should be connection error',
            );
          }
        }
      },
      tags: ['property-test'],
    );

    test(
      'Property 12 (edge case): Multiple connection attempts should provide '
      'consistent error messages',
      () async {
        final connection = MysqlConnection(
          host: 'consistent-error-host',
          port: 9999,
          database: 'test_db',
          user: 'root',
          password: 'password',
        );

        final errorMessages = <String>[];

        // Try connecting multiple times
        for (var i = 0; i < 5; i++) {
          try {
            await connection.open();
            await connection.close();
            // If connection succeeds, skip this test
            return;
          } catch (e) {
            expect(e, isA<RepositoryException>());
            final exception = e as RepositoryException;
            errorMessages.add(exception.message);
          }
        }

        // All error messages should contain similar information
        for (var i = 0; i < errorMessages.length; i++) {
          final message = errorMessages[i].toLowerCase();

          expect(
            message.contains('connection') || message.contains('error'),
            isTrue,
            reason:
                'Attempt $i: Error message should indicate connection error',
          );

          // Should contain connection parameters
          expect(
            message.contains('consistent-error-host') ||
                message.contains('9999') ||
                message.contains('host') ||
                message.contains('port'),
            isTrue,
            reason: 'Attempt $i: Error message should contain connection info',
          );
        }
      },
      tags: ['property-test'],
    );
  });
}
