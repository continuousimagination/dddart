import 'dart:async';
import 'package:dddart/dddart.dart';
import 'package:test/test.dart';

// Test event classes
class TestEvent extends DomainEvent {
  final String message;

  TestEvent({
    required UuidValue aggregateId,
    required this.message,
  }) : super(aggregateId: aggregateId);
}

class AnotherTestEvent extends DomainEvent {
  final int value;

  AnotherTestEvent({
    required UuidValue aggregateId,
    required this.value,
  }) : super(aggregateId: aggregateId);
}

void main() {
  group('EventBus', () {
    late EventBus eventBus;

    setUp(() {
      eventBus = EventBus();
    });

    tearDown(() async {
      await eventBus.close();
    });

    test('publishes events to subscribers', () async {
      final receivedEvents = <TestEvent>[];
      
      eventBus.on<TestEvent>().listen((event) {
        receivedEvents.add(event);
      });

      final event = TestEvent(aggregateId: UuidValue.generate(), message: 'Hello');
      eventBus.publish(event);

      await Future.delayed(Duration(milliseconds: 10));

      expect(receivedEvents, hasLength(1));
      expect(receivedEvents.first.message, equals('Hello'));
    });

    test('delivers events to multiple subscribers', () async {
      final subscriber1Events = <TestEvent>[];
      final subscriber2Events = <TestEvent>[];

      eventBus.on<TestEvent>().listen((event) {
        subscriber1Events.add(event);
      });

      eventBus.on<TestEvent>().listen((event) {
        subscriber2Events.add(event);
      });

      final event = TestEvent(aggregateId: UuidValue.generate(), message: 'Broadcast');
      eventBus.publish(event);

      await Future.delayed(Duration(milliseconds: 10));

      expect(subscriber1Events, hasLength(1));
      expect(subscriber2Events, hasLength(1));
      expect(subscriber1Events.first.eventId, equals(subscriber2Events.first.eventId));
    });

    test('type-safe subscriptions only receive matching event types', () async {
      final testEvents = <TestEvent>[];
      final anotherEvents = <AnotherTestEvent>[];

      eventBus.on<TestEvent>().listen((event) {
        testEvents.add(event);
      });

      eventBus.on<AnotherTestEvent>().listen((event) {
        anotherEvents.add(event);
      });

      eventBus.publish(TestEvent(aggregateId: UuidValue.generate(), message: 'Test'));
      eventBus.publish(AnotherTestEvent(aggregateId: UuidValue.generate(), value: 42));

      await Future.delayed(Duration(milliseconds: 10));

      expect(testEvents, hasLength(1));
      expect(anotherEvents, hasLength(1));
      expect(testEvents.first.message, equals('Test'));
      expect(anotherEvents.first.value, equals(42));
    });

    test('throws StateError when publishing to closed event bus', () async {
      await eventBus.close();

      expect(
        () => eventBus.publish(TestEvent(aggregateId: UuidValue.generate(), message: 'Fail')),
        throwsStateError,
      );
    });

    test('isClosed returns correct state', () async {
      expect(eventBus.isClosed, isFalse);
      
      await eventBus.close();
      
      expect(eventBus.isClosed, isTrue);
    });

    test('completes subscriptions when event bus is closed', () async {
      var completed = false;
      
      eventBus.on<TestEvent>().listen(
        (event) {},
        onDone: () {
          completed = true;
        },
      );

      await eventBus.close();
      await Future.delayed(Duration(milliseconds: 10));

      expect(completed, isTrue);
    });
  });
}
