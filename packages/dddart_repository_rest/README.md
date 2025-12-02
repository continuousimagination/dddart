# dddart_repository_rest

REST API-backed repository implementation for DDDart aggregate roots with code generation support.

## Overview

`dddart_repository_rest` provides a code-generated REST repository implementation for DDDart aggregate roots, enabling distributed domain-driven design architectures where aggregates are persisted via HTTP rather than direct database access. This package is ideal for microservices, remote data storage, and client-server architectures.

The package follows the established patterns from other DDDart repository packages (`dddart_repository_mongodb`, `dddart_repository_dynamodb`, `dddart_repository_sqlite`), ensuring consistency across the ecosystem and making it easy to swap implementations.

## Features

- **Code Generation**: Automatically generates REST repository implementations from annotated aggregate root classes
- **JSON Serialization**: Reuses existing `dddart_json` serializers for HTTP request/response bodies
- **Authentication**: Integrates with `dddart_rest_client` for automatic token management and refresh
- **Extensibility**: Generated repositories can be used directly or extended with custom query methods
- **Error Handling**: Comprehensive HTTP status code mapping to `RepositoryException` types
- **Connection Pooling**: Efficient HTTP client reuse across multiple repositories
- **Type Safety**: Compile-time safe code generation with proper error handling

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  dddart: ^0.9.0
  dddart_json: ^0.9.0
  dddart_repository_rest: ^0.1.0
  dddart_rest_client: ^0.1.0

dev_dependencies:
  build_runner: ^2.4.0
```

Then run:

```bash
dart pub get
```

## Quick Start

### 1. Annotate Your Aggregate Root

```dart
import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_repository_rest/dddart_repository_rest.dart';

@Serializable()
@GenerateRestRepository(resourcePath: '/users')
class User extends AggregateRoot {
  User({
    UuidValue? id,
    required this.firstName,
    required this.lastName,
    required this.email,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : super(id: id, createdAt: createdAt, updatedAt: updatedAt);

  final String firstName;
  final String lastName;
  final String email;

  String get fullName => '$firstName $lastName';
}

part 'user.g.dart';
part 'user.rest_repository.g.dart';
```

### 2. Generate Code

Run the build_runner to generate the repository and serializer:

```bash
dart run build_runner build
```

This generates two files:
- `user.g.dart` - JSON serializer (from `dddart_json`)
- `user.rest_repository.g.dart` - REST repository implementation

### 3. Use the Generated Repository

```dart
import 'package:dddart/dddart.dart';
import 'package:dddart_repository_rest/dddart_repository_rest.dart';
import 'user.dart';

Future<void> main() async {
  // Create a REST connection
  final connection = RestConnection(
    baseUrl: 'https://api.example.com',
  );

  // Create repository instance
  final userRepo = UserRestRepository(connection);

  // Create and save a user
  final user = User(
    firstName: 'John',
    lastName: 'Doe',
    email: 'john.doe@example.com',
  );
  await userRepo.save(user);
  print('User created: ${user.id}');

  // Retrieve the user
  final retrieved = await userRepo.getById(user.id);
  print('Retrieved: ${retrieved.fullName}');

  // Update the user
  final updated = User(
    id: retrieved.id,
    firstName: retrieved.firstName,
    lastName: 'Smith',
    email: 'john.smith@example.com',
    createdAt: retrieved.createdAt,
    updatedAt: DateTime.now(),
  );
  await userRepo.save(updated);
  print('User updated');

  // Delete the user
  await userRepo.deleteById(user.id);
  print('User deleted');

  // Clean up
  connection.dispose();
}
```

## RestConnection Configuration

### Basic Connection (No Authentication)

```dart
final connection = RestConnection(
  baseUrl: 'http://localhost:8080',
);
```

### Connection with Authentication

The `RestConnection` integrates with `dddart_rest_client`'s `AuthProvider` for automatic token management:

```dart
import 'package:dddart_rest_client/dddart_rest_client.dart';

// Create an auth provider (example: static token)
class MyAuthProvider implements AuthProvider {
  MyAuthProvider(this._token);
  
  final String _token;
  
  @override
  Future<String> getAccessToken() async => _token;
  
  @override
  Future<void> login() async {
    // Implement login logic
  }
  
  @override
  Future<void> logout() async {
    // Implement logout logic
  }
  
  @override
  Future<bool> isAuthenticated() async => _token.isNotEmpty;
}

// Create connection with authentication
final authProvider = MyAuthProvider('your-api-token');
final connection = RestConnection(
  baseUrl: 'https://api.example.com',
  authProvider: authProvider,
);
```

### Device Flow Authentication

For CLI tools and applications without a browser:

```dart
final authProvider = DeviceFlowAuthProvider(
  authUrl: 'https://api.example.com/auth',
  clientId: 'your-client-id',
  credentialsPath: '.credentials.json',
);

// This will display a verification URL and code
await authProvider.login();

final connection = RestConnection(
  baseUrl: 'https://api.example.com',
  authProvider: authProvider,
);
```

### Connection Lifecycle

**Best Practice**: Create one `RestConnection` per application and share it across all repositories:

```dart
// ✓ Good: Single connection shared across repositories
final connection = RestConnection(baseUrl: 'https://api.example.com');
final userRepo = UserRestRepository(connection);
final orderRepo = OrderRestRepository(connection);
final productRepo = ProductRestRepository(connection);

// Use repositories...

// Clean up when done
connection.dispose();
```

```dart
// ✗ Bad: Creating multiple connections
final userRepo = UserRestRepository(
  RestConnection(baseUrl: 'https://api.example.com'),
);
final orderRepo = OrderRestRepository(
  RestConnection(baseUrl: 'https://api.example.com'),
);
// This creates unnecessary HTTP clients and wastes resources
```

## Annotation Parameters

### `@GenerateRestRepository`

The `@GenerateRestRepository` annotation controls code generation behavior.

#### `resourcePath` (optional)

Specifies the REST API resource path for the aggregate:

```dart
@GenerateRestRepository(resourcePath: '/users')
class User extends AggregateRoot { ... }
```

If omitted, the path is generated from the class name:
- `User` → `/users`
- `OrderItem` → `/order-items`
- `Company` → `/companies`

#### `implements` (optional)

Specifies a custom repository interface for domain-specific query methods:

```dart
// Define custom interface
abstract interface class UserRepository implements Repository<User> {
  Future<User?> findByEmail(String email);
  Future<List<User>> findByLastName(String lastName);
}

// Use in annotation
@Serializable()
@GenerateRestRepository(implements: UserRepository)
class User extends AggregateRoot { ... }
```

When `implements` is specified with custom methods, the generator creates an **abstract base class** that you must extend. See [Custom Repository Interface Pattern](#custom-repository-interface-pattern) below.

## Custom Repository Interface Pattern

For domain-specific queries beyond basic CRUD, define a custom repository interface:

### 1. Define the Interface

```dart
abstract interface class ProductRepository implements Repository<Product> {
  Future<List<Product>> findByCategory(String category);
  Future<List<Product>> findByPriceRange(double minPrice, double maxPrice);
}
```

### 2. Annotate with Custom Interface

```dart
@Serializable()
@GenerateRestRepository(implements: ProductRepository)
class Product extends AggregateRoot {
  Product({
    UuidValue? id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : super(id: id, createdAt: createdAt, updatedAt: updatedAt);

  final String name;
  final String description;
  final double price;
  final String category;
}

part 'product.g.dart';
part 'product.rest_repository.g.dart';
```

### 3. Implement Custom Methods

The generator creates `ProductRestRepositoryBase` with:
- Concrete implementations of `getById()`, `save()`, `deleteById()`
- Abstract declarations of custom methods
- Protected members: `_connection`, `_serializer`, `_resourcePath`, `_mapHttpException()`

Extend the base class and implement custom methods:

```dart
class ProductRestRepository extends ProductRestRepositoryBase {
  ProductRestRepository(super.connection);

  @override
  Future<List<Product>> findByCategory(String category) async {
    try {
      final response = await _connection.client.get(
        '$_resourcePath?category=$category',
      );

      if (response.statusCode == 200) {
        final jsonList = jsonDecode(response.body) as List<dynamic>;
        return jsonList
            .map((json) => _serializer.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      throw _mapHttpException(response.statusCode, response.body);
    } catch (e) {
      if (e is RepositoryException) rethrow;
      throw RepositoryException(
        'Failed to find products by category: $e',
        type: RepositoryExceptionType.unknown,
        cause: e,
      );
    }
  }

  @override
  Future<List<Product>> findByPriceRange(
    double minPrice,
    double maxPrice,
  ) async {
    try {
      final response = await _connection.client.get(
        '$_resourcePath?minPrice=$minPrice&maxPrice=$maxPrice',
      );

      if (response.statusCode == 200) {
        final jsonList = jsonDecode(response.body) as List<dynamic>;
        return jsonList
            .map((json) => _serializer.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      throw _mapHttpException(response.statusCode, response.body);
    } catch (e) {
      if (e is RepositoryException) rethrow;
      throw RepositoryException(
        'Failed to find products by price range: $e',
        type: RepositoryExceptionType.unknown,
        cause: e,
      );
    }
  }
}
```

### Protected Members

When extending the generated base class, you have access to:

- **`_connection`**: The `RestConnection` instance for making HTTP requests
- **`_serializer`**: The JSON serializer for the aggregate type
- **`_resourcePath`**: The resource path string (e.g., `'users'`)
- **`_mapHttpException()`**: Helper method for mapping HTTP status codes to `RepositoryException` types

## Error Handling

### Exception Types

All repository operations throw `RepositoryException` with specific types:

| HTTP Status | Exception Type | Description |
|-------------|---------------|-------------|
| 404 | `notFound` | Resource not found |
| 409 | `duplicate` | Duplicate resource (conflict) |
| 408, 504 | `timeout` | Request timeout |
| 500-599 | `connection` | Server error |
| Network errors | `connection` | Cannot reach server |
| Other | `unknown` | Unexpected error |

### Handling Specific Error Types

```dart
try {
  final user = await userRepo.getById(userId);
  print('Found: ${user.fullName}');
} on RepositoryException catch (e) {
  switch (e.type) {
    case RepositoryExceptionType.notFound:
      print('User not found');
      return null;
    case RepositoryExceptionType.connection:
      print('Server unavailable, try again later');
      throw ServiceUnavailableException();
    case RepositoryExceptionType.timeout:
      print('Request timed out, retrying...');
      // Implement retry logic
      break;
    default:
      print('Unexpected error: ${e.message}');
      rethrow;
  }
}
```

### Retry Strategy for Transient Errors

```dart
Future<User> getUserWithRetry(
  UserRestRepository repo,
  UuidValue id, {
  int maxAttempts = 3,
}) async {
  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    try {
      return await repo.getById(id);
    } on RepositoryException catch (e) {
      // Retry on transient errors
      if (e.type == RepositoryExceptionType.timeout ||
          e.type == RepositoryExceptionType.connection) {
        if (attempt == maxAttempts - 1) rethrow;
        
        // Exponential backoff
        final delay = math.pow(2, attempt).toInt();
        await Future.delayed(Duration(seconds: delay));
        continue;
      }
      
      // Don't retry on non-transient errors
      rethrow;
    }
  }
  throw StateError('Unreachable');
}
```

### Graceful Degradation

```dart
Future<User?> findUserSafely(
  UserRestRepository repo,
  UuidValue id,
) async {
  try {
    return await repo.getById(id);
  } on RepositoryException catch (e) {
    if (e.type == RepositoryExceptionType.notFound) {
      return null;
    }
    
    // Log error and return null for other errors
    logger.error('Failed to fetch user', error: e);
    return null;
  }
}
```

## Best Practices

### Connection Management

1. **Create one connection per application** and share it across repositories
2. **Always dispose connections** when done to release resources
3. **Use connection pooling** by reusing the same connection
4. **Configure timeouts** appropriately for your use case

### Authentication

1. **Use HTTPS in production** - never send tokens over HTTP
2. **Implement proper token refresh** in your `AuthProvider`
3. **Handle authentication failures** gracefully
4. **Store tokens securely** - never log or expose them

### Error Handling

1. **Handle specific exception types** appropriately
2. **Implement retry strategies** for transient errors (timeout, connection)
3. **Use graceful degradation** for non-critical operations
4. **Log errors with context** for debugging
5. **Validate input** before making API calls

### Custom Repositories

1. **Use protected members** (`_connection`, `_serializer`, `_mapHttpException`)
2. **Follow the same error handling pattern** as generated methods
3. **Validate query parameters** before making requests
4. **Document custom methods** with clear examples

### Performance

1. **Reuse connections** to leverage HTTP connection pooling
2. **Batch operations** when possible to reduce round trips
3. **Implement caching** for frequently accessed data
4. **Use pagination** for large result sets

## API Reference

### RestConnection

```dart
class RestConnection {
  RestConnection({
    required String baseUrl,
    AuthProvider? authProvider,
    http.Client? httpClient,
  });
  
  String get baseUrl;
  RestClient get client;
  void dispose();
}
```

### @GenerateRestRepository

```dart
class GenerateRestRepository {
  const GenerateRestRepository({
    String? resourcePath,
    Type? implements,
  });
}
```

### Generated Repository Methods

All generated repositories implement `Repository<T>`:

```dart
abstract interface class Repository<T extends AggregateRoot> {
  Future<T> getById(UuidValue id);
  Future<void> save(T aggregate);
  Future<void> deleteById(UuidValue id);
}
```

## Examples

The `example/` directory contains comprehensive examples:

- **[basic_crud_example.dart](example/basic_crud_example.dart)** - Basic CRUD operations
- **[authentication_example.dart](example/authentication_example.dart)** - Authentication setup and usage
- **[custom_repository_example.dart](example/custom_repository_example.dart)** - Custom query methods
- **[error_handling_example.dart](example/error_handling_example.dart)** - Error handling patterns

To run an example:

```bash
cd example
dart run basic_crud_example.dart
```

**Note**: Examples require a REST API server running at `http://localhost:8080`. You can use `dddart_rest` to create a test server.

## Troubleshooting

### Code Generation Issues

**Problem**: Generated files not created

**Solution**:
```bash
# Clean and rebuild
dart run build_runner clean
dart run build_runner build --delete-conflicting-outputs
```

**Problem**: "Class must extend AggregateRoot" error

**Solution**: Ensure your class extends `AggregateRoot` from `dddart`:
```dart
class User extends AggregateRoot { ... }
```

**Problem**: "Class must have @Serializable annotation" error

**Solution**: Add the `@Serializable()` annotation:
```dart
@Serializable()
@GenerateRestRepository()
class User extends AggregateRoot { ... }
```

### Connection Issues

**Problem**: "Connection refused" errors

**Solution**:
- Verify the server is running at the specified `baseUrl`
- Check firewall settings
- Ensure the URL includes the protocol (`http://` or `https://`)

**Problem**: Authentication failures

**Solution**:
- Verify your `AuthProvider` returns valid tokens
- Check token expiration and refresh logic
- Ensure the server accepts the token format

### Runtime Issues

**Problem**: "Failed to deserialize" errors

**Solution**:
- Verify the server returns JSON in the expected format
- Check that all required fields are present in the response
- Ensure field names match between client and server

**Problem**: Timeout errors

**Solution**:
- Increase timeout configuration in your HTTP client
- Implement retry logic for transient failures
- Check server performance and response times

### Custom Repository Issues

**Problem**: Cannot access protected members

**Solution**: Ensure your custom repository class is in the same library as the generated base class (same file or use `part`/`part of`).

**Problem**: Custom methods not working

**Solution**:
- Verify the server supports the query parameters you're using
- Check the response format matches your deserialization logic
- Use `_mapHttpException()` for consistent error handling

## Related Packages

- **[dddart](https://pub.dev/packages/dddart)** - Core DDD framework
- **[dddart_json](https://pub.dev/packages/dddart_json)** - JSON serialization
- **[dddart_rest_client](https://pub.dev/packages/dddart_rest_client)** - REST client with authentication
- **[dddart_rest](https://pub.dev/packages/dddart_rest)** - REST API server framework
- **[dddart_repository_mongodb](https://pub.dev/packages/dddart_repository_mongodb)** - MongoDB repository
- **[dddart_repository_dynamodb](https://pub.dev/packages/dddart_repository_dynamodb)** - DynamoDB repository
- **[dddart_repository_sqlite](https://pub.dev/packages/dddart_repository_sqlite)** - SQLite repository

## License

MIT License - see [LICENSE](LICENSE) file for details.
