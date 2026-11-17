import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_events_distributed/dddart_events_distributed.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:test/test.dart';

import 'identity_models.dart';

void main() {
  test('generated registry and tagged mixed store preserve all identity kinds',
      () {
    final registry =
        createGeneratedEventRegistry(identityCodecs: issueIdentityCodecs());
    final events = <DomainEvent<Identity>>[
      NativeIssueOpened(
        aggregateId: const NativeId('Repo/IssueA %, café'),
        title: 'native',
        context: {'tenantId': 'one'},
      ),
      ScopedIssueOpened(
        aggregateId: const ScopedId('org/Repo %, café', 12),
        title: 'first',
      ),
      ScopedIssueOpened(
        aggregateId: const ScopedId('org/repo %, café', 12),
        title: 'second',
      ),
      StockChanged(aggregateId: UuidValue.generate()),
    ];
    final keys = <String>{};
    for (final event in events) {
      final stored =
          StoredEvent<Identity>.fromDomainEvent(event, registry: registry);
      final json = stored.toJson();
      expect(json['aggregateId'], isA<Map<String, Object?>>());
      expect(stored.id, event.eventId);
      final restored = StoredEvent<Identity>.fromJson(
        json,
        identityCodecs: registry.identityCodecs,
      ).restore(registry);
      expect(restored.runtimeType, event.runtimeType);
      expect(restored.aggregateId, event.aggregateId);
      expect(restored.eventId, event.eventId);
      expect(restored.occurredAt, event.occurredAt);
      expect(restored.context, event.context);
      keys.add(jsonEncode(json['aggregateId']));
    }
    expect(keys, hasLength(4));
    expect(registry.keyFor(events.first), 'issue.native.opened.v1');
    expect(
      () => StoredEvent<Identity>.fromDomainEvent(
        events.first,
        registry: createGeneratedEventRegistry(),
      ),
      throwsA(isA<SerializationException>()),
    );
    final malformed =
        StoredEvent<Identity>.fromDomainEvent(events.first, registry: registry)
            .toJson()
          ..['aggregateId'] = {'type': 'native-issue', 'value': 42};
    expect(
      () => StoredEvent<Identity>.fromJson(
        malformed,
        identityCodecs: registry.identityCodecs,
      ),
      throwsA(isA<DeserializationException>()),
    );
    final mismatched =
        StoredEvent<Identity>.fromDomainEvent(events.first, registry: registry)
            .toJson()
          ..['aggregateId'] = {'type': 'native-issue', 'value': 'different'};
    expect(
      () => StoredEvent<Identity>.fromJson(
        mismatched,
        identityCodecs: registry.identityCodecs,
      ).restore(registry),
      throwsA(isA<DeserializationException>()),
    );
    expect(
      () => registry.registerSerializer<StockChanged>(
        'duplicate',
        StockChangedJsonSerializer(),
      ),
      throwsArgumentError,
    );
  });
}
