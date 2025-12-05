/// Unit tests for EventHttpEndpoints.
library;

import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_events_distributed/src/event_http_endpoints.dart';
import 'package:dddart_events_distributed/src/event_repository.dart';
import 'package:dddart_events_distributed/src/stored_event.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  group('EventHttpEndpoints', () {
    group('GET /events', () {
      test('should return events with valid timestamp', () async {
        // Arrange
        final repository = InMemoryEventRepository();
        final event1 = StoredEvent(
          id: UuidValue.generate(),
          createdAt: DateTime(2024, 1, 1, 10),
          aggregateId: UuidValue.generate(),
          eventType: 'TestEvent',
          eventJson: '{"data":"test1"}',
          userId: 'user-1',
        );
        final event2 = StoredEvent(
          id: UuidValue.generate(),
          createdAt: DateTime(2024, 1, 1, 11),
          aggregateId: UuidValue.generate(),
          eventType: 'TestEvent',
          eventJson: '{"data":"test2"}',
          userId: 'user-2',
        );
        await repository.save(event1);
        await repository.save(event2);

        final endpoints = EventHttpEndpoints<StoredEvent>(
          eventRepository: repository,
        );

        final request = Request(
          'GET',
          Uri.parse('http://localhost/events?since=2024-01-01T09:00:00.000Z'),
        );

        // Act
        final response = await endpoints.handleGetEvents(request);

        // Assert
        expect(response.statusCode, equals(200));
        expect(
          response.headers['Content-Type'],
          equals('application/json'),
        );

        final body = await response.readAsString();
        final events = jsonDecode(body) as List<dynamic>;
        expect(events.length, equals(2));
      });

      test('should return 400 when "since" parameter is missing', () async {
        // Arrange
        final repository = InMemoryEventRepository();
        final endpoints = EventHttpEndpoints<StoredEvent>(
          eventRepository: repository,
        );

        final request = Request(
          'GET',
          Uri.parse('http://localhost/events'), // No "since" parameter
        );

        // Act
        final response = await endpoints.handleGetEvents(request);

        // Assert
        expect(response.statusCode, equals(400));
        expect(
          response.headers['Content-Type'],
          equals('application/json'),
        );

        final body = await response.readAsString();
        final error = jsonDecode(body) as Map<String, dynamic>;
        expect(error['error'], contains('Missing required parameter'));
      });

      test('should return 400 when timestamp format is invalid', () async {
        // Arrange
        final repository = InMemoryEventRepository();
        final endpoints = EventHttpEndpoints<StoredEvent>(
          eventRepository: repository,
        );

        final request = Request(
          'GET',
          Uri.parse('http://localhost/events?since=invalid-timestamp'),
        );

        // Act
        final response = await endpoints.handleGetEvents(request);

        // Assert
        expect(response.statusCode, equals(400));
        expect(
          response.headers['Content-Type'],
          equals('application/json'),
        );

        final body = await response.readAsString();
        final error = jsonDecode(body) as Map<String, dynamic>;
        expect(error['error'], contains('Invalid timestamp format'));
      });

      test('should apply authorization filter when configured', () async {
        // Arrange
        final repository = InMemoryEventRepository();
        final event1 = StoredEvent(
          id: UuidValue.generate(),
          createdAt: DateTime(2024, 1, 1, 10),
          aggregateId: UuidValue.generate(),
          eventType: 'TestEvent',
          eventJson: '{"data":"test1"}',
          userId: 'user-1',
        );
        final event2 = StoredEvent(
          id: UuidValue.generate(),
          createdAt: DateTime(2024, 1, 1, 11),
          aggregateId: UuidValue.generate(),
          eventType: 'TestEvent',
          eventJson: '{"data":"test2"}',
          userId: 'user-2',
        );
        await repository.save(event1);
        await repository.save(event2);

        final endpoints = EventHttpEndpoints<StoredEvent>(
          eventRepository: repository,
          authorizationFilter: (event, request) {
            // Only allow events for user-1
            return event.userId == 'user-1';
          },
        );

        final request = Request(
          'GET',
          Uri.parse('http://localhost/events?since=2024-01-01T09:00:00.000Z'),
        );

        // Act
        final response = await endpoints.handleGetEvents(request);

        // Assert
        expect(response.statusCode, equals(200));

        final body = await response.readAsString();
        final events = jsonDecode(body) as List<dynamic>;
        expect(events.length, equals(1));
        expect(events[0]['userId'], equals('user-1'));
      });

      test('should return empty array when no events match timestamp',
          () async {
        // Arrange
        final repository = InMemoryEventRepository();
        final event = StoredEvent(
          id: UuidValue.generate(),
          createdAt: DateTime(2024, 1, 1, 10),
          aggregateId: UuidValue.generate(),
          eventType: 'TestEvent',
          eventJson: '{"data":"test"}',
          userId: 'user-1',
        );
        await repository.save(event);

        final endpoints = EventHttpEndpoints<StoredEvent>(
          eventRepository: repository,
        );

        final request = Request(
          'GET',
          Uri.parse('http://localhost/events?since=2025-01-01T00:00:00.000Z'),
        );

        // Act
        final response = await endpoints.handleGetEvents(request);

        // Assert
        expect(response.statusCode, equals(200));

        final body = await response.readAsString();
        final events = jsonDecode(body) as List<dynamic>;
        expect(events.length, equals(0));
      });

      test('should handle repository errors gracefully', () async {
        // Arrange
        final repository = FailingEventRepository();
        final endpoints = EventHttpEndpoints<StoredEvent>(
          eventRepository: repository,
        );

        final request = Request(
          'GET',
          Uri.parse('http://localhost/events?since=2024-01-01T00:00:00.000Z'),
        );

        // Act
        final response = await endpoints.handleGetEvents(request);

        // Assert
        expect(response.statusCode, equals(500));
        expect(
          response.headers['Content-Type'],
          equals('application/json'),
        );

        final body = await response.readAsString();
        final error = jsonDecode(body) as Map<String, dynamic>;
        expect(error['error'], equals('Internal server error'));
      });
    });

    group('POST /events', () {
      test('should save valid event and return 201', () async {
        // Arrange
        final repository = InMemoryEventRepository();
        final endpoints = EventHttpEndpoints<StoredEvent>(
          eventRepository: repository,
        );

        final eventId = UuidValue.generate();
        final createdAt = DateTime(2024, 1, 1, 10);
        final eventJson = jsonEncode({
          'id': eventId.toString(),
          'createdAt': createdAt.toIso8601String(),
          'aggregateId': UuidValue.generate().toString(),
          'eventType': 'TestEvent',
          'eventJson': '{"data":"test"}',
          'userId': 'user-1',
          'tenantId': null,
          'sessionId': null,
        });

        final request = Request(
          'POST',
          Uri.parse('http://localhost/events'),
          body: eventJson,
          headers: {'Content-Type': 'application/json'},
        );

        // Act
        final response = await endpoints.handlePostEvent(request, null);

        // Assert
        expect(response.statusCode, equals(201));
        expect(
          response.headers['Content-Type'],
          equals('application/json'),
        );

        final body = await response.readAsString();
        final result = jsonDecode(body) as Map<String, dynamic>;
        expect(result['id'], equals(eventId.toString()));
        expect(result['createdAt'], equals(createdAt.toIso8601String()));

        // Verify event was saved
        final savedEvents = await repository.findAll();
        expect(savedEvents.length, equals(1));
        expect(savedEvents[0].id, equals(eventId));
      });

      test('should return 400 when JSON is invalid', () async {
        // Arrange
        final repository = InMemoryEventRepository();
        final endpoints = EventHttpEndpoints<StoredEvent>(
          eventRepository: repository,
        );

        final request = Request(
          'POST',
          Uri.parse('http://localhost/events'),
          body: 'invalid json{',
          headers: {'Content-Type': 'application/json'},
        );

        // Act
        final response = await endpoints.handlePostEvent(request, null);

        // Assert
        expect(response.statusCode, equals(400));
        expect(
          response.headers['Content-Type'],
          equals('application/json'),
        );

        final body = await response.readAsString();
        final error = jsonDecode(body) as Map<String, dynamic>;
        expect(error['error'], equals('Invalid JSON format'));
      });

      test('should return 400 when event data is invalid', () async {
        // Arrange
        final repository = InMemoryEventRepository();
        final endpoints = EventHttpEndpoints<StoredEvent>(
          eventRepository: repository,
        );

        final invalidEventJson = jsonEncode({
          'id': 'not-a-uuid', // Invalid UUID
          'createdAt': '2024-01-01T10:00:00.000Z',
          'aggregateId': UuidValue.generate().toString(),
          'eventType': 'TestEvent',
          'eventJson': '{"data":"test"}',
        });

        final request = Request(
          'POST',
          Uri.parse('http://localhost/events'),
          body: invalidEventJson,
          headers: {'Content-Type': 'application/json'},
        );

        // Act
        final response = await endpoints.handlePostEvent(request, null);

        // Assert
        expect(response.statusCode, equals(400));
        expect(
          response.headers['Content-Type'],
          equals('application/json'),
        );

        final body = await response.readAsString();
        final error = jsonDecode(body) as Map<String, dynamic>;
        expect(error['error'], equals('Invalid event data'));
      });

      test('should handle repository save errors gracefully', () async {
        // Arrange
        final repository = FailingEventRepository();
        final endpoints = EventHttpEndpoints<StoredEvent>(
          eventRepository: repository,
        );

        final eventJson = jsonEncode({
          'id': UuidValue.generate().toString(),
          'createdAt': DateTime.now().toIso8601String(),
          'aggregateId': UuidValue.generate().toString(),
          'eventType': 'TestEvent',
          'eventJson': '{"data":"test"}',
          'userId': 'user-1',
          'tenantId': null,
          'sessionId': null,
        });

        final request = Request(
          'POST',
          Uri.parse('http://localhost/events'),
          body: eventJson,
          headers: {'Content-Type': 'application/json'},
        );

        // Act
        final response = await endpoints.handlePostEvent(request, null);

        // Assert
        expect(response.statusCode, equals(500));
        expect(
          response.headers['Content-Type'],
          equals('application/json'),
        );

        final body = await response.readAsString();
        final error = jsonDecode(body) as Map<String, dynamic>;
        expect(error['error'], equals('Internal server error'));
      });
    });
  });
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

  /// Helper method for testing - not part of Repository interface.
  Future<List<StoredEvent>> findAll() async {
    return List.from(_events);
  }
}

/// Repository that always fails for testing error handling.
class FailingEventRepository implements EventRepository<StoredEvent> {
  @override
  Future<void> save(StoredEvent entity) async {
    throw Exception('Repository save failed');
  }

  @override
  Future<StoredEvent> getById(UuidValue id) async {
    throw Exception('Repository getById failed');
  }

  @override
  Future<void> deleteById(UuidValue id) async {
    throw Exception('Repository deleteById failed');
  }

  @override
  Future<List<StoredEvent>> findSince(DateTime timestamp) async {
    throw Exception('Repository findSince failed');
  }

  @override
  Future<void> deleteOlderThan(DateTime timestamp) async {
    throw Exception('Repository deleteOlderThan failed');
  }
}
