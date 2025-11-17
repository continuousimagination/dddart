import 'package:dddart/dddart.dart';
import 'package:dddart_rest/dddart_rest.dart';
import 'lib/models/user.dart';
import 'lib/models/address.dart';
import 'lib/models/profile.dart';
import 'lib/serializers/user_serializer.dart';
import 'lib/handlers/query_handlers.dart';
import 'lib/handlers/exception_handlers.dart';
import 'lib/exceptions/user_exceptions.dart';

/// Example HTTP CRUD API application
///
/// This example demonstrates:
/// - Defining an aggregate root with child entities and value objects
/// - Creating a JSON serializer
/// - Setting up an HTTP server with CRUD endpoints
/// - Registering custom query handlers
/// - Registering custom exception handlers
/// - Configuring pagination
void main() async {
  print('Starting HTTP CRUD API Example...\n');

  // Create repository with some sample data
  final repository = InMemoryRepository<User>();
  await _seedSampleData(repository);

  // Create serializer
  final serializer = UserSerializer();

  // Create HTTP server
  final server = HttpServer(port: 8080);

  // Register CRUD resource with all features
  server.registerResource(
    CrudResource<User>(
      path: '/users',
      repository: repository,
      serializers: {
        'application/json': serializer,
      },
      queryHandlers: {
        'firstName': firstNameQueryHandler,
        'email': emailQueryHandler,
      },
      customExceptionHandlers: {
        InvalidEmailException: handleInvalidEmailException,
        DuplicateEmailException: handleDuplicateEmailException,
      },
      defaultSkip: 0,
      defaultTake: 10,
      maxTake: 50,
    ),
  );

  // Start server
  await server.start();

  print('Server running on http://localhost:8080');
  print('\nAvailable endpoints:');
  print('  GET    /users           - List all users (paginated)');
  print('  GET    /users/:id       - Get user by ID');
  print('  GET    /users?firstName=John - Filter by first name');
  print('  GET    /users?email=john@example.com - Filter by email');
  print('  POST   /users           - Create new user');
  print('  PUT    /users/:id       - Update user');
  print('  DELETE /users/:id       - Delete user');
  print('\nPagination parameters:');
  print('  ?skip=N&take=M          - Skip N items, return M items');
  print('\nPress Ctrl+C to stop the server');
}

/// Seeds the repository with sample data for demonstration
///
/// SAMPLE DATA SEEDING:
/// This function populates the repository with test data so you can immediately
/// try out the API without having to create users first.
///
/// DATA DESIGN:
/// The sample data is designed to demonstrate various features:
///
/// 1. QUERY HANDLER TESTING:
///    - Two users named "John" (Doe and Anderson) to test firstName filter
///    - Each user has unique email to test email filter
///    - GET /users?firstName=John should return 2 users
///    - GET /users?email=john.doe@example.com should return 1 user
///
/// 2. AGGREGATE STRUCTURE:
///    - All users have Address (required value object)
///    - Some users have Profile (optional child entity)
///    - Bob and John Anderson have no profile to show optional fields work
///
/// 3. PAGINATION TESTING:
///    - 5 users total allows testing pagination
///    - Default take=10 returns all 5
///    - GET /users?skip=2&take=2 returns users 3-4
///    - GET /users?skip=10 returns empty array
///
/// 4. VARIED DATA:
///    - Different cities/states for realistic data
///    - Different bio lengths and content
///    - Mix of users with and without profiles
///
/// PRODUCTION CONSIDERATIONS:
/// - In production, use database migrations or seed scripts
/// - Don't seed data in application startup
/// - Use environment variables to control seeding (dev vs prod)
/// - Consider using factories or builders for test data
Future<void> _seedSampleData(Repository<User> repository) async {
  final users = [
    // User 1: John Doe - has profile, used for firstName query testing
    User(
      firstName: 'John',
      lastName: 'Doe',
      email: 'john.doe@example.com',
      address: const Address(
        street: '123 Main St',
        city: 'Springfield',
        state: 'IL',
        zipCode: '62701',
        country: 'USA',
      ),
      profile: Profile(
        bio: 'Software developer and tech enthusiast',
        avatarUrl: 'https://example.com/avatars/john.jpg',
        phoneNumber: '+1-555-0101',
      ),
    ),

    // User 2: Jane Smith - has profile, different from John for testing
    User(
      firstName: 'Jane',
      lastName: 'Smith',
      email: 'jane.smith@example.com',
      address: const Address(
        street: '456 Oak Ave',
        city: 'Portland',
        state: 'OR',
        zipCode: '97201',
        country: 'USA',
      ),
      profile: Profile(
        bio: 'Designer and creative professional',
        avatarUrl: 'https://example.com/avatars/jane.jpg',
        phoneNumber: '+1-555-0102',
      ),
    ),

    // User 3: Bob Johnson - NO profile (demonstrates optional child entity)
    User(
      firstName: 'Bob',
      lastName: 'Johnson',
      email: 'bob.johnson@example.com',
      address: const Address(
        street: '789 Pine Rd',
        city: 'Austin',
        state: 'TX',
        zipCode: '78701',
        country: 'USA',
      ),
      // profile is null - demonstrates optional child entity
    ),

    // User 4: Alice Williams - has profile, different location
    User(
      firstName: 'Alice',
      lastName: 'Williams',
      email: 'alice.williams@example.com',
      address: const Address(
        street: '321 Elm St',
        city: 'Seattle',
        state: 'WA',
        zipCode: '98101',
        country: 'USA',
      ),
      profile: Profile(
        bio: 'Product manager and strategist',
        avatarUrl: 'https://example.com/avatars/alice.jpg',
        phoneNumber: '+1-555-0104',
      ),
    ),

    // User 5: John Anderson - NO profile, second "John" for firstName query testing
    // This demonstrates that firstName query should return multiple results
    User(
      firstName: 'John',
      lastName: 'Anderson',
      email: 'john.anderson@example.com',
      address: const Address(
        street: '654 Maple Dr',
        city: 'Boston',
        state: 'MA',
        zipCode: '02101',
        country: 'USA',
      ),
      // profile is null - demonstrates optional child entity
    ),
  ];

  // Save each user to the repository
  // In production, this might be a batch operation for better performance
  for (final user in users) {
    await repository.save(user);
  }

  print('Seeded ${users.length} sample users');
  print('  - 2 users named "John" (for firstName query testing)');
  print(
      '  - 3 users with profiles, 2 without (demonstrates optional child entity)');
  print('  - All users have addresses (demonstrates required value object)');
}
