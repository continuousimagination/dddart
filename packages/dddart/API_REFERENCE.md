# DDDart API Reference

Complete API reference for the DDDart domain events system.

## Table of Contents

- [DomainEvent](#domainevent)
- [AggregateRoot](#aggregateroot)
- [EventBus](#eventbus)
- [Repository](#repository)
- [InMemoryRepository](#inmemoryrepository)
- [RepositoryException](#repositoryexception)
- [Entity](#entity)
- [Value](#value)
- [UuidValue](#uuidvalue)

---

## DomainEvent

Base class for all domain events in the DDDart framework.

### Class Definition

```dart
abstract class DomainEvent {
  final UuidValue eventId;
  final DateTime occurredAt;
  final UuidValue aggregateId;
  final Map<String, dynamic> context;
  
  DomainEvent({
    required this.aggregateId,
    UuidValue? eventId,
    DateTime? occurredAt,
    this.context = const {},
  });
}
```

### Properties

#### `eventId`
- **Type:** `UuidValue`
- **Description:** Unique identifier for this event instance. Auto-generated using UUID v4 if not provided.
- **Read-only:** Yes

#### `occurredAt`
- **Type:** `DateTime`
- **Description:** Timestamp when the event occurred. Defaults to current time if not provided.
- **Read-only:** Yes

#### `aggregateId`
- **Type:** `UuidValue`
- **Description:** Identifier of the aggregate that raised this event. Required.
- **Read-only:** Yes

#### `context`
- **Type:** `Map<String, dynamic>`
- **Description:** Additional context data for filtering and metadata. Defaults to empty map.
- **Read-only:** Yes

### Constructor

```dart
DomainEvent({
  required this.aggregateId,
  UuidValue? eventId,
  DateTime? occurredAt,
  this.context = const {},
})
```

**Parameters:**
- `aggregateId` (required): UuidValue ID of the aggregate that raised the event
- `eventId` (optional): Custom event ID as UuidValue. Auto-generated if not provided.
- `occurredAt` (optional): Custom timestamp. Defaults to `DateTime.now()`.
- `context` (optional): Additional metadata. Defaults to empty map.

### Methods

#### `toString()`
Returns a string representation of the event.

```dart
String toString()
```

**Returns:** String in format `EventType(eventId: xxx, aggregateId: yyy, occurredAt: zzz)`

**Example:**
```dart
final userId = UuidValue.fromString('12345678-1234-1234-1234-123456789abc');
final event = UserRegistered(userId: userId, email: 'test@example.com');
print(event.toString());
// Output: UserRegistered(eventId: abc-123..., aggregateId: 12345678-1234-1234-1234-123456789abc, occurredAt: 2024-01-15 10:30:00)
```

#### `operator ==`
Compares events based on their event ID.

```dart
bool operator ==(Object other)
```

**Returns:** `true` if both events have the same `eventId`, `false` otherwise.

#### `hashCode`
Returns hash code based on event ID.

```dart
int get hashCode
```

### Usage Example

```dart
// Define a custom domain event
class UserRegistered extends DomainEvent {
  final String email;
  final String fullName;
  
  UserRegistered({
    required UuidValue userId,
    required this.email,
    required this.fullName,
  }) : super(aggregateId: userId);
}

// Create an event
final userId = UuidValue.generate();
final event = UserRegistered(
  userId: userId,
  email: 'john@example.com',
  fullName: 'John Doe',
);

// Access properties
print(event.eventId);        // Auto-generated UuidValue
print(event.occurredAt);     // Current timestamp
print(event.aggregateId);    // UuidValue
print(event.email);          // 'john@example.com'
```

### With Context

```dart
class OrderPlaced extends DomainEvent {
  final String customerId;
  final double totalAmount;
  
  OrderPlaced({
    required UuidValue orderId,
    required this.customerId,
    required this.totalAmount,
  }) : super(
    aggregateId: orderId,
    context: {
      'customerId': customerId,
      'totalAmount': totalAmount,
      'currency': 'USD',
    },
  );
}

// Access context
final orderId = UuidValue.generate();
final event = OrderPlaced(
  orderId: orderId,
  customerId: 'customer-789',
  totalAmount: 299.99,
);
print(event.context['currency']);  // 'USD'
```

---

## AggregateRoot

Base class for aggregate roots with domain event support.

### Class Definition

```dart
abstract class AggregateRoot extends Entity {
  AggregateRoot({
    UuidValue? id,
    DateTime? createdAt,
    DateTime? updatedAt,
  });
  
  void raiseEvent(DomainEvent event);
  List<DomainEvent> getUncommittedEvents();
  void markEventsAsCommitted();
}
```

### Inheritance

Extends: [`Entity`](#entity)

### Constructor

```dart
AggregateRoot({
  UuidValue? id,
  DateTime? createdAt,
  DateTime? updatedAt,
})
```

**Parameters:**
- `id` (optional): Unique identifier. Auto-generated if not provided.
- `createdAt` (optional): Creation timestamp. Defaults to current time.
- `updatedAt` (optional): Last update timestamp. Defaults to current time.

### Methods

#### `raiseEvent()`
Raises a domain event and adds it to the uncommitted events list.

```dart
void raiseEvent(DomainEvent event)
```

**Parameters:**
- `event`: The domain event to raise

**Description:** 
- Adds the event to an internal list of uncommitted events
- Does not automatically publish the event
- Should be called within domain logic when significant operations occur

**Example:**
```dart
class Order extends AggregateRoot {
  void ship(String trackingNumber) {
    // Update state
    status = OrderStatus.shipped;
    
    // Raise event
    raiseEvent(OrderShipped(
      orderId: id.uuid,
      trackingNumber: trackingNumber,
    ));
  }
}
```

#### `getUncommittedEvents()`
Returns an unmodifiable list of uncommitted events.

```dart
List<DomainEvent> getUncommittedEvents()
```

**Returns:** Unmodifiable list of domain events that have been raised but not yet committed.

**Description:**
- Returns events in the order they were raised
- List is unmodifiable to prevent external modification
- Typically called by infrastructure code to retrieve events for publishing

**Example:**
```dart
final order = Order.place(customerId: 'customer-123', items: items);
final events = order.getUncommittedEvents();

for (final event in events) {
  eventBus.publish(event);
}
```

#### `markEventsAsCommitted()`
Clears the list of uncommitted events.

```dart
void markEventsAsCommitted()
```

**Description:**
- Removes all events from the uncommitted events list
- Should be called after events have been successfully published
- Prevents duplicate publishing of the same events

**Example:**
```dart
// After publishing events
for (final event in order.getUncommittedEvents()) {
  eventBus.publish(event);
}

// Mark as committed
order.markEventsAsCommitted();

// Now list is empty
assert(order.getUncommittedEvents().isEmpty);
```

### Usage Example

```dart
class Order extends AggregateRoot {
  final String customerId;
  final List<OrderItem> items;
  OrderStatus status;
  
  Order._({
    required this.customerId,
    required this.items,
    this.status = OrderStatus.pending,
    super.id,
  });
  
  // Factory method that raises event
  factory Order.place({
    required String customerId,
    required List<OrderItem> items,
  }) {
    final order = Order._(
      customerId: customerId,
      items: items,
    );
    
    // Raise domain event
    order.raiseEvent(OrderPlaced(
      orderId: order.id.uuid,
      customerId: customerId,
      items: items,
    ));
    
    return order;
  }
  
  // Business method that raises event
  void ship(String trackingNumber) {
    if (status != OrderStatus.pending) {
      throw StateError('Only pending orders can be shipped');
    }
    
    status = OrderStatus.shipped;
    
    raiseEvent(OrderShipped(
      orderId: id.uuid,
      trackingNumber: trackingNumber,
    ));
  }
}

// Usage
final order = Order.place(
  customerId: 'customer-123',
  items: [OrderItem(productId: 'prod-1', quantity: 2)],
);

// Get and publish events
final events = order.getUncommittedEvents();
for (final event in events) {
  eventBus.publish(event);
}

// Mark as committed
order.markEventsAsCommitted();
```

---

## EventBus

Local event bus for publishing and subscribing to domain events.

### Class Definition

```dart
class EventBus {
  EventBus();
  
  void publish(DomainEvent event);
  Stream<T> on<T extends DomainEvent>();
  Future<void> close();
  bool get isClosed;
}
```

### Constructor

```dart
EventBus()
```

Creates a new EventBus instance with a broadcast stream controller.

### Methods

#### `publish()`
Publishes a domain event to all subscribers.

```dart
void publish(DomainEvent event)
```

**Parameters:**
- `event`: The domain event to publish

**Throws:**
- `StateError` if the EventBus is closed

**Description:**
- Delivers the event to all active subscribers
- Events are delivered asynchronously via Dart streams
- If a listener throws an error, other listeners still receive the event

**Example:**
```dart
final eventBus = EventBus();

final event = UserRegistered(
  userId: UuidValue.generate(),
  email: 'test@example.com',
  fullName: 'Test User',
);

eventBus.publish(event);
```

#### `on<T>()`
Subscribes to events of a specific type.

```dart
Stream<T> on<T extends DomainEvent>()
```

**Type Parameters:**
- `T`: The type of domain event to subscribe to. Must extend `DomainEvent`.

**Returns:** A `Stream<T>` that emits only events of type `T` or its subtypes.

**Description:**
- Creates a type-safe subscription to specific event types
- Multiple subscriptions can be created for the same or different types
- Uses Dart's stream filtering for efficient type-based routing
- Subscription is active until cancelled or EventBus is closed

**Example:**
```dart
// Subscribe to specific event type
final subscription = eventBus.on<UserRegistered>().listen((event) {
  print('User registered: ${event.email}');
});

// Subscribe to different event type
eventBus.on<OrderPlaced>().listen((event) {
  print('Order placed: ${event.aggregateId}');
});

// Cancel subscription when done
await subscription.cancel();
```

#### `close()`
Closes the event bus and releases resources.

```dart
Future<void> close()
```

**Returns:** A `Future` that completes when the EventBus is closed.

**Description:**
- Closes the underlying stream controller
- Completes all active subscriptions
- After closing, no more events can be published
- Attempting to publish after closing throws `StateError`

**Example:**
```dart
final eventBus = EventBus();

// Use the event bus...

// Clean up when done
await eventBus.close();
```

#### `isClosed`
Returns whether the event bus has been closed.

```dart
bool get isClosed
```

**Returns:** `true` if the EventBus is closed, `false` otherwise.

**Example:**
```dart
final eventBus = EventBus();
print(eventBus.isClosed);  // false

await eventBus.close();
print(eventBus.isClosed);  // true
```

### Usage Examples

#### Basic Publish/Subscribe

```dart
final eventBus = EventBus();

// Subscribe
eventBus.on<UserRegistered>().listen((event) {
  print('User registered: ${event.email}');
});

// Publish
eventBus.publish(UserRegistered(
  userId: UuidValue.generate(),
  email: 'test@example.com',
  fullName: 'Test User',
));

// Clean up
await eventBus.close();
```

#### Multiple Listeners

```dart
final eventBus = EventBus();

// Email service
eventBus.on<UserRegistered>().listen((event) {
  emailService.sendWelcomeEmail(event.email);
});

// Analytics service
eventBus.on<UserRegistered>().listen((event) {
  analyticsService.trackRegistration(event.aggregateId);
});

// Profile service
eventBus.on<UserRegistered>().listen((event) {
  profileService.createProfile(event.aggregateId);
});
```

#### Error Handling

```dart
eventBus.on<OrderPlaced>().listen(
  (event) async {
    try {
      await processOrder(event);
    } catch (e) {
      logger.error('Failed to process order', e);
    }
  },
  onError: (error) {
    logger.error('Event handler error', error);
  },
);
```

#### Managing Subscriptions

```dart
class MyService {
  final EventBus eventBus;
  final List<StreamSubscription> _subscriptions = [];
  
  MyService(this.eventBus) {
    _setupListeners();
  }
  
  void _setupListeners() {
    _subscriptions.add(
      eventBus.on<UserRegistered>().listen(_handleUserRegistered),
    );
    
    _subscriptions.add(
      eventBus.on<OrderPlaced>().listen(_handleOrderPlaced),
    );
  }
  
  void _handleUserRegistered(UserRegistered event) {
    // Handle event
  }
  
  void _handleOrderPlaced(OrderPlaced event) {
    // Handle event
  }
  
  Future<void> dispose() async {
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
  }
}
```

---

## Repository

Base interface for repositories that manage aggregate roots.

### Interface Definition

```dart
abstract interface class Repository<T extends AggregateRoot> {
  Future<T> getById(UuidValue id);
  Future<void> save(T aggregate);
  Future<void> deleteById(UuidValue id);
}
```

### Type Parameters

- `T`: The aggregate root type. Must extend `AggregateRoot`.

### Methods

#### `getById()`
Retrieves an aggregate root by its ID.

```dart
Future<T> getById(UuidValue id)
```

**Parameters:**
- `id`: The unique identifier of the aggregate to retrieve

**Returns:** A `Future` that completes with the aggregate root

**Throws:**
- `RepositoryException` with type `notFound` if no aggregate with the given ID exists
- `RepositoryException` for other failures (connection errors, timeouts, etc.)

**Description:**
- Asynchronous operation that retrieves an aggregate from storage
- Throws an exception if the aggregate doesn't exist (no null returns)
- Rationale: If you have a UUID, you expect it to exist

**Example:**
```dart
final userId = UuidValue.fromString('123e4567-e89b-12d3-a456-426614174000');

try {
  final user = await userRepository.getById(userId);
  print('Found user: ${user.name}');
} on RepositoryException catch (e) {
  if (e.type == RepositoryExceptionType.notFound) {
    print('User not found');
  } else {
    print('Error retrieving user: ${e.message}');
  }
}
```

#### `save()`
Saves an aggregate root to the repository.

```dart
Future<void> save(T aggregate)
```

**Parameters:**
- `aggregate`: The aggregate root to save

**Returns:** A `Future` that completes when the save operation finishes

**Throws:**
- `RepositoryException` if the operation fails

**Description:**
- Performs an upsert operation (insert if new, update if exists)
- Uses the aggregate's `id` property as the key
- Asynchronous to support both local and remote storage

**Example:**
```dart
final user = User(name: 'John Doe', email: 'john@example.com');

try {
  await userRepository.save(user);
  print('User saved successfully');
} on RepositoryException catch (e) {
  print('Failed to save user: ${e.message}');
}
```

#### `deleteById()`
Deletes an aggregate root by its ID.

```dart
Future<void> deleteById(UuidValue id)
```

**Parameters:**
- `id`: The unique identifier of the aggregate to delete

**Returns:** A `Future` that completes when the delete operation finishes

**Throws:**
- `RepositoryException` with type `notFound` if no aggregate with the given ID exists
- `RepositoryException` for other failures

**Description:**
- Removes the aggregate from storage
- Throws an exception if the aggregate doesn't exist
- Consistent with `getById` behavior (if you have a UUID, it should exist)

**Example:**
```dart
final userId = UuidValue.fromString('123e4567-e89b-12d3-a456-426614174000');

try {
  await userRepository.deleteById(userId);
  print('User deleted successfully');
} on RepositoryException catch (e) {
  if (e.type == RepositoryExceptionType.notFound) {
    print('User not found');
  } else {
    print('Error deleting user: ${e.message}');
  }
}
```

### Usage Examples

#### Basic CRUD Operations

```dart
import 'package:dddart/dddart.dart';

// Define your aggregate
class User extends AggregateRoot {
  final String name;
  final String email;
  
  User({
    required this.name,
    required this.email,
    super.id,
  });
}

void main() async {
  // Create repository
  final repository = InMemoryRepository<User>();
  
  // Create and save
  final user = User(name: 'John Doe', email: 'john@example.com');
  await repository.save(user);
  
  // Retrieve
  final retrieved = await repository.getById(user.id);
  print('Retrieved: ${retrieved.name}');
  
  // Update (save again with same ID)
  final updated = User(
    name: 'John Smith',
    email: 'john@example.com',
    id: user.id,
  );
  await repository.save(updated);
  
  // Delete
  await repository.deleteById(user.id);
}
```

#### Custom Repository Interface

```dart
// Define domain-specific repository interface
abstract interface class UserRepository implements Repository<User> {
  Future<User?> getByEmail(String email);
  Future<List<User>> getByFirstName(String firstName);
  Future<List<User>> getActiveUsers();
}

// Implement for specific data store
class MySqlUserRepository implements UserRepository {
  final MySqlConnection connection;
  
  MySqlUserRepository(this.connection);
  
  @override
  Future<User> getById(UuidValue id) async {
    final result = await connection.query(
      'SELECT * FROM users WHERE id = ?',
      [id.uuid],
    );
    
    if (result.isEmpty) {
      throw RepositoryException(
        'User with ID $id not found',
        type: RepositoryExceptionType.notFound,
      );
    }
    
    return User.fromMap(result.first);
  }
  
  @override
  Future<void> save(User aggregate) async {
    await connection.query(
      '''
      INSERT INTO users (id, name, email, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?)
      ON DUPLICATE KEY UPDATE
        name = VALUES(name),
        email = VALUES(email),
        updated_at = VALUES(updated_at)
      ''',
      [
        aggregate.id.uuid,
        aggregate.name,
        aggregate.email,
        aggregate.createdAt,
        aggregate.updatedAt,
      ],
    );
  }
  
  @override
  Future<void> deleteById(UuidValue id) async {
    final result = await connection.query(
      'DELETE FROM users WHERE id = ?',
      [id.uuid],
    );
    
    if (result.affectedRows == 0) {
      throw RepositoryException(
        'User with ID $id not found',
        type: RepositoryExceptionType.notFound,
      );
    }
  }
  
  @override
  Future<User?> getByEmail(String email) async {
    final result = await connection.query(
      'SELECT * FROM users WHERE email = ?',
      [email],
    );
    
    return result.isEmpty ? null : User.fromMap(result.first);
  }
  
  @override
  Future<List<User>> getByFirstName(String firstName) async {
    final result = await connection.query(
      'SELECT * FROM users WHERE name LIKE ?',
      ['$firstName%'],
    );
    
    return result.map((row) => User.fromMap(row)).toList();
  }
  
  @override
  Future<List<User>> getActiveUsers() async {
    final result = await connection.query(
      'SELECT * FROM users WHERE status = ?',
      ['active'],
    );
    
    return result.map((row) => User.fromMap(row)).toList();
  }
}
```

#### Error Handling

```dart
Future<void> updateUser(UuidValue userId, String newName) async {
  try {
    // Retrieve user
    final user = await userRepository.getById(userId);
    
    // Update user
    final updated = User(
      name: newName,
      email: user.email,
      id: user.id,
    );
    
    // Save changes
    await userRepository.save(updated);
    
    print('User updated successfully');
  } on RepositoryException catch (e) {
    switch (e.type) {
      case RepositoryExceptionType.notFound:
        print('User not found');
      case RepositoryExceptionType.connection:
        print('Database connection error');
      case RepositoryExceptionType.timeout:
        print('Operation timed out');
      default:
        print('Unexpected error: ${e.message}');
    }
  }
}
```

#### Integration with Domain Events

```dart
class Order extends AggregateRoot {
  final String customerId;
  final List<OrderItem> items;
  OrderStatus status;
  
  Order._({
    required this.customerId,
    required this.items,
    this.status = OrderStatus.pending,
    super.id,
  });
  
  factory Order.place({
    required String customerId,
    required List<OrderItem> items,
  }) {
    final order = Order._(
      customerId: customerId,
      items: items,
    );
    
    order.raiseEvent(OrderPlaced(
      orderId: order.id.uuid,
      customerId: customerId,
    ));
    
    return order;
  }
  
  void ship(String trackingNumber) {
    status = OrderStatus.shipped;
    
    raiseEvent(OrderShipped(
      orderId: id.uuid,
      trackingNumber: trackingNumber,
    ));
  }
}

// Usage with repository and event bus
Future<void> placeOrder(String customerId, List<OrderItem> items) async {
  final eventBus = EventBus();
  final orderRepository = InMemoryRepository<Order>();
  
  // Create order (raises OrderPlaced event)
  final order = Order.place(
    customerId: customerId,
    items: items,
  );
  
  // Save to repository
  await orderRepository.save(order);
  
  // Publish domain events
  for (final event in order.getUncommittedEvents()) {
    eventBus.publish(event);
  }
  
  // Mark events as committed
  order.markEventsAsCommitted();
  
  print('Order placed: ${order.id.uuid}');
}
```

#### Testing with InMemoryRepository

```dart
void main() {
  group('UserService', () {
    late UserRepository repository;
    late UserService service;
    
    setUp(() {
      repository = InMemoryRepository<User>();
      service = UserService(repository);
    });
    
    test('creates user successfully', () async {
      final user = await service.createUser(
        name: 'John Doe',
        email: 'john@example.com',
      );
      
      expect(user.name, equals('John Doe'));
      
      // Verify it was saved
      final retrieved = await repository.getById(user.id);
      expect(retrieved.name, equals('John Doe'));
    });
    
    test('throws when user not found', () async {
      final nonExistentId = UuidValue.generate();
      
      expect(
        () => repository.getById(nonExistentId),
        throwsA(isA<RepositoryException>()),
      );
    });
  });
}
```

---

## InMemoryRepository

In-memory implementation of the Repository interface for testing purposes.

### Class Definition

```dart
class InMemoryRepository<T extends AggregateRoot> implements Repository<T> {
  InMemoryRepository();
  
  @override
  Future<T> getById(UuidValue id);
  
  @override
  Future<void> save(T aggregate);
  
  @override
  Future<void> deleteById(UuidValue id);
  
  void clear();
  List<T> getAll();
}
```

### Type Parameters

- `T`: The aggregate root type. Must extend `AggregateRoot`.

### Constructor

```dart
InMemoryRepository()
```

Creates a new in-memory repository with empty storage.

### Methods

#### `getById()`
Retrieves an aggregate from memory by its ID.

```dart
Future<T> getById(UuidValue id)
```

**Implementation Details:**
- Looks up aggregate in internal Map storage
- Throws `RepositoryException` with type `notFound` if not present
- Returns immediately (wrapped in Future for interface consistency)

#### `save()`
Saves an aggregate to memory.

```dart
Future<void> save(T aggregate)
```

**Implementation Details:**
- Stores aggregate in internal Map using its ID as key
- Performs upsert (overwrites if ID already exists)
- Returns immediately (wrapped in Future for interface consistency)

#### `deleteById()`
Removes an aggregate from memory by its ID.

```dart
Future<void> deleteById(UuidValue id)
```

**Implementation Details:**
- Removes aggregate from internal Map
- Throws `RepositoryException` with type `notFound` if not present
- Returns immediately (wrapped in Future for interface consistency)

#### `clear()`
Removes all aggregates from the repository.

```dart
void clear()
```

**Description:**
- Utility method for test cleanup
- Empties the internal storage Map
- Not part of the Repository interface

**Example:**
```dart
final repository = InMemoryRepository<User>();

// Add some users
await repository.save(user1);
await repository.save(user2);

// Clear all
repository.clear();

// Repository is now empty
expect(repository.getAll(), isEmpty);
```

#### `getAll()`
Returns all aggregates in the repository.

```dart
List<T> getAll()
```

**Returns:** An unmodifiable list of all stored aggregates

**Description:**
- Utility method for testing and debugging
- Returns unmodifiable list to prevent external modification
- Not part of the Repository interface
- Order is not guaranteed

**Example:**
```dart
final repository = InMemoryRepository<User>();

await repository.save(user1);
await repository.save(user2);

final allUsers = repository.getAll();
expect(allUsers.length, equals(2));
```

### Usage Examples

#### Basic Testing

```dart
void main() {
  test('repository stores and retrieves aggregates', () async {
    final repository = InMemoryRepository<User>();
    
    final user = User(name: 'John Doe', email: 'john@example.com');
    await repository.save(user);
    
    final retrieved = await repository.getById(user.id);
    expect(retrieved.id, equals(user.id));
    expect(retrieved.name, equals('John Doe'));
  });
  
  test('repository throws when aggregate not found', () async {
    final repository = InMemoryRepository<User>();
    final nonExistentId = UuidValue.generate();
    
    expect(
      () => repository.getById(nonExistentId),
      throwsA(
        isA<RepositoryException>()
          .having((e) => e.type, 'type', RepositoryExceptionType.notFound),
      ),
    );
  });
}
```

#### Test Isolation

```dart
void main() {
  group('UserService', () {
    late InMemoryRepository<User> repository;
    late UserService service;
    
    setUp(() {
      // Fresh repository for each test
      repository = InMemoryRepository<User>();
      service = UserService(repository);
    });
    
    tearDown(() {
      // Clean up (optional, since setUp creates new instance)
      repository.clear();
    });
    
    test('creates user', () async {
      final user = await service.createUser('John', 'john@example.com');
      expect(repository.getAll().length, equals(1));
    });
    
    test('updates user', () async {
      final user = await service.createUser('John', 'john@example.com');
      await service.updateUserName(user.id, 'Jane');
      
      final updated = await repository.getById(user.id);
      expect(updated.name, equals('Jane'));
    });
  });
}
```

#### Multiple Aggregate Types

```dart
void main() {
  test('different repositories store different types', () async {
    final userRepo = InMemoryRepository<User>();
    final orderRepo = InMemoryRepository<Order>();
    
    final user = User(name: 'John', email: 'john@example.com');
    final order = Order.place(customerId: 'customer-1', items: []);
    
    await userRepo.save(user);
    await orderRepo.save(order);
    
    expect(userRepo.getAll().length, equals(1));
    expect(orderRepo.getAll().length, equals(1));
    
    // Type safety enforced
    final retrievedUser = await userRepo.getById(user.id);
    expect(retrievedUser, isA<User>());
  });
}
```

### Performance Characteristics

- **getById**: O(1) - HashMap lookup
- **save**: O(1) - HashMap insert/update
- **deleteById**: O(1) - HashMap removal
- **getAll**: O(n) - Iterates all values
- **clear**: O(n) - Clears HashMap
- **Memory**: O(n) where n is number of stored aggregates

### Limitations

- **Not thread-safe**: Concurrent access may cause issues
- **No persistence**: Data lost when process ends
- **No transactions**: Operations are not atomic
- **No indexing**: Only lookup by ID is efficient
- **Memory bound**: Limited by available RAM

**Use Cases:**
- Unit testing
- Integration testing
- Prototyping
- Examples and demos

**Not Suitable For:**
- Production applications
- Large datasets
- Concurrent access scenarios
- Data that needs persistence

---

## RepositoryException

Exception thrown when a repository operation fails.

### Class Definition

```dart
class RepositoryException implements Exception {
  const RepositoryException(
    this.message, {
    this.type = RepositoryExceptionType.unknown,
    this.cause,
  });
  
  final String message;
  final RepositoryExceptionType type;
  final Object? cause;
  
  @override
  String toString();
}
```

### Properties

#### `message`
- **Type:** `String`
- **Description:** Human-readable error message describing what went wrong
- **Read-only:** Yes

#### `type`
- **Type:** `RepositoryExceptionType`
- **Description:** Classification of the error for programmatic handling
- **Read-only:** Yes
- **Default:** `RepositoryExceptionType.unknown`

#### `cause`
- **Type:** `Object?`
- **Description:** Optional underlying exception that caused this error
- **Read-only:** Yes
- **Default:** `null`

### Constructor

```dart
const RepositoryException(
  this.message, {
  this.type = RepositoryExceptionType.unknown,
  this.cause,
})
```

**Parameters:**
- `message` (required): Human-readable error description
- `type` (optional): Error classification. Defaults to `unknown`.
- `cause` (optional): Underlying exception. Defaults to `null`.

### Methods

#### `toString()`
Returns a string representation of the exception.

```dart
String toString()
```

**Returns:** String in format `RepositoryException: message (type: type)` or `RepositoryException: message (type: type, cause: cause)` if cause is present

**Example:**
```dart
final exception = RepositoryException(
  'User not found',
  type: RepositoryExceptionType.notFound,
);
print(exception.toString());
// Output: RepositoryException: User not found (type: RepositoryExceptionType.notFound)
```

### RepositoryExceptionType Enum

```dart
enum RepositoryExceptionType {
  notFound,
  duplicate,
  constraint,
  connection,
  timeout,
  unknown,
}
```

#### Values

- **notFound**: The requested aggregate was not found
- **duplicate**: A duplicate aggregate already exists (e.g., unique constraint violation)
- **constraint**: The operation violated a database constraint
- **connection**: A connection or network error occurred
- **timeout**: The operation timed out
- **unknown**: An unknown or unexpected error occurred

### Usage Examples

#### Basic Error Handling

```dart
try {
  final user = await userRepository.getById(userId);
  print('Found user: ${user.name}');
} on RepositoryException catch (e) {
  print('Error: ${e.message}');
  print('Type: ${e.type}');
}
```

#### Type-Specific Handling

```dart
try {
  await userRepository.save(user);
} on RepositoryException catch (e) {
  switch (e.type) {
    case RepositoryExceptionType.notFound:
      // Handle not found
      showError('Item not found');
    case RepositoryExceptionType.duplicate:
      // Handle duplicate
      showError('Item already exists');
    case RepositoryExceptionType.connection:
      // Handle connection error
      showError('Connection failed. Please try again.');
    case RepositoryExceptionType.timeout:
      // Handle timeout
      showError('Operation timed out');
    case RepositoryExceptionType.constraint:
      // Handle constraint violation
      showError('Operation violates data constraints');
    case RepositoryExceptionType.unknown:
      // Handle unknown error
      showError('An unexpected error occurred');
  }
}
```

#### Wrapping Underlying Exceptions

```dart
class MySqlUserRepository implements UserRepository {
  @override
  Future<User> getById(UuidValue id) async {
    try {
      final result = await connection.query(
        'SELECT * FROM users WHERE id = ?',
        [id.uuid],
      );
      
      if (result.isEmpty) {
        throw RepositoryException(
          'User with ID $id not found',
          type: RepositoryExceptionType.notFound,
        );
      }
      
      return User.fromMap(result.first);
    } on MySqlException catch (e) {
      if (e.errorNumber == 2006) {
        // MySQL server has gone away
        throw RepositoryException(
          'Database connection lost',
          type: RepositoryExceptionType.connection,
          cause: e,
        );
      }
      
      throw RepositoryException(
        'Failed to retrieve user',
        type: RepositoryExceptionType.unknown,
        cause: e,
      );
    }
  }
}
```

#### Logging with Cause

```dart
try {
  await repository.save(user);
} on RepositoryException catch (e) {
  logger.error('Repository operation failed: ${e.message}');
  
  if (e.cause != null) {
    logger.error('Caused by: ${e.cause}');
    logger.error('Stack trace: ${StackTrace.current}');
  }
  
  rethrow;
}
```

#### Custom Exception Messages

```dart
Future<void> deleteUser(UuidValue userId) async {
  try {
    await userRepository.deleteById(userId);
  } on RepositoryException catch (e) {
    if (e.type == RepositoryExceptionType.notFound) {
      throw RepositoryException(
        'Cannot delete user $userId: user does not exist',
        type: RepositoryExceptionType.notFound,
        cause: e,
      );
    }
    rethrow;
  }
}
```

---

## Entity

Base class for domain entities with identity and lifecycle management.

### Class Definition

```dart
abstract class Entity {
  final UuidValue id;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  Entity({
    UuidValue? id,
    DateTime? createdAt,
    DateTime? updatedAt,
  });
}
```

### Properties

#### `id`
- **Type:** `UuidValue`
- **Description:** Unique identifier for the entity. Auto-generated if not provided.
- **Read-only:** Yes

#### `createdAt`
- **Type:** `DateTime`
- **Description:** Timestamp when the entity was created. Defaults to current time.
- **Read-only:** Yes

#### `updatedAt`
- **Type:** `DateTime`
- **Description:** Timestamp when the entity was last updated. Defaults to current time.
- **Read-only:** Yes

### Constructor

```dart
Entity({
  UuidValue? id,
  DateTime? createdAt,
  DateTime? updatedAt,
})
```

### Methods

#### `operator ==`
Compares entities based on their ID.

```dart
bool operator ==(Object other)
```

#### `hashCode`
Returns hash code based on entity ID.

```dart
int get hashCode
```

### Usage Example

```dart
class User extends Entity {
  final String name;
  final String email;
  
  User({
    required this.name,
    required this.email,
    super.id,
    super.createdAt,
    super.updatedAt,
  });
}

final user = User(name: 'John Doe', email: 'john@example.com');
print(user.id.uuid);        // Auto-generated UUID
print(user.createdAt);      // Current timestamp
```

---

## Value

Base class for immutable value objects.

### Class Definition

```dart
abstract class Value {
  const Value();
  
  List<Object?> get props;
}
```

### Properties

#### `props`
- **Type:** `List<Object?>`
- **Description:** List of properties used for equality comparison. Must be overridden.
- **Read-only:** Yes

### Methods

#### `operator ==`
Compares value objects based on their properties.

```dart
bool operator ==(Object other)
```

#### `hashCode`
Returns hash code based on properties.

```dart
int get hashCode
```

### Usage Example

```dart
class Money extends Value {
  final double amount;
  final String currency;
  
  const Money(this.amount, this.currency);
  
  @override
  List<Object?> get props => [amount, currency];
}

final price1 = Money(100.0, 'USD');
final price2 = Money(100.0, 'USD');
print(price1 == price2);  // true
```

---

## UuidValue

Value object wrapper for UUID strings.

### Class Definition

```dart
class UuidValue extends Value {
  final String uuid;
  
  UuidValue([String? uuid]);
  
  @override
  List<Object?> get props => [uuid];
}
```

### Properties

#### `uuid`
- **Type:** `String`
- **Description:** The UUID string. Auto-generated if not provided.
- **Read-only:** Yes

### Constructor

```dart
UuidValue([String? uuid])
```

**Parameters:**
- `uuid` (optional): Custom UUID string. Auto-generated using UUID v4 if not provided.

### Usage Example

```dart
// Auto-generated UUID
final id1 = UuidValue();
print(id1.uuid);  // e.g., '123e4567-e89b-12d3-a456-426614174000'

// Custom UUID
final id2 = UuidValue('custom-id-123');
print(id2.uuid);  // 'custom-id-123'

// Equality
final id3 = UuidValue('same-id');
final id4 = UuidValue('same-id');
print(id3 == id4);  // true
```

---

## Complete Example

Here's a complete example using all the main APIs:

```dart
import 'package:dddart/dddart.dart';

// 1. Define domain event
class OrderPlaced extends DomainEvent {
  final String customerId;
  final double totalAmount;
  
  OrderPlaced({
    required String orderId,
    required this.customerId,
    required this.totalAmount,
  }) : super(aggregateId: orderId);
}

// 2. Define aggregate root
class Order extends AggregateRoot {
  final String customerId;
  final List<String> items;
  
  Order._({
    required this.customerId,
    required this.items,
    super.id,
  });
  
  factory Order.place({
    required String customerId,
    required List<String> items,
    required double totalAmount,
  }) {
    final order = Order._(
      customerId: customerId,
      items: items,
    );
    
    order.raiseEvent(OrderPlaced(
      orderId: order.id.uuid,
      customerId: customerId,
      totalAmount: totalAmount,
    ));
    
    return order;
  }
}

// 3. Use the event system
void main() async {
  // Create event bus
  final eventBus = EventBus();
  
  // Set up event handler
  eventBus.on<OrderPlaced>().listen((event) {
    print('Order placed: ${event.aggregateId}');
    print('Customer: ${event.customerId}');
    print('Total: \$${event.totalAmount}');
  });
  
  // Create aggregate
  final order = Order.place(
    customerId: 'customer-123',
    items: ['item-1', 'item-2'],
    totalAmount: 299.99,
  );
  
  // Publish events
  for (final event in order.getUncommittedEvents()) {
    eventBus.publish(event);
  }
  
  // Mark as committed
  order.markEventsAsCommitted();
  
  // Clean up
  await Future.delayed(Duration(milliseconds: 100));
  await eventBus.close();
}
```

**Output:**
```
📦 Order placed: 123e4567-e89b-12d3-a456-426614174000
   Customer: customer-123
   Total: $299.99
🚚 Order shipped: 123e4567-e89b-12d3-a456-426614174000
   Tracking: TRACK-123456

📊 Customer has 1 order(s)
```

---

## See Also

- [README.md](README.md) - Main documentation and quick start guide
- [DOMAIN_EVENTS_GUIDE.md](DOMAIN_EVENTS_GUIDE.md) - Comprehensive guide to domain events
- [example/](../../example) - Working examples and usage patterns
