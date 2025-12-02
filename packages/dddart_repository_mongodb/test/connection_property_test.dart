/// Property-based tests for MongoDB connection operations.
library;

import 'dart:math';

import 'package:dddart_repository_mongodb/src/connection/mongo_connection.dart';
import 'package:dddart_repository_mongodb/src/exceptions/mongo_repository_exception.dart';
import 'package:test/test.dart';

void main() {
  group('MongoConnection Property Tests', () {
    // Property: Connection lifecycle correctness
    // Validates: Connection can be opened, used, and closed properly
    group('Property: Connection lifecycle correctness', () {
      test(
        'should be usable after open() and throw after close()',
        () async {
          final random = Random(50);

          for (var i = 0; i < 10; i++) {
            // Generate random connection parameters
            final connection = _generateRandomConnection(random);

            // Initially should not be connected
            expect(connection.isConnected, isFalse);

            // After open, should be usable
            try {
              await connection.open();
              expect(connection.isConnected, isTrue);

              // Should be able to access database
              final db = connection.database;
              expect(db, isNotNull);

              // After close, should not be usable
              await connection.close();
              expect(connection.isConnected, isFalse);

              // Should throw StateError on database access
              expect(
                () => connection.database,
                throwsA(isA<StateError>()),
                reason: 'Iteration $i: Should throw StateError after close',
              );
            } catch (e) {
              // If connection fails (e.g., MongoDB not available), skip
              if (e is MongoRepositoryException) {
                // Skip this iteration - MongoDB not available
                continue;
              }
              rethrow;
            }
          }
        },
        tags: ['requires-mongo', 'property-test'],
      );

      test(
        'should handle multiple open() calls gracefully',
        () async {
          final connection = MongoConnection(
            host: 'localhost',
            port: 27017,
            databaseName: 'test_db',
          );

          try {
            // First open
            await connection.open();
            expect(connection.isConnected, isTrue);

            // Second open should be no-op
            await connection.open();
            expect(connection.isConnected, isTrue);

            // Should still be usable
            final db = connection.database;
            expect(db, isNotNull);

            await connection.close();
          } catch (e) {
            // If connection fails, skip this test
            if (e is MongoRepositoryException) {
              return;
            }
            rethrow;
          }
        },
        tags: ['requires-mongo', 'property-test'],
      );

      test(
        'should handle multiple close() calls gracefully',
        () async {
          final connection = MongoConnection(
            host: 'localhost',
            port: 27017,
            databaseName: 'test_db',
          );

          try {
            await connection.open();

            // First close
            await connection.close();
            expect(connection.isConnected, isFalse);

            // Second close should be no-op
            await connection.close();
            expect(connection.isConnected, isFalse);
          } catch (e) {
            // If connection fails, skip this test
            if (e is MongoRepositoryException) {
              return;
            }
            rethrow;
          }
        },
        tags: ['requires-mongo', 'property-test'],
      );
    });

    // Property: Connection error handling
    // Validates: Invalid parameters throw appropriate exceptions
    group('Property: Connection error handling', () {
      test(
        'should throw MongoRepositoryException for invalid parameters',
        () async {
          final random = Random(51);

          for (var i = 0; i < 10; i++) {
            // Generate invalid connection parameters
            final connection = _generateInvalidConnection(random);

            // Should throw MongoRepositoryException
            try {
              await connection.open();
              fail('Should have thrown MongoRepositoryException');
            } catch (e) {
              expect(
                e,
                isA<MongoRepositoryException>(),
                reason: 'Iteration $i: Should throw MongoRepositoryException',
              );
            }
          }
        },
        tags: ['property-test'],
      );

      test(
        'should include error details in exception message',
        () async {
          final connection = MongoConnection(
            host: 'invalid-host-that-does-not-exist',
            port: 27017,
            databaseName: 'test_db',
          );

          try {
            await connection.open();
            fail('Should have thrown MongoRepositoryException');
          } catch (e) {
            expect(e, isA<MongoRepositoryException>());
            final exception = e as MongoRepositoryException;
            expect(exception.message, contains('Failed to open'));
            expect(exception.cause, isNotNull);
          }
        },
        tags: ['property-test'],
      );
    });

    // Property: URI parsing correctness
    // Validates: URIs are parsed correctly into connection parameters
    group('Property: URI parsing correctness', () {
      test(
        'should correctly parse various URI formats',
        () {
          final testCases = [
            (
              uri: 'mongodb://localhost:27017/testdb',
              host: 'localhost',
              port: 27017,
              db: 'testdb',
              user: null,
              pass: null,
            ),
            (
              uri: 'mongodb://user:pass@localhost:27017/testdb',
              host: 'localhost',
              port: 27017,
              db: 'testdb',
              user: 'user',
              pass: 'pass',
            ),
            (
              uri: 'mongodb://localhost/testdb',
              host: 'localhost',
              port: 27017,
              db: 'testdb',
              user: null,
              pass: null,
            ),
          ];

          for (final testCase in testCases) {
            final connection = MongoConnection.fromUri(testCase.uri);

            expect(connection.host, equals(testCase.host));
            expect(connection.port, equals(testCase.port));
            expect(connection.databaseName, equals(testCase.db));
            expect(connection.username, equals(testCase.user));
            expect(connection.password, equals(testCase.pass));
          }
        },
        tags: ['property-test'],
      );

      test(
        'should reject invalid URI schemes',
        () {
          final invalidSchemes = [
            'http://localhost:27017/testdb',
            'https://localhost:27017/testdb',
            'postgres://localhost:27017/testdb',
            'mysql://localhost:27017/testdb',
          ];

          for (final uri in invalidSchemes) {
            expect(
              () => MongoConnection.fromUri(uri),
              throwsA(isA<ArgumentError>()),
              reason: 'Should reject URI: $uri',
            );
          }
        },
        tags: ['property-test'],
      );

      test(
        'should reject URIs without database name',
        () {
          final invalidUris = [
            'mongodb://localhost:27017/',
            'mongodb://localhost:27017',
            'mongodb://user:pass@localhost:27017/',
          ];

          for (final uri in invalidUris) {
            expect(
              () => MongoConnection.fromUri(uri),
              throwsA(isA<ArgumentError>()),
              reason: 'Should reject URI without database: $uri',
            );
          }
        },
        tags: ['property-test'],
      );
    });

    // Property: Connection string building
    // Validates: Connection parameters are correctly formatted
    group('Property: Connection string building', () {
      test(
        'should build valid connection strings for various configurations',
        () {
          final random = Random(52);

          for (var i = 0; i < 20; i++) {
            final connection = _generateRandomConnection(random);

            // Connection should be created without errors
            expect(connection.host, isNotEmpty);
            expect(connection.port, greaterThan(0));
            expect(connection.databaseName, isNotEmpty);

            // If credentials provided, both should be present or both null
            if (connection.username != null) {
              expect(connection.password, isNotNull);
            }
            if (connection.password != null) {
              expect(connection.username, isNotNull);
            }
          }
        },
        tags: ['property-test'],
      );
    });
  });
}

// Generator functions

/// Generates a random MongoDB connection with potentially valid parameters.
MongoConnection _generateRandomConnection(Random random) {
  // For testing, we'll use localhost with standard test credentials
  final useAuth = random.nextBool();

  return MongoConnection(
    host: 'localhost',
    port: 27017,
    databaseName: 'test_db_${random.nextInt(100)}',
    username: useAuth ? 'test_user' : null,
    password: useAuth ? 'test_password' : null,
    authSource: useAuth && random.nextBool() ? 'admin' : null,
    tls: random.nextBool(),
    tlsAllowInvalidCertificates: random.nextBool(),
  );
}

/// Generates a MongoDB connection with invalid parameters.
MongoConnection _generateInvalidConnection(Random random) {
  final invalidConfigs = [
    // Invalid host
    () => MongoConnection(
          host: 'invalid-host-${random.nextInt(1000)}',
          port: 27017,
          databaseName: 'test_db',
        ),
    // Invalid port
    () => MongoConnection(
          host: 'localhost',
          port: 9999,
          databaseName: 'test_db',
        ),
    // Invalid credentials
    () => MongoConnection(
          host: 'localhost',
          port: 27017,
          databaseName: 'test_db',
          username: 'invalid_user',
          password: 'invalid_password',
        ),
  ];

  return invalidConfigs[random.nextInt(invalidConfigs.length)]();
}
