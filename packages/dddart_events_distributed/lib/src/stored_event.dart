import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_events_distributed/src/event_registry.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

/// UUID event record with a separately typed aggregate reference.
///
/// Mixed stores use StoredEvent<Identity>. JSON explicitly tags the aggregate
/// identity kind; old records with bare UUID strings require migration.
class StoredEvent<I extends Identity> extends UuidAggregateRoot {
  /// Creates a stored record with common authorization metadata.
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
    IdentityCodecRegistry? identityCodecs,
  })  : _identityCodecs = identityCodecs ?? IdentityCodecRegistry(),
        super(updatedAt: updatedAt ?? createdAt);

  /// Stores an event through its explicitly registered serializer and key.
  factory StoredEvent.fromDomainEvent(
    DomainEvent<I> event, {
    required EventRegistry registry,
  }) =>
      StoredEvent<I>(
        id: event.eventId,
        createdAt: event.occurredAt,
        aggregateId: event.aggregateId,
        eventType: registry.keyFor(event),
        eventJson: jsonEncode(registry.encode(event)),
        userId: event.context['userId'] as String?,
        tenantId: event.context['tenantId'] as String?,
        sessionId: event.context['sessionId'] as String?,
        identityCodecs: registry.identityCodecs,
      );

  /// Restores an envelope using an explicitly shared identity registry.
  factory StoredEvent.fromJson(
    Map<String, dynamic> json, {
    IdentityCodecRegistry? identityCodecs,
  }) {
    final codecs = identityCodecs ?? IdentityCodecRegistry();
    final identity = codecs.fromTaggedJson(json['aggregateId']);
    if (identity is! I) {
      throw const DeserializationException(
        'Stored aggregate identity kind mismatch',
      );
    }
    return StoredEvent<I>(
      id: UuidValue.fromString(json['id'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      aggregateId: identity,
      eventType: json['eventType'] as String,
      eventJson: json['eventJson'] as String,
      userId: json['userId'] as String?,
      tenantId: json['tenantId'] as String?,
      sessionId: json['sessionId'] as String?,
      identityCodecs: codecs,
    );
  }

  final IdentityCodecRegistry _identityCodecs;

  /// Concrete aggregate reference; it is independent of this record's UUID ID.
  final I aggregateId;

  /// Explicitly registered stable event discriminator.
  final String eventType;

  /// Registered event serializer payload.
  final String eventJson;

  /// User identifier for event authorization filtering.
  final String? userId;

  /// Tenant identifier for event authorization filtering.
  final String? tenantId;

  /// Session identifier for event authorization filtering.
  final String? sessionId;

  /// Reconstructs and verifies payload metadata against this envelope.
  DomainEvent<Identity> restore(EventRegistry registry) {
    final event = registry.decode(
      eventType,
      jsonDecode(eventJson) as Map<String, dynamic>,
    );
    if (event.eventId != id ||
        event.aggregateId != aggregateId ||
        event.occurredAt != createdAt) {
      throw const DeserializationException(
        'Event payload does not match its envelope',
      );
    }
    return event;
  }

  /// Serializes the envelope with a stable aggregate identity tag.
  Map<String, dynamic> toJson() => {
        'id': id.uuid,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'aggregateId': _identityCodecs.toTaggedJson(aggregateId),
        'eventType': eventType,
        'eventJson': eventJson,
        if (userId != null) 'userId': userId,
        if (tenantId != null) 'tenantId': tenantId,
        if (sessionId != null) 'sessionId': sessionId,
      };
}
