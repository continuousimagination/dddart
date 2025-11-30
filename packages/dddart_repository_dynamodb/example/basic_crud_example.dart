// ignore_for_file: avoid_print

import 'package:dddart/dddart.dart';
import 'package:dddart_repository_dynamodb/dddart_repository_dynamodb.dart';
import 'lib/domain/user.dart';

/// Basic CRUD example demonstrating DynamoDB repository usage.
///
/// This example shows:
/// - Creating a DynamoDB connection
/// - Creating and saving aggregates
/// - Retrieving aggregates by ID
/// - Updating aggregates
/// - Deleting aggregates
/// - Basic error handling
///
/// Prerequisites:
/// - DynamoDB Local running on localhost:8000
/// - Or update connection parameters below
/// - Table 'users' must exist (see table_creation_example.dart)
Future<void> main() async {
  print('=== Basic CRUD Example ===\n');

  // Step 1: Create connection to DynamoDB Local
  print('1. Creating DynamoDB connection...');
  final connection = DynamoConnection.local();
  print('   ✓ Connection created (DynamoDB Local on port 8000)\n');

  // Step 2: Create repository
  print('2. Creating repository...');
  final userRepo = UserDynamoRepository(connection);
  print('   ✓ Repository created\n');

  try {
    // Step 3: Create and save a new user
    print('3. Creating and saving a new user...');
    final user = User(
      firstName: 'John',
      lastName: 'Doe',
      email: 'john.doe@example.com',
    );
    print('   User ID: ${user.id}');
    print('   Name: ${user.fullName}');
    print('   Email: ${user.email}');

    await userRepo.save(user);
    print('   ✓ User saved to DynamoDB\n');

    // Step 4: Retrieve the user by ID
    print('4. Retrieving user by ID...');
    final retrievedUser = await userRepo.getById(user.id);
    print('   ✓ User retrieved');
    print('   Name: ${retrievedUser.fullName}');
    print('   Email: ${retrievedUser.email}\n');

    // Step 5: Update the user
    print('5. Updating user...');
    final updatedUser = User(
      id: user.id,
      firstName: 'John',
      lastName: 'Smith',
      email: 'john.smith@example.com',
    );
    await userRepo.save(updatedUser);
    print('   ✓ User updated\n');

    // Step 6: Verify the update
    print('6. Verifying update...');
    final verifiedUser = await userRepo.getById(user.id);
    print('   ✓ Update verified');
    print('   Name: ${verifiedUser.fullName}');
    print('   Email: ${verifiedUser.email}\n');

    // Step 7: Delete the user
    print('7. Deleting user...');
    await userRepo.deleteById(user.id);
    print('   ✓ User deleted\n');

    // Step 8: Verify deletion
    print('8. Verifying deletion...');
    try {
      await userRepo.getById(user.id);
      print('   ✗ User still exists (unexpected)');
    } on RepositoryException catch (e) {
      if (e.type == RepositoryExceptionType.notFound) {
        print('   ✓ User not found (expected)');
      } else {
        print('   ✗ Unexpected error: ${e.message}');
      }
    }

    print('\n=== Example completed successfully ===');
  } catch (e, stackTrace) {
    print('\n✗ Error: $e');
    print('Stack trace: $stackTrace');
  } finally {
    // Step 9: Clean up connection
    print('\n9. Disposing connection...');
    connection.dispose();
    print('   ✓ Connection disposed');
  }
}
