/// Example of extending StoredEvent with custom authorization fields.
library;

import 'package:dddart/dddart.dart';
import 'package:dddart_events_distributed/dddart_events_distributed.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

part 'custom_stored_event.g.dart';

/// Custom stored event with additional authorization fields.
///
/// This demonstrates how to extend StoredEvent to add application-specific
/// authorization fields, including collections like userRoles.
@Serializable()
class CustomStoredEvent extends StoredEvent {
  CustomStoredEvent({
    required super.id,
    required super.createdAt,
    required super.aggregateId,
    required super.eventType,
    required super.eventJson,
    super.userId,
    super.tenantId,
    super.sessionId,
    this.userRoles,
    this.organizationId,
  });

  /// Extract authorization fields from DomainEvent.context.
  factory CustomStoredEvent.fromDomainEvent(DomainEvent event) {
    return CustomStoredEvent(
      id: event.eventId,
      createdAt: event.occurredAt,
      aggregateId: event.aggregateId,
      eventType: event.runtimeType.toString(),
      eventJson: _serializeEvent(event),
      userId: event.context['userId'] as String?,
      tenantId: event.context['tenantId'] as String?,
      sessionId: event.context['sessionId'] as String?,
      userRoles: (event.context['userRoles'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      organizationId: event.context['organizationId'] as String?,
    );
  }

  /// User roles for role-based authorization.
  final List<String>? userRoles;

  /// Organization identifier for organization-specific filtering.
  final String? organizationId;

  static String _serializeEvent(DomainEvent event) {
    // In a real implementation, this would use the event's toJson method
    // For this example, we'll use a simple JSON encoding
    return '{"eventId":"${event.eventId}","occurredAt":"${event.occurredAt.toIso8601String()}","aggregateId":"${event.aggregateId}"}';
  }

  static CustomStoredEvent fromJson(Map<String, dynamic> json) {
    return CustomStoredEvent(
      id: UuidValue.fromString(json['id'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      aggregateId: UuidValue.fromString(json['aggregateId'] as String),
      eventType: json['eventType'] as String,
      eventJson: json['eventJson'] as String,
      userId: json['userId'] as String?,
      tenantId: json['tenantId'] as String?,
      sessionId: json['sessionId'] as String?,
      userRoles: (json['userRoles'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      organizationId: json['organizationId'] as String?,
    );
  }
}
