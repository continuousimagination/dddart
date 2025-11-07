# Domain Events Guide

This guide provides comprehensive information about using domain events in DDDart, including design patterns, best practices, and common scenarios.

## Table of Contents

- [What are Domain Events?](#what-are-domain-events)
- [When to Use Domain Events](#when-to-use-domain-events)
- [Event Design Patterns](#event-design-patterns)
- [Implementation Patterns](#implementation-patterns)
- [Best Practices](#best-practices)
- [Common Scenarios](#common-scenarios)
- [Testing Events](#testing-events)
- [Future: Remote Events](#future-remote-events)

## What are Domain Events?

Domain events are a way to explicitly capture and communicate that something significant happened in your domain. They represent facts about things that have already occurred and cannot be changed.

### Characteristics of Domain Events

1. **Immutable** - Once created, events cannot be modified
2. **Past tense** - Named after what happened (e.g., `OrderPlaced`, not `PlaceOrder`)
3. **Rich in context** - Include all relevant information about what happened
4. **Timestamped** - Automatically include when the event occurred
5. **Traceable** - Include unique identifiers for auditing and debugging

### Benefits

- **Decoupling** - Components react to events without direct dependencies
- **Auditability** - Complete history of what happened in the system
- **Scalability** - Easy to add new event handlers without modifying existing code
- **Testability** - Events make it easy to verify business logic
- **Integration** - Events provide natural integration points between bounded contexts

## When to Use Domain Events

### Use Domain Events When:

✅ **Significant business operations occur**
```dart
// User registration is a significant business event
class UserRegistered extends DomainEvent { ... }
```

✅ **Multiple systems need to react to the same occurrence**
```dart
// Order placement triggers inventory, email, and analytics
class OrderPlaced extends DomainEvent { ... }
```

✅ **You need an audit trail**
```dart
// Track all state changes for compliance
class AccountStatusChanged extends DomainEvent { ... }
```

✅ **Cross-aggregate coordination is needed**
```dart
// Payment processed affects order and inventory aggregates
class PaymentProcessed extends DomainEvent { ... }
```

✅ **Eventual consistency is acceptable**
```dart
// Email sending can happen asynchronously
class WelcomeEmailRequested extends DomainEvent { ... }
```

### Don't Use Domain Events When:

❌ **Simple getters/setters** - Not every property change needs an event

❌ **Technical operations** - Database connections, logging, etc.

❌ **Immediate consistency required** - Use direct method calls instead

❌ **Private implementation details** - Internal state changes that don't matter to other components

## Event Design Patterns

### 1. Simple Event Pattern

For straightforward domain occurrences:

```dart
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

### 2. Rich Event Pattern

Include comprehensive context for complex scenarios:

```dart
class OrderPlaced extends DomainEvent {
  final String customerId;
  final List<OrderLineItem> items;
  final Money totalAmount;
  final Address shippingAddress;
  final PaymentMethod paymentMethod;
  final String? promotionCode;
  
  OrderPlaced({
    required UuidValue orderId,
    required this.customerId,
    required this.items,
    required this.totalAmount,
    required this.shippingAddress,
    required this.paymentMethod,
    this.promotionCode,
  }) : super(
    aggregateId: orderId,
    context: {
      'customerId': customerId,
      'itemCount': items.length,
      'totalAmount': totalAmount.amount,
      'currency': totalAmount.currency,
      'hasPromotion': promotionCode != null,
    },
  );
}
```

### 3. State Transition Event Pattern

Capture state changes with before/after context:

```dart
class OrderStatusChanged extends DomainEvent {
  final OrderStatus previousStatus;
  final OrderStatus newStatus;
  final String reason;
  final String changedBy;
  
  OrderStatusChanged({
    required UuidValue orderId,
    required this.previousStatus,
    required this.newStatus,
    required this.reason,
    required this.changedBy,
  }) : super(
    aggregateId: orderId,
    context: {
      'previousStatus': previousStatus.name,
      'newStatus': newStatus.name,
      'changedBy': changedBy,
    },
  );
}
```

### 4. Compensation Event Pattern

For handling failures or rollbacks:

```dart
class PaymentFailed extends DomainEvent {
  final String orderId;
  final String reason;
  final String errorCode;
  final Money attemptedAmount;
  
  PaymentFailed({
    required UuidValue paymentId,
    required this.orderId,
    required this.reason,
    required this.errorCode,
    required this.attemptedAmount,
  }) : super(
    aggregateId: paymentId,
    context: {
      'orderId': orderId,
      'errorCode': errorCode,
    },
  );
}
```

## Implementation Patterns

### Pattern 1: Factory Method with Events

Create aggregates using factory methods that raise events:

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
    required Address shippingAddress,
  }) {
    // Validate business rules
    if (items.isEmpty) {
      throw ArgumentError('Order must have at least one item');
    }
    
    final order = Order._(
      customerId: customerId,
      items: items,
    );
    
    // Raise domain event
    order.raiseEvent(OrderPlaced(
      orderId: order.id.uuid,
      customerId: customerId,
      items: items,
      shippingAddress: shippingAddress,
    ));
    
    return order;
  }
}
```

### Pattern 2: Business Method with Events

Raise events when business operations modify state:

```dart
class Order extends AggregateRoot {
  OrderStatus status;
  DateTime? shippedAt;
  String? trackingNumber;
  
  void ship(String trackingNumber, String carrier) {
    // Validate business rules
    if (status != OrderStatus.pending) {
      throw StateError('Only pending orders can be shipped');
    }
    
    // Update state
    status = OrderStatus.shipped;
    shippedAt = DateTime.now();
    this.trackingNumber = trackingNumber;
    
    // Raise domain event
    raiseEvent(OrderShipped(
      orderId: id.uuid,
      trackingNumber: trackingNumber,
      carrier: carrier,
      shippedAt: shippedAt!,
    ));
  }
  
  void cancel(String reason) {
    // Validate business rules
    if (status == OrderStatus.shipped) {
      throw StateError('Cannot cancel shipped orders');
    }
    
    // Update state
    status = OrderStatus.cancelled;
    
    // Raise domain event
    raiseEvent(OrderCancelled(
      orderId: id.uuid,
      reason: reason,
      cancelledAt: DateTime.now(),
    ));
  }
}
```

### Pattern 3: Repository Pattern with Event Publishing

Publish events after successful persistence:

```dart
class OrderRepository {
  final Database database;
  final EventBus eventBus;
  
  OrderRepository(this.database, this.eventBus);
  
  Future<void> save(Order order) async {
    // Start transaction
    await database.transaction((txn) async {
      // Persist aggregate
      await txn.save(order);
      
      // Get uncommitted events
      final events = order.getUncommittedEvents();
      
      // Optionally persist events for audit trail
      for (final event in events) {
        await txn.saveEvent(event);
      }
      
      // Publish events (after transaction commits)
      txn.onCommit(() {
        for (final event in events) {
          eventBus.publish(event);
        }
        
        // Mark events as committed
        order.markEventsAsCommitted();
      });
    });
  }
}
```

### Pattern 4: Application Service Coordination

Coordinate multiple aggregates using events:

```dart
class OrderApplicationService {
  final OrderRepository orderRepository;
  final InventoryRepository inventoryRepository;
  final EventBus eventBus;
  
  OrderApplicationService(
    this.orderRepository,
    this.inventoryRepository,
    this.eventBus,
  ) {
    _setupEventHandlers();
  }
  
  void _setupEventHandlers() {
    // When order is placed, reserve inventory
    eventBus.on<OrderPlaced>().listen((event) async {
      try {
        await _reserveInventory(event);
      } catch (e) {
        // Publish compensation event
        eventBus.publish(InventoryReservationFailed(
          orderId: event.aggregateId,
          reason: e.toString(),
        ));
      }
    });
    
    // When order is cancelled, release inventory
    eventBus.on<OrderCancelled>().listen((event) async {
      await _releaseInventory(event.aggregateId);
    });
  }
  
  Future<void> _reserveInventory(OrderPlaced event) async {
    for (final item in event.items) {
      final inventory = await inventoryRepository.findByProductId(item.productId);
      inventory.reserve(item.quantity, event.aggregateId);
      await inventoryRepository.save(inventory);
    }
  }
  
  Future<void> _releaseInventory(String orderId) async {
    final reservations = await inventoryRepository.findReservationsByOrderId(orderId);
    for (final reservation in reservations) {
      reservation.release();
      await inventoryRepository.save(reservation);
    }
  }
}
```

## Best Practices

### 1. Event Naming

✅ **Use past tense verbs**
```dart
class UserRegistered extends DomainEvent { }  // Good
class RegisterUser extends DomainEvent { }    // Bad
```

✅ **Be specific and descriptive**
```dart
class OrderShippedToCustomer extends DomainEvent { }  // Good
class OrderUpdated extends DomainEvent { }            // Bad (too vague)
```

✅ **Include the aggregate type**
```dart
class OrderPlaced extends DomainEvent { }     // Good
class Placed extends DomainEvent { }          // Bad (unclear)
```

### 2. Event Content

✅ **Include all relevant data**
```dart
class OrderPlaced extends DomainEvent {
  final String customerId;
  final List<OrderItem> items;
  final Money totalAmount;
  // Include everything handlers might need
}
```

❌ **Don't include just IDs**
```dart
class OrderPlaced extends DomainEvent {
  final String orderId;  // Bad - handlers need more context
}
```

✅ **Use value objects for complex data**
```dart
class OrderPlaced extends DomainEvent {
  final Address shippingAddress;  // Good - rich type
  final Money totalAmount;        // Good - rich type
}
```

### 3. Event Granularity

✅ **One event per business occurrence**
```dart
// Good - separate events for separate occurrences
class OrderPlaced extends DomainEvent { }
class OrderShipped extends DomainEvent { }
class OrderDelivered extends DomainEvent { }
```

❌ **Don't create overly generic events**
```dart
// Bad - too generic
class OrderChanged extends DomainEvent {
  final String changeType;  // Avoid this pattern
}
```

### 4. Event Handlers

✅ **Keep handlers focused and independent**
```dart
// Good - each handler has one responsibility
eventBus.on<OrderPlaced>().listen((event) {
  emailService.sendConfirmation(event);
});

eventBus.on<OrderPlaced>().listen((event) {
  analyticsService.trackOrder(event);
});
```

✅ **Handle errors gracefully**
```dart
eventBus.on<OrderPlaced>().listen(
  (event) async {
    try {
      await emailService.sendConfirmation(event);
    } catch (e) {
      logger.error('Failed to send confirmation', e);
      // Don't throw - let other handlers continue
    }
  },
);
```

✅ **Make handlers idempotent**
```dart
eventBus.on<OrderPlaced>().listen((event) async {
  // Check if already processed
  if (await emailService.wasEmailSent(event.eventId)) {
    return;  // Skip duplicate
  }
  
  await emailService.sendConfirmation(event);
  await emailService.markEmailSent(event.eventId);
});
```

### 5. Transaction Boundaries

✅ **Publish events after persistence**
```dart
Future<void> saveOrder(Order order) async {
  // 1. Persist first
  await database.save(order);
  
  // 2. Then publish events
  for (final event in order.getUncommittedEvents()) {
    eventBus.publish(event);
  }
  
  // 3. Finally mark as committed
  order.markEventsAsCommitted();
}
```

❌ **Don't publish before persistence**
```dart
Future<void> saveOrder(Order order) async {
  // Bad - events published before persistence
  for (final event in order.getUncommittedEvents()) {
    eventBus.publish(event);
  }
  
  await database.save(order);  // What if this fails?
}
```

## Common Scenarios

### Scenario 1: User Registration Flow

```dart
// 1. Define the event
class UserRegistered extends DomainEvent {
  final String email;
  final String fullName;
  final String organizationId;
  
  UserRegistered({
    required UuidValue userId,
    required this.email,
    required this.fullName,
    required this.organizationId,
  }) : super(aggregateId: userId);
}

// 2. Create aggregate that raises event
class User extends AggregateRoot {
  final String email;
  final String fullName;
  
  User._({
    required this.email,
    required this.fullName,
    super.id,
  });
  
  factory User.register({
    required String email,
    required String fullName,
    required String organizationId,
  }) {
    final user = User._(email: email, fullName: fullName);
    
    user.raiseEvent(UserRegistered(
      userId: user.id,
      email: email,
      fullName: fullName,
      organizationId: organizationId,
    ));
    
    return user;
  }
}

// 3. Set up event handlers
void setupUserHandlers(EventBus eventBus) {
  // Send welcome email
  eventBus.on<UserRegistered>().listen((event) async {
    await emailService.sendWelcomeEmail(
      to: event.email,
      name: event.fullName,
    );
  });
  
  // Create user profile
  eventBus.on<UserRegistered>().listen((event) async {
    await profileService.createProfile(
      userId: event.aggregateId,
      email: event.email,
      fullName: event.fullName,
    );
  });
  
  // Track analytics
  eventBus.on<UserRegistered>().listen((event) async {
    await analyticsService.track('user_registered', {
      'userId': event.aggregateId,
      'organizationId': event.organizationId,
      'timestamp': event.occurredAt,
    });
  });
}

// 4. Use in application service
class UserApplicationService {
  final UserRepository userRepository;
  final EventBus eventBus;
  
  Future<User> registerUser({
    required String email,
    required String fullName,
    required String organizationId,
  }) async {
    // Create user
    final user = User.register(
      email: email,
      fullName: fullName,
      organizationId: organizationId,
    );
    
    // Save and publish events
    await userRepository.save(user);
    
    return user;
  }
}
```

### Scenario 2: Order Processing Workflow

```dart
// Define events for the workflow
class OrderPlaced extends DomainEvent {
  final String customerId;
  final List<OrderItem> items;
  final Money totalAmount;
  
  OrderPlaced({
    required UuidValue orderId,
    required this.customerId,
    required this.items,
    required this.totalAmount,
  }) : super(aggregateId: orderId);
}

class PaymentProcessed extends DomainEvent {
  final String orderId;
  final Money amount;
  final String paymentMethod;
  
  PaymentProcessed({
    required UuidValue paymentId,
    required this.orderId,
    required this.amount,
    required this.paymentMethod,
  }) : super(aggregateId: paymentId);
}

class OrderShipped extends DomainEvent {
  final String trackingNumber;
  final String carrier;
  
  OrderShipped({
    required UuidValue orderId,
    required this.trackingNumber,
    required this.carrier,
  }) : super(aggregateId: orderId);
}

// Set up workflow coordination
void setupOrderWorkflow(EventBus eventBus) {
  // Step 1: When order placed, process payment
  eventBus.on<OrderPlaced>().listen((event) async {
    try {
      await paymentService.processPayment(
        orderId: event.aggregateId,
        amount: event.totalAmount,
      );
    } catch (e) {
      eventBus.publish(PaymentFailed(
        paymentId: uuid.v4(),
        orderId: event.aggregateId,
        reason: e.toString(),
      ));
    }
  });
  
  // Step 2: When payment processed, reserve inventory and ship
  eventBus.on<PaymentProcessed>().listen((event) async {
    await inventoryService.reserveItems(event.orderId);
    await shippingService.createShipment(event.orderId);
  });
  
  // Step 3: When shipped, notify customer
  eventBus.on<OrderShipped>().listen((event) async {
    await emailService.sendShippingNotification(
      orderId: event.aggregateId,
      trackingNumber: event.trackingNumber,
    );
  });
}
```

### Scenario 3: Saga Pattern with Events

```dart
class OrderSaga {
  final EventBus eventBus;
  final Map<String, SagaState> _sagaStates = {};
  
  OrderSaga(this.eventBus) {
    _setupSaga();
  }
  
  void _setupSaga() {
    // Track saga state
    eventBus.on<OrderPlaced>().listen((event) {
      _sagaStates[event.aggregateId] = SagaState(
        orderId: event.aggregateId,
        step: SagaStep.orderPlaced,
      );
    });
    
    eventBus.on<PaymentProcessed>().listen((event) {
      final state = _sagaStates[event.orderId];
      if (state != null) {
        state.step = SagaStep.paymentProcessed;
      }
    });
    
    eventBus.on<OrderShipped>().listen((event) {
      final state = _sagaStates[event.aggregateId];
      if (state != null) {
        state.step = SagaStep.orderShipped;
        state.completed = true;
      }
    });
    
    // Handle failures and compensate
    eventBus.on<PaymentFailed>().listen((event) async {
      await _compensateOrder(event.orderId);
    });
  }
  
  Future<void> _compensateOrder(String orderId) async {
    // Cancel order and release resources
    final order = await orderRepository.findById(orderId);
    order.cancel('Payment failed');
    await orderRepository.save(order);
  }
}
```

## Testing Events

### Testing Event Raising

```dart
test('Order.place raises OrderPlaced event', () {
  // Arrange
  final customerId = 'customer-123';
  final items = [OrderItem(productId: 'prod-1', quantity: 2)];
  
  // Act
  final order = Order.place(
    customerId: customerId,
    items: items,
  );
  
  // Assert
  final events = order.getUncommittedEvents();
  expect(events, hasLength(1));
  expect(events.first, isA<OrderPlaced>());
  
  final event = events.first as OrderPlaced;
  expect(event.aggregateId, equals(order.id.uuid));
  expect(event.customerId, equals(customerId));
  expect(event.items, equals(items));
});
```

### Testing Event Handlers

```dart
test('UserRegistered event triggers welcome email', () async {
  // Arrange
  final eventBus = EventBus();
  final emailService = MockEmailService();
  
  eventBus.on<UserRegistered>().listen((event) {
    emailService.sendWelcomeEmail(event.email);
  });
  
  // Act
  final event = UserRegistered(
    userId: UuidValue.generate(),
    email: 'test@example.com',
    fullName: 'Test User',
    organizationId: 'org-123',
  );
  eventBus.publish(event);
  
  // Wait for async processing
  await Future.delayed(Duration(milliseconds: 100));
  
  // Assert
  verify(emailService.sendWelcomeEmail('test@example.com')).called(1);
  
  await eventBus.close();
});
```

### Testing Event Bus

```dart
test('EventBus delivers events to multiple listeners', () async {
  // Arrange
  final eventBus = EventBus();
  final receivedEvents = <UserRegistered>[];
  
  eventBus.on<UserRegistered>().listen(receivedEvents.add);
  eventBus.on<UserRegistered>().listen(receivedEvents.add);
  
  // Act
  final event = UserRegistered(
    userId: UuidValue.generate(),
    email: 'test@example.com',
    fullName: 'Test User',
    organizationId: 'org-123',
  );
  eventBus.publish(event);
  
  await Future.delayed(Duration(milliseconds: 100));
  
  // Assert
  expect(receivedEvents, hasLength(2));
  expect(receivedEvents.every((e) => e.eventId == event.eventId), isTrue);
  
  await eventBus.close();
});
```

### Integration Testing

```dart
test('Complete order workflow with events', () async {
  // Arrange
  final eventBus = EventBus();
  final orderRepository = InMemoryOrderRepository(eventBus);
  final emailService = MockEmailService();
  final inventoryService = MockInventoryService();
  
  // Set up handlers
  eventBus.on<OrderPlaced>().listen((event) {
    emailService.sendConfirmation(event.aggregateId);
  });
  
  eventBus.on<OrderPlaced>().listen((event) {
    inventoryService.reserveItems(event.items);
  });
  
  // Act
  final order = Order.place(
    customerId: 'customer-123',
    items: [OrderItem(productId: 'prod-1', quantity: 2)],
  );
  
  await orderRepository.save(order);
  await Future.delayed(Duration(milliseconds: 100));
  
  // Assert
  verify(emailService.sendConfirmation(order.id.uuid)).called(1);
  verify(inventoryService.reserveItems(any)).called(1);
  expect(order.getUncommittedEvents(), isEmpty);
  
  await eventBus.close();
});
```

## Future: Remote Events

The domain events system is designed to support future remote event distribution. Here's how the architecture will evolve:

### Remote Event Transport Interface

```dart
/// Future interface for remote event transport
abstract interface class EventTransport {
  /// Send an event to remote subscribers
  Future<void> send(DomainEvent event);
  
  /// Receive events from remote publishers
  Stream<DomainEvent> receive();
  
  /// Subscribe to specific event types with filters
  Future<void> subscribe(EventSubscription subscription);
  
  /// Close the transport and release resources
  Future<void> close();
}
```

### Event Subscription with Filtering

```dart
/// Future class for filtered event subscriptions
class EventSubscription {
  final Type eventType;
  final String clientId;
  final Map<String, dynamic> filters;
  
  EventSubscription({
    required this.eventType,
    required this.clientId,
    this.filters = const {},
  });
}

// Example usage (future):
final subscription = EventSubscription(
  eventType: OrderPlaced,
  clientId: 'inventory-service',
  filters: {
    'region': 'US',
    'totalAmount': {'greaterThan': 1000},
  },
);
```

### Remote Event Client

```dart
/// Future interface for receiving remote events
abstract interface class RemoteEventClient {
  /// Subscribe to remote events with filtering
  Future<void> subscribe(EventSubscription subscription);
  
  /// Unsubscribe from event type
  Future<void> unsubscribe(Type eventType);
  
  /// Get stream of events (same API as local EventBus)
  Stream<T> on<T extends DomainEvent>();
}
```

### Future Implementation Examples

**WebSocket Transport:**
```dart
class WebSocketEventTransport implements EventTransport {
  final WebSocket socket;
  
  @override
  Future<void> send(DomainEvent event) async {
    final json = serializeEvent(event);
    socket.send(json);
  }
  
  @override
  Stream<DomainEvent> receive() {
    return socket.stream.map((data) => deserializeEvent(data));
  }
}
```

**Message Queue Transport:**
```dart
class RabbitMQEventTransport implements EventTransport {
  final RabbitMQClient client;
  
  @override
  Future<void> send(DomainEvent event) async {
    await client.publish(
      exchange: 'domain-events',
      routingKey: event.runtimeType.toString(),
      message: serializeEvent(event),
    );
  }
}
```

**AWS SNS/SQS Transport:**
```dart
class AWSEventTransport implements EventTransport {
  final SNSClient sns;
  final SQSClient sqs;
  
  @override
  Future<void> send(DomainEvent event) async {
    await sns.publish(
      topicArn: 'arn:aws:sns:region:account:domain-events',
      message: serializeEvent(event),
      attributes: {
        'eventType': event.runtimeType.toString(),
        'aggregateId': event.aggregateId,
      },
    );
  }
}
```

### Migration Path

When remote events are implemented, migration will be straightforward:

```dart
// Current local-only code
final eventBus = EventBus();
eventBus.on<OrderPlaced>().listen(handleOrderPlaced);

// Future remote-enabled code (minimal changes)
final remoteClient = RemoteEventClient(
  transport: WebSocketEventTransport(url: 'ws://events.example.com'),
);
await remoteClient.subscribe(EventSubscription(
  eventType: OrderPlaced,
  clientId: 'order-service',
));
remoteClient.on<OrderPlaced>().listen(handleOrderPlaced);
```

The same event handling code works for both local and remote events!

## Conclusion

Domain events are a powerful pattern for building decoupled, scalable, and maintainable systems. By following the patterns and best practices in this guide, you can effectively use events to model your domain and coordinate complex business workflows.

For more examples, see the [example](../../example) directory and run:

```bash
dart run example/events_main.dart
```
