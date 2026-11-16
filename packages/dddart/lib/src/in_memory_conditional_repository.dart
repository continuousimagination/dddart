import 'package:dddart/src/aggregate_root.dart';
import 'package:dddart/src/conditional_aggregate_repository.dart';
import 'package:dddart/src/conditional_repository.dart';
import 'package:dddart/src/event_publisher.dart';
import 'package:dddart/src/identity.dart';
import 'package:dddart/src/repository.dart';
import 'package:dddart/src/repository_exception.dart';
import 'package:dddart/src/save_with_events.dart';
import 'package:dddart/src/uuid_value.dart';

/// Explicit shared storage for multiple in-memory repository instances.
///
/// Instance-local, single-isolate test/development storage; no durability or
/// cross-process coordination is implied.
class InMemoryConditionalStore<T extends AggregateRoot<I>, I extends Identity> {
  final Map<I, VersionedAggregate<T, I>> _records = {};
}

/// Detached reference implementation of atomic single-aggregate operations.
///
/// The `clone` callback must copy all mutable domain data (for example a serializer round
/// trip), preserve identity, and omit transient pending-event bookkeeping.
/// Checks and mutations contain no await, making them atomic within one isolate.
class InMemoryConditionalRepository<T extends AggregateRoot<I>,
        I extends Identity>
    implements Repository<T, I>, ConditionalAggregateRepository<T, I> {
  /// Uses application-defined snapshots and optional shared storage/publication.
  InMemoryConditionalRepository({
    required T Function(T) clone,
    InMemoryConditionalStore<T, I>? store,
    this.eventPublisher,
  })  : _clone = clone,
        _store = store ?? InMemoryConditionalStore<T, I>();

  final T Function(T) _clone;
  final InMemoryConditionalStore<T, I> _store;

  /// Publishes only after successful persistence, using captured pending events.
  final EventPublisher? eventPublisher;

  T _snapshot(T value) {
    final copy = _clone(value);
    if (identical(copy, value) || copy.id != value.id) {
      throw ArgumentError(
        'clone must return a detached copy with the same identity',
      );
    }
    return copy;
  }

  @override
  Future<T> getById(I id) async => (await getVersioned(id)).aggregate;

  @override
  Future<VersionedAggregate<T, I>> getVersioned(I id) async {
    final record = _store._records[id];
    if (record == null) {
      throw const RepositoryException(
        'Aggregate not found',
        type: RepositoryExceptionType.notFound,
      );
    }
    return VersionedAggregate(_snapshot(record.aggregate), record.revision);
  }

  @override
  Future<void> save(T aggregate) => saveWithEvents(
        aggregate: aggregate,
        publisher: eventPublisher,
        persist: () async {
          final snapshot = _snapshot(aggregate);
          _store._records[aggregate.id] =
              VersionedAggregate(snapshot, UuidValue.generate().uuid);
        },
      );

  void _check(I id, ExpectedRevision expected) {
    validateExpectedRevision(expected);
    if (_store._records[id]?.revision != expected.revision) {
      throw RevisionConflictException(id, expected);
    }
  }

  @override
  Future<String> saveConditional(
    T aggregate, {
    required ExpectedRevision expected,
  }) async {
    validateExpectedRevision(expected);
    late String revision;
    await saveWithEvents(
      aggregate: aggregate,
      publisher: eventPublisher,
      persist: () async {
        final snapshot = _snapshot(aggregate);
        _check(aggregate.id, expected);
        revision = UuidValue.generate().uuid;
        _store._records[aggregate.id] = VersionedAggregate(snapshot, revision);
      },
    );
    return revision;
  }

  @override
  Future<void> deleteById(I id) async {
    if (_store._records.remove(id) == null) {
      throw const RepositoryException(
        'Aggregate not found',
        type: RepositoryExceptionType.notFound,
      );
    }
  }

  @override
  Future<void> deleteConditional(
    I id, {
    required ExpectedRevision expected,
  }) async {
    _check(id, expected);
    _store._records.remove(id);
  }
}
