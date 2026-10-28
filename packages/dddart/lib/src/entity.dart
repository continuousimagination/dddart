import 'package:dddart/src/identity.dart';
import 'package:dddart/src/uuid_value.dart';

/// Base class for all domain entities in the DDD framework.
///
/// Entities have identity and lifecycle timestamps. They are equal based on their ID,
/// not their properties. Each entity has a unique identifier and tracks when it was
/// created and last updated.
abstract class Entity<I extends Identity> {
  /// Creates an entity with an explicitly supplied identity.
  ///
  /// Use [UuidEntity] for automatic UUID generation.
  /// If [createdAt] is not provided, the current time will be used.
  /// If [updatedAt] is not provided, the current time will be used.
  Entity({
    required this.id,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Unique identifier for this entity
  final I id;

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
      other is Entity<Identity> &&
          runtimeType == other.runtimeType &&
          id == other.id;

  /// Hash code is based on the entity's ID.
  @override
  int get hashCode => id.hashCode;

  /// String representation of the entity showing its type and ID.
  @override
  String toString() => '$runtimeType(id: $id)';
}

/// An entity whose identity is a supplied or automatically generated UUID.
abstract class UuidEntity extends Entity<UuidValue> {
  /// Creates a UUID entity, generating [id] when omitted.
  UuidEntity({UuidValue? id, super.createdAt, super.updatedAt})
      : super(id: id ?? UuidValue.generate());
}
