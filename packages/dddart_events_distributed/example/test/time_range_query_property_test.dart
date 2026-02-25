/// Property test for time-range queries.
///
/// **Feature: distributed-events, Property 3: findSince returns events in time range**
/// **Validates: Requirements 11.3**
library;

import 'package:dddart/dddart.dart';
import 'package:dddart_events_distributed/dddart_events_distributed.dart';
import 'package:test/test.dart';

void main() {
  group('Property 3: findSince returns events in time range', () {
    late InMemoryEventRepository repository;

    setUp(() {
      repository = InMemoryEventRepository();
    });

    test('should return only events with createdAt >= timestamp', () async {
      // Property: For any timestamp T, calling findSince(T) should return
      // only events with createdAt >= T

      // Run multiple iterations to test the property
      for (var i = 0; i < 100; i++) {
        repository.clear();

        // Generate random events with various timestamps
        final baseTime = DateTime.now();
        final events = <StoredEvent>[];

        // Create events at different time offsets
        for (var j = 0; j < 10; j++) {
          final offset = Duration(minutes: j - 5); // -5 to +4 minutes
          final eventTime = baseTime.add(offset);

          final event = StoredEvent(
            id: UuidValue.generate(),
            createdAt: eventTime,
            aggregateId: UuidValue.generate(),
            eventType: 'TestEvent',
            eventJson: '{}',
          );

          events.add(event);
          await repository.save(event);
        }

        // Pick a random timestamp in the middle
        final queryTime = baseTime.add(const Duration(minutes: -2));

        // Query events since that timestamp
        final results = await repository.findSince(queryTime);

        // Verify all returned events have createdAt >= queryTime
        for (final event in results) {
          expect(
            event.createdAt.isAfter(queryTime) ||
                event.createdAt.isAtSameMomentAs(queryTime),
            isTrue,
            reason:
                'Event ${event.id} has createdAt ${event.createdAt} which is before query time $queryTime',
          );
        }

        // Verify no events before queryTime are included
        final expectedEvents = events
            .where(
              (e) =>
                  e.createdAt.isAfter(queryTime) ||
                  e.createdAt.isAtSameMomentAs(queryTime),
            )
            .toList();

        expect(
          results.length,
          equals(expectedEvents.length),
          reason: 'Should return exactly the events in the time range',
        );

        // Verify results are sorted by createdAt
        for (var k = 1; k < results.length; k++) {
          expect(
            results[k].createdAt.isAfter(results[k - 1].createdAt) ||
                results[k].createdAt.isAtSameMomentAs(results[k - 1].createdAt),
            isTrue,
            reason: 'Results should be sorted by createdAt',
          );
        }
      }
    });

    test('should return empty list when no events match timestamp', () async {
      // Property: For any timestamp T after all events, findSince(T)
      // should return empty list

      for (var i = 0; i < 50; i++) {
        repository.clear();

        // Create events in the past
        final baseTime = DateTime.now().subtract(const Duration(hours: 1));
        for (var j = 0; j < 5; j++) {
          final event = StoredEvent(
            id: UuidValue.generate(),
            createdAt: baseTime.add(Duration(minutes: j)),
            aggregateId: UuidValue.generate(),
            eventType: 'TestEvent',
            eventJson: '{}',
          );
          await repository.save(event);
        }

        // Query with timestamp in the future
        final futureTime = DateTime.now().add(const Duration(hours: 1));
        final results = await repository.findSince(futureTime);

        expect(
          results,
          isEmpty,
          reason: 'Should return empty list when timestamp is after all events',
        );
      }
    });

    test('should return all events when timestamp is before all events',
        () async {
      // Property: For any timestamp T before all events, findSince(T)
      // should return all events

      for (var i = 0; i < 50; i++) {
        repository.clear();

        // Create events
        final baseTime = DateTime.now();
        final events = <StoredEvent>[];
        for (var j = 0; j < 5; j++) {
          final event = StoredEvent(
            id: UuidValue.generate(),
            createdAt: baseTime.add(Duration(minutes: j)),
            aggregateId: UuidValue.generate(),
            eventType: 'TestEvent',
            eventJson: '{}',
          );
          events.add(event);
          await repository.save(event);
        }

        // Query with timestamp before all events
        final pastTime = baseTime.subtract(const Duration(hours: 1));
        final results = await repository.findSince(pastTime);

        expect(
          results.length,
          equals(events.length),
          reason:
              'Should return all events when timestamp is before all events',
        );
      }
    });

    test('should include events at exact timestamp', () async {
      // Property: For any timestamp T, events with createdAt == T
      // should be included in findSince(T)

      for (var i = 0; i < 50; i++) {
        repository.clear();

        final exactTime = DateTime.now();

        // Create event at exact timestamp
        final exactEvent = StoredEvent(
          id: UuidValue.generate(),
          createdAt: exactTime,
          aggregateId: UuidValue.generate(),
          eventType: 'ExactEvent',
          eventJson: '{}',
        );
        await repository.save(exactEvent);

        // Create events before and after
        final beforeEvent = StoredEvent(
          id: UuidValue.generate(),
          createdAt: exactTime.subtract(const Duration(seconds: 1)),
          aggregateId: UuidValue.generate(),
          eventType: 'BeforeEvent',
          eventJson: '{}',
        );
        await repository.save(beforeEvent);

        final afterEvent = StoredEvent(
          id: UuidValue.generate(),
          createdAt: exactTime.add(const Duration(seconds: 1)),
          aggregateId: UuidValue.generate(),
          eventType: 'AfterEvent',
          eventJson: '{}',
        );
        await repository.save(afterEvent);

        // Query at exact timestamp
        final results = await repository.findSince(exactTime);

        // Should include exact and after, but not before
        expect(
          results.length,
          equals(2),
          reason: 'Should include events at and after exact timestamp',
        );

        expect(
          results.any((e) => e.id == exactEvent.id),
          isTrue,
          reason: 'Should include event at exact timestamp',
        );

        expect(
          results.any((e) => e.id == afterEvent.id),
          isTrue,
          reason: 'Should include event after timestamp',
        );

        expect(
          results.any((e) => e.id == beforeEvent.id),
          isFalse,
          reason: 'Should not include event before timestamp',
        );
      }
    });
  });
}
