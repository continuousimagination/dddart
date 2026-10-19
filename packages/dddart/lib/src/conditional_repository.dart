import 'package:dddart/src/aggregate_root.dart';
import 'package:dddart/src/uuid_value.dart';

/// A detached aggregate and the token required for its next conditional write.
final class VersionedAggregate<T extends AggregateRoot> {
  /// Creates a detached snapshot with its storage revision.
  const VersionedAggregate(this.aggregate, this.revision);

  /// The decoded aggregate snapshot.
  final T aggregate;

  /// The opaque revision required for a subsequent write or delete.
  final String revision;
}

/// The record state a mutation expects to find when it reaches storage.
///
/// Tokens change on every successful put. A stale token therefore cannot
/// authorize a write after a delete and recreation of the same identity.
final class ExpectedRevision {
  /// Expects that no record currently has the aggregate identity.
  const ExpectedRevision.absent() : revision = null;

  /// Expects the record to still have [revision].
  const ExpectedRevision.match(String token)
      : revision = token,
        assert(token != '', 'Revision must be nonempty');

  /// The expected token, or null for an absent record.
  final String? revision;

  /// Whether this condition expects no record.
  bool get isAbsent => revision == null;
}

/// A caller-normalized unique value in a named index.
///
/// The repository enforces equality of the supplied strings. Domain-specific
/// case folding, whitespace rules, and display names remain with the caller.
final class UniqueValue {
  /// Creates a unique value in [index] with a normalized [value].
  const UniqueValue(this.index, this.value);

  /// Namespace for the uniqueness rule.
  final String index;

  /// Caller-normalized value compared for equality in that namespace.
  final String value;
}

/// One put or delete in an atomic conditional commit.
final class ConditionalMutation<T extends AggregateRoot> {
  /// Inserts or replaces [aggregate] if [expected] still matches.
  ConditionalMutation.put(
    T aggregate, {
    required this.expected,
    this.uniqueValues = const [],
  })  : id = aggregate.id,
        aggregate = aggregate,
        isDelete = false;

  /// Deletes [id] if [expected] still matches.
  ConditionalMutation.delete(this.id, {required this.expected})
      : aggregate = null,
        uniqueValues = const [],
        isDelete = true;

  /// Identity of the affected aggregate.
  final UuidValue id;

  /// Aggregate snapshot for a put, or null for a delete.
  final T? aggregate;

  /// Required state at storage commit time.
  final ExpectedRevision expected;

  /// Complete desired unique values after a put.
  final List<UniqueValue> uniqueValues;

  /// Whether this mutation deletes the aggregate.
  final bool isDelete;
}

/// An operation identity and all records that must change together.
final class ConditionalCommit<T extends AggregateRoot> {
  /// Creates one atomic operation with a stable [operationId].
  const ConditionalCommit({required this.operationId, required this.mutations});

  /// Identity retained through retries and uncertain outcomes.
  final UuidValue operationId;

  /// All aggregate changes to check and apply together.
  final List<ConditionalMutation<T>> mutations;
}

/// Whether an operation committed, was rejected, or needs reconciliation.
enum CommitDecision {
  /// All mutations and the operation receipt committed together.
  committed,

  /// A condition failed and that rejection was committed as a receipt.
  rejected,

  /// The caller cannot establish whether the operation committed.
  uncertain,
}

/// A confirmed reason for rejecting a conditional operation.
enum CommitRejection {
  /// An aggregate was absent or had a different revision.
  staleRevision,

  /// A unique value belongs to another aggregate.
  uniqueConflict,
}

/// The durable result, or an uncertain result requiring reconciliation.
final class CommitResult {
  /// Creates an operation result.
  const CommitResult({
    required this.operationId,
    required this.payloadDigest,
    required this.decision,
    this.revisions = const {},
    this.rejection,
  });

  /// Identity of the attempted operation.
  final UuidValue operationId;

  /// Digest of the encoded payload and conditions.
  final String payloadDigest;

  /// Confirmed or uncertain outcome.
  final CommitDecision decision;

  /// New revision for each committed put.
  final Map<UuidValue, String> revisions;

  /// Reason for a confirmed rejection, if any.
  final CommitRejection? rejection;
}

/// Optional transactional capability beyond the basic CRUD Repository.
///
/// Implementations must atomically check revisions and unique values, mutate
/// every affected record, and store an operation receipt. An uncertain result
/// must be retried with the same operation ID and identical encoded payload.
abstract interface class ConditionalRepository<T extends AggregateRoot> {
  /// Reads an aggregate and the revision needed to change it.
  Future<VersionedAggregate<T>> getVersioned(UuidValue id);

  /// Reads the aggregate owning a unique value in one consistent transaction.
  Future<VersionedAggregate<T>> findUnique(UniqueValue value);

  /// Computes the identity of the encoded request before dispatch.
  String digestFor(ConditionalCommit<T> request);

  /// Checks all conditions and commits every mutation with one receipt.
  Future<CommitResult> commitConditional(ConditionalCommit<T> request);

  /// Missing receipts are uncertain, not proof that a write did not commit.
  Future<CommitResult> resolveOperation(
    UuidValue operationId,
    String payloadDigest,
  );
}
