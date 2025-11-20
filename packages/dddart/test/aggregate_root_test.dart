import 'package:dddart/src/aggregate_root.dart';
import 'package:dddart/src/domain_event.dart';
import 'package:dddart/src/entity.dart';
import 'package:dddart/src/uuid_value.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart' as uuid_pkg;

// Concrete implementation of AggregateRoot for testing
class TestAggregateRoot extends AggregateRoot {
  TestAggregateRoot({
    super.id,
    super.createdAt,
    super.updatedAt,
  });
}

// Test domain event for testing event collection
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

void main() {
  group('AggregateRoot', () {
    group('inheritance', () {
      test('extends Entity', () {
        final aggregateRoot = TestAggregateRoot();

        expect(aggregateRoot, isA<Entity>());
      });

      test('is an AggregateRoot', () {
        final aggregateRoot = TestAggregateRoot();

        expect(aggregateRoot, isA<AggregateRoot>());
      });
    });

    group('constructor parameter delegation', () {
      test('delegates ID parameter to Entity constructor', () {
        final providedId = UuidValue.fromString(const uuid_pkg.Uuid().v4());
        final aggregateRoot = TestAggregateRoot(id: providedId);

        expect(aggregateRoot.id, equals(providedId));
      });

      test('delegates createdAt parameter to Entity constructor', () {
        final createdAt = DateTime(2023);
        final aggregateRoot = TestAggregateRoot(createdAt: createdAt);

        expect(aggregateRoot.createdAt, equals(createdAt));
      });

      test('delegates updatedAt parameter to Entity constructor', () {
        final updatedAt = DateTime(2023, 1, 2);
        final aggregateRoot = TestAggregateRoot(updatedAt: updatedAt);

        expect(aggregateRoot.updatedAt, equals(updatedAt));
      });

      test('delegates all parameters to Entity constructor', () {
        final providedId = UuidValue.fromString(const uuid_pkg.Uuid().v4());
        final createdAt = DateTime(2023);
        final updatedAt = DateTime(2023, 1, 2);
        final aggregateRoot = TestAggregateRoot(
          id: providedId,
          createdAt: createdAt,
          updatedAt: updatedAt,
        );

        expect(aggregateRoot.id, equals(providedId));
        expect(aggregateRoot.createdAt, equals(createdAt));
        expect(aggregateRoot.updatedAt, equals(updatedAt));
      });

      test('auto-generates parameters when not provided', () {
        final beforeCreation = DateTime.now();
        final aggregateRoot = TestAggregateRoot();
        final afterCreation = DateTime.now();

        expect(aggregateRoot.id, isA<UuidValue>());
        expect(aggregateRoot.id.uuid, isNotEmpty);
        expect(
          aggregateRoot.createdAt
              .isAfter(beforeCreation.subtract(const Duration(seconds: 1))),
          isTrue,
        );
        expect(
          aggregateRoot.createdAt
              .isBefore(afterCreation.add(const Duration(seconds: 1))),
          isTrue,
        );
        expect(
          aggregateRoot.updatedAt
              .isAfter(beforeCreation.subtract(const Duration(seconds: 1))),
          isTrue,
        );
        expect(
          aggregateRoot.updatedAt
              .isBefore(afterCreation.add(const Duration(seconds: 1))),
          isTrue,
        );
      });
    });

    group('Entity functionality maintenance', () {
      test('maintains Entity equality behavior', () {
        final id = UuidValue.fromString(const uuid_pkg.Uuid().v4());
        final aggregateRoot1 = TestAggregateRoot(id: id);
        final aggregateRoot2 = TestAggregateRoot(id: id);

        expect(aggregateRoot1, equals(aggregateRoot2));
        expect(aggregateRoot1.hashCode, equals(aggregateRoot2.hashCode));
      });

      test('maintains Entity touch() functionality', () {
        final aggregateRoot = TestAggregateRoot(updatedAt: DateTime(2023));
        final originalUpdatedAt = aggregateRoot.updatedAt;

        // Wait a small amount to ensure timestamp difference
        Future.delayed(const Duration(milliseconds: 1), () {
          aggregateRoot.touch();

          expect(aggregateRoot.updatedAt.isAfter(originalUpdatedAt), isTrue);
        });
      });

      test('maintains Entity toString() functionality', () {
        final aggregateRoot = TestAggregateRoot();
        final result = aggregateRoot.toString();

        expect(result, contains('TestAggregateRoot'));
        expect(result, contains('id:'));
        expect(result, contains(aggregateRoot.id.toString()));
      });

      test('maintains Entity immutable properties', () {
        final id = UuidValue.fromString(const uuid_pkg.Uuid().v4());
        final createdAt = DateTime(2023);
        final aggregateRoot = TestAggregateRoot(id: id, createdAt: createdAt);

        // These should be immutable
        expect(aggregateRoot.id, equals(id));
        expect(aggregateRoot.createdAt, equals(createdAt));

        // updatedAt should be mutable via touch()
        final originalUpdatedAt = aggregateRoot.updatedAt;
        aggregateRoot.touch();
        expect(aggregateRoot.updatedAt, isNot(equals(originalUpdatedAt)));
      });
    });

    group('event collection', () {
      test('starts with empty uncommitted events list', () {
        final aggregateRoot = TestAggregateRoot();

        expect(aggregateRoot.getUncommittedEvents(), isEmpty);
      });

      test('raiseEvent adds event to uncommitted events list', () {
        final aggregateRoot = TestAggregateRoot();
        final event = TestDomainEvent(
          aggregateId: aggregateRoot.id,
          data: 'test data',
        );

        aggregateRoot.raiseEvent(event);

        final uncommittedEvents = aggregateRoot.getUncommittedEvents();
        expect(uncommittedEvents, hasLength(1));
        expect(uncommittedEvents.first, equals(event));
      });

      test('raiseEvent collects multiple events in order', () {
        final aggregateRoot = TestAggregateRoot();
        final event1 = TestDomainEvent(
          aggregateId: aggregateRoot.id,
          data: 'first event',
        );
        final event2 = TestDomainEvent(
          aggregateId: aggregateRoot.id,
          data: 'second event',
        );
        final event3 = TestDomainEvent(
          aggregateId: aggregateRoot.id,
          data: 'third event',
        );

        aggregateRoot.raiseEvent(event1);
        aggregateRoot.raiseEvent(event2);
        aggregateRoot.raiseEvent(event3);

        final uncommittedEvents = aggregateRoot.getUncommittedEvents();
        expect(uncommittedEvents, hasLength(3));
        expect(uncommittedEvents[0], equals(event1));
        expect(uncommittedEvents[1], equals(event2));
        expect(uncommittedEvents[2], equals(event3));
      });

      test('getUncommittedEvents returns unmodifiable list', () {
        final aggregateRoot = TestAggregateRoot();
        final event = TestDomainEvent(
          aggregateId: aggregateRoot.id,
          data: 'test data',
        );

        aggregateRoot.raiseEvent(event);
        final uncommittedEvents = aggregateRoot.getUncommittedEvents();

        expect(() => uncommittedEvents.add(event), throwsUnsupportedError);
      });

      test('markEventsAsCommitted clears uncommitted events list', () {
        final aggregateRoot = TestAggregateRoot();
        final event1 = TestDomainEvent(
          aggregateId: aggregateRoot.id,
          data: 'first event',
        );
        final event2 = TestDomainEvent(
          aggregateId: aggregateRoot.id,
          data: 'second event',
        );

        aggregateRoot.raiseEvent(event1);
        aggregateRoot.raiseEvent(event2);
        expect(aggregateRoot.getUncommittedEvents(), hasLength(2));

        aggregateRoot.markEventsAsCommitted();

        expect(aggregateRoot.getUncommittedEvents(), isEmpty);
      });

      test('can raise new events after marking as committed', () {
        final aggregateRoot = TestAggregateRoot();
        final event1 = TestDomainEvent(
          aggregateId: aggregateRoot.id,
          data: 'first event',
        );
        final event2 = TestDomainEvent(
          aggregateId: aggregateRoot.id,
          data: 'second event',
        );

        aggregateRoot.raiseEvent(event1);
        aggregateRoot.markEventsAsCommitted();
        aggregateRoot.raiseEvent(event2);

        final uncommittedEvents = aggregateRoot.getUncommittedEvents();
        expect(uncommittedEvents, hasLength(1));
        expect(uncommittedEvents.first, equals(event2));
      });
    });
  });
}
