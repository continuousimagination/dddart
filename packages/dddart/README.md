# DDDart

A lightweight Domain-Driven Design (DDD) framework for Dart that provides base classes and utilities to help developers implement DDD principles in their applications.

## Features

- **Entity**: Base class for domain entities with identity and lifecycle timestamps
- **Aggregate Root**: Base class for aggregate root entities with domain event support
- **Value Object**: Base class for immutable value types
- **Domain Events**: Event-driven architecture with local publish/subscribe
- **Event Bus**: Type-safe event distribution system
- Automatic GUID generation for entity IDs and event IDs
- Automatic timestamp management (createdAt, updatedAt, occurredAt)

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  dddart: ^1.0.0
```

Then run:

```bash
dart pub get
```

## Quick Start

### Creating Entities

```dart
import 'package:dddart/dddart.dart';

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
```

### Creating Aggregate Roots with Events

```dart
import 'package:dddart/dddart.dart';

// Define a domain event
class OrderPlaced extends DomainEvent {
  final String customerId;
  final double totalAmount;
  
  OrderPlaced({
    required UuidValue orderId,
    required this.customerId,
    required this.totalAmount,
  }) : super(aggregateId: orderId);
}

// Create an aggregate that raises events
class Order extends AggregateRoot {
  final String customerId;
  final List<OrderItem> items;
  
  Order._({
    required this.customerId,
    required this.items,
    super.id,
    super.createdAt,
    super.updatedAt,
  });
  
  // Factory method that raises domain event
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
      orderId: order.id,
      customerId: customerId,
      totalAmount: items.fold(0, (sum, item) => sum + item.price),
    ));
    
    return order;
  }
}
```

### Creating Value Objects

```dart
import 'package:dddart/dddart.dart';

class Money extends Value {
  final double amount;
  final String currency;
  
  const Money(this.amount, this.currency);
  
  @override
  List<Object?> get props => [amount, currency];
}
```

### Using the Event Bus

```dart
import 'package:dddart/dddart.dart';

void main() async {
  // Create an event bus
  final eventBus = EventBus();
  
  // Subscribe to events
  eventBus.on<OrderPlaced>().listen((event) {
    print('Order placed: ${event.aggregateId}');
    // Send confirmation email, update inventory, etc.
  });
  
  // Create an aggregate
  final order = Order.place(
    customerId: 'customer-123',
    items: [/* order items */],
  );
  
  // Publish events
  for (final event in order.getUncommittedEvents()) {
    eventBus.publish(event);
  }
  
  // Mark events as committed
  order.markEventsAsCommitted();
  
  // Clean up
  await eventBus.close();
}
```

## Core Concepts

### Domain Events

Domain events represent something significant that happened in your domain. They are immutable records of business occurrences that other parts of your system may need to react to.

**Key characteristics:**
- Immutable - events cannot be changed after creation
- Named in past tense - `OrderPlaced`, `UserRegistered`, `PaymentProcessed`
- Include relevant context - aggregate ID (as UuidValue), timestamp, and additional metadata
- Type-safe IDs - uses UuidValue for aggregate and event IDs to enforce GUID usage
- Serializable - can be persisted or transmitted across boundaries

### Aggregate Roots

Aggregate roots are the entry points to aggregates and serve as consistency boundaries. They collect domain events as business operations occur.

**Event lifecycle in aggregates:**
1. **Raise** - Events are raised during domain operations using `raiseEvent()`
2. **Collect** - Events are stored in an internal list as "uncommitted"
3. **Retrieve** - Infrastructure code retrieves events with `getUncommittedEvents()`
4. **Publish** - Events are published to the EventBus or message broker
5. **Commit** - Events are marked as committed with `markEventsAsCommitted()`

### Event Bus

The EventBus provides local publish/subscribe functionality for domain events within a single application instance.

**Features:**
- Type-safe subscriptions using generics
- Multiple listeners per event type
- Broadcast delivery to all subscribers
- Built on Dart's Stream API
- Platform-independent (works on server, web, mobile)

## Logging

DDDart integrates with the official Dart `logging` package to provide optional diagnostic logging across all components. Logging is completely optional - DDDart works perfectly without any logging configuration.

### Hierarchical Logger Structure

DDDart uses a hierarchical logger structure with `dddart` as the root:

```
dddart (root)
├── dddart.eventbus    - Event publishing and subscriptions
├── dddart.repository  - Repository operations (save, retrieve, delete)
└── dddart.http        - HTTP request handling (in dddart_http package)
```

This structure allows you to configure logging levels independently for each component or set a global level for all DDDart components.

### Console Logging

Enable console logging to see DDDart diagnostic messages in your terminal:

```dart
import 'package:logging/logging.dart';
import 'package:dddart/dddart.dart';

void main() {
  // Configure console logging
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });
  
  // Use DDDart components - they will log automatically
  final eventBus = EventBus();
  final repository = InMemoryRepository<User>();
  
  // Logs will appear in console:
  // FINE: 2024-01-15 10:30:45.123: Publishing event: OrderPlaced for aggregate abc-123
  // FINE: 2024-01-15 10:30:45.456: Saving User with ID: def-456
}
```

### File Logging

Write logs to a file using the built-in `FileLogHandler`:

```dart
import 'package:logging/logging.dart';
import 'package:dddart/dddart.dart';

void main() async {
  // Configure file logging
  final fileHandler = FileLogHandler('app.log');
  
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen(fileHandler);
  
  // Use DDDart components
  final eventBus = EventBus();
  final repository = InMemoryRepository<User>();
  
  // Logs will be written to app.log with format:
  // [2024-01-15T10:30:45.123456] [FINE] [dddart.eventbus] Publishing event: OrderPlaced
  
  // Clean up when done
  await fileHandler.close();
}
```

### Component-Specific Log Levels

Configure different log levels for different components:

```dart
import 'package:logging/logging.dart';
import 'package:dddart/dddart.dart';

void main() {
  // Set default level for all loggers
  Logger.root.level = Level.INFO;
  
  // Enable detailed logging for EventBus only
  Logger('dddart.eventbus').level = Level.FINE;
  
  // Disable repository logging completely
  Logger('dddart.repository').level = Level.OFF;
  
  // Enable HTTP logging at warning level (in dddart_http)
  Logger('dddart.http').level = Level.WARNING;
  
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.message}');
  });
  
  // EventBus will log detailed FINE messages
  // Repository will not log at all
  // HTTP will only log warnings and errors
}
```

### Log Levels

DDDart components use these log levels:

- **FINE** - Detailed tracing (event publishing, repository operations, HTTP responses)
- **INFO** - Informational messages (EventBus closed, HTTP requests received)
- **WARNING** - Warnings (deserialization failures, validation issues)
- **SEVERE** - Errors (exceptions, operation failures, handler errors)

### Custom Log Formatting

Customize the log format by providing your own formatter:

```dart
import 'dart:convert';
import 'package:logging/logging.dart';
import 'package:dddart/dddart.dart';

// JSON formatter for structured logging
String jsonFormatter(LogRecord record) {
  return jsonEncode({
    'timestamp': record.time.toIso8601String(),
    'level': record.level.name,
    'logger': record.loggerName,
    'message': record.message,
    'error': record.error?.toString(),
    'stackTrace': record.stackTrace?.toString(),
  });
}

void main() async {
  final fileHandler = FileLogHandler('app.json', formatter: jsonFormatter);
  
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen(fileHandler);
  
  // Logs will be written as JSON objects
}
```

### Multiple Log Handlers

Send logs to multiple destinations simultaneously:

```dart
import 'package:logging/logging.dart';
import 'package:dddart/dddart.dart';

void main() async {
  // Log to both console and file
  final fileHandler = FileLogHandler('app.log');
  
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    // Console handler
    print('${record.level.name}: ${record.message}');
    
    // File handler
    fileHandler(record);
  });
  
  // All logs go to both console and file
  
  // Clean up
  await fileHandler.close();
}
```

### Disabling Logging

Logging is disabled by default. If you don't configure any handlers, DDDart components will still call logging methods, but the messages will be silently discarded with minimal performance overhead.

```dart
import 'package:dddart/dddart.dart';

void main() {
  // No logging configuration needed
  final eventBus = EventBus();
  final repository = InMemoryRepository<User>();
  
  // Components work normally, logging is a no-op
}
```

### What Gets Logged

**EventBus:**
- Event publishing (FINE): Event type and aggregate ID
- Subscription creation (FINE): Event type
- Handler exceptions (SEVERE): Exception and stack trace
- EventBus closed (INFO): Confirmation message

**Repository:**
- Save operations (FINE): Aggregate type and ID
- Retrieve operations (FINE): Aggregate type and ID
- Delete operations (FINE): Aggregate type and ID
- Operation failures (SEVERE): Exception and stack trace

**HTTP (dddart_http):**
- Incoming requests (INFO): HTTP method, path, aggregate type
- Responses (FINE): Status code
- Deserialization errors (WARNING): Error details
- Exceptions (SEVERE): Exception and stack trace

## Usage Guide

### Designing Domain Events

Follow these best practices when creating domain events:

```dart
// ✅ Good: Clear, past-tense name with relevant data
class UserRegistered extends DomainEvent {
  final String email;
  final String fullName;
  final String organizationId;
  
  UserRegistered({
    required UuidValue userId,
    required this.email,
    required this.fullName,
    required this.organizationId,
  }) : super(
    aggregateId: userId,
    context: {'organizationId': organizationId},
  );
}

// ❌ Bad: Present tense, missing context
class RegisterUser extends DomainEvent {
  final String email;
  
  RegisterUser(this.email) : super(aggregateId: '');
}
```

**Best practices:**
- Use past-tense naming (what happened, not what should happen)
- Include the aggregate ID that raised the event
- Add relevant data needed by event handlers
- Use the context map for filtering criteria
- Keep events focused on a single occurrence

### Raising Events in Aggregates

Events should be raised when significant business operations occur:

```dart
class User extends AggregateRoot {
  String email;
  String fullName;
  bool isActive;
  
  User._({
    required this.email,
    required this.fullName,
    this.isActive = true,
    super.id,
  });
  
  // Factory method for user registration
  factory User.register({
    required String email,
    required String fullName,
    required String organizationId,
  }) {
    final user = User._(email: email, fullName: fullName);
    
    // Raise event when user is created
    user.raiseEvent(UserRegistered(
      userId: user.id,
      email: email,
      fullName: fullName,
      organizationId: organizationId,
    ));
    
    return user;
  }
  
  // Business method that raises event
  void deactivate(String reason) {
    if (!isActive) {
      throw StateError('User is already deactivated');
    }
    
    isActive = false;
    
    // Raise event when state changes
    raiseEvent(UserDeactivated(
      userId: id.uuid,
      reason: reason,
      deactivatedAt: DateTime.now(),
    ));
  }
}
```

### Publishing Events

Events should be published after successful persistence to maintain consistency:

```dart
// In your repository or application service
Future<void> saveUser(User user) async {
  // 1. Persist the aggregate
  await database.save(user);
  
  // 2. Retrieve uncommitted events
  final events = user.getUncommittedEvents();
  
  // 3. Publish events to the bus
  for (final event in events) {
    eventBus.publish(event);
  }
  
  // 4. Mark events as committed
  user.markEventsAsCommitted();
}
```

### Setting Up Event Handlers

Create focused event handlers for different concerns:

```dart
class EmailService {
  final EventBus eventBus;
  final List<StreamSubscription> _subscriptions = [];
  
  EmailService(this.eventBus) {
    _setupListeners();
  }
  
  void _setupListeners() {
    // Handle user registration
    _subscriptions.add(
      eventBus.on<UserRegistered>().listen((event) {
        _sendWelcomeEmail(event.email, event.fullName);
      }),
    );
    
    // Handle order placement
    _subscriptions.add(
      eventBus.on<OrderPlaced>().listen((event) {
        _sendOrderConfirmation(event.customerId, event.aggregateId);
      }),
    );
  }
  
  Future<void> _sendWelcomeEmail(String email, String name) async {
    // Send email logic
  }
  
  Future<void> _sendOrderConfirmation(String customerId, String orderId) async {
    // Send email logic
  }
  
  Future<void> dispose() async {
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
  }
}
```

### Multiple Services Pattern

Different services can react to the same events independently:

```dart
void setupEventHandlers(EventBus eventBus) {
  // Email service
  eventBus.on<UserRegistered>().listen((event) {
    emailService.sendWelcomeEmail(event.email);
  });
  
  // Analytics service
  eventBus.on<UserRegistered>().listen((event) {
    analyticsService.trackRegistration(event.organizationId);
  });
  
  // Profile service
  eventBus.on<UserRegistered>().listen((event) {
    profileService.createProfile(event.aggregateId, event.fullName);
  });
  
  // Audit service
  eventBus.on<UserRegistered>().listen((event) {
    auditService.logEvent('USER_REGISTERED', event);
  });
}
```

### Error Handling

Event handlers should handle errors gracefully:

```dart
eventBus.on<OrderPlaced>().listen(
  (event) async {
    try {
      await inventoryService.reserveItems(event.aggregateId);
    } catch (e) {
      // Log error but don't crash
      logger.error('Failed to reserve inventory for order ${event.aggregateId}', e);
      // Optionally publish a compensation event
      eventBus.publish(InventoryReservationFailed(
        orderId: event.aggregateId,
        reason: e.toString(),
      ));
    }
  },
  onError: (error) {
    logger.error('Event handler error', error);
  },
);
```

## API Reference

### DomainEvent

Base class for all domain events.

```dart
abstract class DomainEvent {
  final UuidValue eventId;        // Unique event identifier (auto-generated)
  final DateTime occurredAt;      // When the event occurred (auto-generated)
  final UuidValue aggregateId;    // ID of the aggregate that raised the event
  final Map<String, dynamic> context;  // Additional context for filtering
  
  DomainEvent({
    required this.aggregateId,
    UuidValue? eventId,
    DateTime? occurredAt,
    this.context = const {},
  });
}
```

### AggregateRoot

Base class for aggregate roots with event support.

```dart
abstract class AggregateRoot extends Entity {
  // Raise a domain event
  void raiseEvent(DomainEvent event);
  
  // Get all uncommitted events
  List<DomainEvent> getUncommittedEvents();
  
  // Clear uncommitted events after publishing
  void markEventsAsCommitted();
}
```

### EventBus

Local event bus for publish/subscribe.

```dart
class EventBus {
  // Publish an event to all subscribers
  void publish(DomainEvent event);
  
  // Subscribe to events of a specific type
  Stream<T> on<T extends DomainEvent>();
  
  // Close the event bus and release resources
  Future<void> close();
  
  // Check if the event bus is closed
  bool get isClosed;
}
```

## Advanced Topics

### Event Context and Filtering

Use the context map to include metadata for filtering:

```dart
class OrderPlaced extends DomainEvent {
  final String customerId;
  final String region;
  final double totalAmount;
  
  OrderPlaced({
    required UuidValue orderId,
    required this.customerId,
    required this.region,
    required this.totalAmount,
  }) : super(
    aggregateId: orderId,
    context: {
      'customerId': customerId,
      'region': region,
      'totalAmount': totalAmount,
    },
  );
}

// Future: Filter events by context
// eventBus.on<OrderPlaced>()
//   .where((e) => e.context['region'] == 'US')
//   .listen(...);
```

### Event Serialization

Events can be serialized using the `dddart_serialization` package:

```dart
import 'package:dddart_serialization/dddart_serialization.dart';

@Serializable()
class UserRegistered extends DomainEvent {
  final String email;
  final String fullName;
  
  UserRegistered({
    required UuidValue userId,
    required this.email,
    required this.fullName,
  }) : super(aggregateId: userId);
  
  // Generated serialization methods
  factory UserRegistered.fromJson(Map<String, dynamic> json) =>
      _$UserRegisteredFromJson(json);
  Map<String, dynamic> toJson() => _$UserRegisteredToJson(this);
}
```

**Note on UuidValue Serialization:** When manually serializing events, use `.uuid` to convert UuidValue to string:
```dart
Map<String, dynamic> toJson() => {
  'eventId': eventId.uuid,           // UuidValue → String
  'aggregateId': aggregateId.uuid,   // UuidValue → String
  ...
};
```

### Future: Remote Event Distribution

The architecture supports future remote event capabilities:

```dart
// Future interface for remote event transport
abstract interface class EventTransport {
  Future<void> send(DomainEvent event);
  Stream<DomainEvent> receive();
  Future<void> subscribe(EventSubscription subscription);
  Future<void> close();
}

// Future interface for remote event client
abstract interface class RemoteEventClient {
  Future<void> subscribe(EventSubscription subscription);
  Future<void> unsubscribe(Type eventType);
  Stream<T> on<T extends DomainEvent>();
}
```

These interfaces will enable:
- WebSocket-based event distribution
- Message queue integration (RabbitMQ, AWS SQS, etc.)
- Event filtering and routing
- Cross-service event communication

## Examples

See the [example](../../example) directory for comprehensive examples:

- **Basic event raising** - Creating aggregates that raise events
- **EventBus usage** - Publishing and subscribing to events
- **Multiple listeners** - Multiple services reacting to events
- **Type-filtered subscriptions** - Handling specific event types
- **Event lifecycle** - Complete flow from creation to commitment
- **Real-world scenario** - E-commerce order processing workflow

Run the examples:

```bash
# Domain events examples
dart run example/events_main.dart

# Serialization examples
dart run example/main.dart
```

## Documentation

### Quick Links

- **[Getting Started Guide](GETTING_STARTED.md)** - 5-minute quick start for domain events
- **[Domain Events Guide](DOMAIN_EVENTS_GUIDE.md)** - Comprehensive patterns and best practices
- **[API Reference](API_REFERENCE.md)** - Complete API documentation
- **[Examples](../../example)** - Working code examples and usage patterns

### Documentation Structure

1. **New to DDDart?** Start with [GETTING_STARTED.md](GETTING_STARTED.md)
2. **Building features?** Read [DOMAIN_EVENTS_GUIDE.md](DOMAIN_EVENTS_GUIDE.md)
3. **Need API details?** Check [API_REFERENCE.md](API_REFERENCE.md)
4. **Want to see code?** Explore the [example](../../example) directory

## Platform Support

DDDart works on all Dart platforms:
- ✅ **Server** - Dart VM and compiled executables
- ✅ **Web** - Dart web and Flutter web applications
- ✅ **Mobile** - Flutter iOS and Android apps
- ✅ **Desktop** - Flutter desktop applications

The event system uses only Dart core libraries with no platform-specific dependencies.

## Contributing

Contributions are welcome! Please read our contributing guidelines and submit pull requests to our repository.

## License

This project is licensed under the MIT License - see the LICENSE file for details.