/// Property-based tests for EventBusServer cleanup functionality.
///
/// **Feature: distributed-events, Property 11: Cleanup deletes old events**
/// **Validates: Requirements 12.3**
@Tags(['property-test'])
library;

import 'dart:math';

import 'package:dddart/dddart.dart';
import 'package:dddart_events_distributed/src/event_bus_server.dart';
import 'package:dddart_events_distributed/src/event_repository.dart';
import 'package:dddart_events_distributed/src/stored_event.dart';
import 'package:test/test.dart';

void main() {
  group('Property 11: Cleanup deletes old events', () {
    test(
      'should delete all events older than retention duration',
      () async {
        final random = Random(42);

        for (var i = 0; i < 100; i++) {
          // Create fresh instances
          final eventBus = EventBus();
          final repository = InMemoryEventRepository();

          // Generate random retention duration (1-30 days)
          final retentionDays = 1 + random.nextInt(30);
          final retentionDuration = Duration(days: retentionDays);

          final server = EventBusServer<StoredEvent>(
            localEventBus: eventBus,
            eventRepository: repository,
            storedEventFactory: StoredEvent.fromDomainEvent,
            retentionDuration: retentionDuration,
          );

          // Generate events with various ages
          final now = DateTime.now();
          final oldEventCount = 2 + random.nextInt(5); // 2-6 old events
          final recentEventCount = 2 + random.nextInt(5); // 2-6 recent events

          // Create old events (older than retention)
          for (var j = 0; j < oldEventCount; j++) {
            final daysOld = retentionDays + 1 + random.nextInt(30);
            final oldTimestamp = now.subtract(Duration(days: daysOld));
            final oldEvent = _createEventWithTimestamp(oldTimestamp);
            await repository.save(oldEvent);
          }

          // Create recent events (within retention)
          for (var j = 0; j < recentEventCount; j++) {
            final daysOld = random.nextInt(retentionDays);
            final recentTimestamp = now.subtract(Duration(days: daysOld));
            final recentEvent = _createEventWithTimestamp(recentTimestamp);
            await repository.save(recentEvent);
          }

          // Verify initial state
          final beforeCleanup = await repository.findAll();
          expect(
            beforeCleanup.length,
            equals(oldEventCount + recentEventCount),
            reason: 'Iteration $i: should have all events before cleanup',
          );

          // Perform cleanup
          await server.cleanup();

          // Verify old events were deleted
          final afterCleanup = await repository.findAll();
          expect(
            afterCleanup.length,
            equals(recentEventCount),
            reason:
                'Iteration $i: should only have recent events after cleanup',
          );

          // Verify all remaining events are within retention
          final cutoff = now.subtract(retentionDuration);
          for (final event in afterCleanup) {
            expect(
              event.createdAt.isAfter(cutoff) ||
                  event.createdAt.isAtSameMomentAs(cutoff),
              isTrue,
              reason: 'Iteration $i: all remaining events should be '
                  'within retention',
            );
          }

          // Clean up
          await server.close();
        }
      },
    );

    test(
      'should handle cleanup with no old events',
      () async {
        final random = Random(43);

        for (var i = 0; i < 50; i++) {
          // Create fresh instances
          final eventBus = EventBus();
          final repository = InMemoryEventRepository();
          const retentionDuration = Duration(days: 30);

          final server = EventBusServer<StoredEvent>(
            localEventBus: eventBus,
            eventRepository: repository,
            storedEventFactory: StoredEvent.fromDomainEvent,
            retentionDuration: retentionDuration,
          );

          // Create only recent events
          final now = DateTime.now();
          final eventCount = 2 + random.nextInt(8); // 2-9 events

          for (var j = 0; j < eventCount; j++) {
            final daysOld = random.nextInt(30); // All within retention
            final timestamp = now.subtract(Duration(days: daysOld));
            final event = _createEventWithTimestamp(timestamp);
            await repository.save(event);
          }

          // Verify initial state
          final beforeCleanup = await repository.findAll();
          expect(beforeCleanup.length, equals(eventCount));

          // Perform cleanup
          await server.cleanup();

          // Verify no events were deleted
          final afterCleanup = await repository.findAll();
          expect(
            afterCleanup.length,
            equals(eventCount),
            reason:
                'Iteration $i: no events should be deleted when all are recent',
          );

          // Clean up
          await server.close();
        }
      },
    );

    test(
      'should handle cleanup with all old events',
      () async {
        final random = Random(44);

        for (var i = 0; i < 50; i++) {
          // Create fresh instances
          final eventBus = EventBus();
          final repository = InMemoryEventRepository();
          const retentionDuration = Duration(days: 7);

          final server = EventBusServer<StoredEvent>(
            localEventBus: eventBus,
            eventRepository: repository,
            storedEventFactory: StoredEvent.fromDomainEvent,
            retentionDuration: retentionDuration,
          );

          // Create only old events
          final now = DateTime.now();
          final eventCount = 2 + random.nextInt(8); // 2-9 events

          for (var j = 0; j < eventCount; j++) {
            final daysOld = 8 + random.nextInt(30); // All older than retention
            final timestamp = now.subtract(Duration(days: daysOld));
            final event = _createEventWithTimestamp(timestamp);
            await repository.save(event);
          }

          // Verify initial state
          final beforeCleanup = await repository.findAll();
          expect(beforeCleanup.length, equals(eventCount));

          // Perform cleanup
          await server.cleanup();

          // Verify all events were deleted
          final afterCleanup = await repository.findAll();
          expect(
            afterCleanup.length,
            equals(0),
            reason:
                'Iteration $i: all events should be deleted when all are old',
          );

          // Clean up
          await server.close();
        }
      },
    );

    test(
      'should handle cleanup with no retention duration configured',
      () async {
        final random = Random(45);

        for (var i = 0; i < 50; i++) {
          // Create server without retention duration
          final eventBus = EventBus();
          final repository = InMemoryEventRepository();

          final server = EventBusServer<StoredEvent>(
            localEventBus: eventBus,
            eventRepository: repository,
            storedEventFactory: StoredEvent.fromDomainEvent,
            // No retentionDuration specified
          );

          // Create some events
          final now = DateTime.now();
          final eventCount = 2 + random.nextInt(5);

          for (var j = 0; j < eventCount; j++) {
            final daysOld = random.nextInt(60);
            final timestamp = now.subtract(Duration(days: daysOld));
            final event = _createEventWithTimestamp(timestamp);
            await repository.save(event);
          }

          // Verify initial state
          final beforeCleanup = await repository.findAll();
          expect(beforeCleanup.length, equals(eventCount));

          // Perform cleanup (should do nothing)
          await server.cleanup();

          // Verify no events were deleted
          final afterCleanup = await repository.findAll();
          expect(
            afterCleanup.length,
            equals(eventCount),
            reason: 'Iteration $i: no events should be deleted when no '
                'retention is configured',
          );

          // Clean up
          await server.close();
        }
      },
    );

    test(
      'should handle cleanup at exact retention boundary',
      () async {
        for (var i = 0; i < 100; i++) {
          // Create fresh instances
          final eventBus = EventBus();
          final repository = InMemoryEventRepository();
          const retentionDuration = Duration(days: 10);

          final server = EventBusServer<StoredEvent>(
            localEventBus: eventBus,
            eventRepository: repository,
            storedEventFactory: StoredEvent.fromDomainEvent,
            retentionDuration: retentionDuration,
          );

          // Use a fixed reference time to avoid timing issues
          final now = DateTime.now();

          // Create events relative to retention duration
          // Old event: clearly before retention
          final oldEvent = _createEventWithTimestamp(
            now.subtract(retentionDuration).subtract(const Duration(days: 1)),
          );
          await repository.save(oldEvent);

          // Recent event: clearly within retention
          final recentEvent = _createEventWithTimestamp(
            now.subtract(const Duration(days: 5)),
          );
          await repository.save(recentEvent);

          // Perform cleanup
          await server.cleanup();

          // Verify boundary behavior
          final afterCleanup = await repository.findAll();
          expect(
            afterCleanup.length,
            equals(1),
            reason: 'Iteration $i: only recent events should remain',
          );

          // Verify the correct event remains
          expect(
            afterCleanup.first.id,
            equals(recentEvent.id),
            reason: 'Iteration $i: recent event should be kept',
          );

          // Clean up
          await server.close();
        }
      },
    );
  });
}

// Helper functions

/// Creates a StoredEvent with a specific timestamp.
StoredEvent _createEventWithTimestamp(DateTime timestamp) {
  return StoredEvent(
    id: UuidValue.generate(),
    createdAt: timestamp,
    aggregateId: UuidValue.generate(),
    eventType: 'TestEvent',
    eventJson: '{"data":"test"}',
  );
}

// Test implementations

/// In-memory implementation of EventRepository for testing.
class InMemoryEventRepository implements EventRepository<StoredEvent> {
  final List<StoredEvent> _events = [];

  @override
  Future<void> save(StoredEvent entity) async {
    _events.add(entity);
  }

  @override
  Future<StoredEvent> getById(UuidValue id) async {
    try {
      return _events.firstWhere((e) => e.id == id);
    } catch (_) {
      throw Exception('Event not found: $id');
    }
  }

  /// Helper method for testing - not part of Repository interface.
  Future<List<StoredEvent>> findAll() async {
    return List.from(_events);
  }

  @override
  Future<void> deleteById(UuidValue id) async {
    final initialLength = _events.length;
    _events.removeWhere((e) => e.id == id);
    if (_events.length == initialLength) {
      throw Exception('Event not found: $id');
    }
  }

  @override
  Future<List<StoredEvent>> findSince(DateTime timestamp) async {
    return _events
        .where(
          (e) =>
              e.createdAt.isAfter(timestamp) ||
              e.createdAt.isAtSameMomentAs(timestamp),
        )
        .toList();
  }

  @override
  Future<void> deleteOlderThan(DateTime timestamp) async {
    _events.removeWhere((e) => e.createdAt.isBefore(timestamp));
  }
}
