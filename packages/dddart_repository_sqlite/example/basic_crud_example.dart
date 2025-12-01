/// Basic CRUD example demonstrating save, retrieve, and delete operations.
///
/// This example shows:
/// - Creating a SQLite connection (in-memory for demo)
/// - Creating database tables
/// - Saving a new aggregate
/// - Retrieving an aggregate by ID
/// - Updating an existing aggregate
/// - Deleting an aggregate
/// - Proper connection lifecycle management
library;

import 'package:dddart/dddart.dart';
import 'package:dddart_repository_sqlite/dddart_repository_sqlite.dart';

import 'lib/simple_user.dart';

Future<void> main() async {
  // Create an in-memory SQLite connection for this example
  // For persistent storage, use: SqliteConnection.file('path/to/database.db')
  final connection = SqliteConnection.memory();

  try {
    // Open the database connection
    await connection.open();
    print('✓ Database connection opened');

    // Create the repository
    final repository = SimpleUserSqliteRepository(connection);

    // Create the database tables
    await repository.createTables();
    print('✓ Database tables created');

    // Create a new user
    final user = SimpleUser(
      name: 'Alice Johnson',
      email: 'alice@example.com',
      age: 28,
      isActive: true,
    );
    print('\n--- Creating User ---');
    print('ID: ${user.id}');
    print('Name: ${user.name}');
    print('Email: ${user.email}');
    print('Age: ${user.age}');
    print('Active: ${user.isActive}');

    // Save the user to the database
    await repository.save(user);
    print('✓ User saved to database');

    // Retrieve the user by ID
    print('\n--- Retrieving User ---');
    final retrievedUser = await repository.getById(user.id);
    print('ID: ${retrievedUser.id}');
    print('Name: ${retrievedUser.name}');
    print('Email: ${retrievedUser.email}');
    print('Age: ${retrievedUser.age}');
    print('Active: ${retrievedUser.isActive}');
    print('Created: ${retrievedUser.createdAt}');
    print('Updated: ${retrievedUser.updatedAt}');

    // Update the user
    print('\n--- Updating User ---');
    final updatedUser = SimpleUser(
      id: retrievedUser.id,
      name: retrievedUser.name,
      email: 'alice.johnson@example.com', // Updated email
      age: 29, // Updated age
      isActive: retrievedUser.isActive,
      createdAt: retrievedUser.createdAt,
      updatedAt: DateTime.now(),
    );
    await repository.save(updatedUser);
    print('✓ User updated');

    // Retrieve again to verify update
    final verifyUser = await repository.getById(user.id);
    print('Updated Email: ${verifyUser.email}');
    print('Updated Age: ${verifyUser.age}');

    // Delete the user
    print('\n--- Deleting User ---');
    await repository.deleteById(user.id);
    print('✓ User deleted from database');

    // Try to retrieve deleted user (should throw exception)
    print('\n--- Verifying Deletion ---');
    try {
      await repository.getById(user.id);
      print('✗ ERROR: User should not exist!');
    } on RepositoryException catch (e) {
      if (e.type == RepositoryExceptionType.notFound) {
        print('✓ User not found (as expected)');
      } else {
        print('✗ Unexpected exception: $e');
      }
    }

    print('\n✓ Basic CRUD example completed successfully!');
  } catch (e, stackTrace) {
    print('✗ Error: $e');
    print(stackTrace);
  } finally {
    // Always close the connection when done
    await connection.close();
    print('\n✓ Database connection closed');
  }
}
