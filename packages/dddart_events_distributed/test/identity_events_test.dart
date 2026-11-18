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
    final events = <DomainEvent<Identity, Identity>>[
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
      ImportedIssueChanged(
        aggregateId: const NativeId('remote-issue'),
        eventId: const ScopedId('provider/Acme %, café', 42),
        title: 'imported',
      ),
      StockChanged(aggregateId: UuidValue.generate()),
    ];
    final keys = <String>{};
    for (final event in events) {
      final stored = StoredEvent<Identity, Identity>.fromDomainEvent(
        event,
        registry: registry,
      );
      final json = stored.toJson();
      expect(json['aggregateId'], isA<Map<String, Object?>>());
      expect(json['id'], registry.identityCodecs.toTaggedJson(event.eventId));
      expect(stored.id, event.eventId);
      final restored = StoredEvent<Identity, Identity>.fromJson(
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
    expect(keys, hasLength(5));
    expect(registry.keyFor(events.first), 'issue.native.opened.v1');
    expect(
      () => StoredEvent<Identity, Identity>.fromDomainEvent(
        events.first,
        registry: createGeneratedEventRegistry(),
      ),
      throwsA(isA<SerializationException>()),
    );
    final malformed = StoredEvent<Identity, Identity>.fromDomainEvent(
      events.first,
      registry: registry,
    ).toJson()
      ..['aggregateId'] = {'type': 'native-issue', 'value': 42};
    expect(
      () => StoredEvent<Identity, Identity>.fromJson(
        malformed,
        identityCodecs: registry.identityCodecs,
      ),
      throwsA(isA<DeserializationException>()),
    );
    final mismatched = StoredEvent<Identity, Identity>.fromDomainEvent(
      events.first,
      registry: registry,
    ).toJson()
      ..['aggregateId'] = {'type': 'native-issue', 'value': 'different'};
    expect(
      () => StoredEvent<Identity, Identity>.fromJson(
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
  test(
      'stored event IDs reject unknown, malformed, mismatched and legacy values',
      () {
    final registry =
        createGeneratedEventRegistry(identityCodecs: issueIdentityCodecs());
    final event = ImportedIssueChanged(
      aggregateId: const NativeId('issue'),
      eventId: const ScopedId('provider', 42),
      title: 'imported',
    );
    final stored = StoredEvent<NativeId, ScopedId>.fromDomainEvent(
      event,
      registry: registry,
    );
    for (final id in [
      {'type': 'missing', 'value': 42},
      {'type': 'scoped-issue', 'value': 'invalid'},
      registry.identityCodecs.toTaggedJson(UuidValue.generate()),
      UuidValue.generate().uuid,
    ]) {
      expect(
        () => StoredEvent<NativeId, ScopedId>.fromJson(
          {...stored.toJson(), 'id': id},
          identityCodecs: registry.identityCodecs,
        ),
        throwsA(isA<DeserializationException>()),
      );
    }
    final changed = StoredEvent<NativeId, ScopedId>.fromJson(
      {
        ...stored.toJson(),
        'id': registry.identityCodecs
            .toTaggedJson(const ScopedId('other-provider', 42)),
      },
      identityCodecs: registry.identityCodecs,
    );
    expect(
      () => changed.restore(registry),
      throwsA(isA<DeserializationException>()),
    );
  });
}
