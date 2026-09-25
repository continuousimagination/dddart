import 'package:dddart/src/uuid_value.dart';
import 'package:dddart/src/versioned_aggregate_root.dart';
import 'package:dddart/src/write_precondition.dart';

/// Repository with atomic expectations and accepted aggregate return values.
///
/// This deliberately does not implement the unconditional Repository contract.
abstract interface class ConditionalRepository<
    T extends VersionedAggregateRoot> {
  /// Reads an independent persisted snapshot, or reports not found.
  Future<T> getById(UuidValue id);

  /// Atomically persists [proposed] if [precondition] holds, returning the
  /// independent accepted snapshot with its advanced revision.
  Future<T> save(T proposed, {required WritePrecondition precondition});

  /// Atomically retires the key at a positive expected revision. Retirement
  /// retains a fence and prevents recreation with an absent expectation.
  Future<void> deleteById(
    UuidValue id, {
    required WritePrecondition precondition,
  });
}
