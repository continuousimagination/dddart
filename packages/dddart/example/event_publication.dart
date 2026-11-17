import 'dart:async';

import 'package:dddart/dddart.dart';

/// Finite local demonstration of accepted/rejected publication and capture races.
Future<void> main() async {
  final publisher = DemoPublisher();
  final repository = InMemoryRepository<Counter, UuidValue>(
    eventPublisher: publisher,
  );
  final counter = Counter();
  final first = counter.increment();
  final saving = repository.save(counter);
  await publisher.started.future;
  final later = counter.increment();
  publisher.release.complete();
  await saving;
  if (counter.getUncommittedEvents().length != 1 ||
      !identical(counter.getUncommittedEvents().single, later) ||
      !identical(publisher.seen.single, first)) {
    throw StateError(
        'A save must acknowledge only its accepted captured batch');
  }
  publisher.accept = false;
  await repository.save(counter);
  if (!identical(counter.getUncommittedEvents().single, later)) {
    throw StateError('Rejected publication must remain pending');
  }
  publisher.accept = true;
  await repository.save(counter);
  if (counter.getUncommittedEvents().isNotEmpty) {
    throw StateError('Accepted retry must acknowledge its pending occurrence');
  }
  print(
      'Captured events acknowledged; later/rejected events retained for retry.');
}

class Counter extends AggregateRoot<UuidValue> {
  Counter() : super(id: UuidValue.generate());
  int value = 0;

  CounterChanged increment() {
    final event = CounterChanged(aggregateId: id, value: ++value);
    raiseEvent(event);
    return event;
  }
}

class CounterChanged extends DomainEvent<UuidValue> {
  CounterChanged({required super.aggregateId, required this.value});
  final int value;
}

/// Local test publisher: acceptance is explicit, without a cloud service.
class DemoPublisher implements EventPublisher {
  final started = Completer<void>();
  final release = Completer<void>();
  final seen = <DomainEvent<Identity>>[];
  bool accept = true;

  @override
  Future<bool> publish(DomainEvent<Identity> event) async {
    seen.add(event);
    if (!started.isCompleted) started.complete();
    await release.future;
    return accept;
  }
}
