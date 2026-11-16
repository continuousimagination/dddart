import 'package:dddart/dddart.dart';

/// Domain data contains no persistence revision field.
class Counter extends UuidAggregateRoot {
  Counter({required this.value, super.id});
  final int value;
}

Future<void> main() async {
  final repository = InMemoryConditionalRepository<Counter, UuidValue>(
    clone: (value) => Counter(id: value.id, value: value.value),
  );
  final counter = Counter(value: 0);
  await repository.save(counter);
  final first = await repository.getVersioned(counter.id);
  final second = await repository.getVersioned(counter.id);
  await repository.saveConditional(
    Counter(id: first.aggregate.id, value: first.aggregate.value + 1),
    expected: ExpectedRevision.match(first.revision),
  );
  try {
    await repository.saveConditional(
      Counter(id: second.aggregate.id, value: second.aggregate.value + 10),
      expected: ExpectedRevision.match(second.revision),
    );
    throw StateError('A stale snapshot unexpectedly committed');
  } on RevisionConflictException<UuidValue> {
    final current = await repository.getVersioned(counter.id);
    // The application deliberately recomputes its change from current state.
    await repository.saveConditional(
      Counter(id: current.aggregate.id, value: current.aggregate.value + 10),
      expected: ExpectedRevision.match(current.revision),
    );
  }
  if ((await repository.getById(counter.id)).value != 11) {
    throw StateError('Expected both deliberate updates to be reflected');
  }
}
