/// Property-based tests for event registry deserialization.
///
/// **Feature: distributed-events, Property 5: Event registry deserializes correctly**
/// **Validates: Requirements 13.4, 14.1**
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
  group('Property 5: Event registry deserializes correctly', () {
    test(
      'should deserialize registered events correctly',
      () async {
        final random = Random(42);

        for (var i = 0; i < 100; i++) {
          final eventBus = EventBus();
          final receivedEvents = <DomainEvent>[];

          eventBus.on<DomainEvent>().listen(receivedEvents.add);

          // Generate random events of different types
          final eventCount = 1 + random.nextInt(10);
          final serverEvents = <DomainEvent>[];
          final baseTime = DateTime.now().add(const Duration(seconds: 1));

          for (var j = 0; j < eventCount; j++) {
            // Randomly choose event type
            final eventType = random.nextInt(3);
            final eventTime = baseTime.add(Duration(seconds: j));

            switch (eventType) {
              case 0:
                serverEvents
                    .add(_generateTestEventAWithTimestamp(random, eventTime));
              case 1:
                serverEvents
                    .add(_generateTestEventBWithTimestamp(random, eventTime));
              case 2:
                serverEvents
                    .add(_generateTestEventCWithTimestamp(random, eventTime));
            }
          }

          // Mock client that returns these events
          final mockClient = MockClient((request) async {
            if (request.url.path.endsWith('/events') &&
                request.method == 'GET') {
              final since = request.url.queryParameters['since'];
              final sinceTimestamp = DateTime.parse(since!);

              // Only return events after the since timestamp
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
            return http.Response('Not Found', 404);
          });

          // Create client with event registry
          final client = EventBusClient(
            localEventBus: eventBus,
            serverUrl: 'http://test-server',
            eventRegistry: {
              'TestEventA': TestEventA.fromJson,
              'TestEventB': TestEventB.fromJson,
              'TestEventC': TestEventC.fromJson,
            },
            pollingInterval: const Duration(milliseconds: 50),
            httpClient: mockClient,
          );

          // Wait for polling
          await Future<void>.delayed(const Duration(milliseconds: 150));

          // Verify all events were received and deserialized correctly
          expect(
            receivedEvents.length,
            equals(eventCount),
            reason: 'Iteration $i: all $eventCount events should be received',
          );

          // Verify each event was deserialized correctly
          for (var j = 0; j < eventCount; j++) {
            final serverEvent = serverEvents[j];
            final receivedEvent = receivedEvents.firstWhere(
              (e) => e.eventId == serverEvent.eventId,
            );

            expect(
              receivedEvent.runtimeType,
              equals(serverEvent.runtimeType),
              reason: 'Iteration $i, Event $j: type should match',
            );
            expect(
              receivedEvent.aggregateId,
              equals(serverEvent.aggregateId),
              reason: 'Iteration $i, Event $j: aggregateId should match',
            );

            // Verify type-specific data
            if (serverEvent is TestEventA && receivedEvent is TestEventA) {
              expect(
                receivedEvent.dataA,
                equals(serverEvent.dataA),
                reason: 'Iteration $i, Event $j: dataA should match',
              );
            } else if (serverEvent is TestEventB &&
                receivedEvent is TestEventB) {
              expect(
                receivedEvent.dataB,
                equals(serverEvent.dataB),
                reason: 'Iteration $i, Event $j: dataB should match',
              );
            } else if (serverEvent is TestEventC &&
                receivedEvent is TestEventC) {
              expect(
                receivedEvent.dataC,
                equals(serverEvent.dataC),
                reason: 'Iteration $i, Event $j: dataC should match',
              );
            }
          }

          // Clean up
          await client.close();
        }
      },
    );

    test(
      'should preserve event data through serialization round-trip',
      () async {
        final random = Random(43);

        for (var i = 0; i < 100; i++) {
          final eventBus = EventBus();
          final receivedEvents = <TestEventA>[];

          eventBus.on<TestEventA>().listen(receivedEvents.add);

          // Generate random event with various data types
          final eventTime = DateTime.now().add(const Duration(seconds: 1));
          final originalEvent = TestEventA(
            aggregateId: UuidValue.generate(),
            eventId: UuidValue.generate(),
            occurredAt: eventTime,
            dataA: 'test-${random.nextInt(1000)}',
            numberField: random.nextInt(10000),
            boolField: random.nextBool(),
            listField: List.generate(
              random.nextInt(5),
              (_) => 'item-${random.nextInt(100)}',
            ),
          );

          // Mock client that returns this event
          final mockClient = MockClient((request) async {
            if (request.url.path.endsWith('/events') &&
                request.method == 'GET') {
              final since = request.url.queryParameters['since'];
              final sinceTimestamp = DateTime.parse(since!);

              // Only return event if it's after the since timestamp
              final events = originalEvent.occurredAt.isAfter(sinceTimestamp)
                  ? [_eventToStoredEventJson(originalEvent)]
                  : <Map<String, dynamic>>[];

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
              'TestEventA': TestEventA.fromJson,
            },
            pollingInterval: const Duration(milliseconds: 50),
            httpClient: mockClient,
          );

          // Wait for polling
          await Future<void>.delayed(const Duration(milliseconds: 150));

          // Verify event was received
          expect(
            receivedEvents.length,
            equals(1),
            reason: 'Iteration $i: event should be received',
          );

          final receivedEvent = receivedEvents.first;

          // Verify all fields match
          expect(
            receivedEvent.eventId,
            equals(originalEvent.eventId),
            reason: 'Iteration $i: eventId should match',
          );
          expect(
            receivedEvent.aggregateId,
            equals(originalEvent.aggregateId),
            reason: 'Iteration $i: aggregateId should match',
          );
          expect(
            receivedEvent.dataA,
            equals(originalEvent.dataA),
            reason: 'Iteration $i: dataA should match',
          );
          expect(
            receivedEvent.numberField,
            equals(originalEvent.numberField),
            reason: 'Iteration $i: numberField should match',
          );
          expect(
            receivedEvent.boolField,
            equals(originalEvent.boolField),
            reason: 'Iteration $i: boolField should match',
          );
          expect(
            receivedEvent.listField,
            equals(originalEvent.listField),
            reason: 'Iteration $i: listField should match',
          );

          // Clean up
          await client.close();
        }
      },
    );

    test(
      'should handle events with null optional fields',
      () async {
        final random = Random(44);

        for (var i = 0; i < 100; i++) {
          final eventBus = EventBus();
          final receivedEvents = <TestEventB>[];

          eventBus.on<TestEventB>().listen(receivedEvents.add);

          // Generate event with random null fields
          final eventTime = DateTime.now().add(const Duration(seconds: 1));
          final originalEvent = TestEventB(
            aggregateId: UuidValue.generate(),
            eventId: UuidValue.generate(),
            occurredAt: eventTime,
            dataB: 'test-${random.nextInt(1000)}',
            optionalField:
                random.nextBool() ? 'value-${random.nextInt(100)}' : null,
          );

          // Mock client
          final mockClient = MockClient((request) async {
            if (request.url.path.endsWith('/events') &&
                request.method == 'GET') {
              final since = request.url.queryParameters['since'];
              final sinceTimestamp = DateTime.parse(since!);

              // Only return event if it's after the since timestamp
              final events = originalEvent.occurredAt.isAfter(sinceTimestamp)
                  ? [_eventToStoredEventJson(originalEvent)]
                  : <Map<String, dynamic>>[];

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
              'TestEventB': TestEventB.fromJson,
            },
            pollingInterval: const Duration(milliseconds: 50),
            httpClient: mockClient,
          );

          // Wait for polling
          await Future<void>.delayed(const Duration(milliseconds: 150));

          // Verify event was received
          expect(
            receivedEvents.length,
            equals(1),
            reason: 'Iteration $i: event should be received',
          );

          final receivedEvent = receivedEvents.first;

          // Verify fields match including null handling
          expect(
            receivedEvent.dataB,
            equals(originalEvent.dataB),
            reason: 'Iteration $i: dataB should match',
          );
          expect(
            receivedEvent.optionalField,
            equals(originalEvent.optionalField),
            reason: 'Iteration $i: optionalField should match (null or value)',
          );

          // Clean up
          await client.close();
        }
      },
    );
  });
}

// Generator functions

/// Generates TestEventA with specific timestamp.
TestEventA _generateTestEventAWithTimestamp(Random random, DateTime timestamp) {
  return TestEventA(
    aggregateId: UuidValue.generate(),
    eventId: UuidValue.generate(),
    occurredAt: timestamp,
    dataA: 'test-a-${random.nextInt(1000)}',
    numberField: random.nextInt(10000),
    boolField: random.nextBool(),
    listField: List.generate(
      random.nextInt(5),
      (_) => 'item-${random.nextInt(100)}',
    ),
  );
}

/// Generates TestEventB with specific timestamp.
TestEventB _generateTestEventBWithTimestamp(Random random, DateTime timestamp) {
  return TestEventB(
    aggregateId: UuidValue.generate(),
    eventId: UuidValue.generate(),
    occurredAt: timestamp,
    dataB: 'test-b-${random.nextInt(1000)}',
    optionalField: random.nextBool() ? 'value-${random.nextInt(100)}' : null,
  );
}

/// Generates TestEventC with specific timestamp.
TestEventC _generateTestEventCWithTimestamp(Random random, DateTime timestamp) {
  return TestEventC(
    aggregateId: UuidValue.generate(),
    eventId: UuidValue.generate(),
    occurredAt: timestamp,
    dataC: 'test-c-${random.nextInt(1000)}',
  );
}

/// Converts an event to StoredEvent JSON format.
Map<String, dynamic> _eventToStoredEventJson(DomainEvent event) {
  Map<String, dynamic> eventJson;

  if (event is TestEventA) {
    eventJson = {
      'eventId': event.eventId.toString(),
      'occurredAt': event.occurredAt.toIso8601String(),
      'aggregateId': event.aggregateId.toString(),
      'dataA': event.dataA,
      'numberField': event.numberField,
      'boolField': event.boolField,
      'listField': event.listField,
      'context': event.context,
    };
  } else if (event is TestEventB) {
    eventJson = {
      'eventId': event.eventId.toString(),
      'occurredAt': event.occurredAt.toIso8601String(),
      'aggregateId': event.aggregateId.toString(),
      'dataB': event.dataB,
      if (event.optionalField != null) 'optionalField': event.optionalField,
      'context': event.context,
    };
  } else if (event is TestEventC) {
    eventJson = {
      'eventId': event.eventId.toString(),
      'occurredAt': event.occurredAt.toIso8601String(),
      'aggregateId': event.aggregateId.toString(),
      'dataC': event.dataC,
      'context': event.context,
    };
  } else {
    throw Exception('Unknown event type: ${event.runtimeType}');
  }

  return {
    'id': event.eventId.toString(),
    'createdAt': event.occurredAt.toIso8601String(),
    'updatedAt': event.occurredAt.toIso8601String(),
    'aggregateId': event.aggregateId.toString(),
    'eventType': event.runtimeType.toString(),
    'eventJson': jsonEncode(eventJson),
  };
}

// Test event classes

/// Test event A with various field types.
class TestEventA extends DomainEvent {
  TestEventA({
    required super.aggregateId,
    required this.dataA,
    required this.numberField,
    required this.boolField,
    required this.listField,
    super.eventId,
    super.occurredAt,
    super.context,
  });

  final String dataA;
  final int numberField;
  final bool boolField;
  final List<String> listField;

  static TestEventA fromJson(Map<String, dynamic> json) {
    return TestEventA(
      eventId: UuidValue.fromString(json['eventId'] as String),
      occurredAt: DateTime.parse(json['occurredAt'] as String),
      aggregateId: UuidValue.fromString(json['aggregateId'] as String),
      dataA: json['dataA'] as String,
      numberField: json['numberField'] as int,
      boolField: json['boolField'] as bool,
      listField: (json['listField'] as List).cast<String>(),
      context: json['context'] as Map<String, dynamic>? ?? {},
    );
  }
}

/// Test event B with optional field.
class TestEventB extends DomainEvent {
  TestEventB({
    required super.aggregateId,
    required this.dataB,
    this.optionalField,
    super.eventId,
    super.occurredAt,
    super.context,
  });

  final String dataB;
  final String? optionalField;

  static TestEventB fromJson(Map<String, dynamic> json) {
    return TestEventB(
      eventId: UuidValue.fromString(json['eventId'] as String),
      occurredAt: DateTime.parse(json['occurredAt'] as String),
      aggregateId: UuidValue.fromString(json['aggregateId'] as String),
      dataB: json['dataB'] as String,
      optionalField: json['optionalField'] as String?,
      context: json['context'] as Map<String, dynamic>? ?? {},
    );
  }
}

/// Test event C - simple event.
class TestEventC extends DomainEvent {
  TestEventC({
    required super.aggregateId,
    required this.dataC,
    super.eventId,
    super.occurredAt,
    super.context,
  });

  final String dataC;

  static TestEventC fromJson(Map<String, dynamic> json) {
    return TestEventC(
      eventId: UuidValue.fromString(json['eventId'] as String),
      occurredAt: DateTime.parse(json['occurredAt'] as String),
      aggregateId: UuidValue.fromString(json['aggregateId'] as String),
      dataC: json['dataC'] as String,
      context: json['context'] as Map<String, dynamic>? ?? {},
    );
  }
}
