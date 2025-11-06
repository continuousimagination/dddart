import 'package:uuid/uuid.dart' hide UuidValue;
import 'entity.dart';
import 'uuid_value.dart';

/// Base class for aggregate roots in the DDD framework.
/// 
/// An aggregate root is the entry point to an aggregate and extends Entity
/// to provide identity and lifecycle management. It serves as the boundary
/// for consistency and transaction management within the aggregate.
abstract class AggregateRoot extends Entity {
  /// Creates a new AggregateRoot with optional parameters.
  /// 
  /// If [id] is not provided, a new UUID will be generated.
  /// If [createdAt] is not provided, the current time will be used.
  /// If [updatedAt] is not provided, the current time will be used.
  AggregateRoot({
    UuidValue? id,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : super(id: id, createdAt: createdAt, updatedAt: updatedAt);
}