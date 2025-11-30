// ignore_for_file: avoid_print

import 'package:dddart/dddart.dart';
import 'package:dddart_repository_dynamodb/dddart_repository_dynamodb.dart';
import 'lib/domain/user.dart';

/// Error handling example demonstrating exception handling patterns.
///
/// This example shows:
/// - Handling RepositoryException.notFound
/// - Handling connection errors
/// - Proper try-catch patterns
/// - Error type checking and recovery strategies
/// - Graceful degradation
///
/// Prerequisites:
/// - DynamoDB Local running on localhost:8000
/// - Table 'users' must exist
Future<void> main() async {
  print('=== Error Handling Example ===\n');

  // Step 1: Create connection
  print('1. Creating DynamoDB connection...');
  final connection = DynamoConnection.local();
  print('   ✓ Connection created\n');

  final userRepo = UserDynamoRepository(connection);

  try {
    // Step 2: Handle not found errors
    print('2. Handling not found errors...');
    final nonExistentId = UuidValue.generate();
    try {
      await userRepo.getById(nonExistentId);
      print('   ✗ Should have thrown RepositoryException');
    } on RepositoryException catch (e) {
      if (e.type == RepositoryExceptionType.notFound) {
        print('   ✓ Correctly caught notFound exception');
        print('   Message: ${e.message}');
      } else {
        print('   ✗ Unexpected exception type: ${e.type}');
      }
    }
    print('');

    // Step 3: Graceful handling with null return
    print('3. Graceful handling with null return...');
    final user = await _getUserOrNull(userRepo, nonExistentId);
    if (user == null) {
      print('   ✓ Gracefully handled missing user');
    }
    print('');

    // Step 4: Retry logic for transient errors
    print('4. Demonstrating retry logic pattern...');
    final testUser = User(
      firstName: 'Test',
      lastName: 'User',
      email: 'test@example.com',
    );
    await userRepo.save(testUser);
    print('   ✓ Saved test user');

    final retrieved = await _getUserWithRetry(userRepo, testUser.id);
    print('   ✓ Retrieved user with retry logic: ${retrieved.fullName}');

    await userRepo.deleteById(testUser.id);
    print('   ✓ Cleaned up test user');
    print('');

    // Step 5: Handle table not found
    print('5. Handling table not found errors...');
    final badConnection = DynamoConnection.local();
    final badRepo = UserDynamoRepository(badConnection);

    try {
      // Try to access non-existent table by using wrong table name
      await badRepo.getById(UuidValue.generate());
    } on RepositoryException catch (e) {
      if (e.type == RepositoryExceptionType.unknown) {
        print('   ✓ Caught unknown exception (likely table not found)');
        print('   Message: ${e.message}');
        if (e.cause != null) {
          print('   Cause: ${e.cause}');
        }
      }
    } finally {
      badConnection.dispose();
    }
    print('');

    // Step 6: Show error handling patterns
    print('6. Error handling patterns:');
    print('   • Use try-catch for expected errors');
    print('   • Check RepositoryExceptionType for specific handling');
    print('   • Implement retry logic for transient errors');
    print('   • Return null for optional lookups');
    print('   • Log errors with context');
    print('   • Preserve original exception as cause');
    print('   • Clean up resources in finally blocks\n');

    // Step 7: Show exception types
    print('7. Available RepositoryException types:');
    print('   • notFound - Item or table not found');
    print('   • duplicate - Conditional check failed');
    print('   • connection - Network/connectivity issues');
    print('   • timeout - Operation exceeded time limit');
    print('   • unknown - Unexpected errors\n');

    print('=== Example completed successfully ===');
  } catch (e, stackTrace) {
    print('\n✗ Error: $e');
    print('Stack trace: $stackTrace');
  } finally {
    // Step 8: Clean up connection
    print('\n8. Disposing connection...');
    connection.dispose();
    print('   ✓ Connection disposed');
  }
}

/// Gets a user by ID, returning null if not found.
Future<User?> _getUserOrNull(
  UserDynamoRepository repo,
  UuidValue id,
) async {
  try {
    return await repo.getById(id);
  } on RepositoryException catch (e) {
    if (e.type == RepositoryExceptionType.notFound) {
      return null;
    }
    rethrow;
  }
}

/// Gets a user with retry logic for transient errors.
Future<User> _getUserWithRetry(
  UserDynamoRepository repo,
  UuidValue id, {
  int maxRetries = 3,
}) async {
  for (var attempt = 0; attempt < maxRetries; attempt++) {
    try {
      return await repo.getById(id);
    } on RepositoryException catch (e) {
      if (e.type == RepositoryExceptionType.timeout ||
          e.type == RepositoryExceptionType.connection) {
        if (attempt == maxRetries - 1) rethrow;
        await Future<void>.delayed(Duration(seconds: attempt + 1));
        continue;
      }
      rethrow;
    }
  }
  throw StateError('Should not reach here');
}
