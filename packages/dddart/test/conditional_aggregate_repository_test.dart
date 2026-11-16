import 'package:dddart/dddart.dart';
import 'package:test/test.dart';

import 'support/conditional_aggregate_contract.dart';

class Sample<I extends Identity> extends AggregateRoot<I> {
  Sample({required super.id, required this.value, List<int>? numbers})
      : numbers = numbers ?? [];
  int value;
  final List<int> numbers;
  Sample<I> clone() => Sample(id: id, value: value, numbers: [...numbers]);
}

class NativeId extends Identity {
  const NativeId(this.scope, this.value);
  final String scope;
  final String value;
  @override
  List<Object?> get props => [scope, value];
}

class _Changed<I extends Identity> extends DomainEvent<I> {
  _Changed(I id) : super(aggregateId: id);
}

class _Publisher implements EventPublisher {
  final events = <DomainEvent<Identity>>[];
  @override
  Future<bool> publish(DomainEvent<Identity> event) async {
    events.add(event);
    return true;
  }
}

void main() {
  conditionalAggregateContract<Sample<UuidValue>, UuidValue>(
    open: () async {
      final store = InMemoryConditionalStore<Sample<UuidValue>, UuidValue>();
      InMemoryConditionalRepository<Sample<UuidValue>, UuidValue> repo() =>
          InMemoryConditionalRepository(
            clone: (value) => value.clone(),
            store: store,
          );
      return (repo(), repo(), () async {});
    },
    create: (value, id) => Sample(id: id ?? UuidValue.generate(), value: value),
    value: (value) => value.value,
  );

  test('native/scoped snapshots are detached on save and on read', () async {
    final repo = InMemoryConditionalRepository<Sample<NativeId>, NativeId>(
      clone: (value) => value.clone(),
    );
    const id = NativeId('CaseSensitive', 'external/node');
    final source = Sample(id: id, value: 1, numbers: [1]);
    await repo.save(source);
    source.value = 9;
    source.numbers.add(9);
    final a = await repo.getVersioned(id);
    final b = await repo.getVersioned(id);
    a.aggregate.numbers.add(8);
    expect(b.aggregate.numbers, [1]);
    expect(b.aggregate.value, 1);
    expect((await repo.getById(id)).numbers, [1]);
    await expectLater(
      repo.getById(const NativeId('casesensitive', 'external/node')),
      throwsA(isA<RepositoryException>()),
    );
  });

  test('conflicts and encoding failures preserve events and committed state',
      () async {
    final publisher = _Publisher();
    var failClone = false;
    final repo = InMemoryConditionalRepository<Sample<UuidValue>, UuidValue>(
      clone: (value) {
        if (failClone) {
          throw const RepositoryException(
            'serialization failure',
            type: RepositoryExceptionType.constraint,
          );
        }
        return value.clone();
      },
      eventPublisher: publisher,
    );
    final sample = Sample(id: UuidValue.generate(), value: 1);
    await repo.save(sample);
    final snapshot = await repo.getVersioned(sample.id);
    final event = _Changed(sample.id);
    sample.raiseEvent(event);
    await expectLater(
      repo.saveConditional(sample, expected: const ExpectedRevision.absent()),
      throwsA(isA<RevisionConflictException<UuidValue>>()),
    );
    failClone = true;
    await expectLater(
      repo.saveConditional(
        sample,
        expected: ExpectedRevision.match(snapshot.revision),
      ),
      throwsA(
        isA<RepositoryException>().having(
          (e) => e.type,
          'type',
          RepositoryExceptionType.constraint,
        ),
      ),
    );
    expect(publisher.events, isEmpty);
    expect(sample.getUncommittedEvents(), [event]);
    failClone = false;
    expect((await repo.getVersioned(sample.id)).revision, snapshot.revision);
    await repo.saveConditional(
      sample,
      expected: ExpectedRevision.match(snapshot.revision),
    );
    expect(publisher.events, [event]);
    expect(sample.getUncommittedEvents(), isEmpty);
  });

  test('unsupported capabilities fail closed', () {
    expect(
      () => requireConditionalAggregateRepository(
        InMemoryRepository<Sample<UuidValue>, UuidValue>(),
      ),
      throwsA(isA<ConditionalCapabilityUnsupportedException>()),
    );
  });

  test('uncertain persistence does not retry or acknowledge/publish events',
      () async {
    final sample = Sample(id: UuidValue.generate(), value: 1);
    final event = _Changed(sample.id);
    sample.raiseEvent(event);
    final publisher = _Publisher();
    var attempts = 0;
    var stored = false;
    await expectLater(
      saveWithEvents(
        aggregate: sample,
        publisher: publisher,
        persist: () async {
          attempts++;
          stored =
              true; // Simulate a successful write followed by a lost acknowledgment.
          throw const ConditionalWriteUncertainException();
        },
      ),
      throwsA(isA<ConditionalWriteUncertainException>()),
    );
    expect(attempts, 1);
    expect(stored, isTrue);
    expect(publisher.events, isEmpty);
    expect(sample.getUncommittedEvents(), [event]);
  });
}
