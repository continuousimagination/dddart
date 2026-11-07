import 'package:dddart/dddart.dart';
import 'package:test/test.dart';

void main() {
  test('acknowledges only the captured raise of a reused event object', () {
    final aggregate = _Aggregate();
    final event = _Event(aggregate.id);
    aggregate.raiseEvent(event);
    final batch = aggregate.captureUncommittedEvents();
    aggregate.raiseEvent(event);

    batch.acknowledge(event);
    batch.acknowledge(event);

    expect(aggregate.getUncommittedEvents(), [same(event)]);
    expect(batch.events.clear, throwsUnsupportedError);
  });

  test('partial acknowledgment retains failures and newly raised events', () {
    final aggregate = _Aggregate();
    final accepted = _Event(aggregate.id);
    final failed = _Event(aggregate.id);
    aggregate.raiseEvent(accepted);
    aggregate.raiseEvent(failed);
    final batch = aggregate.captureUncommittedEvents();
    final later = _Event(aggregate.id);
    aggregate.raiseEvent(later);

    batch.acknowledge(accepted);

    expect(aggregate.getUncommittedEvents(), [failed, later]);
    aggregate.markEventsAsCommitted(batch: batch);
    expect(aggregate.getUncommittedEvents(), [later]);
  });

  test('same UUID does not acknowledge a different event instance', () {
    final aggregate = _Aggregate();
    final captured = _Event(aggregate.id);
    aggregate.raiseEvent(captured);
    final batch = aggregate.captureUncommittedEvents();
    final replacement = _Event(aggregate.id, eventId: captured.eventId);
    aggregate.raiseEvent(replacement);

    expect(() => batch.acknowledge(replacement), throwsArgumentError);
    batch.acknowledgeAll();
    expect(aggregate.getUncommittedEvents().single, same(replacement));
  });

  test('overlapping snapshots cannot acknowledge events outside either batch',
      () {
    final aggregate = _Aggregate();
    final first = _Event(aggregate.id);
    aggregate.raiseEvent(first);
    final firstBatch = aggregate.captureUncommittedEvents();
    final second = _Event(aggregate.id);
    aggregate.raiseEvent(second);
    final secondBatch = aggregate.captureUncommittedEvents();
    final third = _Event(aggregate.id);
    aggregate.raiseEvent(third);

    secondBatch.acknowledge(first);
    firstBatch.acknowledgeAll();
    expect(aggregate.getUncommittedEvents(), [second, third]);
    secondBatch.acknowledgeAll();
    expect(aggregate.getUncommittedEvents(), [third]);
  });

  test('rejects committing another aggregate snapshot', () {
    final first = _Aggregate();
    final second = _Aggregate();
    first.raiseEvent(_Event(first.id));
    final batch = first.captureUncommittedEvents();

    expect(
      () => second.markEventsAsCommitted(batch: batch),
      throwsArgumentError,
    );
    expect(first.getUncommittedEvents(), hasLength(1));
  });
}

class _Aggregate extends UuidAggregateRoot {}

class _Event extends DomainEvent<UuidValue> {
  _Event(UuidValue id, {super.eventId}) : super(aggregateId: id);
}
