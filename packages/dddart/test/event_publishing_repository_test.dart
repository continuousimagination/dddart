import 'dart:async';

import 'package:dddart/dddart.dart';
import 'package:logging/logging.dart' show LogRecord;
import 'package:test/test.dart';

void main() {
  test('in-memory repository supports the same optional publisher hook',
      () async {
    final aggregate = _Aggregate();
    final event = _Event(aggregate.id);
    aggregate.raiseEvent(event);
    final calls = <DomainEvent<Identity>>[];
    final repository = InMemoryRepository<_Aggregate, UuidValue>(
      eventPublisher: _Publisher((event) async {
        calls.add(event);
        return true;
      }),
    );
    await repository.save(aggregate);
    expect(calls, [event]);
    expect(aggregate.getUncommittedEvents(), isEmpty);
    expect(await repository.getById(aggregate.id), same(aggregate));
  });

  test('captures before persistence and awaits publication before returning',
      () async {
    final aggregate = _Aggregate();
    final first = _Event(aggregate.id);
    aggregate.raiseEvent(first);
    final persisted = Completer<void>();
    final accepted = Completer<bool>();
    final calls = <DomainEvent<Identity>>[];
    final publisher = _Publisher((event) {
      calls.add(event);
      return accepted.future;
    });
    var complete = false;
    final save = saveWithEvents(
      aggregate: aggregate,
      persist: () => persisted.future,
      publisher: publisher,
    ).then((_) => complete = true);
    final later = _Event(aggregate.id);
    aggregate.raiseEvent(later);

    expect(calls, isEmpty);
    persisted.complete();
    await Future<void>.delayed(Duration.zero);
    expect(calls, [first]);
    expect(complete, isFalse);
    accepted.complete(true);
    await save;
    expect(aggregate.getUncommittedEvents(), [later]);
  });

  test('failed persistence propagates without publication or acknowledgment',
      () async {
    final aggregate = _Aggregate();
    final event = _Event(aggregate.id);
    aggregate.raiseEvent(event);
    var publications = 0;

    await expectLater(
      saveWithEvents(
        aggregate: aggregate,
        persist: () async => throw StateError('storage unavailable'),
        publisher: _Publisher((_) async {
          publications++;
          return true;
        }),
      ),
      throwsStateError,
    );

    expect(publications, 0);
    expect(aggregate.getUncommittedEvents(), [event]);
  });

  test('rejected publication leaves the saved aggregate and event available',
      () async {
    final aggregate = _Aggregate();
    final event = _Event(aggregate.id);
    aggregate.raiseEvent(event);
    final storage = InMemoryRepository<_Aggregate, UuidValue>();
    final repository = EventPublishingRepository<_Aggregate, UuidValue>(
      repository: storage,
      publisher: _Publisher((_) async => false),
    );

    await repository.save(aggregate);

    expect(await repository.getById(aggregate.id), same(aggregate));
    expect(aggregate.getUncommittedEvents(), [event]);
    await repository.deleteById(aggregate.id);
    await expectLater(
      storage.getById(aggregate.id),
      throwsA(isA<RepositoryException>()),
    );
  });

  test('logs unexpected failure, continues, and retries only pending events',
      () async {
    final aggregate = _Aggregate();
    final first = _Event(aggregate.id);
    final second = _Event(aggregate.id);
    aggregate.raiseEvent(first);
    aggregate.raiseEvent(second);
    final records = <LogRecord>[];
    final previousLevel = Logger.root.level;
    Logger.root.level = Level.ALL;
    final subscription = Logger.root.onRecord.listen(records.add);
    addTearDown(() async {
      await subscription.cancel();
      Logger.root.level = previousLevel;
    });
    final calls = <DomainEvent<Identity>>[];
    var fail = true;
    final repository = EventPublishingRepository<_Aggregate, UuidValue>(
      repository: InMemoryRepository<_Aggregate, UuidValue>(),
      publisher: _Publisher((event) async {
        calls.add(event);
        if (identical(event, first) && fail) throw StateError('failure');
        return true;
      }),
    );

    await repository.save(aggregate);
    expect(calls, [first, second]);
    expect(aggregate.getUncommittedEvents(), [first]);
    expect(
      records.any(
        (record) =>
            record.level == Level.SEVERE &&
            record.message.contains(first.eventId.uuid),
      ),
      isTrue,
    );

    fail = false;
    await repository.save(aggregate);
    expect(calls, [first, second, first]);
    expect(aggregate.getUncommittedEvents(), isEmpty);
  });

  test('ordinary saves retain manual events when publication is not configured',
      () async {
    final aggregate = _Aggregate();
    aggregate.raiseEvent(_Event(aggregate.id));
    var saves = 0;
    await saveWithEvents(
      aggregate: aggregate,
      persist: () async => saves++,
    );
    expect(saves, 1);
    expect(aggregate.getUncommittedEvents(), hasLength(1));
  });
}

class _Aggregate extends UuidAggregateRoot {}

class _Event extends DomainEvent<UuidValue> {
  _Event(UuidValue id) : super(aggregateId: id);
}

class _Publisher implements EventPublisher {
  _Publisher(this.callback);

  final Future<bool> Function(DomainEvent<Identity>) callback;

  @override
  Future<bool> publish(DomainEvent<Identity> event) => callback(event);
}
