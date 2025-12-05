/// Property-based tests for no-filter behavior in HTTP endpoints.
///
/// **Feature: distributed-events, Property 8: No filter means all events delivered**
/// **Validates: Requirements 4.5**
@Tags(['property-test'])
library;

import 'dart:convert';
import 'dart:math';

import 'package:dddart/dddart.dart';
import 'package:dddart_events_distributed/src/event_http_endpoints.dart';
import 'package:dddart_events_distributed/src/event_repository.dart';
import 'package:dddart_events_distributed/src/stored_event.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  group('Property 8: No filter means all events delivered', () {
    test(
      'should return all events when no authorization filter is configured',
      () async {
        final random = Random(42);

        for (var i = 0; i < 100; i++) {
          // Create repository with random events
          final repository = InMemoryEventRepository();
          final eventCount = 5 + random.nextInt(26); // 5-30 events

          // Generate events with various authorization fields
          final events = <StoredEvent>[];
          for (var j = 0; j < eventCount; j++) {
            final event = _generateRandomStoredEvent(random);
            await repository.save(event);
            events.add(event);
          }

          // Create endpoints WITHOUT authorization filter
          final endpoints = EventHttpEndpoints<StoredEvent>(
            eventRepository: repository,
            // authorizationFilter is null
          );

          // Create mock request
          final request = Request(
            'GET',
            Uri.parse('http://localhost/events?since=2020-01-01T00:00:00.000Z'),
          );

          // Call GET endpoint
          final response = await endpoints.handleGetEvents(request);

          // Verify response
          expect(response.statusCode, equals(200));

          // Parse response body
          final body = await response.readAsString();
          final returnedEvents = jsonDecode(body) as List<dynamic>;

          // Verify ALL events are returned
          expect(
            returnedEvents.length,
            equals(eventCount),
            reason:
                'Iteration $i: all $eventCount events should be returned without filter',
          );

          // Verify each event is present in response
          for (final event in events) {
            final found = returnedEvents.any(
              (json) => json['id'] == event.id.toString(),
            );
            expect(
              found,
              isTrue,
              reason: 'Iteration $i: event ${event.id} should be in response',
            );
          }
        }
      },
    );

    test(
      'should return events regardless of authorization fields when no filter',
      () async {
        final random = Random(43);

        for (var i = 0; i < 100; i++) {
          // Create repository with events having various authorization fields
          final repository = InMemoryEventRepository();
          final eventCount = 10 + random.nextInt(21); // 10-30 events

          final events = <StoredEvent>[];

          // Create events with different combinations of authorization fields
          for (var j = 0; j < eventCount; j++) {
            final event = StoredEvent(
              id: UuidValue.generate(),
              createdAt: _generateRandomDateTime(random),
              aggregateId: UuidValue.generate(),
              eventType: 'TestEvent',
              eventJson: '{"data":"test-$j"}',
              // Vary which fields are present
              userId: j % 3 == 0 ? 'user-${random.nextInt(10)}' : null,
              tenantId: j % 3 == 1 ? 'tenant-${random.nextInt(5)}' : null,
              sessionId: j % 3 == 2 ? 'session-${random.nextInt(10)}' : null,
            );
            await repository.save(event);
            events.add(event);
          }

          // Create endpoints WITHOUT authorization filter
          final endpoints = EventHttpEndpoints<StoredEvent>(
            eventRepository: repository,
          );

          // Create mock request
          final request = Request(
            'GET',
            Uri.parse('http://localhost/events?since=2020-01-01T00:00:00.000Z'),
          );

          // Call GET endpoint
          final response = await endpoints.handleGetEvents(request);

          // Verify response
          expect(response.statusCode, equals(200));

          // Parse response body
          final body = await response.readAsString();
          final returnedEvents = jsonDecode(body) as List<dynamic>;

          // Verify ALL events are returned regardless of authorization fields
          expect(
            returnedEvents.length,
            equals(eventCount),
            reason:
                'Iteration $i: all events should be returned regardless of auth fields',
          );

          // Verify events with null userId are included
          final eventsWithNullUserId =
              events.where((e) => e.userId == null).length;
          final returnedWithNullUserId =
              returnedEvents.where((json) => json['userId'] == null).length;
          expect(
            returnedWithNullUserId,
            equals(eventsWithNullUserId),
            reason: 'Iteration $i: events with null userId should be included',
          );

          // Verify events with null tenantId are included
          final eventsWithNullTenantId =
              events.where((e) => e.tenantId == null).length;
          final returnedWithNullTenantId =
              returnedEvents.where((json) => json['tenantId'] == null).length;
          expect(
            returnedWithNullTenantId,
            equals(eventsWithNullTenantId),
            reason:
                'Iteration $i: events with null tenantId should be included',
          );
        }
      },
    );

    test(
      'should return all events even with sensitive data when no filter',
      () async {
        final random = Random(44);

        for (var i = 0; i < 50; i++) {
          // Create repository with events containing "sensitive" data
          final repository = InMemoryEventRepository();
          final eventCount = 5 + random.nextInt(16); // 5-20 events

          final events = <StoredEvent>[];
          for (var j = 0; j < eventCount; j++) {
            final isSensitive = random.nextBool();
            final event = StoredEvent(
              id: UuidValue.generate(),
              createdAt: _generateRandomDateTime(random),
              aggregateId: UuidValue.generate(),
              eventType: isSensitive ? 'SensitiveEvent' : 'PublicEvent',
              eventJson: isSensitive
                  ? '{"secret":"confidential-$j"}'
                  : '{"data":"public-$j"}',
              userId: 'user-${random.nextInt(10)}',
              tenantId: 'tenant-${random.nextInt(5)}',
            );
            await repository.save(event);
            events.add(event);
          }

          // Create endpoints WITHOUT authorization filter
          final endpoints = EventHttpEndpoints<StoredEvent>(
            eventRepository: repository,
          );

          // Create mock request
          final request = Request(
            'GET',
            Uri.parse('http://localhost/events?since=2020-01-01T00:00:00.000Z'),
          );

          // Call GET endpoint
          final response = await endpoints.handleGetEvents(request);

          // Verify response
          expect(response.statusCode, equals(200));

          // Parse response body
          final body = await response.readAsString();
          final returnedEvents = jsonDecode(body) as List<dynamic>;

          // Verify ALL events are returned, including sensitive ones
          expect(
            returnedEvents.length,
            equals(eventCount),
            reason:
                'Iteration $i: all events including sensitive should be returned',
          );

          // Verify sensitive events are included
          final sensitiveCount =
              events.where((e) => e.eventType == 'SensitiveEvent').length;
          final returnedSensitiveCount = returnedEvents
              .where((json) => json['eventType'] == 'SensitiveEvent')
              .length;
          expect(
            returnedSensitiveCount,
            equals(sensitiveCount),
            reason:
                'Iteration $i: sensitive events should be included without filter',
          );
        }
      },
    );

    test(
      'should return empty array when no events match timestamp but no filter',
      () async {
        final random = Random(45);

        for (var i = 0; i < 50; i++) {
          // Create repository with old events
          final repository = InMemoryEventRepository();
          final eventCount = 5 + random.nextInt(11); // 5-15 events

          // Generate events with old timestamps (before 2020)
          for (var j = 0; j < eventCount; j++) {
            final event = StoredEvent(
              id: UuidValue.generate(),
              createdAt: DateTime(
                2019,
                1 + random.nextInt(12),
                1 + random.nextInt(28),
              ),
              aggregateId: UuidValue.generate(),
              eventType: 'TestEvent',
              eventJson: '{"data":"test-$j"}',
              userId: 'user-${random.nextInt(10)}',
            );
            await repository.save(event);
          }

          // Create endpoints WITHOUT authorization filter
          final endpoints = EventHttpEndpoints<StoredEvent>(
            eventRepository: repository,
          );

          // Create mock request with timestamp after all events
          final request = Request(
            'GET',
            Uri.parse('http://localhost/events?since=2025-01-01T00:00:00.000Z'),
          );

          // Call GET endpoint
          final response = await endpoints.handleGetEvents(request);

          // Verify response
          expect(response.statusCode, equals(200));

          // Parse response body
          final body = await response.readAsString();
          final returnedEvents = jsonDecode(body) as List<dynamic>;

          // Verify empty array is returned (no events match timestamp)
          expect(
            returnedEvents.length,
            equals(0),
            reason:
                'Iteration $i: empty array should be returned when no events match timestamp',
          );
        }
      },
    );

    test(
      'should return all events from mixed sources when no filter',
      () async {
        final random = Random(46);

        for (var i = 0; i < 100; i++) {
          // Create repository with events from different "sources"
          final repository = InMemoryEventRepository();
          final eventCount = 10 + random.nextInt(21); // 10-30 events

          final events = <StoredEvent>[];

          // Simulate events from different users, tenants, and sessions
          for (var j = 0; j < eventCount; j++) {
            final event = StoredEvent(
              id: UuidValue.generate(),
              createdAt: _generateRandomDateTime(random),
              aggregateId: UuidValue.generate(),
              eventType: 'Event${random.nextInt(5)}', // Different event types
              eventJson: '{"data":"test-$j"}',
              userId: 'user-${random.nextInt(20)}', // Wide range of users
              tenantId: 'tenant-${random.nextInt(10)}', // Wide range of tenants
              sessionId:
                  'session-${random.nextInt(50)}', // Wide range of sessions
            );
            await repository.save(event);
            events.add(event);
          }

          // Create endpoints WITHOUT authorization filter
          final endpoints = EventHttpEndpoints<StoredEvent>(
            eventRepository: repository,
          );

          // Create mock request
          final request = Request(
            'GET',
            Uri.parse('http://localhost/events?since=2020-01-01T00:00:00.000Z'),
          );

          // Call GET endpoint
          final response = await endpoints.handleGetEvents(request);

          // Verify response
          expect(response.statusCode, equals(200));

          // Parse response body
          final body = await response.readAsString();
          final returnedEvents = jsonDecode(body) as List<dynamic>;

          // Verify ALL events from all sources are returned
          expect(
            returnedEvents.length,
            equals(eventCount),
            reason:
                'Iteration $i: all events from all sources should be returned',
          );

          // Verify we have events from multiple users
          final uniqueUsers = returnedEvents
              .map((json) => json['userId'] as String?)
              .where((userId) => userId != null)
              .toSet();
          expect(
            uniqueUsers.length,
            greaterThan(1),
            reason:
                'Iteration $i: events from multiple users should be present',
          );

          // Verify we have events from multiple tenants
          final uniqueTenants = returnedEvents
              .map((json) => json['tenantId'] as String?)
              .where((tenantId) => tenantId != null)
              .toSet();
          expect(
            uniqueTenants.length,
            greaterThan(1),
            reason:
                'Iteration $i: events from multiple tenants should be present',
          );
        }
      },
    );
  });
}

// Helper functions

/// Generates a random StoredEvent for testing.
StoredEvent _generateRandomStoredEvent(Random random) {
  final includeUserId = random.nextBool();
  final includeTenantId = random.nextBool();
  final includeSessionId = random.nextBool();

  return StoredEvent(
    id: UuidValue.generate(),
    createdAt: _generateRandomDateTime(random),
    aggregateId: UuidValue.generate(),
    eventType: 'TestEvent',
    eventJson: '{"data":"test-${random.nextInt(1000)}"}',
    userId: includeUserId ? 'user-${random.nextInt(10)}' : null,
    tenantId: includeTenantId ? 'tenant-${random.nextInt(5)}' : null,
    sessionId: includeSessionId ? 'session-${random.nextInt(10)}' : null,
  );
}

/// Generates a random DateTime.
DateTime _generateRandomDateTime(Random random) {
  final year = 2020 + random.nextInt(5);
  final month = 1 + random.nextInt(12);
  final day = 1 + random.nextInt(28);
  final hour = random.nextInt(24);
  final minute = random.nextInt(60);
  final second = random.nextInt(60);

  return DateTime(year, month, day, hour, minute, second);
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

  @override
  Future<void> deleteById(UuidValue id) async {
    _events.removeWhere((e) => e.id == id);
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
