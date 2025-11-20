// ignore_for_file: avoid_print

import 'package:dddart/dddart.dart';
import 'package:dddart_repository_mongodb/dddart_repository_mongodb.dart';
import 'lib/domain/user.dart';

/// Error handling example demonstrating proper exception handling patterns.
///
/// This example shows:
/// - Handling RepositoryException.notFound
/// - Handling connection errors
/// - Proper try-catch patterns
/// - Error type checking and recovery
///
/// Prerequisites:
/// - MongoDB running on localhost:27017 for successful connection test
/// - MongoDB NOT running on localhost:27018 for connection error test
Future<void> main() async {
  print('=== Error Handling Example ===\n');

  await _demonstrateNotFoundError();
  print("");

  await _demonstrateConnectionError();
  print("");

  await _demonstrateProperErrorHandling();
  print("");

  print('=== Example completed successfully ===');
}

/// Demonstrates handling of RepositoryException.notFound.
Future<void> _demonstrateNotFoundError() async {
  print('1. Demonstrating NOT FOUND error handling...');

  final connection = MongoConnection(
    host: 'localhost',
    port: 27017,
    databaseName: 'dddart_example',
  );

  try {
    await connection.open();
    final userRepo = UserMongoRepository(connection.database);

    // Try to get a non-existent user
    final nonExistentId = UuidValue.generate();
    print('   Attempting to retrieve non-existent user: $nonExistentId');

    try {
      await userRepo.getById(nonExistentId);
      print('   ✗ Should have thrown RepositoryException.notFound');
    } on RepositoryException catch (e) {
      if (e.type == RepositoryExceptionType.notFound) {
        print('   ✓ Caught RepositoryException.notFound');
        print('   Message: ${e.message}');
      } else {
        print('   ✗ Unexpected exception type: ${e.type}');
      }
    }

    // Try to delete a non-existent user
    print('\n   Attempting to delete non-existent user: $nonExistentId');
    try {
      await userRepo.deleteById(nonExistentId);
      print('   ✗ Should have thrown RepositoryException.notFound');
    } on RepositoryException catch (e) {
      if (e.type == RepositoryExceptionType.notFound) {
        print('   ✓ Caught RepositoryException.notFound');
        print('   Message: ${e.message}');
      } else {
        print('   ✗ Unexpected exception type: ${e.type}');
      }
    }
  } finally {
    await connection.close();
  }
}

/// Demonstrates handling of connection errors.
Future<void> _demonstrateConnectionError() async {
  print('2. Demonstrating CONNECTION error handling...');

  // Try to connect to a non-existent MongoDB instance
  final connection = MongoConnection(
    host: 'localhost',
    port: 27018, // Wrong port - MongoDB not running here
    databaseName: 'dddart_example',
  );

  print('   Attempting to connect to localhost:27018 (should fail)...');
  try {
    await connection.open();
    print('   ✗ Connection should have failed');
    await connection.close();
  } catch (e) {
    print('   ✓ Caught connection error');
    print('   Error type: ${e.runtimeType}');
    print('   Message: ${e.toString().split('\n').first}');
  }
}

/// Demonstrates proper error handling patterns with recovery.
Future<void> _demonstrateProperErrorHandling() async {
  print('3. Demonstrating proper error handling with recovery...');

  final connection = MongoConnection(
    host: 'localhost',
    port: 27017,
    databaseName: 'dddart_example',
  );

  try {
    await connection.open();
    final userRepo = UserMongoRepository(connection.database);

    // Create a test user
    final user = User(
      firstName: 'Test',
      lastName: 'User',
      email: 'test@example.com',
    );
    await userRepo.save(user);
    print('   ✓ Created test user: ${user.id}');

    // Pattern 1: Try to get user, handle not found gracefully
    print('\n   Pattern 1: Graceful handling with default value');
    final userId = UuidValue.generate(); // Non-existent ID
    User? retrievedUser;
    try {
      retrievedUser = await userRepo.getById(userId);
    } on RepositoryException catch (e) {
      if (e.type == RepositoryExceptionType.notFound) {
        print('   ✓ User not found, using default');
        retrievedUser = null;
      } else {
        print('   ✗ Unexpected error: ${e.message}');
        rethrow;
      }
    }
    print('   Result: ${retrievedUser?.fullName ?? "No user"}');

    // Pattern 2: Try operation, log error, continue
    print('\n   Pattern 2: Log and continue');
    try {
      await userRepo.deleteById(UuidValue.generate());
    } on RepositoryException catch (e) {
      if (e.type == RepositoryExceptionType.notFound) {
        print('   ✓ Delete failed (not found), continuing...');
      } else {
        print('   ✗ Unexpected error: ${e.message}');
      }
    }

    // Pattern 3: Specific error type handling
    print('\n   Pattern 3: Specific error type handling');
    try {
      await userRepo.getById(UuidValue.generate());
    } on RepositoryException catch (e) {
      switch (e.type) {
        case RepositoryExceptionType.notFound:
          print('   ✓ Handled: Resource not found');
        case RepositoryExceptionType.connection:
          print('   ✓ Handled: Connection issue');
        case RepositoryExceptionType.timeout:
          print('   ✓ Handled: Operation timed out');
        case RepositoryExceptionType.duplicate:
          print('   ✓ Handled: Duplicate key');
        case RepositoryExceptionType.constraint:
          print('   ✓ Handled: Constraint violation');
        case RepositoryExceptionType.unknown:
          print('   ✓ Handled: Unknown error');
      }
    }

    // Clean up
    await userRepo.deleteById(user.id);
    print('\n   ✓ Cleaned up test data');
  } finally {
    await connection.close();
  }
}
