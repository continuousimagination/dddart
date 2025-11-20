# dddart_repository_mongodb

MongoDB repository implementation for DDDart - Domain-Driven Design for Dart.

## Overview

`dddart_repository_mongodb` provides code-generated MongoDB repositories for DDDart aggregate roots. It leverages existing JSON serialization from `dddart_json` and the mature `mongo_dart` driver for MongoDB connectivity, with full support for AWS DocumentDB Serverless.

The package follows DDDart's code generation pattern to automatically create repository implementations from annotated aggregate roots, eliminating boilerplate while maintaining type safety and extensibility.

## Features

- **Code Generation**: Automatically generate repository implementations from annotated aggregate roots
- **JSON Serialization Integration**: Reuses `dddart_json` serializers for seamless persistence - no duplicate serialization logic
- **Extensibility**: Support for custom repository interfaces with domain-specific query methods
- **AWS DocumentDB Compatible**: Works with AWS DocumentDB Serverless and standard MongoDB 4.0+
- **Type-Safe**: Leverages Dart's type system for compile-time safety
- **Error Handling**: Comprehensive exception mapping to `RepositoryException` types
- **Connection Management**: Flexible connection configuration with URI support and TLS options
- **Zero Reflection**: Pure code generation approach for optimal performance
- **Repository Pattern**: Clean abstraction over MongoDB operations following DDD principles

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  dddart: ^0.9.0
  dddart_json: ^0.9.0
  dddart_repository_mongodb: ^0.9.0

dev_dependencies:
  build_runner: ^2.4.0
```

## Quick Start

### 1. Annotate Your Aggregate Root

```dart
import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_repository_mongodb/dddart_repository_mongodb.dart';

@Serializable()
@GenerateMongoRepository(collectionName: 'users')
class User extends AggregateRoot {
  final String firstName;
  final String lastName;
  final String email;

  User({
    required this.firstName,
    required this.lastName,
    required this.email,
  });
}

part 'user.g.dart';
```

### 2. Generate Code

```bash
dart run build_runner build
```

This generates `UserMongoRepository` with full CRUD operations.

### 3. Use the Repository

```dart
import 'package:mongo_dart/mongo_dart.dart';

Future<void> main() async {
  // Create connection
  final connection = MongoConnection(
    host: 'localhost',
    port: 27017,
    databaseName: 'myapp',
  );
  await connection.open();

  // Create repository
  final userRepo = UserMongoRepository(connection.database);

  // Create and save a user
  final user = User(
    firstName: 'John',
    lastName: 'Doe',
    email: 'john@example.com',
  );
  await userRepo.save(user);

  // Retrieve by ID
  final retrieved = await userRepo.getById(user.id);
  print('Retrieved: ${retrieved.firstName} ${retrieved.lastName}');

  // Delete
  await userRepo.deleteById(user.id);

  // Close connection
  await connection.close();
}
```

## Custom Repository Interfaces

Define custom interfaces for domain-specific queries:

```dart
// Define custom interface
abstract interface class UserRepository implements Repository<User> {
  Future<User?> findByEmail(String email);
  Future<List<User>> findByLastName(String lastName);
}

// Annotate with custom interface
@Serializable()
@GenerateMongoRepository(implements: UserRepository)
class User extends AggregateRoot {
  final String firstName;
  final String lastName;
  final String email;

  User({
    required this.firstName,
    required this.lastName,
    required this.email,
  });
}

part 'user.g.dart';

// Implement custom methods
class UserMongoRepository extends UserMongoRepositoryBase {
  UserMongoRepository(super.database);

  @override
  Future<User?> findByEmail(String email) async {
    final doc = await _collection.findOne(where.eq('email', email));
    if (doc == null) return null;

    doc['id'] = doc['_id'];
    doc.remove('_id');
    return _serializer.fromJson(doc);
  }

  @override
  Future<List<User>> findByLastName(String lastName) async {
    final docs = await _collection
        .find(where.eq('lastName', lastName))
        .toList();

    return docs.map((doc) {
      doc['id'] = doc['_id'];
      doc.remove('_id');
      return _serializer.fromJson(doc);
    }).toList();
  }
}
```

## Connection Configuration

### Using Connection Parameters

```dart
final connection = MongoConnection(
  host: 'localhost',
  port: 27017,
  databaseName: 'myapp',
  username: 'user',
  password: 'password',
  authSource: 'admin',
);
```

### Using Connection URI

```dart
final connection = MongoConnection.fromUri(
  'mongodb://user:password@localhost:27017/myapp?authSource=admin'
);
```

### AWS DocumentDB

```dart
final connection = MongoConnection(
  host: 'my-cluster.cluster-xxx.us-east-1.docdb.amazonaws.com',
  port: 27017,
  databaseName: 'myapp',
  username: 'user',
  password: 'password',
  tls: true,
  tlsAllowInvalidCertificates: true,
);
```

## Error Handling

The package maps MongoDB errors to `RepositoryException` types:

```dart
try {
  final user = await userRepo.getById(userId);
} on RepositoryException catch (e) {
  switch (e.type) {
    case RepositoryExceptionType.notFound:
      print('User not found');
    case RepositoryExceptionType.duplicate:
      print('Duplicate key error');
    case RepositoryExceptionType.connection:
      print('Connection error');
    case RepositoryExceptionType.timeout:
      print('Operation timed out');
    case RepositoryExceptionType.unknown:
      print('Unknown error: ${e.message}');
  }
}
```

## Annotation Parameters

### `@GenerateMongoRepository()`

The annotation supports two optional parameters:

#### `collectionName` (String?)

Specifies the MongoDB collection name for the aggregate type.

- **Default**: Class name converted to snake_case (e.g., `UserProfile` → `user_profiles`)
- **Example**: `@GenerateMongoRepository(collectionName: 'users')`

#### `implements` (Type?)

Specifies a custom repository interface to implement.

- **Without custom methods**: Generates a concrete class `{ClassName}MongoRepository`
- **With custom methods**: Generates an abstract base class `{ClassName}MongoRepositoryBase` requiring you to implement custom methods
- **Example**: `@GenerateMongoRepository(implements: UserRepository)`

### Code Generation Behavior

The generator intelligently determines what to generate based on your interface:

| Scenario | Generated Class | Type | Usage |
|----------|----------------|------|-------|
| No interface | `UserMongoRepository` | Concrete | Use directly |
| Interface with only base methods | `UserMongoRepository` | Concrete | Use directly |
| Interface with custom methods | `UserMongoRepositoryBase` | Abstract | Extend and implement |

## Extensibility Patterns

### Pattern 1: Direct Usage (No Custom Interface)

Best for simple CRUD operations without custom queries.

```dart
@Serializable()
@GenerateMongoRepository()
class Product extends AggregateRoot {
  final String name;
  final double price;
  
  Product({required this.name, required this.price});
}

// Usage
final repo = ProductMongoRepository(database);
await repo.save(product);
```

### Pattern 2: Custom Interface for Multiple Implementations

Best when you need different implementations (MongoDB, REST, in-memory) conforming to the same interface.

```dart
// Domain layer - define interface
abstract interface class UserRepository implements Repository<User> {
  Future<User?> findByEmail(String email);
}

// Aggregate with interface
@Serializable()
@GenerateMongoRepository(implements: UserRepository)
class User extends AggregateRoot {
  final String email;
  User({required this.email});
}

// MongoDB implementation
class UserMongoRepository extends UserMongoRepositoryBase {
  UserMongoRepository(super.database);
  
  @override
  Future<User?> findByEmail(String email) async {
    final doc = await _collection.findOne(where.eq('email', email));
    if (doc == null) return null;
    
    doc['id'] = doc['_id'];
    doc.remove('_id');
    return _serializer.fromJson(doc);
  }
}

// Swap implementations
UserRepository repo = UserMongoRepository(database);     // Production
UserRepository repo = InMemoryRepository<User>();        // Testing
```

### Pattern 3: Accessing MongoDB Internals

The generated base class exposes protected members for custom queries:

- **`_database`**: The MongoDB `Db` instance
- **`_collection`**: Helper getter for the collection
- **`_serializer`**: The JSON serializer for the aggregate
- **`collectionName`**: The collection name

```dart
class UserMongoRepository extends UserMongoRepositoryBase {
  UserMongoRepository(super.database);
  
  Future<List<User>> findActive() async {
    final docs = await _collection
        .find(where.eq('isActive', true))
        .toList();
    
    return docs.map((doc) {
      doc['id'] = doc['_id'];
      doc.remove('_id');
      return _serializer.fromJson(doc);
    }).toList();
  }
  
  Future<int> countByStatus(String status) async {
    return await _collection.count(where.eq('status', status));
  }
}
```

## Connection Lifecycle Best Practices

### Connection Pooling

Connection pooling is handled automatically by `mongo_dart`. Each `Db` instance maintains its own connection pool, so you should:

- **Create one `MongoConnection` per application**: Reuse the same connection across your application
- **Don't create connections per request**: This defeats pooling and wastes resources
- **Share the `Db` instance**: Pass the same database instance to all repositories

```dart
// ✅ Good: Single connection, shared database
final connection = MongoConnection(host: 'localhost', port: 27017, databaseName: 'myapp');
await connection.open();

final userRepo = UserMongoRepository(connection.database);
final productRepo = ProductMongoRepository(connection.database);
final orderRepo = OrderMongoRepository(connection.database);

// ❌ Bad: Multiple connections
final userRepo = UserMongoRepository((await MongoConnection(...).open()).database);
final productRepo = ProductMongoRepository((await MongoConnection(...).open()).database);
```

### Connection Reuse Patterns

#### Pattern 1: Dependency Injection

```dart
class AppServices {
  final Db database;
  late final UserRepository userRepo;
  late final ProductRepository productRepo;
  
  AppServices(this.database) {
    userRepo = UserMongoRepository(database);
    productRepo = ProductMongoRepository(database);
  }
}

Future<void> main() async {
  final connection = MongoConnection(host: 'localhost', port: 27017, databaseName: 'myapp');
  await connection.open();
  
  final services = AppServices(connection.database);
  
  // Use services throughout your app
  await services.userRepo.save(user);
  
  await connection.close();
}
```

#### Pattern 2: With dddart_config

```dart
import 'package:dddart_config/dddart_config.dart';

Future<void> main() async {
  // Load configuration
  final config = Configuration([
    YamlConfigProvider('config.yaml'),
    EnvironmentConfigProvider(),
  ]);
  await config.load();
  
  // Create connection from config
  final connection = MongoConnection(
    host: config.get('mongodb.host'),
    port: config.get('mongodb.port'),
    databaseName: config.get('mongodb.database'),
    username: config.get('mongodb.username'),
    password: config.get('mongodb.password'),
  );
  await connection.open();
  
  // Use throughout app
  final userRepo = UserMongoRepository(connection.database);
  
  // Cleanup
  await connection.close();
}
```

### Proper Connection Closing

Always close connections when your application shuts down:

```dart
Future<void> main() async {
  final connection = MongoConnection(host: 'localhost', port: 27017, databaseName: 'myapp');
  
  try {
    await connection.open();
    
    // Application logic
    final userRepo = UserMongoRepository(connection.database);
    await userRepo.save(user);
    
  } finally {
    // Always close, even on error
    await connection.close();
  }
}
```

For long-running applications (servers), keep the connection open and close on shutdown:

```dart
import 'dart:io';

Future<void> main() async {
  final connection = MongoConnection(host: 'localhost', port: 27017, databaseName: 'myapp');
  await connection.open();
  
  // Handle shutdown signals
  ProcessSignal.sigint.watch().listen((_) async {
    print('Shutting down...');
    await connection.close();
    exit(0);
  });
  
  // Start server with repositories
  final userRepo = UserMongoRepository(connection.database);
  // ... server logic
}
```

## AWS DocumentDB Compatibility

The package is fully compatible with AWS DocumentDB Serverless through `mongo_dart`'s MongoDB protocol support.

### Connection Configuration

```dart
final connection = MongoConnection(
  host: 'my-cluster.cluster-xxx.us-east-1.docdb.amazonaws.com',
  port: 27017,
  databaseName: 'myapp',
  username: 'myuser',
  password: 'mypassword',
  tls: true,
  tlsAllowInvalidCertificates: true, // For DocumentDB's certificate
);
await connection.open();
```

### Using Connection URI

```dart
final connection = MongoConnection.fromUri(
  'mongodb://myuser:mypassword@my-cluster.cluster-xxx.us-east-1.docdb.amazonaws.com:27017/myapp?tls=true&tlsAllowInvalidCertificates=true'
);
await connection.open();
```

### DocumentDB Considerations

- **TLS Required**: DocumentDB requires TLS connections
- **Certificate Validation**: Use `tlsAllowInvalidCertificates: true` or provide a CA bundle
- **Feature Compatibility**: DocumentDB supports MongoDB 4.0 API - all features in this package are compatible
- **Serverless Mode**: Works seamlessly with DocumentDB Serverless clusters

## Error Handling Patterns

### Exception Types

All MongoDB errors are mapped to `RepositoryException` with specific types:

| Exception Type | Cause | Common Scenarios |
|---------------|-------|------------------|
| `notFound` | Document doesn't exist | `getById` or `deleteById` with invalid ID |
| `duplicate` | Unique constraint violation | Duplicate `_id` or unique index violation |
| `connection` | Network or auth failure | Database unreachable, invalid credentials |
| `timeout` | Operation exceeded time limit | Slow queries, network latency |
| `unknown` | Unexpected error | Serialization errors, unexpected MongoDB errors |

### Handling Patterns

#### Pattern 1: Specific Error Handling

```dart
try {
  final user = await userRepo.getById(userId);
  print('Found: ${user.firstName}');
} on RepositoryException catch (e) {
  switch (e.type) {
    case RepositoryExceptionType.notFound:
      print('User not found');
      return null;
    case RepositoryExceptionType.connection:
      print('Database connection failed');
      throw ServerException('Database unavailable');
    default:
      print('Unexpected error: ${e.message}');
      rethrow;
  }
}
```

#### Pattern 2: Retry Logic for Transient Errors

```dart
Future<User> getUserWithRetry(UuidValue id, {int maxRetries = 3}) async {
  for (var attempt = 0; attempt < maxRetries; attempt++) {
    try {
      return await userRepo.getById(id);
    } on RepositoryException catch (e) {
      if (e.type == RepositoryExceptionType.timeout || 
          e.type == RepositoryExceptionType.connection) {
        if (attempt == maxRetries - 1) rethrow;
        await Future.delayed(Duration(seconds: attempt + 1));
        continue;
      }
      rethrow;
    }
  }
  throw StateError('Should not reach here');
}
```

#### Pattern 3: Graceful Degradation

```dart
Future<User?> findUserSafely(UuidValue id) async {
  try {
    return await userRepo.getById(id);
  } on RepositoryException catch (e) {
    if (e.type == RepositoryExceptionType.notFound) {
      return null; // Expected case
    }
    // Log unexpected errors but don't crash
    logger.error('Failed to fetch user', error: e);
    return null;
  }
}
```

## API Reference

### Core Classes

- **`MongoConnection`**: Manages MongoDB database connections
  - `MongoConnection({required host, required port, required databaseName, ...})`: Create from parameters
  - `MongoConnection.fromUri(String uri)`: Create from connection URI
  - `Future<void> open()`: Open the connection
  - `Future<void> close()`: Close the connection
  - `Db get database`: Get the database instance
  - `bool get isConnected`: Check connection status

- **`@GenerateMongoRepository`**: Annotation for code generation
  - `collectionName`: Optional custom collection name
  - `implements`: Optional custom repository interface

### Generated Repository Classes

Generated repositories implement `Repository<T>` with these methods:

- `Future<T> getById(UuidValue id)`: Retrieve aggregate by ID
- `Future<void> save(T aggregate)`: Save or update aggregate (upsert)
- `Future<void> deleteById(UuidValue id)`: Delete aggregate by ID

When extending generated base classes, you also have access to:

- `Db _database`: MongoDB database instance
- `DbCollection get _collection`: Collection for this aggregate type
- `String get collectionName`: Collection name
- `JsonSerializer<T> _serializer`: Serializer for the aggregate

## Examples

See the `example/` directory for comprehensive examples including:

- **`basic_crud_example.dart`**: Basic CRUD operations without custom interface
- **`custom_interface_example.dart`**: Custom repository interface with domain-specific queries
- **`error_handling_example.dart`**: Comprehensive error handling patterns
- **`config_integration_example.dart`**: Integration with `dddart_config` for configuration management
- **`repository_swapping_example.dart`**: Swapping implementations for testing

Run examples:

```bash
cd example
dart run basic_crud_example.dart
```

## Requirements

- **Dart SDK**: >=3.5.0 <4.0.0
- **MongoDB**: 4.0+ or AWS DocumentDB
- **Aggregate roots must**:
  - Extend `AggregateRoot` from `dddart`
  - Be annotated with `@Serializable()` from `dddart_json`
  - Be annotated with `@GenerateMongoRepository()` from this package

## Troubleshooting

### Code Generation Issues

**Problem**: Generated files not created

```bash
# Clean and rebuild
dart run build_runner clean
dart run build_runner build --delete-conflicting-outputs
```

**Problem**: "Class must extend AggregateRoot" error

Ensure your class extends `AggregateRoot`:
```dart
class User extends AggregateRoot { // ✅ Correct
class User extends Entity {        // ❌ Wrong
```

**Problem**: "Class must be annotated with @Serializable()" error

Add both annotations:
```dart
@Serializable()                    // ✅ Required
@GenerateMongoRepository()
class User extends AggregateRoot { ... }
```

### Connection Issues

**Problem**: "Connection not open" error

Always call `open()` before accessing the database:
```dart
await connection.open();           // ✅ Required
final db = connection.database;
```

**Problem**: AWS DocumentDB connection fails

Ensure TLS is enabled:
```dart
MongoConnection(
  host: 'cluster.docdb.amazonaws.com',
  tls: true,                       // ✅ Required for DocumentDB
  tlsAllowInvalidCertificates: true,
  ...
)
```

## Contributing

Contributions are welcome! Please see the main DDDart repository for contribution guidelines.

## License

MIT License - see LICENSE file for details.
