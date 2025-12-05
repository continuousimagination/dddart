/// Property-based tests for authorization filtering in HTTP endpoints.
///
/// **Feature: distributed-events, Property 7: Authorization filter controls event delivery**
/// **Validates: Requirements 4.3**
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
  group('Property 7: Authorization filter controls event delivery', () {
    test(
      'should exclude events when authorization filter returns false',
      () async {
        final random = Random(42);

        for (var i = 0; i < 100; i++) {
          // Create repository with random events
          final repository = InMemoryEventRepository();
          final eventCount = 5 + random.nextInt(16); // 5-20 events

          // Generate events with random userId values
          final events = <StoredEvent>[];
          for (var j = 0; j < eventCount; j++) {
            final event = _generateRandomStoredEvent(random);
            await repository.save(event);
            events.add(event);
          }

          // Pick a random userId to filter by
          final allowedUserId = events[random.nextInt(events.length)].userId;

          // Create endpoints with authorization filter
          final endpoints = EventHttpEndpoints<StoredEvent>(
            eventRepository: repository,
            authorizationFilter: (event, request) {
              // Only allow events with matching userId
              return event.userId == allowedUserId;
            },
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

          // Verify only authorized events are returned
          final expectedCount =
              events.where((e) => e.userId == allowedUserId).length;
          expect(
            returnedEvents.length,
            equals(expectedCount),
            reason: 'Iteration $i: only authorized events should be returned',
          );

          // Verify all returned events have the allowed userId
          for (final eventJson in returnedEvents) {
            final userId = eventJson['userId'] as String?;
            expect(
              userId,
              equals(allowedUserId),
              reason:
                  'Iteration $i: all returned events should have allowed userId',
            );
          }

          // Verify excluded events are not in response
          final excludedEvents =
              events.where((e) => e.userId != allowedUserId).toList();
          for (final excludedEvent in excludedEvents) {
            final found = returnedEvents.any(
              (json) => json['id'] == excludedEvent.id.toString(),
            );
            expect(
              found,
              isFalse,
              reason:
                  'Iteration $i: excluded event ${excludedEvent.id} should not be in response',
            );
          }
        }
      },
    );

    test(
      'should include events when authorization filter returns true',
      () async {
        final random = Random(43);

        for (var i = 0; i < 100; i++) {
          // Create repository with random events
          final repository = InMemoryEventRepository();
          final eventCount = 5 + random.nextInt(16); // 5-20 events

          final events = <StoredEvent>[];
          for (var j = 0; j < eventCount; j++) {
            final event = _generateRandomStoredEvent(random);
            await repository.save(event);
            events.add(event);
          }

          // Create endpoints with filter that always returns true
          final endpoints = EventHttpEndpoints<StoredEvent>(
            eventRepository: repository,
            authorizationFilter: (event, request) => true,
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

          // Verify all events are returned
          expect(
            returnedEvents.length,
            equals(eventCount),
            reason:
                'Iteration $i: all events should be returned when filter returns true',
          );
        }
      },
    );

    test(
      'should handle authorization filter exceptions gracefully',
      () async {
        final random = Random(44);

        for (var i = 0; i < 50; i++) {
          // Create repository with random events
          final repository = InMemoryEventRepository();
          final eventCount = 5 + random.nextInt(11); // 5-15 events

          final events = <StoredEvent>[];
          for (var j = 0; j < eventCount; j++) {
            final event = _generateRandomStoredEvent(random);
            await repository.save(event);
            events.add(event);
          }

          // Create endpoints with filter that throws for some events
          final endpoints = EventHttpEndpoints<StoredEvent>(
            eventRepository: repository,
            authorizationFilter: (event, request) {
              // Throw exception for events with null userId
              if (event.userId == null) {
                throw Exception('Authorization check failed');
              }
              return true;
            },
          );

          // Create mock request
          final request = Request(
            'GET',
            Uri.parse('http://localhost/events?since=2020-01-01T00:00:00.000Z'),
          );

          // Call GET endpoint - should not throw
          final response = await endpoints.handleGetEvents(request);

          // Verify response is successful
          expect(response.statusCode, equals(200));

          // Parse response body
          final body = await response.readAsString();
          final returnedEvents = jsonDecode(body) as List<dynamic>;

          // Verify only events with non-null userId are returned
          // (events that caused exceptions should be excluded)
          final expectedCount = events.where((e) => e.userId != null).length;
          expect(
            returnedEvents.length,
            equals(expectedCount),
            reason:
                'Iteration $i: events causing filter exceptions should be excluded',
          );

          // Verify all returned events have non-null userId
          for (final eventJson in returnedEvents) {
            final userId = eventJson['userId'];
            expect(
              userId,
              isNotNull,
              reason:
                  'Iteration $i: returned events should have non-null userId',
            );
          }
        }
      },
    );

    test(
      'should apply complex authorization logic correctly',
      () async {
        final random = Random(45);

        for (var i = 0; i < 100; i++) {
          // Create repository with random events
          final repository = InMemoryEventRepository();
          final eventCount = 10 + random.nextInt(21); // 10-30 events

          final events = <StoredEvent>[];
          for (var j = 0; j < eventCount; j++) {
            final event = _generateRandomStoredEvent(random);
            await repository.save(event);
            events.add(event);
          }

          // Pick random tenantId and sessionId for filtering
          final allowedTenantId = 'tenant-${random.nextInt(5)}';
          final allowedSessionId = 'session-${random.nextInt(10)}';

          // Create endpoints with complex authorization filter
          final endpoints = EventHttpEndpoints<StoredEvent>(
            eventRepository: repository,
            authorizationFilter: (event, request) {
              // Allow if tenantId matches OR sessionId matches
              return event.tenantId == allowedTenantId ||
                  event.sessionId == allowedSessionId;
            },
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

          // Verify correct events are returned
          final expectedEvents = events.where(
            (e) =>
                e.tenantId == allowedTenantId ||
                e.sessionId == allowedSessionId,
          );
          expect(
            returnedEvents.length,
            equals(expectedEvents.length),
            reason: 'Iteration $i: correct number of events should be returned',
          );

          // Verify all returned events match the filter criteria
          for (final eventJson in returnedEvents) {
            final tenantId = eventJson['tenantId'] as String?;
            final sessionId = eventJson['sessionId'] as String?;
            final matches =
                tenantId == allowedTenantId || sessionId == allowedSessionId;
            expect(
              matches,
              isTrue,
              reason:
                  'Iteration $i: returned event should match filter criteria',
            );
          }
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
