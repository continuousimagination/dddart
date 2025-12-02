/// Basic CRUD operations example for dddart_repository_rest.
///
/// This example demonstrates:
/// - Creating a REST connection
/// - Performing basic CRUD operations (Create, Read, Update, Delete)
/// - Handling repository exceptions
///
/// To run this example, you need a REST API server running at
/// http://localhost:8080 with a /users endpoint.
library;

import 'package:dddart/dddart.dart';
import 'package:dddart_repository_rest/dddart_repository_rest.dart';

import 'lib/user.dart';

Future<void> main() async {
  // Create a REST connection to the API server
  final connection = RestConnection(
    baseUrl: 'http://localhost:8080',
  );

  // Create a repository instance
  final userRepository = UserRestRepository(connection);

  print('=== Basic CRUD Operations Example ===\n');

  try {
    // CREATE: Save a new user
    print('1. Creating a new user...');
    final newUser = User(
      firstName: 'John',
      lastName: 'Doe',
      email: 'john.doe@example.com',
    );

    await userRepository.save(newUser);
    print('   ✓ User created with ID: ${newUser.id}');
    print('   Name: ${newUser.fullName}');
    print('   Email: ${newUser.email}\n');

    // READ: Retrieve the user by ID
    print('2. Retrieving user by ID...');
    final retrievedUser = await userRepository.getById(newUser.id);
    print('   ✓ User retrieved: ${retrievedUser.fullName}');
    print('   Email: ${retrievedUser.email}\n');

    // UPDATE: Modify and save the user
    print('3. Updating user...');
    final updatedUser = User(
      id: retrievedUser.id,
      firstName: retrievedUser.firstName,
      lastName: 'Smith', // Changed last name
      email: 'john.smith@example.com', // Changed email
      createdAt: retrievedUser.createdAt,
      updatedAt: DateTime.now(),
    );

    await userRepository.save(updatedUser);
    print('   ✓ User updated');
    print('   New name: ${updatedUser.fullName}');
    print('   New email: ${updatedUser.email}\n');

    // Verify the update
    print('4. Verifying update...');
    final verifiedUser = await userRepository.getById(updatedUser.id);
    print('   ✓ Verified: ${verifiedUser.fullName}');
    print('   Email: ${verifiedUser.email}\n');

    // DELETE: Remove the user
    print('5. Deleting user...');
    await userRepository.deleteById(updatedUser.id);
    print('   ✓ User deleted\n');

    // Verify deletion
    print('6. Verifying deletion...');
    try {
      await userRepository.getById(updatedUser.id);
      print('   ✗ Error: User still exists!');
    } on RepositoryException catch (e) {
      if (e.type == RepositoryExceptionType.notFound) {
        print('   ✓ Confirmed: User no longer exists');
      } else {
        print('   ✗ Unexpected error: ${e.message}');
      }
    }

    print('\n=== Example completed successfully! ===');
  } on RepositoryException catch (e) {
    print('\n✗ Repository error: ${e.message}');
    print('  Type: ${e.type}');
    if (e.cause != null) {
      print('  Cause: ${e.cause}');
    }
  } catch (e) {
    print('\n✗ Unexpected error: $e');
  } finally {
    // Clean up the connection
    connection.dispose();
    print('\nConnection closed.');
  }
}
