# Getting Started with DDDart Domain Events

This guide will help you get started with domain events in DDDart quickly.

## Installation

Add DDDart to your `pubspec.yaml`:

```yaml
dependencies:
  dddart: ^0.1.0
```

Then run:

```bash
dart pub get
```

## 5-Minute Quick Start

### Step 1: Define a Domain Event

Create an event that represents something that happened in your domain:

```dart
import 'package:dddart/dddart.dart';

class UserRegistered extends DomainEvent {
  final String email;
  final String fullName;
  
  UserRegistered({
    required UuidValue userId,
    required this.email,
    required this.fullName,
  }) : super(aggregateId: userId);
}
```

### Step 2: Create an Aggregate that Raises Events

```dart
class User extends AggregateRoot {
  final String email;
  final String fullName;
  
  User._({
    required this.email,
    required this.fullName,
    super.id,
  });
  
  // Factory method that raises an event
  factory User.register({
    required String email,
    required String fullName,
  }) {
    final user = User._(email: email, fullName: fullName);
    
    // Raise the domain event
    user.raiseEvent(UserRegistered(
      userId: user.id,
      email: email,
      fullName: fullName,
    ));
    
    return user;
  }
}
```

### Step 3: Set Up Event Handlers

```dart
void main() async {
  // Create an event bus
  final eventBus = EventBus();
  
  // Subscribe to events
  eventBus.on<UserRegistered>().listen((event) {
    print('New user registered: ${event.email}');
    // Send welcome email, create profile, etc.
  });
  
  // Create a user (raises event)
  final user = User.register(
    email: 'john@example.com',
    fullName: 'John Doe',
  );
  
  // Publish events
  for (final event in user.getUncommittedEvents()) {
    eventBus.publish(event);
  }
  
  // Mark events as committed
  user.markEventsAsCommitted();
  
  // Clean up
  await Future.delayed(Duration(milliseconds: 100));
  await eventBus.close();
}
```

That's it! You now have a working domain events system.

## Key Concepts

### 1. Domain Events

Events represent facts about things that happened:
- Named in **past tense** (e.g., `UserRegistered`, not `RegisterUser`)
- **Immutable** - cannot be changed after creation
- Include **relevant context** - all data needed by handlers
- Automatically include **metadata** - event ID, timestamp, aggregate ID

### 2. Aggregate Roots

Aggregates collect events as business operations occur:
- **Raise events** with `raiseEvent()` during domain operations
- **Collect events** internally as "uncommitted"
- **Provide access** to events via `getUncommittedEvents()`
- **Mark as committed** after publishing with `markEventsAsCommitted()`

### 3. Event Bus

The EventBus distributes events to interested listeners:
- **Publish** events with `publish(event)`
- **Subscribe** to specific types with `on<EventType>()`
- **Type-safe** - uses Dart generics for compile-time safety
- **Broadcast** - delivers to all subscribers

## Common Patterns

### Pattern 1: Multiple Services Reacting to Events

```dart
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
  profileService.createProfile(event.aggregateId, event.fullName);
});
```

### Pattern 2: Event-Driven Workflow

```dart
// Step 1: Order placed
eventBus.on<OrderPlaced>().listen((event) async {
  await paymentService.processPayment(event.aggregateId);
});

// Step 2: Payment processed
eventBus.on<PaymentProcessed>().listen((event) async {
  await inventoryService.reserveItems(event.orderId);
  await shippingService.createShipment(event.orderId);
});

// Step 3: Order shipped
eventBus.on<OrderShipped>().listen((event) async {
  await emailService.sendTrackingInfo(event.aggregateId);
});
```

### Pattern 3: Repository with Event Publishing

```dart
class UserRepository {
  final Database database;
  final EventBus eventBus;
  
  Future<void> save(User user) async {
    // 1. Persist the aggregate
    await database.save(user);
    
    // 2. Publish events
    for (final event in user.getUncommittedEvents()) {
      eventBus.publish(event);
    }
    
    // 3. Mark as committed
    user.markEventsAsCommitted();
  }
}
```

## Best Practices

✅ **DO:**
- Name events in past tense
- Include all relevant data in events
- Publish events after successful persistence
- Handle errors gracefully in event handlers
- Make event handlers idempotent
- Clean up resources (close EventBus, cancel subscriptions)

❌ **DON'T:**
- Use present tense for event names
- Include only IDs without context
- Publish events before persistence
- Let one handler's failure affect others
- Assume events are delivered exactly once
- Forget to close the EventBus

## Next Steps

### Run the Examples

See the domain events system in action:

```bash
# Clone the repository
git clone https://github.com/your-repo/dddart.git
cd dddart

# Run the examples
dart run example/events_main.dart
```

### Read the Documentation

- **[README.md](README.md)** - Main documentation with comprehensive usage guide
- **[DOMAIN_EVENTS_GUIDE.md](DOMAIN_EVENTS_GUIDE.md)** - In-depth patterns and best practices
- **[API_REFERENCE.md](API_REFERENCE.md)** - Complete API documentation
- **[example/EVENTS_README.md](../../example/EVENTS_README.md)** - Example code documentation

### Explore Advanced Topics

Once you're comfortable with the basics, explore:

1. **Event Context and Filtering** - Use the context map for metadata
2. **Event Serialization** - Persist events with `dddart_serialization`
3. **Saga Pattern** - Coordinate long-running workflows
4. **Compensation Events** - Handle failures and rollbacks
5. **Future: Remote Events** - Distributed event architecture

## Common Questions

### When should I use domain events?

Use domain events when:
- Multiple parts of your system need to react to the same occurrence
- You need an audit trail of what happened
- You want to decouple components
- Eventual consistency is acceptable

### How do I handle errors in event handlers?

```dart
eventBus.on<OrderPlaced>().listen(
  (event) async {
    try {
      await processOrder(event);
    } catch (e) {
      logger.error('Failed to process order', e);
      // Optionally publish a compensation event
    }
  },
  onError: (error) {
    logger.error('Event handler error', error);
  },
);
```

### Should I publish events before or after saving?

**Always publish after saving** to maintain consistency:

```dart
// ✅ Correct
await database.save(user);
for (final event in user.getUncommittedEvents()) {
  eventBus.publish(event);
}

// ❌ Wrong - what if save fails?
for (final event in user.getUncommittedEvents()) {
  eventBus.publish(event);
}
await database.save(user);
```

### Can I have multiple listeners for the same event?

Yes! That's one of the main benefits of events:

```dart
// All three will receive the same event
eventBus.on<UserRegistered>().listen(sendEmail);
eventBus.on<UserRegistered>().listen(createProfile);
eventBus.on<UserRegistered>().listen(trackAnalytics);
```

### How do I test code that uses events?

```dart
test('User.register raises UserRegistered event', () {
  // Arrange & Act
  final user = User.register(
    email: 'test@example.com',
    fullName: 'Test User',
  );
  
  // Assert
  final events = user.getUncommittedEvents();
  expect(events, hasLength(1));
  expect(events.first, isA<UserRegistered>());
  
  final event = events.first as UserRegistered;
  expect(event.email, equals('test@example.com'));
});
```

## Troubleshooting

### Events not being received

Make sure you:
1. Subscribe before publishing
2. Give streams time to process (use `await Future.delayed()` in tests)
3. Haven't closed the EventBus
4. Are subscribing to the correct event type

### Memory leaks

Always clean up:
```dart
// Cancel subscriptions
await subscription.cancel();

// Close the event bus
await eventBus.close();
```

### Events published multiple times

Make sure you call `markEventsAsCommitted()` after publishing:
```dart
for (final event in aggregate.getUncommittedEvents()) {
  eventBus.publish(event);
}
aggregate.markEventsAsCommitted();  // Don't forget this!
```

## Getting Help

- **Documentation**: Check the docs in the `packages/dddart/` directory
- **Examples**: See working code in the `example/` directory
- **Issues**: Open an issue on the project repository
- **Community**: Join our community discussions

## What's Next?

Now that you understand the basics, you can:

1. **Build your first event-driven feature** using the patterns above
2. **Explore the examples** to see more complex scenarios
3. **Read the comprehensive guide** for advanced patterns
4. **Integrate with your existing code** by adding events to your aggregates

Happy coding! 🚀
