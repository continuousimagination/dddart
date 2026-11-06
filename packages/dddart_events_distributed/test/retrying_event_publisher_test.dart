import 'dart:async';

import 'package:dddart/dddart.dart';
import 'package:dddart_events_distributed/dddart_events_distributed.dart';
import 'package:logging/logging.dart' show LogRecord;
import 'package:test/test.dart';

void main() {
  late List<LogRecord> records;
  late StreamSubscription<LogRecord> logs;
  late Level oldLevel;

  setUp(() {
    records = [];
    oldLevel = Logger.root.level;
    Logger.root.level = Level.ALL;
    logs = Logger.root.onRecord.listen(records.add);
  });
  tearDown(() async {
    await logs.cancel();
    Logger.root.level = oldLevel;
  });

  test(
      'transient attempts preserve the exact occurrence and use shared backoff',
      () async {
    final event = _Event(UuidValue.generate());
    final attempts = <DomainEvent<Identity>>[];
    final delays = <Duration>[];
    final publisher = RetryingEventPublisher(
      policy: EventRetryPolicy(jitter: 0),
      delay: (delay) async => delays.add(delay),
      send: (event) async {
        attempts.add(event);
        if (attempts.length < 3) {
          throw const EventPublicationException('busy', retryable: true);
        }
      },
    );

    expect(await publisher.publish(event), isTrue);
    expect(attempts, everyElement(same(event)));
    expect(
      delays,
      [const Duration(milliseconds: 100), const Duration(milliseconds: 200)],
    );
    expect(
      records.where((record) => record.level == Level.WARNING),
      hasLength(2),
    );
    expect(records.where((record) => record.level == Level.SEVERE), isEmpty);
  });

  test('permanent rejections are not retried and log the occurrence ID',
      () async {
    var attempts = 0;
    final event = _Event(UuidValue.generate());
    final publisher = RetryingEventPublisher(
      send: (_) async {
        attempts++;
        throw const EventPublicationException('not authorized');
      },
    );
    expect(await publisher.publish(event), isFalse);
    expect(attempts, 1);
    final error = records.singleWhere((record) => record.level == Level.SEVERE);
    expect(error.message, contains(event.eventId.uuid));
    expect(error.message, contains('attempts=1'));
  });

  test('exhausted publication retains events without failing a saved aggregate',
      () async {
    var attempts = 0;
    final publisher = RetryingEventPublisher(
      policy: EventRetryPolicy(initialDelay: Duration.zero, jitter: 0),
      send: (_) async {
        attempts++;
        throw const EventPublicationException('unavailable', retryable: true);
      },
    );
    final aggregate = _Aggregate();
    final event = _Event(aggregate.id);
    aggregate.raiseEvent(event);
    final repository = InMemoryRepository<_Aggregate, UuidValue>(
      eventPublisher: publisher,
    );

    await repository.save(aggregate);

    expect(attempts, 3);
    expect(await repository.getById(aggregate.id), same(aggregate));
    expect(aggregate.getUncommittedEvents(), [event]);
    expect(
      records.where((record) => record.level == Level.SEVERE),
      hasLength(1),
    );
  });

  test('non-settling sends are bounded by the total publication budget',
      () async {
    var attempts = 0;
    final publisher = RetryingEventPublisher(
      policy: EventRetryPolicy(
        maxAttempts: 10000,
        initialDelay: Duration.zero,
        attemptTimeout: const Duration(milliseconds: 10),
        maxElapsed: const Duration(milliseconds: 25),
        jitter: 0,
      ),
      send: (_) {
        attempts++;
        return Completer<void>().future;
      },
    );

    expect(await publisher.publish(_Event(UuidValue.generate())), isFalse);
    expect(attempts, inInclusiveRange(1, 3));
    expect(
      records.where((record) => record.level == Level.SEVERE),
      hasLength(1),
    );
  });

  test('a failed backoff scheduler is logged and does not escape publish',
      () async {
    final publisher = RetryingEventPublisher(
      delay: (_) async => throw StateError('scheduler closed'),
      send: (_) async => throw const EventPublicationException(
        'transient',
        retryable: true,
      ),
    );
    expect(await publisher.publish(_Event(UuidValue.generate())), isFalse);
    expect(
      records.where((record) => record.level == Level.SEVERE),
      hasLength(1),
    );
  });

  test('programming/serialization failures are not blindly retried', () async {
    var attempts = 0;
    final publisher = RetryingEventPublisher(
      send: (_) async {
        attempts++;
        throw ArgumentError('invalid event');
      },
    );
    expect(await publisher.publish(_Event(UuidValue.generate())), isFalse);
    expect(attempts, 1);
  });

  test('invalid retry policies fail at configuration time', () {
    expect(() => EventRetryPolicy(maxAttempts: 0), throwsArgumentError);
    expect(
      () => EventRetryPolicy(attemptTimeout: Duration.zero),
      throwsArgumentError,
    );
    expect(() => EventRetryPolicy(jitter: double.nan), throwsArgumentError);
  });
}

class _Aggregate extends UuidAggregateRoot {}

class _Event extends DomainEvent<UuidValue> {
  _Event(UuidValue id) : super(aggregateId: id);
}
