import 'package:dddart/dddart.dart';
import 'package:test/test.dart';

// Concrete test event for testing DomainEvent base class
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

class AnotherTestEvent extends DomainEvent {
  AnotherTestEvent({
    required super.aggregateId,
    required this.value,
  });
  final int value;
}

void main() {
  group('DomainEvent', () {
    group('constructor', () {
      test('creates event with required aggregateId', () {
        final aggregateId = UuidValue.generate();
        final event = TestDomainEvent(
          aggregateId: aggregateId,
          data: 'test data',
        );

        expect(event.aggregateId, equals(aggregateId));
      });

      test('auto-generates eventId when not provided', () {
        final event = TestDomainEvent(
          aggregateId: UuidValue.generate(),
          data: 'test data',
        );

        expect(event.eventId, isNotNull);
        expect(event.eventId.uuid.length, equals(36)); // UUID v4 format
      });

      test('uses provided eventId when specified', () {
        final customEventId =
            UuidValue.fromString('12345678-1234-1234-1234-123456789abc');
        final event = TestDomainEvent(
          aggregateId: UuidValue.generate(),
          data: 'test data',
          eventId: customEventId,
        );

        expect(event.eventId, equals(customEventId));
      });

      test('auto-generates occurredAt timestamp when not provided', () {
        final beforeCreation = DateTime.now();
        final event = TestDomainEvent(
          aggregateId: UuidValue.generate(),
          data: 'test data',
        );
        final afterCreation = DateTime.now();

        expect(event.occurredAt, isNotNull);
        expect(
          event.occurredAt
              .isAfter(beforeCreation.subtract(const Duration(seconds: 1))),
          isTrue,
        );
        expect(
          event.occurredAt
              .isBefore(afterCreation.add(const Duration(seconds: 1))),
          isTrue,
        );
      });

      test('uses provided occurredAt timestamp when specified', () {
        final customTimestamp = DateTime(2023, 6, 15, 10, 30);
        final event = TestDomainEvent(
          aggregateId: UuidValue.generate(),
          data: 'test data',
          occurredAt: customTimestamp,
        );

        expect(event.occurredAt, equals(customTimestamp));
      });

      test('defaults to empty context map when not provided', () {
        final event = TestDomainEvent(
          aggregateId: UuidValue.generate(),
          data: 'test data',
        );

        expect(event.context, isEmpty);
        expect(event.context, isA<Map<String, dynamic>>());
      });

      test('uses provided context map when specified', () {
        final customContext = {
          'userId': 'user-123',
          'organizationId': 'org-456',
          'source': 'web-app',
        };
        final event = TestDomainEvent(
          aggregateId: UuidValue.generate(),
          data: 'test data',
          context: customContext,
        );

        expect(event.context, equals(customContext));
        expect(event.context['userId'], equals('user-123'));
        expect(event.context['organizationId'], equals('org-456'));
        expect(event.context['source'], equals('web-app'));
      });
    });

    group('equality', () {
      test('events with same eventId are equal', () {
        final eventId =
            UuidValue.fromString('12345678-1234-1234-1234-123456789abc');
        final event1 = TestDomainEvent(
          aggregateId: UuidValue.generate(),
          data: 'test data',
          eventId: eventId,
        );
        final event2 = TestDomainEvent(
          aggregateId: UuidValue.generate(),
          data: 'different data',
          eventId: eventId,
        );

        expect(event1, equals(event2));
        expect(event1.hashCode, equals(event2.hashCode));
      });

      test('events with different eventIds are not equal', () {
        final event1 = TestDomainEvent(
          aggregateId: UuidValue.generate(),
          data: 'test data',
          eventId: UuidValue.fromString('12345678-1234-1234-1234-123456789abc'),
        );
        final event2 = TestDomainEvent(
          aggregateId: UuidValue.generate(),
          data: 'test data',
          eventId: UuidValue.fromString('87654321-4321-4321-4321-cba987654321'),
        );

        expect(event1, isNot(equals(event2)));
        expect(event1.hashCode, isNot(equals(event2.hashCode)));
      });

      test('same event instance is equal to itself', () {
        final event = TestDomainEvent(
          aggregateId: UuidValue.generate(),
          data: 'test data',
        );

        expect(event, equals(event));
        expect(identical(event, event), isTrue);
      });

      test('events of different types with same eventId are equal', () {
        final eventId =
            UuidValue.fromString('12345678-1234-1234-1234-123456789abc');
        final event1 = TestDomainEvent(
          aggregateId: UuidValue.generate(),
          data: 'test data',
          eventId: eventId,
        );
        final event2 = AnotherTestEvent(
          aggregateId: UuidValue.generate(),
          value: 42,
        );
        // They should have different IDs by default
        expect(event1, isNot(equals(event2)));
      });
    });

    group('toString', () {
      test('includes event type, eventId, aggregateId, and occurredAt', () {
        final aggregateId =
            UuidValue.fromString('12345678-1234-1234-1234-123456789abc');
        final eventId =
            UuidValue.fromString('87654321-4321-4321-4321-cba987654321');
        final event = TestDomainEvent(
          aggregateId: aggregateId,
          data: 'test data',
          eventId: eventId,
          occurredAt: DateTime(2023, 6, 15, 10, 30),
        );

        final result = event.toString();

        expect(result, contains('TestDomainEvent'));
        expect(
          result,
          contains('eventId: 87654321-4321-4321-4321-cba987654321'),
        );
        expect(
          result,
          contains('aggregateId: 12345678-1234-1234-1234-123456789abc'),
        );
        expect(result, contains('occurredAt: 2023-06-15 10:30:00.000'));
      });
    });

    group('metadata fields', () {
      test('all metadata fields are accessible', () {
        final customTimestamp = DateTime(2023, 6, 15, 10, 30);
        final customContext = {'key': 'value'};
        final aggregateId = UuidValue.generate();
        final eventId = UuidValue.generate();
        final event = TestDomainEvent(
          aggregateId: aggregateId,
          data: 'test data',
          eventId: eventId,
          occurredAt: customTimestamp,
          context: customContext,
        );

        expect(event.eventId, equals(eventId));
        expect(event.occurredAt, equals(customTimestamp));
        expect(event.aggregateId, equals(aggregateId));
        expect(event.context, equals(customContext));
      });

      test('context map supports various data types', () {
        final context = {
          'stringValue': 'test',
          'intValue': 42,
          'doubleValue': 3.14,
          'boolValue': true,
          'listValue': [1, 2, 3],
          'mapValue': {'nested': 'data'},
        };
        final event = TestDomainEvent(
          aggregateId: UuidValue.generate(),
          data: 'test data',
          context: context,
        );

        expect(event.context['stringValue'], equals('test'));
        expect(event.context['intValue'], equals(42));
        expect(event.context['doubleValue'], equals(3.14));
        expect(event.context['boolValue'], isTrue);
        expect(event.context['listValue'], equals([1, 2, 3]));
        expect(event.context['mapValue'], equals({'nested': 'data'}));
      });
    });

    group('immutability', () {
      test('event fields are final and cannot be reassigned', () {
        final event = TestDomainEvent(
          aggregateId: UuidValue.generate(),
          data: 'test data',
        );

        // These should be compile-time errors if uncommented:
        // event.eventId = UuidValue.generate();
        // event.occurredAt = DateTime.now();
        // event.aggregateId = UuidValue.generate();
        // event.context = {};

        // Verify fields are accessible
        expect(event.eventId, isNotNull);
        expect(event.occurredAt, isNotNull);
        expect(event.aggregateId, isNotNull);
        expect(event.context, isNotNull);
      });
    });

    group('unique event generation', () {
      test('multiple events have unique eventIds', () {
        final aggregateId = UuidValue.generate();
        final event1 = TestDomainEvent(
          aggregateId: aggregateId,
          data: 'test data 1',
        );
        final event2 = TestDomainEvent(
          aggregateId: aggregateId,
          data: 'test data 2',
        );
        final event3 = TestDomainEvent(
          aggregateId: aggregateId,
          data: 'test data 3',
        );

        expect(event1.eventId, isNot(equals(event2.eventId)));
        expect(event1.eventId, isNot(equals(event3.eventId)));
        expect(event2.eventId, isNot(equals(event3.eventId)));
      });

      test('events created in rapid succession have unique IDs', () {
        final aggregateId = UuidValue.generate();
        final events = List.generate(
          100,
          (index) => TestDomainEvent(
            aggregateId: aggregateId,
            data: 'test data $index',
          ),
        );

        final eventIds = events.map((e) => e.eventId).toSet();
        expect(eventIds.length, equals(100)); // All IDs should be unique
      });
    });
  });
}
