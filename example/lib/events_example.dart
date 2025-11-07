import 'dart:async';
import 'package:dddart/dddart.dart';

import 'domain/user_aggregate.dart';
import 'domain/user_registered_event.dart';
import 'domain/order_placed_event.dart';
import 'domain/order_shipped_event.dart';

/// Comprehensive example demonstrating DDDart domain events features.
class EventsExample {
  /// Run all example scenarios
  Future<void> runAll() async {
    print('🚀 DDDart Domain Events Example\n');

    await _basicEventRaising();
    await _eventBusPublishSubscribe();
    await _multipleListeners();
    await _typeFilteredSubscriptions();
    await _eventLifecycle();
    await _realWorldScenario();

    print('\n✅ All examples completed successfully!');
  }

  /// Demonstrate basic event raising in aggregates
  Future<void> _basicEventRaising() async {
    print('📢 Basic Event Raising Example');
    print('=' * 40);

    // Create a new user using the factory method
    final user = UserAggregate.register(
      email: 'john.doe@example.com',
      fullName: 'John Doe',
      organizationId: 'org-123',
    );

    print('Created user: ${user.email}');

    // Retrieve uncommitted events
    final events = user.getUncommittedEvents();
    print('Uncommitted events: ${events.length}');

    for (final event in events) {
      print('  - $event');
      print('    Event ID: ${event.eventId}');
      print('    Occurred at: ${event.occurredAt}');
      print('    Aggregate ID: ${event.aggregateId}');
      print('    Context: ${event.context}');
    }

    // Mark events as committed (typically done after publishing)
    user.markEventsAsCommitted();
    print('Events marked as committed');
    print('Remaining uncommitted events: ${user.getUncommittedEvents().length}');

    print('\n✅ Basic event raising completed!\n');
  }

  /// Demonstrate EventBus publish/subscribe functionality
  Future<void> _eventBusPublishSubscribe() async {
    print('🚌 EventBus Publish/Subscribe Example');
    print('=' * 40);

    final eventBus = EventBus();

    // Subscribe to UserRegisteredEvent
    final subscription = eventBus.on<UserRegisteredEvent>().listen((event) {
      print('📧 Listener received: $event');
      print('   Sending welcome email to ${event.email}...');
    });

    // Create and publish an event
    final event = UserRegisteredEvent(
      userId: UuidValue.generate(),
      email: 'jane.smith@example.com',
      fullName: 'Jane Smith',
      organizationId: 'org-789',
    );

    print('Publishing event...');
    eventBus.publish(event);

    // Give the stream time to process
    await Future.delayed(Duration(milliseconds: 100));

    // Clean up
    await subscription.cancel();
    await eventBus.close();

    print('\n✅ EventBus publish/subscribe completed!\n');
  }

  /// Demonstrate multiple listeners for the same event
  Future<void> _multipleListeners() async {
    print('👥 Multiple Listeners Example');
    print('=' * 40);

    final eventBus = EventBus();

    // Multiple listeners for the same event type
    final subscriptions = <StreamSubscription>[];

    // Listener 1: Send welcome email
    subscriptions.add(
      eventBus.on<UserRegisteredEvent>().listen((event) {
        print('📧 Email Service: Sending welcome email to ${event.email}');
      }),
    );

    // Listener 2: Create user profile
    subscriptions.add(
      eventBus.on<UserRegisteredEvent>().listen((event) {
        print('👤 Profile Service: Creating profile for ${event.fullName}');
      }),
    );

    // Listener 3: Update analytics
    subscriptions.add(
      eventBus.on<UserRegisteredEvent>().listen((event) {
        print('📊 Analytics Service: Recording registration for org ${event.organizationId}');
      }),
    );

    // Publish a single event
    final event = UserRegisteredEvent(
      userId: UuidValue.generate(),
      email: 'bob.wilson@example.com',
      fullName: 'Bob Wilson',
      organizationId: 'org-456',
    );

    print('Publishing event to multiple listeners...\n');
    eventBus.publish(event);

    // Give streams time to process
    await Future.delayed(Duration(milliseconds: 100));

    // Clean up
    for (final sub in subscriptions) {
      await sub.cancel();
    }
    await eventBus.close();

    print('\n✅ Multiple listeners completed!\n');
  }

  /// Demonstrate type-filtered subscriptions
  Future<void> _typeFilteredSubscriptions() async {
    print('🔍 Type-Filtered Subscriptions Example');
    print('=' * 40);

    final eventBus = EventBus();

    // Subscribe to different event types
    final userSubscription = eventBus.on<UserRegisteredEvent>().listen((event) {
      print('👤 User Event Handler: ${event.runtimeType}');
    });

    final orderPlacedSubscription = eventBus.on<OrderPlacedEvent>().listen((event) {
      print('📦 Order Placed Handler: Order ${event.aggregateId} for \$${event.totalAmount}');
    });

    final orderShippedSubscription = eventBus.on<OrderShippedEvent>().listen((event) {
      print('🚚 Order Shipped Handler: Tracking ${event.trackingNumber}');
    });

    // Publish various event types
    print('Publishing different event types...\n');

    final userId = UuidValue.generate();
    final orderId = UuidValue.generate();

    eventBus.publish(UserRegisteredEvent(
      userId: userId,
      email: 'alice@example.com',
      fullName: 'Alice Johnson',
      organizationId: 'org-111',
    ));

    eventBus.publish(OrderPlacedEvent(
      orderId: orderId,
      customerId: 'user-111',
      totalAmount: 299.99,
      currency: 'USD',
      itemCount: 3,
    ));

    eventBus.publish(OrderShippedEvent(
      orderId: orderId,
      trackingNumber: '1Z999AA10123456784',
      carrier: 'UPS',
      estimatedDelivery: DateTime.now().add(Duration(days: 3)),
    ));

    // Give streams time to process
    await Future.delayed(Duration(milliseconds: 100));

    // Clean up
    await userSubscription.cancel();
    await orderPlacedSubscription.cancel();
    await orderShippedSubscription.cancel();
    await eventBus.close();

    print('\n✅ Type-filtered subscriptions completed!\n');
  }

  /// Demonstrate complete event lifecycle
  Future<void> _eventLifecycle() async {
    print('♻️  Event Lifecycle Example');
    print('=' * 40);

    final eventBus = EventBus();

    // Set up listener
    final subscription = eventBus.on<UserRegisteredEvent>().listen((event) {
      print('   📨 Event received by listener');
    });

    print('1️⃣  Creating aggregate...');
    final user = UserAggregate.register(
      email: 'lifecycle@example.com',
      fullName: 'Lifecycle Demo',
      organizationId: 'org-lifecycle',
    );

    print('2️⃣  Checking uncommitted events...');
    final events = user.getUncommittedEvents();
    print('   Found ${events.length} uncommitted event(s)');

    print('3️⃣  Publishing events to EventBus...');
    for (final event in events) {
      eventBus.publish(event);
    }

    // Give stream time to process
    await Future.delayed(Duration(milliseconds: 100));

    print('4️⃣  Marking events as committed...');
    user.markEventsAsCommitted();
    print('   Remaining uncommitted: ${user.getUncommittedEvents().length}');

    print('5️⃣  Lifecycle complete!');

    // Clean up
    await subscription.cancel();
    await eventBus.close();

    print('\n✅ Event lifecycle completed!\n');
  }

  /// Demonstrate a real-world scenario with multiple aggregates and events
  Future<void> _realWorldScenario() async {
    print('🌍 Real-World Scenario Example');
    print('=' * 40);
    print('Scenario: E-commerce order processing workflow\n');

    final eventBus = EventBus();
    final subscriptions = <StreamSubscription>[];

    // Set up event handlers for different services

    // Email notification service
    subscriptions.add(
      eventBus.on<UserRegisteredEvent>().listen((event) {
        print('📧 Email Service: Sending welcome email to ${event.email}');
      }),
    );

    subscriptions.add(
      eventBus.on<OrderPlacedEvent>().listen((event) {
        print('📧 Email Service: Sending order confirmation for order ${event.aggregateId}');
      }),
    );

    subscriptions.add(
      eventBus.on<OrderShippedEvent>().listen((event) {
        print('📧 Email Service: Sending shipping notification with tracking ${event.trackingNumber}');
      }),
    );

    // Inventory service
    subscriptions.add(
      eventBus.on<OrderPlacedEvent>().listen((event) {
        print('📦 Inventory Service: Reserving ${event.itemCount} items for order ${event.aggregateId}');
      }),
    );

    subscriptions.add(
      eventBus.on<OrderShippedEvent>().listen((event) {
        print('📦 Inventory Service: Marking items as shipped for order ${event.aggregateId}');
      }),
    );

    // Analytics service
    subscriptions.add(
      eventBus.on<UserRegisteredEvent>().listen((event) {
        print('📊 Analytics Service: New user registered in org ${event.organizationId}');
      }),
    );

    subscriptions.add(
      eventBus.on<OrderPlacedEvent>().listen((event) {
        print('📊 Analytics Service: Revenue +\$${event.totalAmount} ${event.currency}');
      }),
    );

    // Simulate the workflow
    print('Step 1: User Registration');
    print('-' * 40);
    final user = UserAggregate.register(
      email: 'customer@example.com',
      fullName: 'Sarah Customer',
      organizationId: 'org-retail',
    );

    for (final event in user.getUncommittedEvents()) {
      eventBus.publish(event);
    }
    user.markEventsAsCommitted();
    await Future.delayed(Duration(milliseconds: 100));

    print('\nStep 2: Order Placement');
    print('-' * 40);
    final orderId = UuidValue.generate();
    final orderPlaced = OrderPlacedEvent(
      orderId: orderId,
      customerId: user.id.uuid,
      totalAmount: 1299.99,
      currency: 'USD',
      itemCount: 5,
    );
    eventBus.publish(orderPlaced);
    await Future.delayed(Duration(milliseconds: 100));

    print('\nStep 3: Order Shipment');
    print('-' * 40);
    final orderShipped = OrderShippedEvent(
      orderId: orderId,
      trackingNumber: '1Z999AA10123456784',
      carrier: 'UPS',
      estimatedDelivery: DateTime.now().add(Duration(days: 2)),
    );
    eventBus.publish(orderShipped);
    await Future.delayed(Duration(milliseconds: 100));

    print('\n' + '=' * 40);
    print('Workflow completed successfully!');
    print('All services were notified and processed their tasks.');

    // Clean up
    for (final sub in subscriptions) {
      await sub.cancel();
    }
    await eventBus.close();

    print('\n✅ Real-world scenario completed!\n');
  }
}
