import 'package:dddart/src/uuid_value.dart';
import 'package:uuid/uuid.dart' hide UuidValue;

/// Base class for all domain entities in the DDD framework.
///
/// Entities have identity and lifecycle timestamps. They are equal based on their ID,
/// not their properties. Each entity has a unique identifier and tracks when it was
/// created and last updated.
abstract class Entity {
  /// Creates a new Entity with optional parameters.
  ///
  /// If [id] is not provided, a new UUID will be generated.
  /// If [createdAt] is not provided, the current time will be used.
  /// If [updatedAt] is not provided, the current time will be used.
  Entity({
    UuidValue? id,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? UuidValue.fromString(const Uuid().v4()),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Unique identifier for this entity
  final UuidValue id;

  /// Timestamp when this entity was created
  final DateTime createdAt;

  /// Timestamp when this entity was last updated
  DateTime updatedAt;

  /// Updates the updatedAt timestamp to the current time.
  ///
  /// This method should be called whenever the entity is modified
  /// to maintain accurate tracking of when changes occurred.
  void touch() {
    updatedAt = DateTime.now();
  }

  /// Entities are equal if they have the same ID and are of the same type.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Entity && runtimeType == other.runtimeType && id == other.id;

  /// Hash code is based on the entity's ID.
  @override
  int get hashCode => id.hashCode;

  /// String representation of the entity showing its type and ID.
  @override
  String toString() => '$runtimeType(id: $id)';
}
