/// Custom repository example demonstrating custom query methods.
///
/// This example shows:
/// - Defining a custom repository interface
/// - Extending the generated abstract base class
/// - Implementing custom SQL queries
/// - Using protected connection and serializer members
/// - Domain-specific query methods
library;

import 'package:dddart/dddart.dart';
import 'package:dddart_repository_sqlite/dddart_repository_sqlite.dart';

import 'lib/custom_user.dart';
import 'lib/custom_user_repository_impl.dart';

Future<void> main() async {
  final connection = SqliteConnection.memory();

  try {
    await connection.open();
    print('✓ Database connection opened');

    // Use the custom repository implementation
    final repository = CustomUserRepositoryImpl(connection);

    await repository.createTables();
    print('✓ Database tables created');

    // Create some test users
    print('\n--- Creating Test Users ---');
    final users = [
      CustomUser(
        name: 'Alice Johnson',
        email: 'alice@example.com',
        isActive: true,
        registeredAt: DateTime(2024, 1, 15),
      ),
      CustomUser(
        name: 'Bob Smith',
        email: 'bob@example.com',
        isActive: true,
        registeredAt: DateTime(2024, 3, 20),
      ),
      CustomUser(
        name: 'Charlie Brown',
        email: 'charlie@test.com',
        isActive: false,
        registeredAt: DateTime(2024, 2, 10),
      ),
      CustomUser(
        name: 'Diana Prince',
        email: 'diana@example.com',
        isActive: true,
        registeredAt: DateTime(2024, 4, 5),
      ),
      CustomUser(
        name: 'Eve Adams',
        email: 'eve@test.com',
        isActive: false,
        registeredAt: DateTime(2024, 1, 25),
      ),
    ];

    for (final user in users) {
      await repository.save(user);
      print('Created: ${user.name} (${user.email}) - '
          'Active: ${user.isActive}');
    }

    // Use custom query: Find active users
    print('\n--- Custom Query: Find Active Users ---');
    final activeUsers = await repository.findActiveUsers();
    print('Found ${activeUsers.length} active users:');
    for (final user in activeUsers) {
      print('  - ${user.name} (${user.email})');
    }

    // Use custom query: Find by email pattern
    print('\n--- Custom Query: Find by Email Pattern ---');
    final exampleUsers = await repository.findByEmailPattern('example.com');
    print('Found ${exampleUsers.length} users with @example.com:');
    for (final user in exampleUsers) {
      print('  - ${user.name} (${user.email})');
    }

    // Use custom query: Count users
    print('\n--- Custom Query: Count Users ---');
    final count = await repository.countUsers();
    print('Total users in database: $count');

    // Use custom query: Find registered after date
    print('\n--- Custom Query: Find Registered After Date ---');
    final recentUsers =
        await repository.findRegisteredAfter(DateTime(2024, 3, 1));
    print('Found ${recentUsers.length} users registered after March 1, 2024:');
    for (final user in recentUsers) {
      print('  - ${user.name} registered on '
          '${user.registeredAt.toIso8601String().split('T')[0]}');
    }

    // Standard CRUD operations still work
    print('\n--- Standard CRUD Operations ---');
    final userId = users.first.id;
    final retrievedUser = await repository.getById(userId);
    print('Retrieved user by ID: ${retrievedUser.name}');

    await repository.deleteById(userId);
    print('Deleted user: ${users.first.name}');

    final remainingCount = await repository.countUsers();
    print('Remaining users: $remainingCount');

    print('\n✓ Custom repository example completed successfully!');
  } catch (e, stackTrace) {
    print('✗ Error: $e');
    print(stackTrace);
  } finally {
    await connection.close();
    print('\n✓ Database connection closed');
  }
}
