/// Cleanup integration tests for distributed events system.
///
/// Tests event cleanup functionality including deletion of old events
/// while retaining recent events based on retention duration.
library;

import 'dart:async';

import 'package:dddart/dddart.dart';
import 'package:dddart_events_distributed/dddart_events_distributed.dart';
// Import example events
import 'package:dddart_events_distributed_example/example_events.dart';
import 'package:test/test.dart';

void main() {
  group('Cleanup Integration Tests', () {
    late InMemoryEventRepository repository;
    late EventBusServer<StoredEvent> server;
    late EventBus eventBus;

    setUp(() {
      repository = InMemoryEventRepository();
      eventBus = EventBus();
    });

    tearDown(() async {
      await server.close();
      repository.clear();
    });

    test(
      'cleanup deletes old events and retains recent events',
      () async {
        // Requirements: 12.1, 12.2, 12.3
        // Arrange: Create server with retention duration
        const retentionDuration = Duration(hours: 1);
        server = EventBusServer<StoredEvent>(
          localEventBus: eventBus,
          eventRepository: repository,
          retentionDuration: retentionDuration,
          storedEventFactory: StoredEvent.fromDomainEvent,
        );

        // Create events with various timestamps
        final now = DateTime.now();
        final oldTimestamp1 = now.subtract(const Duration(hours: 3));
        final oldTimestamp2 = now.subtract(const Duration(hours: 2));
        final recentTimestamp1 = now.subtract(const Duration(minutes: 30));
        final recentTimestamp2 = now.subtract(const Duration(minutes: 10));

        // Create old events (should be deleted)
        final oldEvent1 = StoredEvent(
          id: UuidValue.generate(),
          createdAt: oldTimestamp1,
          aggregateId: UuidValue.generate(),
          eventType: 'UserCreatedEvent',
          eventJson: '{"email":"old1@example.com"}',
          userId: 'user-1',
        );
        final oldEvent2 = StoredEvent(
          id: UuidValue.generate(),
          createdAt: oldTimestamp2,
          aggregateId: UuidValue.generate(),
          eventType: 'OrderPlacedEvent',
          eventJson: '{"amount":50.0}',
          userId: 'user-2',
        );

        // Create recent events (should be retained)
        final recentEvent1 = StoredEvent(
          id: UuidValue.generate(),
          createdAt: recentTimestamp1,
          aggregateId: UuidValue.generate(),
          eventType: 'UserCreatedEvent',
          eventJson: '{"email":"recent1@example.com"}',
          userId: 'user-3',
        );
        final recentEvent2 = StoredEvent(
          id: UuidValue.generate(),
          createdAt: recentTimestamp2,
          aggregateId: UuidValue.generate(),
          eventType: 'PaymentProcessedEvent',
          eventJson: '{"amount":100.0}',
          userId: 'user-4',
        );

        // Save all events
        await repository.save(oldEvent1);
        await repository.save(oldEvent2);
        await repository.save(recentEvent1);
        await repository.save(recentEvent2);

        // Verify all events are stored
        expect(repository.count, equals(4));

        // Act: Call cleanup
        await server.cleanup();

        // Assert: Old events should be deleted, recent events retained
        expect(repository.count, equals(2));

        final remainingEvents = await repository.findAll();
        final remainingIds = remainingEvents.map((e) => e.id).toSet();

        expect(remainingIds.contains(oldEvent1.id), isFalse);
        expect(remainingIds.contains(oldEvent2.id), isFalse);
        expect(remainingIds.contains(recentEvent1.id), isTrue);
        expect(remainingIds.contains(recentEvent2.id), isTrue);
      },
    );

    test(
      'cleanup with no retention duration logs warning',
      () async {
        // Requirements: 12.1, 12.2
        // Arrange: Create server WITHOUT retention duration
        server = EventBusServer<StoredEvent>(
          localEventBus: eventBus,
          eventRepository: repository,
          // No retentionDuration provided
          storedEventFactory: StoredEvent.fromDomainEvent,
        );

        // Create some events
        final event1 = UserCreatedEvent(
          aggregateId: UuidValue.generate(),
          email: 'user1@example.com',
          name: 'User 1',
        );
        final event2 = OrderPlacedEvent(
          aggregateId: UuidValue.generate(),
          amount: 50,
          productId: 'product-1',
        );

        server.publish(event1);
        server.publish(event2);

        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Verify events are stored
        expect(repository.count, equals(2));

        // Act: Call cleanup (should log warning and not delete anything)
        await server.cleanup();

        // Assert: No events should be deleted
        expect(repository.count, equals(2));
      },
    );

    test(
      'cleanup handles edge case at retention boundary',
      () async {
        // Requirements: 12.1, 12.2, 12.3
        // Arrange: Create server with retention duration
        const retentionDuration = Duration(hours: 1);
        server = EventBusServer<StoredEvent>(
          localEventBus: eventBus,
          eventRepository: repository,
          retentionDuration: retentionDuration,
          storedEventFactory: StoredEvent.fromDomainEvent,
        );

        // Create events relative to a fixed point in the past
        // This ensures the cutoff calculation is predictable
        final baseTime = DateTime.now().subtract(const Duration(hours: 2));

        // These events are 2 hours old
        final veryOldEvent = StoredEvent(
          id: UuidValue.generate(),
          createdAt: baseTime,
          aggregateId: UuidValue.generate(),
          eventType: 'UserCreatedEvent',
          eventJson: '{"email":"veryold@example.com"}',
        );

        // This event is 1 hour and 1 second old (should be deleted)
        final justOldEnough = StoredEvent(
          id: UuidValue.generate(),
          createdAt: baseTime.add(const Duration(hours: 1, seconds: -1)),
          aggregateId: UuidValue.generate(),
          eventType: 'OrderPlacedEvent',
          eventJson: '{"amount":50.0}',
        );

        // This event is 59 minutes old (should be retained)
        final justYoungEnough = StoredEvent(
          id: UuidValue.generate(),
          createdAt: baseTime.add(const Duration(minutes: 61)),
          aggregateId: UuidValue.generate(),
          eventType: 'PaymentProcessedEvent',
          eventJson: '{"amount":100.0}',
        );

        await repository.save(veryOldEvent);
        await repository.save(justOldEnough);
        await repository.save(justYoungEnough);

        expect(repository.count, equals(3));

        // Act: Call cleanup
        await server.cleanup();

        // Assert: Old events should be deleted, recent event retained
        expect(repository.count, equals(1));

        final remainingEvents = await repository.findAll();
        final remainingIds = remainingEvents.map((e) => e.id).toSet();

        expect(remainingIds.contains(veryOldEvent.id), isFalse);
        expect(remainingIds.contains(justOldEnough.id), isFalse);
        expect(remainingIds.contains(justYoungEnough.id), isTrue);
      },
    );

    test(
      'cleanup with large number of events',
      () async {
        // Requirements: 12.1, 12.2, 12.3
        // Arrange: Create server with retention duration
        const retentionDuration = Duration(hours: 1);
        server = EventBusServer<StoredEvent>(
          localEventBus: eventBus,
          eventRepository: repository,
          retentionDuration: retentionDuration,
          storedEventFactory: StoredEvent.fromDomainEvent,
        );

        final now = DateTime.now();
        final oldTimestamp = now.subtract(const Duration(hours: 2));
        final recentTimestamp = now.subtract(const Duration(minutes: 30));

        // Create 50 old events and 50 recent events
        for (var i = 0; i < 50; i++) {
          final oldEvent = StoredEvent(
            id: UuidValue.generate(),
            createdAt: oldTimestamp,
            aggregateId: UuidValue.generate(),
            eventType: 'UserCreatedEvent',
            eventJson: '{"email":"old$i@example.com"}',
          );
          await repository.save(oldEvent);
        }

        for (var i = 0; i < 50; i++) {
          final recentEvent = StoredEvent(
            id: UuidValue.generate(),
            createdAt: recentTimestamp,
            aggregateId: UuidValue.generate(),
            eventType: 'OrderPlacedEvent',
            eventJson: '{"amount":${i * 10.0}}',
          );
          await repository.save(recentEvent);
        }

        expect(repository.count, equals(100));

        // Act: Call cleanup
        await server.cleanup();

        // Assert: Only recent events should remain
        expect(repository.count, equals(50));

        final remainingEvents = await repository.findAll();
        expect(
          remainingEvents.every((e) => e.eventType == 'OrderPlacedEvent'),
          isTrue,
        );
      },
    );

    test(
      'multiple cleanup calls are idempotent',
      () async {
        // Requirements: 12.1, 12.2, 12.3
        // Arrange: Create server with retention duration
        const retentionDuration = Duration(hours: 1);
        server = EventBusServer<StoredEvent>(
          localEventBus: eventBus,
          eventRepository: repository,
          retentionDuration: retentionDuration,
          storedEventFactory: StoredEvent.fromDomainEvent,
        );

        final now = DateTime.now();
        final oldTimestamp = now.subtract(const Duration(hours: 2));
        final recentTimestamp = now.subtract(const Duration(minutes: 30));

        // Create old and recent events
        final oldEvent = StoredEvent(
          id: UuidValue.generate(),
          createdAt: oldTimestamp,
          aggregateId: UuidValue.generate(),
          eventType: 'UserCreatedEvent',
          eventJson: '{"email":"old@example.com"}',
        );
        final recentEvent = StoredEvent(
          id: UuidValue.generate(),
          createdAt: recentTimestamp,
          aggregateId: UuidValue.generate(),
          eventType: 'OrderPlacedEvent',
          eventJson: '{"amount":50.0}',
        );

        await repository.save(oldEvent);
        await repository.save(recentEvent);

        expect(repository.count, equals(2));

        // Act: Call cleanup multiple times
        await server.cleanup();
        expect(repository.count, equals(1));

        await server.cleanup();
        expect(repository.count, equals(1));

        await server.cleanup();
        expect(repository.count, equals(1));

        // Assert: Recent event should still be present
        final remainingEvents = await repository.findAll();
        expect(remainingEvents.first.id, equals(recentEvent.id));
      },
    );
  });
}
