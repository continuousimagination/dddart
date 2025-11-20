// ignore_for_file: avoid_print

import 'package:dddart_repository_mongodb/dddart_repository_mongodb.dart';
import 'lib/domain/user_with_custom_repo.dart';

/// Custom interface example demonstrating extended repository functionality.
///
/// This example shows:
/// - Defining a custom repository interface with domain-specific methods
/// - Using the generated abstract base class
/// - Implementing custom query methods using MongoDB queries
/// - Using both generated CRUD methods and custom query methods
///
/// Prerequisites:
/// - MongoDB running on localhost:27017
/// - Or update connection parameters below
Future<void> main() async {
  print('=== Custom Interface Example ===\n');

  // Step 1: Create and open connection
  print('1. Connecting to MongoDB...');
  final connection = MongoConnection(
    host: 'localhost',
    port: 27017,
    databaseName: 'dddart_example',
  );

  try {
    await connection.open();
    print('   ✓ Connected to MongoDB\n');

    // Step 2: Create repository with custom implementation
    print('2. Creating custom repository...');
    final userRepo = UserWithCustomRepoMongoRepository(connection.database);
    print('   ✓ Custom repository created\n');

    // Step 3: Create and save multiple users
    print('3. Creating and saving multiple users...');
    final users = [
      UserWithCustomRepo(
        firstName: 'John',
        lastName: 'Doe',
        email: 'john.doe@example.com',
      ),
      UserWithCustomRepo(
        firstName: 'Jane',
        lastName: 'Doe',
        email: 'jane.doe@example.com',
      ),
      UserWithCustomRepo(
        firstName: 'Bob',
        lastName: 'Smith',
        email: 'bob.smith@example.com',
      ),
    ];

    for (final user in users) {
      await userRepo.save(user);
      print('   ✓ Saved: ${user.fullName} (${user.email})');
    }
    print('');

    // Step 4: Use custom query method - findByEmail
    print('4. Finding user by email (custom method)...');
    final foundByEmail = await userRepo.findByEmail('jane.doe@example.com');
    if (foundByEmail != null) {
      print('   ✓ Found user: ${foundByEmail.fullName}');
      print('   Email: ${foundByEmail.email}');
    } else {
      print('   ✗ User not found');
    }
    print('');

    // Step 5: Use custom query method - findByLastName
    print('5. Finding users by last name (custom method)...');
    final doeUsers = await userRepo.findByLastName('Doe');
    print('   ✓ Found ${doeUsers.length} users with last name "Doe":');
    for (final user in doeUsers) {
      print('     - ${user.fullName} (${user.email})');
    }
    print("");

    // Step 6: Use generated CRUD method - getById
    print('6. Retrieving user by ID (generated method)...');
    final userById = await userRepo.getById(users[0].id);
    print('   ✓ Retrieved: ${userById.fullName}');
    print("");

    // Step 7: Test custom query with no results
    print('7. Testing custom query with no results...');
    final notFound = await userRepo.findByEmail('nonexistent@example.com');
    if (notFound == null) {
      print('   ✓ Correctly returned null for non-existent email');
    } else {
      print('   ✗ Unexpected result');
    }
    print("");

    // Step 8: Clean up - delete all test users
    print('8. Cleaning up test data...');
    for (final user in users) {
      await userRepo.deleteById(user.id);
    }
    print('   ✓ All test users deleted');

    print('\n=== Example completed successfully ===');
  } catch (e, stackTrace) {
    print('\n✗ Error: $e');
    print('Stack trace: $stackTrace');
  } finally {
    // Step 9: Close connection
    print('\n9. Closing connection...');
    await connection.close();
    print('   ✓ Connection closed');
  }
}
