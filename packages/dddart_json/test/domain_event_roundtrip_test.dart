import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:test/test.dart';

part 'domain_event_roundtrip_test.g.dart';

class EventNativeId extends Identity {
  const EventNativeId(this.value);
  final String value;
  @override
  List<Object?> get props => [value];
}

class _Codec implements IdentityCodec<EventNativeId> {
  @override
  Object toJson(EventNativeId identity) => {'native': identity.value};
  @override
  EventNativeId fromJson(Object? value) {
    if (value is! Map || value['native'] is! String) {
      throw const FormatException('Expected native ID');
    }
    return EventNativeId(value['native'] as String);
  }

  @override
  String toKey(EventNativeId identity) => identity.value;
  @override
  EventNativeId fromKey(String value) => EventNativeId(value);
}

abstract class _EventBase<I extends Identity, E extends Identity>
    extends DomainEvent<I, E> {
  _EventBase({
    required super.aggregateId,
    required this.label,
    required super.eventId,
    super.occurredAt,
    super.context,
  });
  final String label;
}

@Serializable()
class NativeEvent extends _EventBase<EventNativeId, EventNativeId> {
  NativeEvent({
    required super.aggregateId,
    required super.label,
    required super.eventId,
    super.occurredAt,
    super.context,
  });
}

@Serializable()
class UuidEvent extends DomainEvent<UuidValue, UuidValue> {
  UuidEvent({
    required super.aggregateId,
    UuidValue? eventId,
    super.occurredAt,
    super.context,
  }) : super(eventId: eventId ?? UuidValue.generate());
}

void main() {
  test('native event JSON retains inherited generic ID and all base metadata',
      () {
    final codecs = IdentityCodecRegistry()
      ..register<EventNativeId>('native', _Codec());
    final serializer = NativeEventJsonSerializer.withIdentityCodecs(codecs);
    final event = NativeEvent(
      aggregateId: const EventNativeId('Repo/IssueA %, café'),
      eventId: const EventNativeId('evt_0042'),
      label: 'created',
      occurredAt: DateTime.utc(2026),
      context: {
        'tenantId': 'tenant',
        'values': [1, true, null],
      },
    );
    final restored = serializer.deserialize(serializer.serialize(event));
    expect(restored.aggregateId, event.aggregateId);
    expect(restored.eventId, event.eventId);
    expect(serializer.toJson(event)['eventId'], {'native': 'evt_0042'});
    expect(restored.occurredAt, event.occurredAt);
    expect(restored.context, event.context);
    expect(restored.label, event.label);
    expect(
      serializer.toJson(event)['aggregateId'],
      {'native': event.aggregateId.value},
    );
    expect(
      () => serializer.fromJson({
        ...serializer.toJson(event),
        'aggregateId': {'native': 12},
      }),
      throwsA(isA<DeserializationException>()),
    );
  });
  test('stock UUID event JSON still uses UUID strings', () {
    final event = UuidEvent(aggregateId: UuidValue.generate());
    final serializer = UuidEventJsonSerializer();
    expect(
      serializer.deserialize(serializer.serialize(event)).aggregateId,
      event.aggregateId,
    );
    expect(serializer.toJson(event)['eventId'], event.eventId.uuid);
    expect(serializer.toJson(event)['aggregateId'], event.aggregateId.uuid);
  });
}
