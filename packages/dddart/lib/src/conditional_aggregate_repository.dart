import 'package:dddart/src/aggregate_root.dart';
import 'package:dddart/src/conditional_repository.dart';
import 'package:dddart/src/identity.dart';
import 'package:dddart/src/repository.dart';
import 'package:dddart/src/repository_exception.dart';

/// A storage-owned revision and detached aggregate read shared by capabilities.
// A capability boundary, not a free-standing read callback.
// ignore: one_member_abstracts
abstract interface class VersionedRepository<T extends AggregateRoot<I>,
    I extends Identity> {
  /// Reads a coherent aggregate/revision snapshot, or throws notFound.
  Future<VersionedAggregate<T, I>> getVersioned(I id);
}

/// Optional single-aggregate compare-and-write capability for a repository.
///
/// Uses the same revision vocabulary as [ConditionalRepository], without claiming
/// its multi-record transactions, unique claims, durable receipts or resolution.
/// Revisions are opaque, scoped to the repository and identity, and change on
/// every successful save (including ordinary saves with identical content).
/// Deletion/recreation must never revive an old token. Domain timestamps are not
/// revisions. All graph records and the revision commit atomically.
///
/// A confirmed condition failure throws [RevisionConflictException]. Storage
/// failures are never conflicts. An acknowledgment lost after dispatch can throw
/// [ConditionalWriteUncertainException]; reload/reconcile at application level,
/// never blindly retry as if the first attempt were known to have failed.
abstract interface class ConditionalAggregateRepository<
    T extends AggregateRoot<I>,
    I extends Identity> implements VersionedRepository<T, I> {
  /// Atomically creates/replaces the aggregate if [expected] holds.
  ///
  /// Returns the committed revision. An absent expectation is create-if-absent;
  /// a matching expectation on a missing record is a confirmed conflict. Failed
  /// writes must publish/acknowledge no pending events. Successful publication
  /// happens after confirmed persistence, with no transactional outbox guarantee.
  Future<String> saveConditional(
    T aggregate, {
    required ExpectedRevision expected,
  });

  /// Atomically deletes if [expected] holds.
  ///
  /// Match on a missing record conflicts. Absent on a missing record succeeds as
  /// a no-op; absent on an existing record conflicts. Ordinary deleteById retains
  /// its notFound behavior. Malformed/empty tokens fail before storage dispatch.
  Future<void> deleteConditional(I id, {required ExpectedRevision expected});
}

/// A confirmed expected-revision mismatch; no mutation was committed.
class RevisionConflictException<I extends Identity>
    extends RepositoryException {
  /// Records the typed aggregate identity and rejected expectation.
  const RevisionConflictException(this.id, this.expected)
      : super(
          'The aggregate revision no longer matches',
          type: RepositoryExceptionType.conflict,
        );

  /// Identity whose state did not match.
  final I id;

  /// Condition supplied by the caller.
  final ExpectedRevision expected;
}

/// The store may have committed a write whose acknowledgment was lost.
class ConditionalWriteUncertainException extends RepositoryException {
  /// Preserves a diagnostic cause without claiming rejection or success.
  const ConditionalWriteUncertainException({super.cause})
      : super(
          'The conditional write outcome is unknown; reconcile before retrying',
          type: RepositoryExceptionType.uncertain,
        );
}

/// The configured repository does not implement atomic aggregate writes.
class ConditionalCapabilityUnsupportedException extends RepositoryException {
  /// Creates an explicit fail-closed capability error.
  const ConditionalCapabilityUnsupportedException()
      : super(
          'The repository does not support atomic conditional aggregate writes',
          type: RepositoryExceptionType.unsupported,
        );
}

/// Obtains an optional capability without silently downgrading atomic writes.
ConditionalAggregateRepository<T, I> requireConditionalAggregateRepository<
    T extends AggregateRoot<I>,
    I extends Identity>(Repository<T, I> repository) {
  if (repository is ConditionalAggregateRepository<T, I>) {
    return repository as ConditionalAggregateRepository<T, I>;
  }
  throw const ConditionalCapabilityUnsupportedException();
}

/// Rejects malformed tokens consistently before a storage operation is issued.
///
/// Nonempty opaque strings without whitespace/control characters are accepted;
/// an otherwise valid unknown token is a stale conflict, not a syntax error.
void validateExpectedRevision(ExpectedRevision expected) {
  final token = expected.revision;
  if (token != null &&
      (token.isEmpty ||
          token.length > 1024 ||
          RegExp(r'[\s\x00-\x1f\x7f]').hasMatch(token))) {
    throw ArgumentError.value(token, 'expected', 'Invalid revision token');
  }
}
