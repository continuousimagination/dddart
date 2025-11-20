// ignore_for_file: avoid_print

import 'package:dddart/dddart.dart';
import 'package:dddart_repository_mongodb/dddart_repository_mongodb.dart';
import 'lib/domain/user_with_custom_repo.dart';

/// Repository swapping example demonstrating implementation independence.
///
/// This example shows:
/// - Defining a custom repository interface
/// - MongoDB implementation for production
/// - InMemoryRepository for testing
/// - Swapping implementations without changing business logic
///
/// This pattern enables:
/// - Fast unit tests without database
/// - Easy mocking for integration tests
/// - Flexibility to change persistence layer
///
/// Prerequisites:
/// - MongoDB running on localhost:27017 for production example
Future<void> main() async {
  print('=== Repository Swapping Example ===\n');

  await _demonstrateInMemoryRepository();
  print("");

  await _demonstrateMongoRepository();
  print("");

  await _demonstrateBusinessLogicWithSwappableRepo();
  print("");

  print('=== Example completed successfully ===');
}

/// Demonstrates using InMemoryRepository for testing.
Future<void> _demonstrateInMemoryRepository() async {
  print('1. Using InMemoryRepository (for testing)...');

  // Create in-memory repository - no database needed!
  final userRepo = InMemoryRepository<UserWithCustomRepo>();

  // Create and save users
  final user1 = UserWithCustomRepo(
    firstName: 'Alice',
    lastName: 'Johnson',
    email: 'alice@example.com',
  );
  final user2 = UserWithCustomRepo(
    firstName: 'Bob',
    lastName: 'Johnson',
    email: 'bob@example.com',
  );

  await userRepo.save(user1);
  await userRepo.save(user2);
  print('   ✓ Saved 2 users to in-memory repository');

  // Retrieve user
  final retrieved = await userRepo.getById(user1.id);
  print('   ✓ Retrieved: ${retrieved.fullName}');

  // Delete user
  await userRepo.deleteById(user2.id);
  print('   ✓ Deleted: ${user2.fullName}');

  // Verify deletion
  try {
    await userRepo.getById(user2.id);
    print('   ✗ User should have been deleted');
  } on RepositoryException catch (e) {
    if (e.type == RepositoryExceptionType.notFound) {
      print('   ✓ Confirmed deletion');
    }
  }

  print('   ✓ In-memory repository works perfectly for testing!');
}

/// Demonstrates using MongoDB repository for production.
Future<void> _demonstrateMongoRepository() async {
  print('2. Using MongoDB repository (for production)...');

  final connection = MongoConnection(
    host: 'localhost',
    port: 27017,
    databaseName: 'dddart_example',
  );

  try {
    await connection.open();

    // Create MongoDB repository
    final userRepo = UserWithCustomRepoMongoRepository(connection.database);

    // Create and save users
    final user1 = UserWithCustomRepo(
      firstName: 'Charlie',
      lastName: 'Brown',
      email: 'charlie@example.com',
    );
    final user2 = UserWithCustomRepo(
      firstName: 'Diana',
      lastName: 'Brown',
      email: 'diana@example.com',
    );

    await userRepo.save(user1);
    await userRepo.save(user2);
    print('   ✓ Saved 2 users to MongoDB');

    // Use custom query method
    final brownUsers = await userRepo.findByLastName('Brown');
    print('   ✓ Found ${brownUsers.length} users with last name "Brown"');

    // Clean up
    await userRepo.deleteById(user1.id);
    await userRepo.deleteById(user2.id);
    print('   ✓ Cleaned up test data');

    print('   ✓ MongoDB repository provides persistence and custom queries!');
  } finally {
    await connection.close();
  }
}

/// Demonstrates business logic that works with any repository implementation.
Future<void> _demonstrateBusinessLogicWithSwappableRepo() async {
  print('3. Business logic with swappable repositories...');

  // Test with in-memory repository
  print('\n   Testing with InMemoryRepository:');
  final inMemoryRepo = InMemoryRepository<UserWithCustomRepo>();
  await _runBusinessLogic(inMemoryRepo);

  // Test with MongoDB repository
  print('\n   Testing with MongoDB repository:');
  final connection = MongoConnection(
    host: 'localhost',
    port: 27017,
    databaseName: 'dddart_example',
  );

  try {
    await connection.open();
    final mongoRepo = UserWithCustomRepoMongoRepository(connection.database);
    await _runBusinessLogic(mongoRepo);
  } finally {
    await connection.close();
  }

  print('\n   ✓ Same business logic works with both implementations!');
}

/// Business logic that depends on Repository interface, not implementation.
///
/// This function works with ANY implementation of Repository<UserWithCustomRepo>:
/// - InMemoryRepository for fast unit tests
/// - UserWithCustomRepoMongoRepository for production
/// - MockRepository for integration tests
/// - Future: RestRepository, PostgresRepository, etc.
Future<void> _runBusinessLogic(
  Repository<UserWithCustomRepo> userRepo,
) async {
  // Create user
  final user = UserWithCustomRepo(
    firstName: 'Test',
    lastName: 'User',
    email: 'test@example.com',
  );

  // Save user
  await userRepo.save(user);
  print('     ✓ Created user: ${user.fullName}');

  // Retrieve user
  final retrieved = await userRepo.getById(user.id);
  print('     ✓ Retrieved user: ${retrieved.fullName}');

  // Update user
  final updated = UserWithCustomRepo(
    id: user.id,
    firstName: 'Updated',
    lastName: 'User',
    email: 'updated@example.com',
  );
  await userRepo.save(updated);
  print('     ✓ Updated user');

  // Delete user
  await userRepo.deleteById(user.id);
  print('     ✓ Deleted user');
}

/*
Key Benefits of Repository Swapping:

1. Fast Unit Tests:
   - Use InMemoryRepository for instant tests
   - No database setup or teardown needed
   - Tests run in milliseconds

2. Flexible Testing:
   - Mock repositories for specific test scenarios
   - Test error handling without breaking real database
   - Parallel test execution without conflicts

3. Implementation Independence:
   - Business logic doesn't know about MongoDB
   - Easy to switch to different database
   - Can use different repos in different environments

4. Development Workflow:
   - Develop business logic with in-memory repo
   - Test with real database when needed
   - Deploy with production database

Example Test:
```dart
void main() {
  test('user creation workflow', () async {
    // Fast test with in-memory repository
    final repo = InMemoryRepository<UserWithCustomRepo>();
    
    final user = UserWithCustomRepo(
      firstName: 'Test',
      lastName: 'User',
      email: 'test@example.com',
    );
    
    await repo.save(user);
    final retrieved = await repo.getById(user.id);
    
    expect(retrieved.fullName, equals('Test User'));
  });
}
```
*/
