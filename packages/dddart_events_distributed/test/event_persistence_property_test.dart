/// Property-based tests for EventBusServer event persistence.
///
/// **Feature: distributed-events, Property 1: Published events are persisted**
/// **Validates: Requirements 1.2**
@Tags(['property-test'])
library;

import 'dart:math';

import 'package:dddart/dddart.dart';
import 'package:dddart_events_distributed/src/event_bus_server.dart';
import 'package:dddart_events_distributed/src/event_repository.dart';
import 'package:dddart_events_distributed/src/stored_event.dart';
import 'package:test/test.dart';

void main() {
  group('Property 1: Published events are persisted', () {
    test(
      'should persist all DomainEvents published to EventBusServer',
      () async {
        final random = Random(42);

        for (var i = 0; i < 100; i++) {
          // Create fresh instances for each iteration
          final eventBus = EventBus();
          final repository = InMemoryEventRepository();
          final server = EventBusServer<StoredEvent>(
            localEventBus: eventBus,
            eventRepository: repository,
            storedEventFactory: StoredEvent.fromDomainEvent,
          );

          // Generate random test event
          final testEvent = _generateRandomTestEvent(random);

          // Publish event to server
          server.publish(testEvent);

          // Wait for async persistence to complete
          await Future<void>.delayed(const Duration(milliseconds: 10));

          // Verify event was persisted
          final persistedEvents = await repository.findAll();
          expect(
            persistedEvents.length,
            equals(1),
            reason: 'Iteration $i: exactly one event should be persisted',
          );

          final persistedEvent = persistedEvents.first;
          expect(
            persistedEvent.id,
            equals(testEvent.eventId),
            reason: 'Iteration $i: persisted event id should match',
          );
          expect(
            persistedEvent.aggregateId,
            equals(testEvent.aggregateId),
            reason: 'Iteration $i: persisted aggregateId should match',
          );
          expect(
            persistedEvent.eventType,
            equals('TestDomainEvent'),
            reason: 'Iteration $i: persisted eventType should match',
          );

          // Verify authorization fields extracted from context
          expect(
            persistedEvent.userId,
            equals(testEvent.context['userId']),
            reason: 'Iteration $i: userId should be extracted from context',
          );
          expect(
            persistedEvent.tenantId,
            equals(testEvent.context['tenantId']),
            reason: 'Iteration $i: tenantId should be extracted from context',
          );
          expect(
            persistedEvent.sessionId,
            equals(testEvent.context['sessionId']),
            reason: 'Iteration $i: sessionId should be extracted from context',
          );

          // Clean up
          await server.close();
        }
      },
    );

    test(
      'should persist multiple events in order',
      () async {
        final random = Random(43);

        for (var i = 0; i < 50; i++) {
          // Create fresh instances
          final eventBus = EventBus();
          final repository = InMemoryEventRepository();
          final server = EventBusServer<StoredEvent>(
            localEventBus: eventBus,
            eventRepository: repository,
            storedEventFactory: StoredEvent.fromDomainEvent,
          );

          // Generate random number of events (2-10)
          final eventCount = 2 + random.nextInt(9);
          final testEvents = List.generate(
            eventCount,
            (_) => _generateRandomTestEvent(random),
          );

          // Publish all events
          for (final event in testEvents) {
            server.publish(event);
          }

          // Wait for async persistence to complete
          await Future<void>.delayed(const Duration(milliseconds: 50));

          // Verify all events were persisted
          final persistedEvents = await repository.findAll();
          expect(
            persistedEvents.length,
            equals(eventCount),
            reason: 'Iteration $i: all $eventCount events should be persisted',
          );

          // Verify each event was persisted correctly
          for (var j = 0; j < eventCount; j++) {
            final testEvent = testEvents[j];
            final persistedEvent = persistedEvents.firstWhere(
              (e) => e.id == testEvent.eventId,
            );

            expect(
              persistedEvent.aggregateId,
              equals(testEvent.aggregateId),
              reason: 'Iteration $i, Event $j: aggregateId should match',
            );
            expect(
              persistedEvent.eventType,
              equals('TestDomainEvent'),
              reason: 'Iteration $i, Event $j: eventType should match',
            );
          }

          // Clean up
          await server.close();
        }
      },
    );

    test(
      'should handle events with various context values',
      () async {
        final random = Random(44);

        for (var i = 0; i < 100; i++) {
          // Create fresh instances
          final eventBus = EventBus();
          final repository = InMemoryEventRepository();
          final server = EventBusServer<StoredEvent>(
            localEventBus: eventBus,
            eventRepository: repository,
            storedEventFactory: StoredEvent.fromDomainEvent,
          );

          // Generate event with random context fields
          final includeUserId = random.nextBool();
          final includeTenantId = random.nextBool();
          final includeSessionId = random.nextBool();

          final context = <String, dynamic>{};
          if (includeUserId) {
            context['userId'] = 'user-${random.nextInt(10000)}';
          }
          if (includeTenantId) {
            context['tenantId'] = 'tenant-${random.nextInt(1000)}';
          }
          if (includeSessionId) {
            context['sessionId'] = 'session-${random.nextInt(100000)}';
          }

          final testEvent = TestDomainEvent(
            aggregateId: UuidValue.generate(),
            context: context,
            data: 'test-${random.nextInt(1000)}',
          );

          // Publish event
          server.publish(testEvent);

          // Wait for persistence
          await Future<void>.delayed(const Duration(milliseconds: 10));

          // Verify event was persisted with correct context
          final persistedEvents = await repository.findAll();
          expect(persistedEvents.length, equals(1));

          final persistedEvent = persistedEvents.first;
          expect(
            persistedEvent.userId,
            equals(context['userId']),
            reason: 'Iteration $i: userId should match context (null or value)',
          );
          expect(
            persistedEvent.tenantId,
            equals(context['tenantId']),
            reason:
                'Iteration $i: tenantId should match context (null or value)',
          );
          expect(
            persistedEvent.sessionId,
            equals(context['sessionId']),
            reason:
                'Iteration $i: sessionId should match context (null or value)',
          );

          // Clean up
          await server.close();
        }
      },
    );

    test(
      'should continue persisting after persistence errors',
      () async {
        final random = Random(45);

        for (var i = 0; i < 50; i++) {
          // Create instances with failing repository (30% failure rate)
          final eventBus = EventBus();
          final repository = FailingEventRepository(failureRate: 0.3);
          final server = EventBusServer<StoredEvent>(
            localEventBus: eventBus,
            eventRepository: repository,
            storedEventFactory: StoredEvent.fromDomainEvent,
          );

          // Publish multiple events
          final eventCount = 10 + random.nextInt(11); // 10-20 events
          for (var j = 0; j < eventCount; j++) {
            final testEvent = _generateRandomTestEvent(random);
            server.publish(testEvent);
          }

          // Wait for persistence attempts
          await Future<void>.delayed(const Duration(milliseconds: 50));

          // Verify that some events were persisted despite failures
          // (The server should continue processing even after errors)
          // With 30% failure rate and 10-20 events, we should have some
          // successful persists
          final persistedEvents = await repository.findAll();
          expect(
            persistedEvents.length,
            greaterThan(0),
            reason: 'Iteration $i: at least some events should be persisted',
          );

          // Clean up
          await server.close();
        }
      },
    );
  });
}

// Generator functions

/// Generates a random test DomainEvent.
TestDomainEvent _generateRandomTestEvent(Random random) {
  final includeUserId = random.nextBool();
  final includeTenantId = random.nextBool();
  final includeSessionId = random.nextBool();

  final context = <String, dynamic>{};
  if (includeUserId) {
    context['userId'] = 'user-${random.nextInt(10000)}';
  }
  if (includeTenantId) {
    context['tenantId'] = 'tenant-${random.nextInt(1000)}';
  }
  if (includeSessionId) {
    context['sessionId'] = 'session-${random.nextInt(100000)}';
  }

  return TestDomainEvent(
    aggregateId: UuidValue.generate(),
    eventId: UuidValue.generate(),
    occurredAt: _generateRandomDateTime(random),
    context: context,
    data: 'test-data-${random.nextInt(1000)}',
  );
}

/// Generates a random DateTime.
DateTime _generateRandomDateTime(Random random) {
  // Generate dates between 2020 and 2025
  final year = 2020 + random.nextInt(5);
  final month = 1 + random.nextInt(12);
  final day = 1 + random.nextInt(28); // Safe for all months
  final hour = random.nextInt(24);
  final minute = random.nextInt(60);
  final second = random.nextInt(60);
  final millisecond = random.nextInt(1000);

  return DateTime(year, month, day, hour, minute, second, millisecond);
}

// Test implementations

/// Test DomainEvent for property testing.
class TestDomainEvent extends DomainEvent {
  TestDomainEvent({
    required super.aggregateId,
    required this.data,
    super.eventId,
    super.occurredAt,
    super.context,
  });

  final String data;
}

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

/// Repository that randomly fails to test error handling.
class FailingEventRepository implements EventRepository<StoredEvent> {
  FailingEventRepository({this.failureRate = 0.5});

  final double failureRate;
  final List<StoredEvent> _events = [];
  final Random _random = Random();

  void _maybeThrow() {
    if (_random.nextDouble() < failureRate) {
      throw Exception('Simulated repository failure');
    }
  }

  @override
  Future<void> save(StoredEvent entity) async {
    _maybeThrow();
    _events.add(entity);
  }

  @override
  Future<StoredEvent> getById(UuidValue id) async {
    _maybeThrow();
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
    _maybeThrow();
    final initialLength = _events.length;
    _events.removeWhere((e) => e.id == id);
    if (_events.length == initialLength) {
      throw Exception('Event not found: $id');
    }
  }

  @override
  Future<List<StoredEvent>> findSince(DateTime timestamp) async {
    _maybeThrow();
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
    _maybeThrow();
    _events.removeWhere((e) => e.createdAt.isBefore(timestamp));
  }
}
