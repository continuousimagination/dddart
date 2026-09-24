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
  group('Controlled polling lifecycle', () {
    test(
      'slow overlapping ticks deliver each event exactly once and advance cursor',
      () async {
        final harness = _ControlledPolling();
        addTearDown(harness.close);
        harness.timer.fire();
        await _drain();
        harness.timer.fire();
        harness.timer.fire();
        await _drain();
        final first = harness.event(1);
        harness.respondAll([first]);
        await _drain();
        expect(harness.received, hasLength(1));
        expect(harness.received.single.eventId, first.eventId);
        expect(harness.maximumActive, 1);
        expect(harness.requests, hasLength(1));

        final second = harness.event(2);
        harness.timer.fire();
        await _drain();
        expect(
          DateTime.parse(harness.requests.last.uri.queryParameters['since']!),
          first.occurredAt.add(const Duration(microseconds: 1)),
        );
        harness.respondAll([second]);
        await _drain();
        expect(harness.received.map((event) => event.eventId), [
          first.eventId,
          second.eventId,
        ]);
        expect(harness.maximumActive, 1);
      },
    );

    test(
      'close waits for the active poll and rejects late delivery and new work',
      () async {
        final harness = _ControlledPolling();
        addTearDown(harness.close);
        harness.timer.fire();
        await _drain();
        var completed = false;
        final closing = harness.client.close();
        expect(identical(closing, harness.client.close()), isTrue);
        unawaited(closing.then((_) => completed = true));
        await _drain();
        expect(completed, isFalse);
        expect(harness.transport.closes, 1);
        expect(harness.timer.isActive, isFalse);
        expect(
          () => harness.client.publish(harness.event(3)),
          throwsStateError,
        );
        harness.timer.fire();
        expect(harness.requests, hasLength(1));
        harness.respondAll([harness.event(1)]);
        await closing;
        expect(harness.received, isEmpty);
        expect(harness.bus.isClosed, isTrue);
        await harness.client.close();
        expect(harness.transport.closes, 1);
      },
    );

    for (final failure in ['status', 'malformed', 'transport']) {
      test(
        '$failure failure releases the poll slot for later delivery',
        () async {
          final harness = _ControlledPolling();
          addTearDown(harness.close);
          harness.timer.fire();
          await _drain();
          final response = harness.requests.single.response;
          if (failure == 'transport') {
            response.completeError(http.ClientException('synthetic failure'));
          } else {
            response.complete(
              http.Response(
                failure == 'malformed' ? '{' : '[]',
                failure == 'status' ? 503 : 200,
              ),
            );
          }
          await _drain();
          expect(harness.received, isEmpty);
          expect(harness.requests, hasLength(1));
          harness.timer.fire();
          await _drain();
          final later = harness.event(2);
          harness.respondAll([later]);
          await _drain();
          expect(harness.received, hasLength(1));
          expect(harness.received.single.eventId, later.eventId);
          expect(harness.maximumActive, 1);
        },
      );
    }
  });
  group('Property 4: Polling retrieves new events', () {
    test('should retrieve all events since last timestamp', () async {
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
          if (request.url.path.endsWith('/events') && request.method == 'GET') {
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
        final initialTimestamp = serverEvents.first.occurredAt.subtract(
          const Duration(seconds: 1),
        );

        final client = EventBusClient(
          localEventBus: eventBus,
          serverUrl: 'http://test-server',
          eventRegistry: {'TestDomainEvent': TestDomainEvent.fromJson},
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
    });

    test('should only retrieve events after last timestamp', () async {
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
          if (request.url.path.endsWith('/events') && request.method == 'GET') {
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
          eventRegistry: {'TestDomainEvent': TestDomainEvent.fromJson},
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
    });

    test('should handle empty responses when no new events', () async {
      for (var i = 0; i < 50; i++) {
        final eventBus = EventBus();
        final receivedEvents = <TestDomainEvent>[];

        eventBus.on<TestDomainEvent>().listen(receivedEvents.add);

        // Mock client that returns empty array
        final mockClient = MockClient((request) async {
          if (request.url.path.endsWith('/events') && request.method == 'GET') {
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
          eventRegistry: {'TestDomainEvent': TestDomainEvent.fromJson},
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
    });

    test('should update last timestamp after receiving events', () async {
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
          if (request.url.path.endsWith('/events') && request.method == 'GET') {
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
          eventRegistry: {'TestDomainEvent': TestDomainEvent.fromJson},
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
    });
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

Future<void> _drain() => Future<void>.delayed(Duration.zero);

class _ControlledTimer implements Timer {
  _ControlledTimer(this.callback);
  final void Function(Timer) callback;
  @override
  bool isActive = true;
  @override
  int tick = 0;
  void fire() {
    if (!isActive) return;
    tick++;
    callback(this);
  }

  @override
  void cancel() => isActive = false;
}

class _PendingPoll {
  _PendingPoll(this.uri);
  final Uri uri;
  final response = Completer<http.Response>();
}

class _PollTransport extends MockClient {
  _PollTransport(super.handler);
  int closes = 0;
  @override
  void close() {
    closes++;
    super.close();
  }
}

class _ControlledPolling {
  _ControlledPolling() {
    bus.on<TestDomainEvent>().listen(received.add);
    transport = _PollTransport((request) async {
      final pending = _PendingPoll(request.url);
      requests.add(pending);
      active++;
      maximumActive = max(maximumActive, active);
      try {
        return await pending.response.future;
      } finally {
        active--;
      }
    });
    client = runZoned(
      () => EventBusClient(
        localEventBus: bus,
        serverUrl: 'http://synthetic.invalid',
        eventRegistry: {'TestDomainEvent': TestDomainEvent.fromJson},
        initialTimestamp: DateTime.utc(2026),
        httpClient: transport,
      ),
      zoneSpecification: ZoneSpecification(
        createPeriodicTimer: (self, parent, zone, duration, callback) {
          return timer = _ControlledTimer(zone.bindUnaryCallback(callback));
        },
      ),
    );
  }
  final bus = EventBus();
  final received = <TestDomainEvent>[];
  final requests = <_PendingPoll>[];
  late final _PollTransport transport;
  late final EventBusClient client;
  late final _ControlledTimer timer;
  int active = 0;
  int maximumActive = 0;
  TestDomainEvent event(int sequence) => TestDomainEvent(
    aggregateId: UuidValue.fromString('00000000-0000-4000-8000-000000000001'),
    eventId: UuidValue.fromString(
      '00000000-0000-4000-8000-${sequence.toString().padLeft(12, '0')}',
    ),
    occurredAt: DateTime.utc(2026, 1, 1, 0, 0, sequence),
    data: 'synthetic-$sequence',
  );
  void respondAll(List<TestDomainEvent> events) {
    for (final request in requests) {
      if (!request.response.isCompleted) {
        request.response.complete(
          http.Response(
            jsonEncode(events.map(_eventToStoredEventJson).toList()),
            200,
          ),
        );
      }
    }
  }

  Future<void> close() async {
    respondAll([]);
    await client.close();
  }
}

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
