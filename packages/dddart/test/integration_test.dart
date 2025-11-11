import 'dart:async';
import 'package:dddart/dddart.dart';
import 'package:test/test.dart';

// Test domain events
class TestEvent extends DomainEvent {
  TestEvent({
    required super.aggregateId,
    required this.message,
  });
  final String message;
}

class OrderCreatedEvent extends DomainEvent {
  OrderCreatedEvent({
    required UuidValue orderId,
    required this.customerId,
    required this.itemCount,
  }) : super(aggregateId: orderId);
  final String customerId;
  final int itemCount;
}

class OrderConfirmedEvent extends DomainEvent {
  OrderConfirmedEvent({
    required UuidValue orderId,
    required this.confirmedAt,
  }) : super(aggregateId: orderId);
  final DateTime confirmedAt;
}

class PaymentProcessedEvent extends DomainEvent {
  PaymentProcessedEvent({
    required UuidValue orderId,
    required this.amount,
  }) : super(aggregateId: orderId);
  final double amount;
}

// Test aggregate root
class TestAggregate extends AggregateRoot {
  TestAggregate({super.id});

  void doSomething(String message) {
    raiseEvent(
      TestEvent(
        aggregateId: id,
        message: message,
      ),
    );
    touch();
  }
}

// Test aggregate for order flow
class TestOrder extends AggregateRoot {
  TestOrder({
    required this.customerId,
    this.itemCount = 0,
    super.id,
  });
  final String customerId;
  int itemCount;
  String status = 'pending';

  void create(int items) {
    itemCount = items;
    status = 'created';
    raiseEvent(
      OrderCreatedEvent(
        orderId: id,
        customerId: customerId,
        itemCount: items,
      ),
    );
  }

  void confirm() {
    if (status != 'created') {
      throw StateError('Order must be created before confirming');
    }
    status = 'confirmed';
    raiseEvent(
      OrderConfirmedEvent(
        orderId: id,
        confirmedAt: DateTime.now(),
      ),
    );
  }

  void processPayment(double amount) {
    raiseEvent(
      PaymentProcessedEvent(
        orderId: id,
        amount: amount,
      ),
    );
  }
}

void main() {
  group('Framework Integration Tests', () {
    test('DomainEvent uses uuid dependency correctly', () {
      final event = TestEvent(
        aggregateId: UuidValue.generate(),
        message: 'test message',
      );

      expect(event.eventId, isNotEmpty);
      expect(event.eventId.uuid.length, equals(36)); // UUID v4 format
      expect(event.aggregateId, equals('test-123'));
      expect(event.occurredAt, isNotNull);
      expect(event.context, isEmpty);
    });

    test('AggregateRoot extends Entity correctly', () {
      final aggregate = TestAggregate();

      expect(aggregate, isA<Entity>());
      expect(aggregate, isA<AggregateRoot>());
      expect(aggregate.id, isNotNull);
      expect(aggregate.createdAt, isNotNull);
      expect(aggregate.updatedAt, isNotNull);
    });

    test('AggregateRoot can raise and collect events', () {
      final aggregate = TestAggregate();

      aggregate.doSomething('first');
      aggregate.doSomething('second');

      final events = aggregate.getUncommittedEvents();
      expect(events.length, equals(2));
      expect(events[0], isA<TestEvent>());
      expect((events[0] as TestEvent).message, equals('first'));
      expect((events[1] as TestEvent).message, equals('second'));
    });

    test('EventBus can publish and subscribe to events', () async {
      final eventBus = EventBus();
      final receivedEvents = <TestEvent>[];

      eventBus.on<TestEvent>().listen(receivedEvents.add);

      final event = TestEvent(
        aggregateId: UuidValue.generate(),
        message: 'test message',
      );

      eventBus.publish(event);

      await Future.delayed(const Duration(milliseconds: 10));

      expect(receivedEvents.length, equals(1));
      expect(receivedEvents[0].message, equals('test message'));

      await eventBus.close();
    });

    test('Complete event flow from aggregate to event bus', () async {
      final aggregate = TestAggregate();
      final eventBus = EventBus();
      final receivedEvents = <TestEvent>[];

      eventBus.on<TestEvent>().listen(receivedEvents.add);

      // Simulate domain operation
      aggregate.doSomething('operation completed');

      // Publish uncommitted events
      for (final event in aggregate.getUncommittedEvents()) {
        eventBus.publish(event);
      }
      aggregate.markEventsAsCommitted();

      await Future.delayed(const Duration(milliseconds: 10));

      expect(receivedEvents.length, equals(1));
      expect(receivedEvents[0].message, equals('operation completed'));
      expect(aggregate.getUncommittedEvents(), isEmpty);

      await eventBus.close();
    });

    test('All exports are accessible from main library', () {
      // Verify all classes are exported and accessible
      expect(Entity, isNotNull);
      expect(AggregateRoot, isNotNull);
      expect(Value, isNotNull);
      expect(UuidValue, isNotNull);
      expect(DomainEvent, isNotNull);
      expect(EventBus, isNotNull);
    });
  });

  group('End-to-End Event Flow Integration Tests', () {
    late EventBus eventBus;

    setUp(() {
      eventBus = EventBus();
    });

    tearDown(() async {
      await eventBus.close();
    });

    test('Complete event flow from aggregate to multiple listeners', () async {
      final order = TestOrder(customerId: 'customer-123');
      final listener1Events = <DomainEvent>[];
      final listener2Events = <DomainEvent>[];
      final listener3Events = <DomainEvent>[];

      // Set up multiple listeners
      eventBus.on<DomainEvent>().listen(listener1Events.add);
      eventBus.on<OrderCreatedEvent>().listen(listener2Events.add);
      eventBus.on<OrderConfirmedEvent>().listen(listener3Events.add);

      // Execute domain operations
      order.create(5);
      order.confirm();

      // Publish all uncommitted events
      for (final event in order.getUncommittedEvents()) {
        eventBus.publish(event);
      }
      order.markEventsAsCommitted();

      // Wait for async event delivery
      await Future.delayed(const Duration(milliseconds: 10));

      // Verify all listeners received appropriate events
      expect(listener1Events.length, equals(2)); // All events
      expect(listener2Events.length, equals(1)); // Only OrderCreatedEvent
      expect(listener3Events.length, equals(1)); // Only OrderConfirmedEvent

      expect(listener1Events[0], isA<OrderCreatedEvent>());
      expect(listener1Events[1], isA<OrderConfirmedEvent>());
      expect(listener2Events[0], isA<OrderCreatedEvent>());
      expect(listener3Events[0], isA<OrderConfirmedEvent>());

      // Verify events are cleared after commit
      expect(order.getUncommittedEvents(), isEmpty);
    });

    test('Event ordering is preserved across multiple operations', () async {
      final order = TestOrder(customerId: 'customer-456');
      final receivedEvents = <DomainEvent>[];
      final eventTypes = <String>[];

      eventBus.on<DomainEvent>().listen((event) {
        receivedEvents.add(event);
        eventTypes.add(event.runtimeType.toString());
      });

      // Execute operations in specific order
      order.create(3);
      order.confirm();
      order.processPayment(99.99);

      // Publish events in order
      final events = order.getUncommittedEvents();
      for (final event in events) {
        eventBus.publish(event);
      }
      order.markEventsAsCommitted();

      await Future.delayed(const Duration(milliseconds: 10));

      // Verify events are received in the same order
      expect(receivedEvents.length, equals(3));
      expect(eventTypes[0], equals('OrderCreatedEvent'));
      expect(eventTypes[1], equals('OrderConfirmedEvent'));
      expect(eventTypes[2], equals('PaymentProcessedEvent'));

      // Verify event metadata
      expect(receivedEvents[0].aggregateId, equals(order.id.uuid));
      expect(receivedEvents[1].aggregateId, equals(order.id.uuid));
      expect(receivedEvents[2].aggregateId, equals(order.id.uuid));
    });

    test('Multiple aggregates can publish events to same bus', () async {
      final order1 = TestOrder(customerId: 'customer-1');
      final order2 = TestOrder(customerId: 'customer-2');
      final order3 = TestOrder(customerId: 'customer-3');
      final allEvents = <DomainEvent>[];

      eventBus.on<DomainEvent>().listen(allEvents.add);

      // Multiple aggregates perform operations
      order1.create(2);
      order2.create(5);
      order3.create(1);

      // Publish all events
      for (final order in [order1, order2, order3]) {
        for (final event in order.getUncommittedEvents()) {
          eventBus.publish(event);
        }
        order.markEventsAsCommitted();
      }

      await Future.delayed(const Duration(milliseconds: 10));

      // Verify all events were received
      expect(allEvents.length, equals(3));
      expect(allEvents.every((e) => e is OrderCreatedEvent), isTrue);

      // Verify events from different aggregates
      final aggregateIds = allEvents.map((e) => e.aggregateId).toSet();
      expect(aggregateIds.length, equals(3));
    });

    test('Event delivery guarantees - all subscribers receive events',
        () async {
      final order = TestOrder(customerId: 'customer-789');
      final subscriber1 = <OrderCreatedEvent>[];
      final subscriber2 = <OrderCreatedEvent>[];
      final subscriber3 = <OrderCreatedEvent>[];
      final subscriber4 = <OrderCreatedEvent>[];

      // Set up multiple subscribers for same event type
      eventBus.on<OrderCreatedEvent>().listen(subscriber1.add);
      eventBus.on<OrderCreatedEvent>().listen(subscriber2.add);
      eventBus.on<OrderCreatedEvent>().listen(subscriber3.add);
      eventBus.on<OrderCreatedEvent>().listen(subscriber4.add);

      order.create(10);

      for (final event in order.getUncommittedEvents()) {
        eventBus.publish(event);
      }
      order.markEventsAsCommitted();

      await Future.delayed(const Duration(milliseconds: 10));

      // All subscribers should receive the event
      expect(subscriber1.length, equals(1));
      expect(subscriber2.length, equals(1));
      expect(subscriber3.length, equals(1));
      expect(subscriber4.length, equals(1));

      // All should receive the same event
      expect(subscriber1[0].eventId, equals(subscriber2[0].eventId));
      expect(subscriber2[0].eventId, equals(subscriber3[0].eventId));
      expect(subscriber3[0].eventId, equals(subscriber4[0].eventId));
    });

    test('Complex event flow with multiple event types and listeners',
        () async {
      final order = TestOrder(customerId: 'customer-complex');
      final allEvents = <DomainEvent>[];
      final createdEvents = <OrderCreatedEvent>[];
      final confirmedEvents = <OrderConfirmedEvent>[];
      final paymentEvents = <PaymentProcessedEvent>[];

      // Set up type-specific listeners
      eventBus.on<DomainEvent>().listen(allEvents.add);
      eventBus.on<OrderCreatedEvent>().listen(createdEvents.add);
      eventBus.on<OrderConfirmedEvent>().listen(confirmedEvents.add);
      eventBus.on<PaymentProcessedEvent>().listen(paymentEvents.add);

      // Execute complex business flow
      order.create(7);
      order.confirm();
      order.processPayment(149.99);

      // Publish events
      for (final event in order.getUncommittedEvents()) {
        eventBus.publish(event);
      }
      order.markEventsAsCommitted();

      await Future.delayed(const Duration(milliseconds: 10));

      // Verify event distribution
      expect(allEvents.length, equals(3));
      expect(createdEvents.length, equals(1));
      expect(confirmedEvents.length, equals(1));
      expect(paymentEvents.length, equals(1));

      // Verify event data
      expect(createdEvents[0].itemCount, equals(7));
      expect(paymentEvents[0].amount, equals(149.99));
    });
  });

  group('Error Handling Integration Tests', () {
    late EventBus eventBus;

    setUp(() {
      eventBus = EventBus();
    });

    tearDown(() async {
      await eventBus.close();
    });

    test('EventBus continues operating when a listener has error handling',
        () async {
      final order = TestOrder(customerId: 'customer-error');
      final successfulListener = <OrderCreatedEvent>[];
      final errorCaughtListener = <OrderCreatedEvent>[];
      var errorHandled = false;

      // Listener with try-catch that handles its own errors
      eventBus.on<OrderCreatedEvent>().listen((event) {
        try {
          errorCaughtListener.add(event);
          throw Exception('Listener error');
        } catch (e) {
          errorHandled = true;
          // Error is caught and handled within listener
        }
      });

      // Listener that should still receive events
      eventBus.on<OrderCreatedEvent>().listen(successfulListener.add);

      order.create(3);

      for (final event in order.getUncommittedEvents()) {
        eventBus.publish(event);
      }

      await Future.delayed(const Duration(milliseconds: 10));

      // Error was handled and other listener still received event
      expect(errorHandled, isTrue);
      expect(errorCaughtListener.length, equals(1));
      expect(successfulListener.length, equals(1));
    });

    test('Multiple listeners with error handling work independently', () async {
      final order = TestOrder(customerId: 'customer-multi-error');
      final workingListeners = <OrderCreatedEvent>[];
      var errorCount = 0;

      // Multiple listeners with error handling
      eventBus.on<OrderCreatedEvent>().listen((event) {
        try {
          throw Exception('Error 1');
        } catch (e) {
          errorCount++;
        }
      });

      eventBus.on<OrderCreatedEvent>().listen((event) {
        try {
          throw Exception('Error 2');
        } catch (e) {
          errorCount++;
        }
      });

      // Working listener
      eventBus.on<OrderCreatedEvent>().listen(workingListeners.add);

      order.create(5);

      for (final event in order.getUncommittedEvents()) {
        eventBus.publish(event);
      }

      await Future.delayed(const Duration(milliseconds: 10));

      expect(errorCount, equals(2));
      expect(workingListeners.length, equals(1));
    });

    test('Cannot publish events to closed EventBus', () {
      final event =
          TestEvent(aggregateId: UuidValue.generate(), message: 'test');

      eventBus.close();

      expect(
        () => eventBus.publish(event),
        throwsStateError,
      );
    });

    test('Listeners complete gracefully when EventBus closes', () async {
      final receivedEvents = <TestEvent>[];
      var listenerCompleted = false;

      eventBus.on<TestEvent>().listen(
            receivedEvents.add,
            onDone: () => listenerCompleted = true,
          );

      final event =
          TestEvent(aggregateId: UuidValue.generate(), message: 'before close');
      eventBus.publish(event);

      await Future.delayed(const Duration(milliseconds: 10));
      expect(receivedEvents.length, equals(1));

      await eventBus.close();
      expect(listenerCompleted, isTrue);
    });

    test('EventBus handles rapid event publishing without data loss', () async {
      final aggregate = TestAggregate();
      final receivedEvents = <TestEvent>[];

      eventBus.on<TestEvent>().listen(receivedEvents.add);

      // Rapidly raise multiple events
      for (var i = 0; i < 100; i++) {
        aggregate.doSomething('message-$i');
      }

      // Publish all events rapidly
      for (final event in aggregate.getUncommittedEvents()) {
        eventBus.publish(event);
      }
      aggregate.markEventsAsCommitted();

      await Future.delayed(const Duration(milliseconds: 50));

      // All events should be delivered
      expect(receivedEvents.length, equals(100));
      expect(receivedEvents[0], isA<TestEvent>());
      expect(receivedEvents[99], isA<TestEvent>());
    });
  });

  group('Cross-Platform Compatibility Tests', () {
    test('EventBus uses only Dart core libraries', () {
      // This test verifies that EventBus can be instantiated
      // without any platform-specific dependencies
      final eventBus = EventBus();
      expect(eventBus, isNotNull);
      expect(eventBus.isClosed, isFalse);
      eventBus.close();
    });

    test('DomainEvent works without platform-specific code', () {
      // Verify events can be created on any platform
      final event = TestEvent(
        aggregateId: UuidValue.generate(),
        message: 'cross-platform',
      );

      expect(event.eventId, isNotEmpty);
      expect(event.occurredAt, isNotNull);
      expect(event.aggregateId, equals('platform-test'));
      expect(event.context, isEmpty);
    });

    test('AggregateRoot event collection works on all platforms', () {
      // Verify aggregate event collection uses only core Dart features
      final aggregate = TestAggregate();

      aggregate.doSomething('platform test 1');
      aggregate.doSomething('platform test 2');

      final events = aggregate.getUncommittedEvents();
      expect(events.length, equals(2));
      expect(events, everyElement(isA<TestEvent>()));

      aggregate.markEventsAsCommitted();
      expect(aggregate.getUncommittedEvents(), isEmpty);
    });

    test('Event serialization metadata is platform-independent', () {
      final event = TestEvent(
        aggregateId: UuidValue.generate(),
        message: 'test message',
      );

      // Verify all metadata uses platform-independent types
      expect(event.eventId, isA<String>());
      expect(event.occurredAt, isA<DateTime>());
      expect(event.aggregateId, isA<String>());
      expect(event.context, isA<Map<String, dynamic>>());
    });

    test('Complete event flow works with platform-independent code', () async {
      final eventBus = EventBus();
      final aggregate = TestAggregate();
      final receivedEvents = <TestEvent>[];

      // This entire flow uses only Dart core libraries
      eventBus.on<TestEvent>().listen(receivedEvents.add);

      aggregate.doSomething('cross-platform event');

      for (final event in aggregate.getUncommittedEvents()) {
        eventBus.publish(event);
      }
      aggregate.markEventsAsCommitted();

      await Future.delayed(const Duration(milliseconds: 10));

      expect(receivedEvents.length, equals(1));
      expect(receivedEvents[0].message, equals('cross-platform event'));

      await eventBus.close();
    });
  });
}
