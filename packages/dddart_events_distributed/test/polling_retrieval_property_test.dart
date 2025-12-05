/// Property-based tests for EventBusClient polling retrieval.
///
/// **Feature: distributed-events, Property 4: Polling retrieves new events**
/// **Validates: Requirements 2.2**
@Tags(['property-test'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dddart/dddart.dart';
import 'package:dddart_events_distributed/src/event_bus_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('Property 4: Polling retrieves new events', () {
    test(
      'should retrieve all events since last timestamp',
      () async {
        final random = Random(42);

        for (var i = 0; i < 100; i++) {
          // Create fresh instances for each iteration
          final eventBus = EventBus();
          final receivedEvents = <TestDomainEvent>[];

          // Subscribe to events on local bus
          eventBus.on<TestDomainEvent>().listen(receivedEvents.add);

          // Generate random events with timestamps
          final eventCount = 1 + random.nextInt(10); // 1-10 events
          final serverEvents = List.generate(
            eventCount,
            (_) => _generateRandomTestEvent(random),
          );

          // Sort by timestamp to simulate server behavior
          serverEvents.sort((a, b) => a.occurredAt.compareTo(b.occurredAt));

          // Create mock HTTP client that returns these events
          final mockClient = MockClient((request) async {
            if (request.url.path.endsWith('/events') &&
                request.method == 'GET') {
              // Parse the 'since' parameter
              final since = request.url.queryParameters['since'];
              expect(since, isNotNull, reason: 'since parameter is required');

              final sinceTimestamp = DateTime.parse(since!);

              // Filter events that are after the since timestamp
              final filteredEvents = serverEvents
                  .where((e) => e.occurredAt.isAfter(sinceTimestamp))
                  .map(_eventToStoredEventJson)
                  .toList();

              return http.Response(
                jsonEncode(filteredEvents),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            return http.Response('Not Found', 404);
          });

          // Create client with initial timestamp before all events
          final initialTimestamp = serverEvents.first.occurredAt
              .subtract(const Duration(seconds: 1));

          final client = EventBusClient(
            localEventBus: eventBus,
            serverUrl: 'http://test-server',
            eventRegistry: {
              'TestDomainEvent': TestDomainEvent.fromJson,
            },
            pollingInterval: const Duration(milliseconds: 50),
            initialTimestamp: initialTimestamp,
            httpClient: mockClient,
          );

          // Wait for polling to occur
          await Future<void>.delayed(const Duration(milliseconds: 150));

          // Verify all events were received
          expect(
            receivedEvents.length,
            equals(eventCount),
            reason: 'Iteration $i: all $eventCount events should be received',
          );

          // Verify events match
          for (var j = 0; j < eventCount; j++) {
            final serverEvent = serverEvents[j];
            final receivedEvent = receivedEvents.firstWhere(
              (e) => e.eventId == serverEvent.eventId,
            );

            expect(
              receivedEvent.aggregateId,
              equals(serverEvent.aggregateId),
              reason: 'Iteration $i, Event $j: aggregateId should match',
            );
            expect(
              receivedEvent.data,
              equals(serverEvent.data),
              reason: 'Iteration $i, Event $j: data should match',
            );
          }

          // Clean up
          await client.close();
        }
      },
    );

    test(
      'should only retrieve events after last timestamp',
      () async {
        final random = Random(43);

        for (var i = 0; i < 100; i++) {
          final eventBus = EventBus();
          final receivedEvents = <TestDomainEvent>[];

          eventBus.on<TestDomainEvent>().listen(receivedEvents.add);

          // Generate events with specific timestamps
          final baseTime = DateTime.now();
          final oldEvents = List.generate(
            5,
            (j) => _generateTestEventWithTimestamp(
              random,
              baseTime.subtract(Duration(hours: j + 1)),
            ),
          );
          final newEvents = List.generate(
            5,
            (j) => _generateTestEventWithTimestamp(
              random,
              baseTime.add(Duration(hours: j + 1)),
            ),
          );

          final allEvents = [...oldEvents, ...newEvents];

          // Mock client that returns all events
          final mockClient = MockClient((request) async {
            if (request.url.path.endsWith('/events') &&
                request.method == 'GET') {
              final since = request.url.queryParameters['since'];
              final sinceTimestamp = DateTime.parse(since!);

              // Filter events after since timestamp
              final filteredEvents = allEvents
                  .where((e) => e.occurredAt.isAfter(sinceTimestamp))
                  .map(_eventToStoredEventJson)
                  .toList();

              return http.Response(
                jsonEncode(filteredEvents),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            return http.Response('Not Found', 404);
          });

          // Create client with initial timestamp at baseTime
          // Should only receive newEvents
          final client = EventBusClient(
            localEventBus: eventBus,
            serverUrl: 'http://test-server',
            eventRegistry: {
              'TestDomainEvent': TestDomainEvent.fromJson,
            },
            pollingInterval: const Duration(milliseconds: 50),
            initialTimestamp: baseTime,
            httpClient: mockClient,
          );

          // Wait for polling
          await Future<void>.delayed(const Duration(milliseconds: 150));

          // Verify only new events were received
          expect(
            receivedEvents.length,
            equals(newEvents.length),
            reason: 'Iteration $i: only new events should be received',
          );

          // Verify no old events were received
          for (final oldEvent in oldEvents) {
            expect(
              receivedEvents.any((e) => e.eventId == oldEvent.eventId),
              isFalse,
              reason: 'Iteration $i: old events should not be received',
            );
          }

          // Verify all new events were received
          for (final newEvent in newEvents) {
            expect(
              receivedEvents.any((e) => e.eventId == newEvent.eventId),
              isTrue,
              reason: 'Iteration $i: new events should be received',
            );
          }

          // Clean up
          await client.close();
        }
      },
    );

    test(
      'should handle empty responses when no new events',
      () async {
        for (var i = 0; i < 50; i++) {
          final eventBus = EventBus();
          final receivedEvents = <TestDomainEvent>[];

          eventBus.on<TestDomainEvent>().listen(receivedEvents.add);

          // Mock client that returns empty array
          final mockClient = MockClient((request) async {
            if (request.url.path.endsWith('/events') &&
                request.method == 'GET') {
              return http.Response(
                jsonEncode([]),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            return http.Response('Not Found', 404);
          });

          final client = EventBusClient(
            localEventBus: eventBus,
            serverUrl: 'http://test-server',
            eventRegistry: {
              'TestDomainEvent': TestDomainEvent.fromJson,
            },
            pollingInterval: const Duration(milliseconds: 50),
            httpClient: mockClient,
          );

          // Wait for multiple polls
          await Future<void>.delayed(const Duration(milliseconds: 150));

          // Verify no events were received
          expect(
            receivedEvents.length,
            equals(0),
            reason: 'Iteration $i: no events should be received',
          );

          // Clean up
          await client.close();
        }
      },
    );

    test(
      'should update last timestamp after receiving events',
      () async {
        final random = Random(45);

        for (var i = 0; i < 50; i++) {
          final eventBus = EventBus();
          final receivedEvents = <TestDomainEvent>[];

          eventBus.on<TestDomainEvent>().listen(receivedEvents.add);

          // Generate events with increasing timestamps
          final baseTime = DateTime.now();
          final firstBatch = List.generate(
            3,
            (j) => _generateTestEventWithTimestamp(
              random,
              baseTime.add(Duration(seconds: j + 1)),
            ),
          );
          final secondBatch = List.generate(
            3,
            (j) => _generateTestEventWithTimestamp(
              random,
              baseTime.add(Duration(seconds: j + 10)),
            ),
          );

          var pollCount = 0;
          final mockClient = MockClient((request) async {
            if (request.url.path.endsWith('/events') &&
                request.method == 'GET') {
              final since = request.url.queryParameters['since'];
              final sinceTimestamp = DateTime.parse(since!);

              pollCount++;

              // First poll: return first batch
              if (pollCount == 1) {
                final events = firstBatch
                    .where((e) => e.occurredAt.isAfter(sinceTimestamp))
                    .map(_eventToStoredEventJson)
                    .toList();
                return http.Response(
                  jsonEncode(events),
                  200,
                  headers: {'content-type': 'application/json'},
                );
              }

              // Second poll: should only return second batch
              // (first batch should be filtered by updated timestamp)
              final events = secondBatch
                  .where((e) => e.occurredAt.isAfter(sinceTimestamp))
                  .map(_eventToStoredEventJson)
                  .toList();
              return http.Response(
                jsonEncode(events),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            return http.Response('Not Found', 404);
          });

          final client = EventBusClient(
            localEventBus: eventBus,
            serverUrl: 'http://test-server',
            eventRegistry: {
              'TestDomainEvent': TestDomainEvent.fromJson,
            },
            pollingInterval: const Duration(milliseconds: 50),
            initialTimestamp: baseTime,
            httpClient: mockClient,
          );

          // Wait for multiple polls
          await Future<void>.delayed(const Duration(milliseconds: 200));

          // Verify all events from both batches were received
          expect(
            receivedEvents.length,
            equals(firstBatch.length + secondBatch.length),
            reason: 'Iteration $i: all events should be received',
          );

          // Clean up
          await client.close();
        }
      },
    );
  });
}

// Generator functions

/// Generates a random test DomainEvent.
TestDomainEvent _generateRandomTestEvent(Random random) {
  return TestDomainEvent(
    aggregateId: UuidValue.generate(),
    eventId: UuidValue.generate(),
    occurredAt: _generateRandomDateTime(random),
    data: 'test-data-${random.nextInt(1000)}',
  );
}

/// Generates a test event with specific timestamp.
TestDomainEvent _generateTestEventWithTimestamp(
  Random random,
  DateTime timestamp,
) {
  return TestDomainEvent(
    aggregateId: UuidValue.generate(),
    eventId: UuidValue.generate(),
    occurredAt: timestamp,
    data: 'test-data-${random.nextInt(1000)}',
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
  final millisecond = random.nextInt(1000);

  return DateTime(year, month, day, hour, minute, second, millisecond);
}

/// Converts a test event to StoredEvent JSON format.
Map<String, dynamic> _eventToStoredEventJson(TestDomainEvent event) {
  final eventJson = {
    'eventId': event.eventId.toString(),
    'occurredAt': event.occurredAt.toIso8601String(),
    'aggregateId': event.aggregateId.toString(),
    'data': event.data,
    'context': event.context,
  };

  return {
    'id': event.eventId.toString(),
    'createdAt': event.occurredAt.toIso8601String(),
    'updatedAt': event.occurredAt.toIso8601String(),
    'aggregateId': event.aggregateId.toString(),
    'eventType': 'TestDomainEvent',
    'eventJson': jsonEncode(eventJson),
  };
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

  /// Deserializes from JSON.
  static TestDomainEvent fromJson(Map<String, dynamic> json) {
    return TestDomainEvent(
      eventId: UuidValue.fromString(json['eventId'] as String),
      occurredAt: DateTime.parse(json['occurredAt'] as String),
      aggregateId: UuidValue.fromString(json['aggregateId'] as String),
      data: json['data'] as String,
      context: json['context'] as Map<String, dynamic>? ?? {},
    );
  }
}
