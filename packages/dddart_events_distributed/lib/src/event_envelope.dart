import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_events_distributed/src/aggregate_reference.dart';
import 'package:dddart_events_distributed/src/stored_event.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

/// A separately published event with its explicit logical aggregate reference.
///
/// This is an event repository record and publication contract. It must never be
/// appended to an aggregate's public REST JSON or serialized pending-event list.
class EventEnvelope extends UuidAggregateRoot {
  /// Associates one event occurrence with its logical aggregate stream.
  EventEnvelope({required this.aggregate, required this.event})
      : super(
          id: event.id,
          createdAt: event.createdAt,
          updatedAt: event.updatedAt,
        ) {
    if (aggregate.id != event.aggregateId) {
      throw ArgumentError('Event identity does not match aggregate reference');
    }
  }

  /// Restores the versioned publication contract through explicit codecs.
  factory EventEnvelope.fromJson(
    Map<String, dynamic> json, {
    required IdentityCodecRegistry identityCodecs,
  }) {
    if (json['version'] != 1) {
      throw const DeserializationException(
        'Unsupported event envelope version',
      );
    }
    return EventEnvelope(
      aggregate: AggregateReference<Identity>.fromJson(
        Map<String, dynamic>.from(json['aggregate'] as Map),
        identityCodecs: identityCodecs,
      ),
      event: StoredEvent<Identity>.fromJson(
        Map<String, dynamic>.from(json['event'] as Map),
        identityCodecs: identityCodecs,
      ),
    );
  }

  /// Stable kind and typed identity of the aggregate being watched.
  final AggregateReference<Identity> aggregate;

  /// Existing registered event body and occurrence/authorization metadata.
  final StoredEvent<Identity> event;

  /// Canonical occurrence content for idempotent acceptance across transports.
  /// JSON object order is irrelevant; application string values are preserved.
  String canonicalJson(IdentityCodecRegistry identities) {
    final json = toJson(identities);
    final stored = json['event'] as Map<String, dynamic>;
    try {
      stored['eventJson'] =
          jsonEncode(_canonical(jsonDecode(stored['eventJson'] as String)));
    } on FormatException {
      /* Preserve malformed bodies for client log/skip recovery. */
    }
    return jsonEncode(_canonical(json));
  }

  /// Encodes only the explicit event-publication contract.
  Map<String, dynamic> toJson(IdentityCodecRegistry identityCodecs) => {
        'version': 1,
        'aggregate': aggregate.toJson(identityCodecs),
        'event': event.toJson(),
      };
}

Object? _canonical(Object? value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return {for (final key in keys) key: _canonical(value[key])};
  }
  if (value is List) return value.map(_canonical).toList();
  return value;
}
