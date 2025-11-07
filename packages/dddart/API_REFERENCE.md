# DDDart API Reference

Complete API reference for the DDDart domain events system.

## Table of Contents

- [DomainEvent](#domainevent)
- [AggregateRoot](#aggregateroot)
- [EventBus](#eventbus)
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

---

## See Also

- [README.md](README.md) - Main documentation and quick start guide
- [DOMAIN_EVENTS_GUIDE.md](DOMAIN_EVENTS_GUIDE.md) - Comprehensive guide to domain events
- [example/](../../example) - Working examples and usage patterns
