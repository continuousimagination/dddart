/// Property-based tests for disabled automatic forwarding.
///
/// **Feature: distributed-events, Property 10: Disabled forwarding prevents automatic POST**
/// **Validates: Requirements 15.4**
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
  group('Property 10: Disabled forwarding prevents automatic POST', () {
    test(
      'should not POST events when autoForward is disabled',
      () async {
        final random = Random(42);

        for (var i = 0; i < 100; i++) {
          final eventBus = EventBus();
          var postCount = 0;

          // Mock client that counts POST requests
          final mockClient = MockClient((request) async {
            if (request.url.path.endsWith('/events')) {
              if (request.method == 'POST') {
                postCount++;
                return http.Response(
                  jsonEncode({
                    'id': 'test-id',
                    'createdAt': DateTime.now().toIso8601String(),
                  }),
                  201,
                  headers: {'content-type': 'application/json'},
                );
              } else if (request.method == 'GET') {
                // Return empty for polling
                return http.Response(
                  jsonEncode([]),
                  200,
                  headers: {'content-type': 'application/json'},
                );
              }
            }
            return http.Response('Not Found', 404);
          });

          // Create client with autoForward disabled (default)
          final client = EventBusClient(
            localEventBus: eventBus,
            serverUrl: 'http://test-server',
            eventRegistry: {},
            pollingInterval: const Duration(seconds: 10), // Long interval
            httpClient: mockClient,
          );

          // Generate and publish random events
          final eventCount = 1 + random.nextInt(10);
          for (var j = 0; j < eventCount; j++) {
            final event = _generateRandomTestEvent(random);
            eventBus.publish(event);
          }

          // Wait to ensure no forwarding happens
          await Future<void>.delayed(const Duration(milliseconds: 100));

          // Verify no POST requests were made
          expect(
            postCount,
            equals(0),
            reason: 'Iteration $i: no POST requests should be made',
          );

          // Clean up
          await client.close();
        }
      },
    );

    test(
      'should not POST events when autoForward is omitted (defaults to false)',
      () async {
        final random = Random(43);

        for (var i = 0; i < 100; i++) {
          final eventBus = EventBus();
          var postCount = 0;

          // Mock client
          final mockClient = MockClient((request) async {
            if (request.url.path.endsWith('/events')) {
              if (request.method == 'POST') {
                postCount++;
                return http.Response(
                  jsonEncode({
                    'id': 'test-id',
                    'createdAt': DateTime.now().toIso8601String(),
                  }),
                  201,
                  headers: {'content-type': 'application/json'},
                );
              } else if (request.method == 'GET') {
                return http.Response(
                  jsonEncode([]),
                  200,
                  headers: {'content-type': 'application/json'},
                );
              }
            }
            return http.Response('Not Found', 404);
          });

          // Create client without specifying autoForward (defaults to false)
          final client = EventBusClient(
            localEventBus: eventBus,
            serverUrl: 'http://test-server',
            eventRegistry: {},
            pollingInterval: const Duration(seconds: 10),
            httpClient: mockClient,
            // autoForward not specified - should default to false
          );

          // Publish events
          final eventCount = 1 + random.nextInt(10);
          for (var j = 0; j < eventCount; j++) {
            final event = _generateRandomTestEvent(random);
            eventBus.publish(event);
          }

          // Wait
          await Future<void>.delayed(const Duration(milliseconds: 100));

          // Verify no POST requests
          expect(
            postCount,
            equals(0),
            reason: 'Iteration $i: no POST requests should be made by default',
          );

          // Clean up
          await client.close();
        }
      },
    );

    test(
      'should still receive events via polling when autoForward is disabled',
      () async {
        final random = Random(44);

        for (var i = 0; i < 50; i++) {
          final eventBus = EventBus();
          final receivedEvents = <TestEvent>[];
          var postCount = 0;

          eventBus.on<TestEvent>().listen(receivedEvents.add);

          // Generate server events
          final serverEventCount = 1 + random.nextInt(5);
          final baseTime = DateTime.now().add(const Duration(seconds: 1));
          final serverEvents = List.generate(
            serverEventCount,
            (j) => _generateTestEventWithTimestamp(
              random,
              baseTime.add(Duration(seconds: j)),
            ),
          );

          // Mock client that returns events on GET but counts POSTs
          final mockClient = MockClient((request) async {
            if (request.url.path.endsWith('/events')) {
              if (request.method == 'POST') {
                postCount++;
                return http.Response(
                  jsonEncode({
                    'id': 'test-id',
                    'createdAt': DateTime.now().toIso8601String(),
                  }),
                  201,
                  headers: {'content-type': 'application/json'},
                );
              } else if (request.method == 'GET') {
                final since = request.url.queryParameters['since'];
                final sinceTimestamp = DateTime.parse(since!);

                final events = serverEvents
                    .where((e) => e.occurredAt.isAfter(sinceTimestamp))
                    .map(_eventToStoredEventJson)
                    .toList();

                return http.Response(
                  jsonEncode(events),
                  200,
                  headers: {'content-type': 'application/json'},
                );
              }
            }
            return http.Response('Not Found', 404);
          });

          // Create client with autoForward disabled
          final client = EventBusClient(
            localEventBus: eventBus,
            serverUrl: 'http://test-server',
            eventRegistry: {
              'TestEvent': TestEvent.fromJson,
            },
            pollingInterval: const Duration(milliseconds: 50),
            httpClient: mockClient,
          );

          // Publish local events (should not be forwarded)
          final localEventCount = 1 + random.nextInt(5);
          for (var j = 0; j < localEventCount; j++) {
            final event = _generateRandomTestEvent(random);
            eventBus.publish(event);
          }

          // Wait for polling to receive server events
          await Future<void>.delayed(const Duration(milliseconds: 150));

          // Verify no POST requests were made
          expect(
            postCount,
            equals(0),
            reason: 'Iteration $i: no POST requests should be made',
          );

          // Verify server events were received via polling
          expect(
            receivedEvents.length,
            greaterThanOrEqualTo(serverEventCount),
            reason: 'Iteration $i: server events should be received',
          );

          // Clean up
          await client.close();
        }
      },
    );

    test(
      'should not create event subscription when autoForward is disabled',
      () async {
        final random = Random(45);

        for (var i = 0; i < 50; i++) {
          final eventBus = EventBus();
          var postCount = 0;

          // Mock client
          final mockClient = MockClient((request) async {
            if (request.url.path.endsWith('/events')) {
              if (request.method == 'POST') {
                postCount++;
                return http.Response(
                  jsonEncode({
                    'id': 'test-id',
                    'createdAt': DateTime.now().toIso8601String(),
                  }),
                  201,
                  headers: {'content-type': 'application/json'},
                );
              } else if (request.method == 'GET') {
                return http.Response(
                  jsonEncode([]),
                  200,
                  headers: {'content-type': 'application/json'},
                );
              }
            }
            return http.Response('Not Found', 404);
          });

          // Create client with autoForward disabled
          final client = EventBusClient(
            localEventBus: eventBus,
            serverUrl: 'http://test-server',
            eventRegistry: {},
            pollingInterval: const Duration(seconds: 10),
            httpClient: mockClient,
          );

          // Publish many events rapidly
          final eventCount = 20 + random.nextInt(31); // 20-50 events
          for (var j = 0; j < eventCount; j++) {
            final event = _generateRandomTestEvent(random);
            eventBus.publish(event);
          }

          // Wait
          await Future<void>.delayed(const Duration(milliseconds: 100));

          // Verify absolutely no POST requests
          expect(
            postCount,
            equals(0),
            reason: 'Iteration $i: no POST requests even with many events',
          );

          // Clean up
          await client.close();
        }
      },
    );
  });
}

// Generator functions

/// Generates a random test event.
TestEvent _generateRandomTestEvent(Random random) {
  return TestEvent(
    aggregateId: UuidValue.generate(),
    eventId: UuidValue.generate(),
    occurredAt: DateTime.now(),
    data: 'test-data-${random.nextInt(1000)}',
  );
}

/// Generates a test event with specific timestamp.
TestEvent _generateTestEventWithTimestamp(Random random, DateTime timestamp) {
  return TestEvent(
    aggregateId: UuidValue.generate(),
    eventId: UuidValue.generate(),
    occurredAt: timestamp,
    data: 'test-data-${random.nextInt(1000)}',
  );
}

/// Converts a test event to StoredEvent JSON format.
Map<String, dynamic> _eventToStoredEventJson(TestEvent event) {
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
    'eventType': 'TestEvent',
    'eventJson': jsonEncode(eventJson),
  };
}

// Test event class

/// Test event for property testing.
class TestEvent extends DomainEvent {
  TestEvent({
    required super.aggregateId,
    required this.data,
    super.eventId,
    super.occurredAt,
    super.context,
  });

  final String data;

  /// Deserializes from JSON.
  static TestEvent fromJson(Map<String, dynamic> json) {
    return TestEvent(
      eventId: UuidValue.fromString(json['eventId'] as String),
      occurredAt: DateTime.parse(json['occurredAt'] as String),
      aggregateId: UuidValue.fromString(json['aggregateId'] as String),
      data: json['data'] as String,
      context: json['context'] as Map<String, dynamic>? ?? {},
    );
  }
}
