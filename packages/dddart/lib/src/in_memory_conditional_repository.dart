import 'package:dddart/src/conditional_repository.dart';
import 'package:dddart/src/conditional_repository_exception.dart';
import 'package:dddart/src/repository_exception.dart';
import 'package:dddart/src/revision.dart';
import 'package:dddart/src/uuid_value.dart';
import 'package:dddart/src/versioned_aggregate_root.dart';
import 'package:dddart/src/write_precondition.dart';

/// Isolate-local atomic conditional storage for tests and prototypes.
///
/// The trusted `copyWithRevision` callback must be synchronous, pure, and return
/// a fresh deep copy without mutating its input or re-entering this repository.
/// It preserves identity/timestamps/content and changes only the revision.
/// Nested mutable isolation relies on that deep-copy contract; generic core
/// code cannot discover arbitrary object graphs without a serialization layer.
/// All callbacks and validation run before the atomic compare/replace section.
/// Retired keys remain fenced for this instance's lifetime.
class InMemoryConditionalRepository<T extends VersionedAggregateRoot>
    implements ConditionalRepository<T> {
  /// Creates storage with a trusted domain-specific deep copier.
  InMemoryConditionalRepository({
    required T Function(T, Revision) copyWithRevision,
  }) : _copy = copyWithRevision;

  final T Function(T, Revision) _copy;
  final Map<String, _Entry<T>> _entries = {};

  @override
  Future<T> getById(UuidValue id) async {
    final entry = _entries[id.uuid];
    if (entry == null || entry.value == null) {
      throw const RepositoryException(
        'Aggregate not found.',
        type: RepositoryExceptionType.notFound,
      );
    }
    return _validatedCopy(entry.value!, entry.revision);
  }

  @override
  Future<T> save(T proposed, {required WritePrecondition precondition}) async {
    final expected = switch (precondition) {
      AbsentWritePrecondition() => const Revision.zero(),
      RevisionWritePrecondition(:final revision) => revision,
    };
    if (proposed.revision != expected) {
      throw ArgumentError('Proposal revision must match its precondition.');
    }
    final next = expected.next();
    final key = proposed.id.uuid;
    final stored = _validatedCopy(proposed, next);
    final returned = _validatedCopy(proposed, next);
    if (identical(stored, returned)) {
      throw const RepositoryCapabilityException();
    }
    final prepared = _Entry<T>(next, stored);
    // No user callback or await is permitted between this compare and replace.
    final current = _entries[key];
    if (expected.value == 0
        ? current != null
        : current == null ||
            current.value == null ||
            current.revision.value != expected.value) {
      throw const PreconditionFailedException();
    }
    _entries[key] = prepared;
    return returned;
  }

  @override
  Future<void> deleteById(
    UuidValue id, {
    required WritePrecondition precondition,
  }) async {
    if (precondition is! RevisionWritePrecondition) {
      throw ArgumentError('Retirement requires a positive expected revision.');
    }
    final expected = precondition.revision;
    final next = expected.next();
    final key = id.uuid;
    final retired = _Entry<T>(next, null);
    final current = _entries[key];
    if (current == null ||
        current.value == null ||
        current.revision.value != expected.value) {
      throw const PreconditionFailedException();
    }
    _entries[key] = retired;
  }

  T _validatedCopy(T source, Revision revision) {
    final id = source.id;
    final createdAt = source.createdAt;
    final updatedAt = source.updatedAt;
    final copy = _copy(source, revision);
    if (identical(copy, source) ||
        copy.id != id ||
        copy.revision != revision ||
        copy.createdAt != createdAt ||
        copy.updatedAt != updatedAt) {
      throw const RepositoryCapabilityException();
    }
    return copy;
  }
}

final class _Entry<T> {
  const _Entry(this.revision, this.value);
  final Revision revision;
  final T? value;
}
