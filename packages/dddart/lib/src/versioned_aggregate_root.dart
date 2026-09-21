import 'package:dddart/src/aggregate_root.dart';
import 'package:dddart/src/revision.dart';

/// Aggregate whose persistence requires an explicit atomic write precondition.
///
/// [revision] is the single concurrency authority. Domain copies must retain
/// their observed revision until a conditional repository accepts a new one.
abstract class VersionedAggregateRoot extends AggregateRoot {
  /// Creates an aggregate, initially unpersisted unless [revision] is supplied.
  VersionedAggregateRoot({
    super.id,
    super.createdAt,
    super.updatedAt,
    this.revision = const Revision.zero(),
  });

  /// Immutable revision supplied by the last accepted persistence operation.
  final Revision revision;
}
