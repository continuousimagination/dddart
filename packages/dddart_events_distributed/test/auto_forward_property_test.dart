/// Property-based tests for automatic event forwarding.
///
/// **Feature: distributed-events, Property 9: Auto-forward sends events to server**
/// **Validates: Requirements 15.3**
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
  group('Property 9: Auto-forward sends events to server', () {
    test(
      'should POST events to server when autoForward is enabled',
      () async {
        final random = Random(42);

        for (var i = 0; i < 100; i++) {
          final eventBus = EventBus();
          final forwardedEvents = <Map<String, dynamic>>[];

          // Mock client that captures POSTed events
          final mockClient = MockClient((request) async {
            if (request.url.path.endsWith('/events')) {
              if (request.method == 'POST') {
                // Capture the forwarded event
                final body = jsonDecode(request.body) as Map<String, dynamic>;
                forwardedEvents.add(body);

                return http.Response(
                  jsonEncode({
                    'id': body['id'],
                    'createdAt': body['createdAt'],
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

          // Create client with autoForward enabled
          final client = EventBusClient(
            localEventBus: eventBus,
            serverUrl: 'http://test-server',
            eventRegistry: {},
            pollingInterval: const Duration(seconds: 10), // Long interval
            autoForward: true,
            httpClient: mockClient,
          );

          // Generate and publish random events
          final eventCount = 1 + random.nextInt(10);
          final publishedEvents = <TestEvent>[];

          for (var j = 0; j < eventCount; j++) {
            final event = _generateRandomTestEvent(random);
            publishedEvents.add(event);
            eventBus.publish(event);
          }

          // Wait for async forwarding to complete
          await Future<void>.delayed(const Duration(milliseconds: 100));

          // Verify all events were forwarded
          expect(
            forwardedEvents.length,
            equals(eventCount),
            reason: 'Iteration $i: all $eventCount events should be forwarded',
          );

          // Verify each event was forwarded correctly
          for (var j = 0; j < eventCount; j++) {
            final publishedEvent = publishedEvents[j];
            final forwardedEvent = forwardedEvents.firstWhere(
              (e) => e['id'] == publishedEvent.eventId.toString(),
            );

            expect(
              forwardedEvent['eventType'],
              equals('TestEvent'),
              reason: 'Iteration $i, Event $j: eventType should match',
            );
            expect(
              forwardedEvent['aggregateId'],
              equals(publishedEvent.aggregateId.toString()),
              reason: 'Iteration $i, Event $j: aggregateId should match',
            );

            // Verify event data is in eventJson
            final eventJson = jsonDecode(forwardedEvent['eventJson'] as String)
                as Map<String, dynamic>;
            expect(
              eventJson['aggregateId'],
              equals(publishedEvent.aggregateId.toString()),
              reason: 'Iteration $i, Event $j: eventJson should contain data',
            );
          }

          // Clean up
          await client.close();
        }
      },
    );

    test(
      'should forward events with authorization context',
      () async {
        final random = Random(43);

        for (var i = 0; i < 100; i++) {
          final eventBus = EventBus();
          final forwardedEvents = <Map<String, dynamic>>[];

          // Mock client
          final mockClient = MockClient((request) async {
            if (request.url.path.endsWith('/events')) {
              if (request.method == 'POST') {
                final body = jsonDecode(request.body) as Map<String, dynamic>;
                forwardedEvents.add(body);

                return http.Response(
                  jsonEncode({
                    'id': body['id'],
                    'createdAt': body['createdAt'],
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

          final client = EventBusClient(
            localEventBus: eventBus,
            serverUrl: 'http://test-server',
            eventRegistry: {},
            pollingInterval: const Duration(seconds: 10),
            autoForward: true,
            httpClient: mockClient,
          );

          // Generate event with authorization context
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

          final event = TestEvent(
            aggregateId: UuidValue.generate(),
            data: 'test-${random.nextInt(1000)}',
            context: context,
          );

          eventBus.publish(event);

          // Wait for forwarding
          await Future<void>.delayed(const Duration(milliseconds: 100));

          // Verify event was forwarded with context
          expect(
            forwardedEvents.length,
            equals(1),
            reason: 'Iteration $i: event should be forwarded',
          );

          final forwardedEvent = forwardedEvents.first;

          // Verify authorization fields
          expect(
            forwardedEvent['userId'],
            equals(context['userId']),
            reason: 'Iteration $i: userId should match (null or value)',
          );
          expect(
            forwardedEvent['tenantId'],
            equals(context['tenantId']),
            reason: 'Iteration $i: tenantId should match (null or value)',
          );
          expect(
            forwardedEvent['sessionId'],
            equals(context['sessionId']),
            reason: 'Iteration $i: sessionId should match (null or value)',
          );

          // Clean up
          await client.close();
        }
      },
    );

    test(
      'should continue forwarding after POST failures',
      () async {
        final random = Random(44);

        for (var i = 0; i < 50; i++) {
          final eventBus = EventBus();
          final forwardedEvents = <Map<String, dynamic>>[];
          var postCount = 0;

          // Mock client that fails 30% of the time
          final mockClient = MockClient((request) async {
            if (request.url.path.endsWith('/events')) {
              if (request.method == 'POST') {
                postCount++;

                // Fail 30% of requests
                if (random.nextDouble() < 0.3) {
                  return http.Response('Internal Server Error', 500);
                }

                final body = jsonDecode(request.body) as Map<String, dynamic>;
                forwardedEvents.add(body);

                return http.Response(
                  jsonEncode({
                    'id': body['id'],
                    'createdAt': body['createdAt'],
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

          final client = EventBusClient(
            localEventBus: eventBus,
            serverUrl: 'http://test-server',
            eventRegistry: {},
            pollingInterval: const Duration(seconds: 10),
            autoForward: true,
            httpClient: mockClient,
          );

          // Publish multiple events
          final eventCount = 10 + random.nextInt(11); // 10-20 events
          for (var j = 0; j < eventCount; j++) {
            final event = _generateRandomTestEvent(random);
            eventBus.publish(event);
          }

          // Wait for forwarding attempts
          await Future<void>.delayed(const Duration(milliseconds: 200));

          // Verify that POST was attempted for all events
          expect(
            postCount,
            equals(eventCount),
            reason: 'Iteration $i: all events should be attempted',
          );

          // Verify that some events were successfully forwarded
          // (With 30% failure rate, we should have some successes)
          expect(
            forwardedEvents.length,
            greaterThan(0),
            reason: 'Iteration $i: at least some events should be forwarded',
          );

          // Clean up
          await client.close();
        }
      },
    );

    test(
      'should forward multiple events in order',
      () async {
        final random = Random(45);

        for (var i = 0; i < 50; i++) {
          final eventBus = EventBus();
          final forwardedEvents = <Map<String, dynamic>>[];

          // Mock client
          final mockClient = MockClient((request) async {
            if (request.url.path.endsWith('/events')) {
              if (request.method == 'POST') {
                final body = jsonDecode(request.body) as Map<String, dynamic>;
                forwardedEvents.add(body);

                return http.Response(
                  jsonEncode({
                    'id': body['id'],
                    'createdAt': body['createdAt'],
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

          final client = EventBusClient(
            localEventBus: eventBus,
            serverUrl: 'http://test-server',
            eventRegistry: {},
            pollingInterval: const Duration(seconds: 10),
            autoForward: true,
            httpClient: mockClient,
          );

          // Publish events sequentially
          final eventCount = 5 + random.nextInt(6); // 5-10 events
          final publishedEvents = <TestEvent>[];

          for (var j = 0; j < eventCount; j++) {
            final event = _generateRandomTestEvent(random);
            publishedEvents.add(event);
            eventBus.publish(event);

            // Small delay between events
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }

          // Wait for all forwarding to complete
          await Future<void>.delayed(const Duration(milliseconds: 100));

          // Verify all events were forwarded
          expect(
            forwardedEvents.length,
            equals(eventCount),
            reason: 'Iteration $i: all events should be forwarded',
          );

          // Verify order is preserved
          for (var j = 0; j < eventCount; j++) {
            final publishedEvent = publishedEvents[j];
            final forwardedEvent = forwardedEvents[j];

            expect(
              forwardedEvent['id'],
              equals(publishedEvent.eventId.toString()),
              reason: 'Iteration $i, Event $j: order should be preserved',
            );
          }

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
}
