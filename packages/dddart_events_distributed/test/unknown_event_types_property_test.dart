/// Property-based tests for unknown event type handling.
///
/// **Feature: distributed-events, Property 6: Unknown event types are skipped**
/// **Validates: Requirements 13.5, 14.4**
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
  group('Property 6: Unknown event types are skipped', () {
    test(
      'should skip events with unknown types without error',
      () async {
        final random = Random(42);

        for (var i = 0; i < 100; i++) {
          final eventBus = EventBus();
          final receivedEvents = <DomainEvent>[];

          eventBus.on<DomainEvent>().listen(receivedEvents.add);

          // Generate mix of known and unknown events
          final knownEventCount = 1 + random.nextInt(5);
          final unknownEventCount = 1 + random.nextInt(5);
          final baseTime = DateTime.now().add(const Duration(seconds: 1));

          final knownEvents = List.generate(
            knownEventCount,
            (j) =>
                _generateKnownEvent(random, baseTime.add(Duration(seconds: j))),
          );

          final unknownEvents = List.generate(
            unknownEventCount,
            (j) => _generateUnknownEvent(
              random,
              baseTime.add(Duration(seconds: knownEventCount + j)),
            ),
          );

          // Mix events together
          final allEvents = [...knownEvents, ...unknownEvents];
          allEvents.shuffle(random);

          // Mock client that returns all events
          final mockClient = MockClient((request) async {
            if (request.url.path.endsWith('/events') &&
                request.method == 'GET') {
              final since = request.url.queryParameters['since'];
              final sinceTimestamp = DateTime.parse(since!);

              final events = allEvents.where((e) {
                final occurredAt = e['occurredAt'] as DateTime;
                return occurredAt.isAfter(sinceTimestamp);
              }).map((e) {
                // Remove the DateTime object before serializing
                final copy = Map<String, dynamic>.from(e);
                copy.remove('occurredAt');
                return copy;
              }).toList();

              return http.Response(
                jsonEncode(events),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            return http.Response('Not Found', 404);
          });

          // Create client with registry that only knows about KnownEvent
          final client = EventBusClient(
            localEventBus: eventBus,
            serverUrl: 'http://test-server',
            eventRegistry: {
              'KnownEvent': KnownEvent.fromJson,
            },
            pollingInterval: const Duration(milliseconds: 50),
            httpClient: mockClient,
          );

          // Wait for polling
          await Future<void>.delayed(const Duration(milliseconds: 150));

          // Verify only known events were received
          expect(
            receivedEvents.length,
            equals(knownEventCount),
            reason: 'Iteration $i: only known events should be received',
          );

          // Verify all received events are KnownEvent
          for (final event in receivedEvents) {
            expect(
              event,
              isA<KnownEvent>(),
              reason: 'Iteration $i: all received events should be KnownEvent',
            );
          }

          // Clean up
          await client.close();
        }
      },
    );

    test(
      'should continue processing after encountering unknown event',
      () async {
        final random = Random(43);

        for (var i = 0; i < 100; i++) {
          final eventBus = EventBus();
          final receivedEvents = <DomainEvent>[];

          eventBus.on<DomainEvent>().listen(receivedEvents.add);

          // Create sequence: known, unknown, known
          final baseTime = DateTime.now().add(const Duration(seconds: 1));
          final event1 = _generateKnownEvent(random, baseTime);
          final event2 = _generateUnknownEvent(
            random,
            baseTime.add(const Duration(seconds: 1)),
          );
          final event3 = _generateKnownEvent(
            random,
            baseTime.add(const Duration(seconds: 2)),
          );

          final allEvents = [event1, event2, event3];

          // Mock client
          final mockClient = MockClient((request) async {
            if (request.url.path.endsWith('/events') &&
                request.method == 'GET') {
              final since = request.url.queryParameters['since'];
              final sinceTimestamp = DateTime.parse(since!);

              final events = allEvents.where((e) {
                final occurredAt = e['occurredAt'] as DateTime;
                return occurredAt.isAfter(sinceTimestamp);
              }).map((e) {
                // Remove the DateTime object before serializing
                final copy = Map<String, dynamic>.from(e);
                copy.remove('occurredAt');
                return copy;
              }).toList();

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
              'KnownEvent': KnownEvent.fromJson,
            },
            pollingInterval: const Duration(milliseconds: 50),
            httpClient: mockClient,
          );

          // Wait for polling
          await Future<void>.delayed(const Duration(milliseconds: 150));

          // Verify both known events were received (unknown was skipped)
          expect(
            receivedEvents.length,
            equals(2),
            reason: 'Iteration $i: both known events should be received',
          );

          // Verify the events are the correct ones
          final receivedIds = receivedEvents.map((e) => e.eventId).toSet();
          expect(
            receivedIds.contains(
              UuidValue.fromString(event1['id'] as String),
            ),
            isTrue,
            reason: 'Iteration $i: first known event should be received',
          );
          expect(
            receivedIds.contains(
              UuidValue.fromString(event3['id'] as String),
            ),
            isTrue,
            reason: 'Iteration $i: second known event should be received',
          );

          // Clean up
          await client.close();
        }
      },
    );

    test(
      'should handle all unknown events gracefully',
      () async {
        final random = Random(44);

        for (var i = 0; i < 50; i++) {
          final eventBus = EventBus();
          final receivedEvents = <DomainEvent>[];

          eventBus.on<DomainEvent>().listen(receivedEvents.add);

          // Generate only unknown events
          final unknownEventCount = 1 + random.nextInt(10);
          final baseTime = DateTime.now().add(const Duration(seconds: 1));

          final unknownEvents = List.generate(
            unknownEventCount,
            (j) => _generateUnknownEvent(
              random,
              baseTime.add(Duration(seconds: j)),
            ),
          );

          // Mock client
          final mockClient = MockClient((request) async {
            if (request.url.path.endsWith('/events') &&
                request.method == 'GET') {
              final since = request.url.queryParameters['since'];
              final sinceTimestamp = DateTime.parse(since!);

              final events = unknownEvents.where((e) {
                final occurredAt = e['occurredAt'] as DateTime;
                return occurredAt.isAfter(sinceTimestamp);
              }).map((e) {
                // Remove the DateTime object before serializing
                final copy = Map<String, dynamic>.from(e);
                copy.remove('occurredAt');
                return copy;
              }).toList();

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
              'KnownEvent': KnownEvent.fromJson,
            },
            pollingInterval: const Duration(milliseconds: 50),
            httpClient: mockClient,
          );

          // Wait for polling
          await Future<void>.delayed(const Duration(milliseconds: 150));

          // Verify no events were received (all were unknown)
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
      'should update timestamp even when skipping unknown events',
      () async {
        final random = Random(45);

        for (var i = 0; i < 50; i++) {
          final eventBus = EventBus();
          final receivedEvents = <DomainEvent>[];

          eventBus.on<DomainEvent>().listen(receivedEvents.add);

          // First batch: unknown events
          // Second batch: known events
          final baseTime = DateTime.now().add(const Duration(seconds: 1));
          final unknownEvents = List.generate(
            3,
            (j) => _generateUnknownEvent(
              random,
              baseTime.add(Duration(seconds: j)),
            ),
          );
          final knownEvents = List.generate(
            3,
            (j) => _generateKnownEvent(
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

              // First poll: return unknown events
              if (pollCount == 1) {
                final events = unknownEvents.where((e) {
                  final occurredAt = e['occurredAt'] as DateTime;
                  return occurredAt.isAfter(sinceTimestamp);
                }).map((e) {
                  final copy = Map<String, dynamic>.from(e);
                  copy.remove('occurredAt');
                  return copy;
                }).toList();
                return http.Response(
                  jsonEncode(events),
                  200,
                  headers: {'content-type': 'application/json'},
                );
              }

              // Second poll: should only return known events
              // (unknown events should be filtered by updated timestamp)
              final events = knownEvents.where((e) {
                final occurredAt = e['occurredAt'] as DateTime;
                return occurredAt.isAfter(sinceTimestamp);
              }).map((e) {
                final copy = Map<String, dynamic>.from(e);
                copy.remove('occurredAt');
                return copy;
              }).toList();
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
              'KnownEvent': KnownEvent.fromJson,
            },
            pollingInterval: const Duration(milliseconds: 50),
            initialTimestamp: baseTime,
            httpClient: mockClient,
          );

          // Wait for multiple polls
          await Future<void>.delayed(const Duration(milliseconds: 200));

          // Verify only known events were received
          expect(
            receivedEvents.length,
            equals(knownEvents.length),
            reason: 'Iteration $i: only known events should be received',
          );

          // Clean up
          await client.close();
        }
      },
    );
  });
}

// Generator functions

/// Generates a known event (in the registry).
Map<String, dynamic> _generateKnownEvent(Random random, DateTime timestamp) {
  final eventId = UuidValue.generate();
  final aggregateId = UuidValue.generate();
  final data = 'known-${random.nextInt(1000)}';

  final eventJson = {
    'eventId': eventId.toString(),
    'occurredAt': timestamp.toIso8601String(),
    'aggregateId': aggregateId.toString(),
    'data': data,
    'context': <String, dynamic>{},
  };

  return {
    'id': eventId.toString(),
    'createdAt': timestamp.toIso8601String(),
    'updatedAt': timestamp.toIso8601String(),
    'aggregateId': aggregateId.toString(),
    'eventType': 'KnownEvent',
    'eventJson': jsonEncode(eventJson),
    'occurredAt': timestamp, // For filtering in tests
  };
}

/// Generates an unknown event (not in the registry).
Map<String, dynamic> _generateUnknownEvent(Random random, DateTime timestamp) {
  final eventId = UuidValue.generate();
  final aggregateId = UuidValue.generate();
  final data = 'unknown-${random.nextInt(1000)}';

  final eventJson = {
    'eventId': eventId.toString(),
    'occurredAt': timestamp.toIso8601String(),
    'aggregateId': aggregateId.toString(),
    'data': data,
    'context': <String, dynamic>{},
  };

  return {
    'id': eventId.toString(),
    'createdAt': timestamp.toIso8601String(),
    'updatedAt': timestamp.toIso8601String(),
    'aggregateId': aggregateId.toString(),
    'eventType': 'UnknownEvent',
    'eventJson': jsonEncode(eventJson),
    'occurredAt': timestamp, // For filtering in tests
  };
}

// Test event class

/// Known event type (in the registry).
class KnownEvent extends DomainEvent {
  KnownEvent({
    required super.aggregateId,
    required this.data,
    super.eventId,
    super.occurredAt,
    super.context,
  });

  final String data;

  static KnownEvent fromJson(Map<String, dynamic> json) {
    return KnownEvent(
      eventId: UuidValue.fromString(json['eventId'] as String),
      occurredAt: DateTime.parse(json['occurredAt'] as String),
      aggregateId: UuidValue.fromString(json['aggregateId'] as String),
      data: json['data'] as String,
      context: json['context'] as Map<String, dynamic>? ?? {},
    );
  }
}
