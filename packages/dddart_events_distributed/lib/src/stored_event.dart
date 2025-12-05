import 'dart:convert';

import 'package:dddart/dddart.dart';

/// Stored event with common authorization fields.
///
/// This class provides standard authorization fields (userId, tenantId,
/// sessionId) that cover most use cases. Developers can extend this class
/// to add additional application-specific authorization fields if needed.
class StoredEvent extends AggregateRoot {
  /// Creates a StoredEvent.
  StoredEvent({
    required super.id,
    required super.createdAt,
    required this.aggregateId,
    required this.eventType,
    required this.eventJson,
    DateTime? updatedAt,
    this.userId,
    this.tenantId,
    this.sessionId,
  }) : super(updatedAt: updatedAt ?? createdAt);

  /// Creates StoredEvent from DomainEvent
  factory StoredEvent.fromDomainEvent(DomainEvent event) {
    return StoredEvent(
      id: event.eventId,
      createdAt: event.occurredAt,
      aggregateId: event.aggregateId,
      eventType: event.runtimeType.toString(),
      eventJson: jsonEncode(_eventToJson(event)),
      userId: event.context['userId'] as String?,
      tenantId: event.context['tenantId'] as String?,
      sessionId: event.context['sessionId'] as String?,
    );
  }

  /// Creates a StoredEvent from a JSON map.
  factory StoredEvent.fromJson(Map<String, dynamic> json) {
    return StoredEvent(
      id: UuidValue.fromString(json['id'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      aggregateId: UuidValue.fromString(json['aggregateId'] as String),
      eventType: json['eventType'] as String,
      eventJson: json['eventJson'] as String,
      userId: json['userId'] as String?,
      tenantId: json['tenantId'] as String?,
      sessionId: json['sessionId'] as String?,
    );
  } // Events never update

  /// Aggregate that raised this event
  final UuidValue aggregateId;

  /// Event type name for deserialization (e.g., "UserCreatedEvent")
  final String eventType;

  /// Serialized event data as JSON string
  final String eventJson;

  /// User identifier for user-specific event filtering
  final String? userId;

  /// Tenant identifier for multi-tenant event filtering
  final String? tenantId;

  /// Session identifier for session-specific event filtering
  final String? sessionId;

  /// Helper to convert DomainEvent to JSON map
  static Map<String, dynamic> _eventToJson(DomainEvent event) {
    // Base event fields
    final json = <String, dynamic>{
      'eventId': event.eventId.toString(),
      'occurredAt': event.occurredAt.toIso8601String(),
      'aggregateId': event.aggregateId.toString(),
      'context': event.context,
    };

    // If the event has a toJson method, call it
    // This will be available for events annotated with @Serializable
    try {
      // Use dynamic approach to call toJson if available
      final dynamic dynamicEvent = event;
      // ignore: avoid_dynamic_calls
      if (dynamicEvent.toJson != null) {
        // ignore: avoid_dynamic_calls
        final eventJson = dynamicEvent.toJson() as Map<String, dynamic>;
        json.addAll(eventJson);
      }
    } catch (_) {
      // If toJson is not available, just use base fields
    }

    return json;
  }

  /// Converts this StoredEvent to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id.toString(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'aggregateId': aggregateId.toString(),
      'eventType': eventType,
      'eventJson': eventJson,
      if (userId != null) 'userId': userId,
      if (tenantId != null) 'tenantId': tenantId,
      if (sessionId != null) 'sessionId': sessionId,
    };
  }
}
