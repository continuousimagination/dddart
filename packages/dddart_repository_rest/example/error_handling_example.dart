/// Error handling example for dddart_repository_rest.
///
/// This example demonstrates:
/// - Different types of repository exceptions
/// - Handling specific error types
/// - Retry strategies for transient errors
/// - Graceful degradation patterns
/// - Error logging and reporting
///
/// To run this example, you need a REST API server running at
/// http://localhost:8080.
library;

import 'dart:math' as math;

import 'package:dddart/dddart.dart';
import 'package:dddart_repository_rest/dddart_repository_rest.dart';

import 'lib/user.dart';

/// Demonstrates handling different repository exception types.
Future<void> demonstrateExceptionTypes(UserRestRepository repository) async {
  print('=== Exception Types ===\n');

  // 1. Not Found Exception
  print('1. Not Found Exception (404)');
  try {
    final nonExistentId = UuidValue.generate();
    await repository.getById(nonExistentId);
    print('   ✗ Should have thrown notFound exception');
  } on RepositoryException catch (e) {
    if (e.type == RepositoryExceptionType.notFound) {
      print('   ✓ Caught notFound exception: ${e.message}');
    } else {
      print('   ✗ Wrong exception type: ${e.type}');
    }
  }
  print('');

  // 2. Duplicate Exception (if server supports it)
  print('2. Duplicate Exception (409)');
  print('   (Depends on server implementation)');
  final user = User(
    firstName: 'Test',
    lastName: 'User',
    email: 'test@example.com',
  );
  try {
    await repository.save(user);
    print('   ✓ User created');
    // Try to create again with same ID (if server enforces uniqueness)
    await repository.save(user);
    print('   Note: Server may not enforce duplicate checking');
  } on RepositoryException catch (e) {
    if (e.type == RepositoryExceptionType.duplicate) {
      print('   ✓ Caught duplicate exception: ${e.message}');
    }
  } finally {
    // Clean up
    try {
      await repository.deleteById(user.id);
    } catch (_) {}
  }
  print('');

  // 3. Connection Exception
  print('3. Connection Exception (5xx or network error)');
  print('   (Simulated by using wrong base URL)');
  final badConnection = RestConnection(baseUrl: 'http://localhost:9999');
  final badRepository = UserRestRepository(badConnection);
  try {
    await badRepository.getById(UuidValue.generate());
    print('   ✗ Should have thrown connection exception');
  } on RepositoryException catch (e) {
    if (e.type == RepositoryExceptionType.connection) {
      print('   ✓ Caught connection exception: ${e.message}');
    } else {
      print('   Note: Got ${e.type} instead of connection');
    }
  } finally {
    badConnection.dispose();
  }
  print('');
}

/// Demonstrates retry strategy for transient errors.
Future<User?> getUserWithRetry(
  UserRestRepository repository,
  UuidValue id, {
  int maxAttempts = 3,
}) async {
  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    try {
      return await repository.getById(id);
    } on RepositoryException catch (e) {
      // Retry on transient errors
      if (e.type == RepositoryExceptionType.timeout ||
          e.type == RepositoryExceptionType.connection) {
        if (attempt == maxAttempts - 1) {
          print('   ✗ Max retry attempts reached');
          rethrow;
        }

        // Exponential backoff
        final delay = math.pow(2, attempt).toInt();
        print('   ⟳ Retry attempt ${attempt + 1} after ${delay}s delay...');
        await Future<void>.delayed(Duration(seconds: delay));
        continue;
      }

      // Don't retry on non-transient errors
      rethrow;
    }
  }

  throw StateError('Unreachable');
}

/// Demonstrates graceful degradation pattern.
Future<User?> findUserSafely(
  UserRestRepository repository,
  UuidValue id,
) async {
  try {
    return await repository.getById(id);
  } on RepositoryException catch (e) {
    // Return null for not found
    if (e.type == RepositoryExceptionType.notFound) {
      return null;
    }

    // Log error and return null for other errors
    print('   ⚠ Error fetching user: ${e.message}');
    return null;
  }
}

/// Demonstrates comprehensive error handling patterns.
Future<void> demonstrateErrorPatterns(UserRestRepository repository) async {
  print('=== Error Handling Patterns ===\n');

  // Create a test user
  final user = User(
    firstName: 'John',
    lastName: 'Doe',
    email: 'john.doe@example.com',
  );
  await repository.save(user);
  print('Test user created: ${user.id}\n');

  // Pattern 1: Specific error type handling
  print('1. Specific Error Type Handling');
  try {
    final retrieved = await repository.getById(user.id);
    print('   ✓ User found: ${retrieved.fullName}');
  } on RepositoryException catch (e) {
    switch (e.type) {
      case RepositoryExceptionType.notFound:
        print('   User not found, creating new one...');
      case RepositoryExceptionType.connection:
        print('   Connection error, will retry later');
      case RepositoryExceptionType.timeout:
        print('   Request timed out, retrying...');
      case RepositoryExceptionType.duplicate:
        print('   Duplicate detected, using existing');
      case RepositoryExceptionType.unknown:
        print('   Unknown error: ${e.message}');
      case RepositoryExceptionType.constraint:
        print('   Constraint violation: ${e.message}');
    }
  }
  print('');

  // Pattern 2: Retry with exponential backoff
  print('2. Retry with Exponential Backoff');
  try {
    final retrieved = await getUserWithRetry(repository, user.id);
    print('   ✓ User retrieved: ${retrieved?.fullName}');
  } on RepositoryException catch (e) {
    print('   ✗ Failed after retries: ${e.message}');
  }
  print('');

  // Pattern 3: Graceful degradation
  print('3. Graceful Degradation');
  final result = await findUserSafely(repository, user.id);
  if (result != null) {
    print('   ✓ User found: ${result.fullName}');
  } else {
    print('   ⚠ User not found or error occurred, using default');
  }
  print('');

  // Pattern 4: Error context and logging
  print('4. Error Context and Logging');
  try {
    await repository.getById(UuidValue.generate());
  } on RepositoryException catch (e, stackTrace) {
    print('   Error Details:');
    print('   - Type: ${e.type}');
    print('   - Message: ${e.message}');
    if (e.cause != null) {
      print('   - Cause: ${e.cause}');
    }
    print('   - Stack trace available: ${stackTrace.toString().isNotEmpty}');
  }
  print('');

  // Clean up
  await repository.deleteById(user.id);
  print('Test user deleted\n');
}

/// Demonstrates validation and defensive programming.
Future<void> demonstrateValidation(UserRestRepository repository) async {
  print('=== Validation and Defensive Programming ===\n');

  print('1. Input Validation');
  try {
    // Validate before making repository call
    const email = 'invalid-email';
    if (!email.contains('@')) {
      print('   ✓ Caught invalid email before API call');
    } else {
      final user = User(
        firstName: 'Test',
        lastName: 'User',
        email: email,
      );
      await repository.save(user);
    }
  } catch (e) {
    print('   ✗ Validation failed: $e');
  }
  print('');

  print('2. Null Safety');
  User? nullableUser;
  try {
    nullableUser = await findUserSafely(
      repository,
      UuidValue.generate(),
    );
    if (nullableUser != null) {
      print('   User: ${nullableUser.fullName}');
    } else {
      print('   ✓ Safely handled null result');
    }
  } catch (e) {
    print('   ✗ Error: $e');
  }
  print('');
}

Future<void> main() async {
  print('=== Error Handling Example ===\n');

  final connection = RestConnection(
    baseUrl: 'http://localhost:8080',
  );

  final repository = UserRestRepository(connection);

  try {
    await demonstrateExceptionTypes(repository);
    await demonstrateErrorPatterns(repository);
    await demonstrateValidation(repository);

    print('=== Example completed successfully! ===');
  } catch (e) {
    print('\n✗ Unexpected error: $e');
  } finally {
    connection.dispose();
    print('\nConnection closed.');
  }

  print('\n=== Best Practices ===');
  print('1. Handle specific exception types appropriately');
  print('2. Use retry strategies for transient errors');
  print('3. Implement graceful degradation for non-critical operations');
  print('4. Log errors with context for debugging');
  print('5. Validate input before making API calls');
  print('6. Use null safety patterns for optional results');
}
