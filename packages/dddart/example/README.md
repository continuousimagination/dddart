# DDDart Domain Events Examples

This directory contains comprehensive examples demonstrating the domain events system in DDDart.

## Running the Examples

```bash
# Main events example - comprehensive event patterns
dart run example/events_example.dart

# Event serialization - persistence and message queues
dart run example/event_serialization_example.dart

# Error handling - graceful failure and compensation
dart run example/error_handling_example.dart
```

## Examples Overview

### 1. events_example.dart - Core Event Patterns

The main example demonstrating fundamental event-driven patterns.

### 1. Basic Event Raising
- Creating aggregates that raise domain events
- Collecting uncommitted events
- Marking events as committed after publishing

### 2. EventBus Publish/Subscribe
- Publishing events to the EventBus
- Subscribing to specific event types
- Type-safe event handling

### 3. Multiple Listeners
- Multiple services listening to the same event
- Decoupled event-driven architecture
- Side effect coordination

### 4. Type-Filtered Subscriptions
- Subscribing to specific event types
- Type safety with generic constraints
- Handling different event types independently

### 5. Event Lifecycle
- Complete event flow from creation to publishing
- Transaction boundary management
- Event commitment patterns

### 6. Real-World Scenario
- E-commerce order processing workflow
- Multiple services coordinating through events
- User registration, order placement, and shipment tracking

### 2. event_serialization_example.dart - Event Persistence

Demonstrates how to serialize events for:
- Event store persistence
- Message queue integration (RabbitMQ, AWS SQS, etc.)
- Event sourcing patterns
- Cross-service communication
- Manual JSON serialization with UuidValue handling

### 3. error_handling_example.dart - Resilient Event Handling

Shows error handling best practices:
- Try-catch in event handlers
- Compensation events for failures
- Error isolation between handlers
- Stream-level error handling with onError
- Preventing cascading failures
- Logging without crashing

## Example Domain Events

### UserRegisteredEvent
Raised when a new user registers in the system. Contains:
- User ID (aggregate ID)
- Email address
- Full name
- Organization ID
- Context data for filtering

### OrderPlacedEvent
Raised when an order is successfully placed. Contains:
- Order ID (aggregate ID)
- Customer ID
- Total amount and currency
- Item count
- Context data for analytics

### OrderShippedEvent
Raised when an order is shipped. Contains:
- Order ID (aggregate ID)
- Tracking number
- Shipping carrier
- Estimated delivery date
- Context data for notifications

## Example Aggregates

### UserAggregate
Demonstrates:
- Factory method pattern for aggregate creation
- Raising events during business operations
- Domain logic encapsulation
- Event collection and lifecycle management

## Usage Patterns

### Creating an Aggregate with Events

```dart
// Create a new user - automatically raises UserRegisteredEvent
final user = UserAggregate.register(
  email: 'user@example.com',
  fullName: 'John Doe',
  organizationId: 'org-123',
);

// Retrieve uncommitted events
final events = user.getUncommittedEvents();

// Publish events to EventBus
for (final event in events) {
  eventBus.publish(event);
}

// Mark events as committed
user.markEventsAsCommitted();
```

### Setting Up Event Listeners

```dart
final eventBus = EventBus();

// Subscribe to specific event types
eventBus.on<UserRegisteredEvent>().listen((event) {
  print('User registered: ${event.email}');
  // Send welcome email, create profile, etc.
});

eventBus.on<OrderPlacedEvent>().listen((event) {
  print('Order placed: ${event.aggregateId}');
  // Reserve inventory, process payment, etc.
});

// Publish events
eventBus.publish(myEvent);

// Clean up when done
await eventBus.close();
```

### Multiple Services Pattern

```dart
// Email service
eventBus.on<UserRegisteredEvent>().listen((event) {
  sendWelcomeEmail(event.email);
});

// Analytics service
eventBus.on<UserRegisteredEvent>().listen((event) {
  trackUserRegistration(event.organizationId);
});

// Profile service
eventBus.on<UserRegisteredEvent>().listen((event) {
  createUserProfile(event.aggregateId, event.fullName);
});
```

## Best Practices

1. **Raise events for significant domain actions**: Events should represent meaningful business occurrences, not technical operations.

2. **Keep events immutable**: Domain events should be immutable records of what happened.

3. **Include relevant context**: Use the context map to include data that might be useful for filtering or processing.

4. **Separate raising from publishing**: Collect events in aggregates, then publish them after successful persistence.

5. **Use type-safe subscriptions**: Leverage Dart's type system with `on<T>()` for compile-time safety.

6. **Handle errors gracefully**: Individual listener failures shouldn't affect other listeners or the event bus.

7. **Clean up resources**: Always close the EventBus and cancel subscriptions when done.

8. **Name events in past tense**: Use names like `OrderPlaced`, `UserRegistered`, not `PlaceOrder` or `RegisterUser`.

9. **Make handlers idempotent**: Event handlers should be safe to run multiple times with the same event.

10. **Publish after persistence**: Only publish events after successfully persisting the aggregate to maintain consistency.

## Architecture Notes

The domain events system is designed with:

- **Local-first approach**: Current implementation focuses on in-process events
- **Future extensibility**: Interfaces designed to support remote event distribution
- **Platform independence**: Works on server, web, and mobile platforms
- **Type safety**: Leverages Dart's type system for compile-time guarantees
- **Simplicity**: Minimal API surface for easy adoption

## Additional Resources

- **Main Documentation**: See [../README.md](../README.md) for quick start guide
- **Domain Events Guide**: See [../DOMAIN_EVENTS_GUIDE.md](../DOMAIN_EVENTS_GUIDE.md) for comprehensive patterns and best practices
- **API Reference**: See [../API_REFERENCE.md](../API_REFERENCE.md) for complete API documentation
