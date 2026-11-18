import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_events_distributed/src/event_registry.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

/// Event record with independently typed aggregate and occurrence identities.
///
/// Mixed stores use StoredEvent<Identity, Identity>. JSON explicitly tags both
/// identity kinds; old records with bare UUID event IDs require migration.
class StoredEvent<A extends Identity, E extends Identity>
    extends AggregateRoot<E> {
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
    DomainEvent<A, E> event, {
    required EventRegistry registry,
  }) =>
      StoredEvent<A, E>(
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
    if (identity is! A) {
      throw const DeserializationException(
        'Stored aggregate identity kind mismatch',
      );
    }
    final eventId = codecs.fromTaggedJson(json['id']);
    if (eventId is! E) {
      throw const DeserializationException(
        'Stored event identity kind mismatch',
      );
    }
    return StoredEvent<A, E>(
      id: eventId,
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

  /// Concrete aggregate reference; it is independent of this record's event ID.
  final A aggregateId;

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
  DomainEvent<Identity, Identity> restore(EventRegistry registry) {
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

  /// Serializes the envelope with explicit aggregate and event identity tags.
  Map<String, dynamic> toJson({IdentityCodecRegistry? identityCodecs}) {
    final codecs = identityCodecs ?? _identityCodecs;
    return {
      'id': codecs.toTaggedJson(id),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'aggregateId': codecs.toTaggedJson(aggregateId),
      'eventType': eventType,
      'eventJson': eventJson,
      if (userId != null) 'userId': userId,
      if (tenantId != null) 'tenantId': tenantId,
      if (sessionId != null) 'sessionId': sessionId,
    };
  }
}
