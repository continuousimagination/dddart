import 'package:dddart/src/uuid_value.dart';

/// Base class for domain events in the DDD framework.
///
/// A domain event represents something significant that happened in the domain.
/// Events are immutable and contain metadata for traceability and filtering.
abstract class DomainEvent {
  /// Creates a new domain event.
  ///
  /// [aggregateId] is required and identifies the aggregate that raised the event.
  /// [eventId] is optional and will be auto-generated if not provided.
  /// [occurredAt] is optional and will default to the current time if not provided.
  /// [context] is optional and defaults to an empty map.
  DomainEvent({
    required this.aggregateId,
    UuidValue? eventId,
    DateTime? occurredAt,
    this.context = const {},
  })  : eventId = eventId ?? UuidValue.generate(),
        occurredAt = occurredAt ?? DateTime.now();

  /// Unique identifier for this event instance.
  final UuidValue eventId;

  /// Timestamp when the event occurred.
  final DateTime occurredAt;

  /// Identifier of the aggregate that raised this event.
  final UuidValue aggregateId;

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
    return other is DomainEvent && other.eventId == eventId;
  }

  @override
  int get hashCode => eventId.hashCode;
}
