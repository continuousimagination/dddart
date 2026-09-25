import 'package:dddart/src/revision.dart';
import 'package:dddart/src/value.dart';

/// Mandatory expectation for an atomic mutation; no unconditional case exists.
sealed class WritePrecondition extends Value {
  const WritePrecondition._();

  /// Requires a key that has never been persisted or retired.
  const factory WritePrecondition.absent() = AbsentWritePrecondition;

  /// Requires a live aggregate at the supplied positive revision.
  factory WritePrecondition.atRevision(Revision revision) {
    if (revision.value == 0) {
      throw ArgumentError('A persisted positive revision is required.');
    }
    return RevisionWritePrecondition._(revision);
  }
}

/// Create-only expectation, including protection against retired-key reuse.
final class AbsentWritePrecondition extends WritePrecondition {
  /// Creates an absent expectation.
  const AbsentWritePrecondition() : super._();

  @override
  List<Object?> get props => const [];
}

/// Expected revision for update or retirement.
final class RevisionWritePrecondition extends WritePrecondition {
  const RevisionWritePrecondition._(this.revision) : super._();

  /// Positive expected persisted revision.
  final Revision revision;

  @override
  List<Object?> get props => [revision];
}
