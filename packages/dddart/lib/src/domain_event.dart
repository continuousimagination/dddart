import 'package:dddart/src/identity.dart';

/// Base class for domain events in the DDD framework.
///
/// A domain event represents something significant that happened in the domain.
/// Events are immutable and contain metadata for traceability and filtering.
/// [A] identifies the aggregate; [E] independently identifies the occurrence.
/// Event identities must include any source scope needed to avoid collisions.
abstract class DomainEvent<A extends Identity, E extends Identity> {
  /// Creates a new domain event.
  ///
  /// [aggregateId] is required and identifies the aggregate that raised the event.
  /// [eventId] is required. The caller owns generation or preserves an external
  /// identity, and must reuse it when restoring or retrying the same occurrence.
  /// [occurredAt] is optional and will default to the current time if not provided.
  /// [context] is optional and defaults to an empty map.
  DomainEvent({
    required this.aggregateId,
    required this.eventId,
    DateTime? occurredAt,
    this.context = const {},
  }) : occurredAt = occurredAt ?? DateTime.now();

  /// Unique identifier for this event instance.
  final E eventId;

  /// Timestamp when the event occurred.
  final DateTime occurredAt;

  /// Identifier of the aggregate that raised this event.
  final A aggregateId;

  /// Additional context data for filtering and metadata.
  /// This map can contain arbitrary key-value pairs that provide
  /// additional information about the event context.
  final Map<String, dynamic> context;

  @override
  String toString() {
    return '$runtimeType(eventId: $eventId, aggregateId: $aggregateId, occurredAt: $occurredAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DomainEvent<Identity, Identity> && other.eventId == eventId;
  }

  @override
  int get hashCode => eventId.hashCode;
}
