# Repository Pattern Design

## Overview

This design implements the Repository pattern for the DDDart framework, providing a standardized abstraction for persisting and retrieving aggregate roots. The implementation includes a base `Repository<T>` interface and an `InMemoryRepository<T>` implementation for testing purposes. The design follows DDD principles and Dart best practices, ensuring type safety, async operations, and cross-platform compatibility.

The repository pattern serves as a collection-like interface to domain objects, abstracting away data access details and allowing domain logic to remain independent of persistence concerns.

## Architecture

### Component Structure

```
packages/dddart/lib/src/
├── repository.dart           # Base Repository<T> interface
├── in_memory_repository.dart # InMemoryRepository<T> implementation
└── repository_exception.dart # Exception types for repository operations
```

### Key Design Decisions

1. **Generic Interface**: `Repository<T extends AggregateRoot>` ensures type safety and works with any aggregate root
2. **Async by Default**: All operations return `Future` types to support both synchronous and asynchronous implementations
3. **Minimal Interface**: Core CRUD operations only (getById, save, deleteById) to keep the abstraction flexible
4. **Extensibility**: Interface can be extended by consumers to add domain-specific query methods
5. **Exception-Based Error Handling**: Clear exception types for different failure scenarios
6. **Platform Agnostic**: No platform-specific dependencies in the abstraction layer

## Components and Interfaces

### Repository Interface

The base repository interface defines the contract for all repository implementations.

```dart
/// Base interface for repositories that manage aggregate roots.
///
/// Repositories provide a collection-like interface for persisting and
/// retrieving aggregate roots, abstracting away data access details.
///
/// Type parameter [T] must extend [AggregateRoot].
abstract interface class Repository<T extends AggregateRoot> {
  /// Retrieves an aggregate root by its ID.
  ///
  /// Returns the aggregate root with the given ID.
  ///
  /// Throws [RepositoryException] with type [RepositoryExceptionType.notFound]
  /// if no aggregate with the given ID exists.
  ///
  /// Throws [RepositoryException] if the operation fails for other reasons.
  Future<T> getById(UuidValue id);

  /// Saves an aggregate root to the repository.
  ///
  /// This operation performs an insert if the aggregate is new,
  /// or an update if it already exists (upsert semantics).
  ///
  /// Throws [RepositoryException] if the operation fails.
  Future<void> save(T aggregate);

  /// Deletes an aggregate root by its ID.
  ///
  /// Throws [RepositoryException] with type [RepositoryExceptionType.notFound]
  /// if no aggregate with the given ID exists.
  ///
  /// Throws [RepositoryException] if the operation fails for other reasons.
  Future<void> deleteById(UuidValue id);
}
```

**Design Notes:**
- Uses `abstract interface class` to prevent implementation inheritance (Dart 3.0+)
- Generic type constraint ensures only aggregate roots can be stored
- Both getById and deleteById throw exceptions when aggregate not found (consistent behavior)
- Rationale: GUIDs come from somewhere - if you have one, you expect it to exist
- Save uses upsert semantics (insert or update) for simplicity

### InMemoryRepository Implementation

A concrete implementation that stores aggregates in memory using a Map.

```dart
/// In-memory implementation of [Repository] for testing purposes.
///
/// Stores aggregate roots in a Map keyed by their ID. This implementation
/// is useful for unit tests and prototyping, but should not be used in
/// production as data is not persisted.
///
/// Type parameter [T] must extend [AggregateRoot].
class InMemoryRepository<T extends AggregateRoot> implements Repository<T> {
  /// Internal storage map
  final Map<UuidValue, T> _storage = {};

  @override
  Future<T> getById(UuidValue id) async {
    final aggregate = _storage[id];
    if (aggregate == null) {
      throw RepositoryException(
        'Aggregate with ID $id not found',
        type: RepositoryExceptionType.notFound,
      );
    }
    return aggregate;
  }

  @override
  Future<void> save(T aggregate) async {
    _storage[aggregate.id] = aggregate;
  }

  @override
  Future<void> deleteById(UuidValue id) async {
    if (!_storage.containsKey(id)) {
      throw RepositoryException(
        'Aggregate with ID $id not found',
        type: RepositoryExceptionType.notFound,
      );
    }
    _storage.remove(id);
  }

  /// Clears all aggregates from the repository.
  ///
  /// Useful for test cleanup.
  void clear() {
    _storage.clear();
  }

  /// Returns all aggregates in the repository.
  ///
  /// Useful for testing and debugging. Returns an unmodifiable list.
  List<T> getAll() {
    return List.unmodifiable(_storage.values);
  }
}
```

**Design Notes:**
- Uses `Map<UuidValue, T>` for O(1) lookups
- Async methods use `async` keyword even though operations are synchronous (for interface consistency)
- Both getById and deleteById throw `RepositoryException` if aggregate not found
- Includes utility methods (clear, getAll) for testing convenience
- Not thread-safe (acceptable for testing scenarios)

### Exception Types

Clear exception hierarchy for repository errors.

```dart
/// Exception thrown when a repository operation fails.
class RepositoryException implements Exception {
  const RepositoryException(
    this.message, {
    this.type = RepositoryExceptionType.unknown,
    this.cause,
  });

  /// Human-readable error message
  final String message;

  /// The type of repository error
  final RepositoryExceptionType type;

  /// Optional underlying cause of the exception
  final Object? cause;

  @override
  String toString() {
    if (cause != null) {
      return 'RepositoryException: $message (type: $type, cause: $cause)';
    }
    return 'RepositoryException: $message (type: $type)';
  }
}

/// Types of repository exceptions
enum RepositoryExceptionType {
  /// The requested aggregate was not found
  notFound,

  /// A duplicate aggregate already exists
  duplicate,

  /// The operation violated a constraint
  constraint,

  /// A connection or network error occurred
  connection,

  /// The operation timed out
  timeout,

  /// An unknown or unexpected error occurred
  unknown,
}
```

**Design Notes:**
- Enum-based type classification for programmatic error handling
- Optional `cause` field for wrapping underlying exceptions
- Extensible design allows future exception types
- Clear toString for debugging

## Data Models

### Repository Storage Model

The repository works with aggregate roots that extend the `AggregateRoot` base class:

```
AggregateRoot (from existing DDDart)
├── id: UuidValue
├── createdAt: DateTime
├── updatedAt: DateTime
└── domain events management
```

Repositories use the aggregate's `id` field as the primary key for storage and retrieval.

### Type Relationships

```
Repository<T extends AggregateRoot>
    ↑
    │ implements
    │
InMemoryRepository<T extends AggregateRoot>

Consumer-Defined:
UserRepository extends Repository<User>
    ↑
    │ implements
    │
MySqlUserRepository implements UserRepository
```

## Error Handling

### Error Scenarios and Responses

| Scenario | Method | Behavior |
|----------|--------|----------|
| Aggregate not found | getById | Throws `RepositoryException` (notFound) |
| Aggregate not found | deleteById | Throws `RepositoryException` (notFound) |
| Save new aggregate | save | Inserts into storage |
| Save existing aggregate | save | Updates in storage |
| Invalid ID format | Any | Caught by UuidValue validation |
| Storage failure | Any | Throws `RepositoryException` (unknown) |

### Exception Handling Pattern

```dart
try {
  final user = await userRepository.getById(userId);
  // Use the user - it's guaranteed to exist if no exception was thrown
} on RepositoryException catch (e) {
  switch (e.type) {
    case RepositoryExceptionType.notFound:
      // Handle not found - the ID doesn't exist
    case RepositoryExceptionType.connection:
      // Handle connection error
    default:
      // Handle other errors
  }
}
```

## Testing Strategy

### Unit Tests

**Repository Interface Tests** (via InMemoryRepository):
1. Test getById throws exception for non-existent ID
2. Test getById returns correct aggregate after save
3. Test save inserts new aggregate
4. Test save updates existing aggregate
5. Test deleteById removes aggregate
6. Test deleteById throws exception for non-existent ID
7. Test type safety with different aggregate types
8. Test concurrent operations (if applicable)

**InMemoryRepository-Specific Tests**:
1. Test clear removes all aggregates
2. Test getAll returns all stored aggregates
3. Test storage isolation between instances

**Exception Tests**:
1. Test RepositoryException message formatting
2. Test exception type classification
3. Test exception with cause wrapping

### Integration Test Patterns

For consumers implementing custom repositories:

```dart
// Test pattern for custom repository implementations
void testRepository(Repository<User> repository) {
  test('saves and retrieves aggregate', () async {
    final user = User(name: 'John');
    await repository.save(user);
    
    final retrieved = await repository.getById(user.id);
    expect(retrieved.id, equals(user.id));
  });
  
  // Additional tests...
}

// Use with different implementations
group('MySqlUserRepository', () {
  testRepository(MySqlUserRepository(connection));
});

group('InMemoryUserRepository', () {
  testRepository(InMemoryRepository<User>());
});
```

## Extension Patterns

### Custom Repository Interfaces

Consumers can extend the base repository with domain-specific methods:

```dart
/// Domain-specific repository interface for User aggregates
abstract interface class UserRepository implements Repository<User> {
  /// Finds a user by email address
  Future<User?> getByEmail(String email);
  
  /// Finds all users with the given first name
  Future<List<User>> getByFirstName(String firstName);
  
  /// Finds all active users
  Future<List<User>> getActiveUsers();
}

/// MySQL implementation
class MySqlUserRepository implements UserRepository {
  MySqlUserRepository(this.connection);
  
  final MySqlConnection connection;
  
  @override
  Future<User?> getById(UuidValue id) async {
    // MySQL-specific implementation
  }
  
  @override
  Future<void> save(User aggregate) async {
    // MySQL-specific implementation
  }
  
  @override
  Future<void> deleteById(UuidValue id) async {
    // MySQL-specific implementation
  }
  
  @override
  Future<User?> getByEmail(String email) async {
    // Custom query implementation
  }
  
  @override
  Future<List<User>> getByFirstName(String firstName) async {
    // Custom query implementation
  }
  
  @override
  Future<List<User>> getActiveUsers() async {
    // Custom query implementation
  }
}
```

### Future Remote Repository Pattern

The design supports future remote API implementations:

```dart
/// Future: Remote API implementation
class ApiUserRepository implements UserRepository {
  ApiUserRepository(this.httpClient, this.baseUrl);
  
  final HttpClient httpClient;
  final String baseUrl;
  
  @override
  Future<User> getById(UuidValue id) async {
    final response = await httpClient.get('$baseUrl/users/${id.uuid}');
    if (response.statusCode == 404) {
      throw RepositoryException(
        'User with ID $id not found',
        type: RepositoryExceptionType.notFound,
      );
    }
    if (response.statusCode != 200) {
      throw RepositoryException(
        'Failed to fetch user',
        type: RepositoryExceptionType.connection,
      );
    }
    return User.fromJson(response.body);
  }
  
  // Additional methods...
}
```

## Integration with Existing DDDart Components

### Aggregate Root Integration

Repositories work seamlessly with the existing `AggregateRoot` class:

```dart
// Existing AggregateRoot provides:
// - id: UuidValue (used as repository key)
// - createdAt/updatedAt: DateTime (persisted with aggregate)
// - Domain events (can be published after save)

// Example usage:
final user = User(name: 'John');
user.updateEmail('john@example.com'); // Raises domain event

await userRepository.save(user);

// Publish events after successful save
final events = user.getUncommittedEvents();
for (final event in events) {
  await eventBus.publish(event);
}
user.markEventsAsCommitted();
```

### Event Bus Integration Pattern

Repositories can be combined with the event bus for event sourcing patterns:

```dart
class EventPublishingRepository<T extends AggregateRoot> 
    implements Repository<T> {
  EventPublishingRepository(this.innerRepository, this.eventBus);
  
  final Repository<T> innerRepository;
  final EventBus eventBus;
  
  @override
  Future<void> save(T aggregate) async {
    await innerRepository.save(aggregate);
    
    // Publish events after successful save
    final events = aggregate.getUncommittedEvents();
    for (final event in events) {
      await eventBus.publish(event);
    }
    aggregate.markEventsAsCommitted();
  }
  
  @override
  Future<T> getById(UuidValue id) => innerRepository.getById(id);
  
  @override
  Future<void> deleteById(UuidValue id) => innerRepository.deleteById(id);
}
```

## File Organization

### New Files to Create

1. **packages/dddart/lib/src/repository.dart**
   - Base `Repository<T>` interface
   - Core documentation and examples

2. **packages/dddart/lib/src/in_memory_repository.dart**
   - `InMemoryRepository<T>` implementation
   - Testing utility methods

3. **packages/dddart/lib/src/repository_exception.dart**
   - `RepositoryException` class
   - `RepositoryExceptionType` enum

### Updates to Existing Files

1. **packages/dddart/lib/dddart.dart**
   - Add exports for new repository classes

```dart
export 'src/repository.dart';
export 'src/in_memory_repository.dart';
export 'src/repository_exception.dart';
```

## Cross-Platform Considerations

### Platform Compatibility

- **Dart VM (Server)**: Full support, no restrictions
- **Flutter Mobile**: Full support, no restrictions
- **Flutter Web**: Full support, no restrictions

### No Platform-Specific Dependencies

The repository abstraction uses only core Dart features:
- Generics
- Async/await
- Collections (Map)
- No reflection
- No platform-specific APIs

### Future Platform-Specific Implementations

While the core abstraction is platform-agnostic, future implementations may be platform-specific:
- `packages/dddart_mysql/` - MySQL repository (server only)
- `packages/dddart_sqlite/` - SQLite repository (mobile/desktop)
- `packages/dddart_indexeddb/` - IndexedDB repository (web only)
- `packages/dddart_api/` - HTTP API repository (all platforms)

## Performance Considerations

### InMemoryRepository Performance

- **getById**: O(1) - HashMap lookup
- **save**: O(1) - HashMap insert/update
- **deleteById**: O(1) - HashMap removal
- **Memory**: O(n) where n is number of stored aggregates

### Scalability Notes

- InMemoryRepository is not suitable for large datasets
- No pagination support in base interface (can be added in extensions)
- No caching strategy in base design (can be added via decorator pattern)
- Thread safety is implementation-specific

### Future Optimization Opportunities

- Add optional caching layer via decorator pattern
- Add batch operations (saveAll, deleteAll)
- Add query result streaming for large datasets
- Add pagination support in extended interfaces

## Documentation and Examples

### API Documentation

All public APIs will include:
- Clear purpose and usage description
- Parameter documentation
- Return value documentation
- Exception documentation
- Code examples

### Usage Examples

Examples will be provided for:
1. Basic CRUD operations with InMemoryRepository
2. Creating custom repository interfaces
3. Implementing custom repositories
4. Error handling patterns
5. Integration with domain events
6. Testing with InMemoryRepository

## Summary

This design provides a solid foundation for the repository pattern in DDDart:

- **Simple and Flexible**: Minimal interface that can be extended
- **Type Safe**: Generic constraints ensure compile-time safety
- **Async Ready**: Supports both local and remote implementations
- **Testable**: InMemoryRepository makes testing easy
- **Extensible**: Clear patterns for custom repositories
- **Platform Agnostic**: Works everywhere Dart runs
- **DDD Aligned**: Integrates naturally with aggregate roots and domain events

The design avoids over-engineering while providing clear extension points for future enhancements like remote repositories, caching, and advanced query capabilities.
