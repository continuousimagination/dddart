import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_events_distributed/dddart_events_distributed.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:test/test.dart';

void main() {
  late DateTime now;
  late IdentityCodecRegistry identities;
  late InMemoryAggregateEventRepository repository;
  late AggregateReference<UuidValue> game;

  setUp(() {
    now = DateTime.utc(2026, 11, 5);
    identities = IdentityCodecRegistry()
      ..register<_ScopedId>('scoped', const _ScopedCodec());
    repository = InMemoryAggregateEventRepository(
      identityCodecs: identities,
      clock: () => now,
    );
    game = AggregateReference(kind: 'game', id: UuidValue.generate());
  });

  EventEnvelope envelope(
    AggregateReference<Identity> aggregate, {
    UuidValue? id,
    DateTime? occurredAt,
    String body = '{"value":1}',
    String eventType = 'changed.v1',
  }) =>
      EventEnvelope(
        aggregate: aggregate,
        event: StoredEvent<Identity>(
          id: id ?? UuidValue.generate(),
          createdAt: occurredAt ?? DateTime.utc(2000),
          aggregateId: aggregate.id,
          eventType: eventType,
          eventJson: body,
          identityCodecs: identities,
        ),
      );

  test('logical references preserve kind, identity kind, case and scope', () {
    final refs = [
      AggregateReference(
        kind: 'game',
        id: const _ScopedId('Acme', 'Doc/1 % café'),
      ),
      AggregateReference(
        kind: 'game',
        id: const _ScopedId('acme', 'Doc/1 % café'),
      ),
      AggregateReference(
        kind: 'document',
        id: const _ScopedId('Acme', 'Doc/1 % café'),
      ),
      game,
      AggregateReference(kind: 'document', id: game.id),
    ];
    expect(
      refs.map((ref) => ref.toKey(identities)).toSet(),
      hasLength(refs.length),
    );
    for (final ref in refs) {
      expect(
        AggregateReference<Identity>.fromJson(
          ref.toJson(identities),
          identityCodecs: identities,
        ),
        ref,
      );
    }
    expect(
      () => AggregateReference(kind: ' ', id: game.id),
      throwsArgumentError,
    );
    expect(
      () => refs.first.toKey(IdentityCodecRegistry()),
      throwsA(isA<SerializationException>()),
    );
  });

  test(
      'fresh heads exclude prior history while reconnect recovers later events',
      () async {
    await repository.append(envelope(game));
    final fresh = await repository.head(game);
    expect((await repository.read(game, after: fresh)).events, isEmpty);

    final later = envelope(game, occurredAt: DateTime.utc(1990));
    await repository.append(later);
    final recovered = await repository.read(game, after: fresh);
    expect(recovered.events.single.envelope.id, later.id);
    expect(recovered.events.single.position, 2);
    expect(recovered.events.single.ingestedAt, now);
  });

  test('concurrent appends expose complete positions, including timestamp ties',
      () async {
    final start = await repository.head(game);
    final input = List.generate(25, (_) => envelope(game));
    await Future.wait(input.map(repository.append));

    var checkpoint = start;
    final ids = <UuidValue>[];
    final positions = <int>[];
    var hasMore = true;
    do {
      final page = await repository.read(game, after: checkpoint, limit: 3);
      ids.addAll(page.events.map((record) => record.envelope.id));
      positions.addAll(page.events.map((record) => record.position));
      checkpoint = page.checkpoint;
      hasMore = page.hasMore;
      if (hasMore) expect(checkpoint.observedAt, start.observedAt);
    } while (hasMore);

    expect(ids.toSet(), input.map((event) => event.id).toSet());
    expect(positions, List.generate(25, (index) => index + 1));
    expect(checkpoint.position, 25);
  });

  test('scope-specific streams reject unrelated and impossible checkpoints',
      () async {
    final other = AggregateReference(kind: 'game', id: UuidValue.generate());
    final checkpoint = await repository.head(game);
    await expectLater(
      repository.read(other, after: checkpoint),
      throwsArgumentError,
    );
    await expectLater(
      repository.read(
        game,
        after: EventCheckpoint(
          streamKey: checkpoint.streamKey,
          position: 99,
          observedAt: now,
        ),
      ),
      throwsArgumentError,
    );
    await expectLater(
      repository.read(game, after: checkpoint, limit: 0),
      throwsArgumentError,
    );
  });

  test('retries normalize JSON and do not create a second history occurrence',
      () async {
    final first = envelope(game, body: '{"a":1,"b":{"x":2,"y":3}}');
    final accepted = await repository.append(first);
    now = now.add(const Duration(hours: 1));
    final retry = envelope(
      game,
      id: first.id,
      body: '{ "b": {"y":3,"x":2}, "a":1 }',
    );
    final repeated = await repository.append(retry);
    expect(repeated.position, accepted.position);
    expect(repeated.ingestedAt, accepted.ingestedAt);
    expect((await repository.head(game)).position, 1);

    repeated.envelope.event.touch();
    expect(
      (await repository.getById(first.id)).event.updatedAt,
      first.event.updatedAt,
    );
  });

  test('conflicting UUID reuse cannot overwrite payload or move stream heads',
      () async {
    final first = envelope(game);
    await repository.append(first);
    await expectLater(
      repository.append(envelope(game, id: first.id, body: '{"value":2}')),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.type,
          'type',
          RepositoryExceptionType.duplicate,
        ),
      ),
    );
    final other = AggregateReference(kind: 'document', id: game.id);
    await expectLater(
      repository.append(envelope(other, id: first.id)),
      throwsA(isA<RepositoryException>()),
    );
    expect((await repository.head(game)).position, 1);
    expect((await repository.head(other)).position, 0);
  });

  test('default retention expires history but retains the logical head',
      () async {
    expect(repository.retention, const Duration(days: 7));
    final initial = await repository.head(game);
    final old = envelope(game);
    await repository.save(old);
    now = now.add(const Duration(days: 8));
    await expectLater(
      repository.read(game, after: initial),
      throwsA(isA<EventHistoryExpired>()),
    );
    await expectLater(
      repository.getById(old.id),
      throwsA(isA<RepositoryException>()),
    );

    final restarted = await repository.head(game);
    expect(restarted.position, 1);
    final current = await repository.append(envelope(game));
    expect(current.position, 2);
    expect(
      (await repository.read(game, after: restarted)).events,
      hasLength(1),
    );
  });

  test('an incomplete page never renews the recovery anchor', () async {
    final checkpoint = await repository.head(game);
    await repository.append(envelope(game));
    await repository.append(envelope(game));
    now = now.add(const Duration(days: 6));
    final page = await repository.read(game, after: checkpoint, limit: 1);
    expect(page.hasMore, isTrue);
    expect(page.checkpoint.observedAt, checkpoint.observedAt);

    now = now.add(const Duration(days: 2));
    await expectLater(
      repository.read(game, after: page.checkpoint),
      throwsA(isA<EventHistoryExpired>()),
    );
  });

  test('empty successful reads renew active checkpoints, not disconnected ones',
      () async {
    final initial = await repository.head(game);
    now = now.add(const Duration(days: 6));
    final active = await repository.read(game, after: initial);
    expect(active.checkpoint.observedAt, now);
    now = now.add(const Duration(days: 2));
    expect(
      (await repository.read(game, after: active.checkpoint)).events,
      isEmpty,
    );
    await expectLater(
      repository.read(game, after: initial),
      throwsA(isA<EventHistoryExpired>()),
    );
  });

  test('configured retention and manual deletion require explicit resync',
      () async {
    repository = InMemoryAggregateEventRepository(
      retention: const Duration(hours: 2),
      identityCodecs: identities,
      clock: () => now,
    );
    final initial = await repository.head(game);
    final first = envelope(game);
    await repository.append(first);
    await repository.deleteById(first.id);
    await expectLater(
      repository.read(game, after: initial),
      throwsA(isA<EventHistoryExpired>()),
    );
    final fresh = await repository.head(game);
    await repository.append(envelope(game));
    now = now.add(const Duration(hours: 3));
    await expectLater(
      repository.read(game, after: fresh),
      throwsA(isA<EventHistoryExpired>()),
    );
  });

  test(
      'history retains malformed/unknown bodies without decoding or trapping pages',
      () async {
    final start = await repository.head(game);
    final malformed = envelope(game, body: 'broken json');
    final unknown = envelope(game, eventType: 'future.v99');
    await repository.append(malformed);
    await repository.append(unknown);
    final page = await repository.read(game, after: start);
    expect(
      page.events.map((record) => record.envelope.id),
      [malformed.id, unknown.id],
    );
    expect(page.events.first.envelope.event.eventJson, 'broken json');
    expect(page.checkpoint.position, 2);
    expect(
      (await repository.read(game, after: page.checkpoint)).events,
      isEmpty,
    );
  });

  test('publication envelopes validate identity and round-trip explicitly', () {
    final record = envelope(game);
    final restored = EventEnvelope.fromJson(
      record.toJson(identities),
      identityCodecs: identities,
    );
    expect(restored.aggregate, game);
    expect(restored.id, record.id);
    expect(restored.event.eventJson, record.event.eventJson);
    expect(
      () => EventEnvelope(
        aggregate: AggregateReference(kind: 'game', id: UuidValue.generate()),
        event: record.event,
      ),
      throwsArgumentError,
    );
    expect(
      () => EventEnvelope.fromJson(
        {...record.toJson(identities), 'version': 99},
        identityCodecs: identities,
      ),
      throwsA(isA<DeserializationException>()),
    );
  });
}

class _ScopedId extends Identity {
  const _ScopedId(this.scope, this.value);
  final String scope;
  final String value;

  @override
  List<Object?> get props => [scope, value];
}

class _ScopedCodec implements IdentityCodec<_ScopedId> {
  const _ScopedCodec();

  @override
  Object toJson(_ScopedId id) => {'scope': id.scope, 'value': id.value};

  @override
  _ScopedId fromJson(Object? value) {
    final json = value! as Map;
    return _ScopedId(json['scope'] as String, json['value'] as String);
  }

  @override
  String toKey(_ScopedId id) => jsonEncode([id.scope, id.value]);

  @override
  _ScopedId fromKey(String value) {
    final parts = jsonDecode(value) as List;
    return _ScopedId(parts[0] as String, parts[1] as String);
  }
}
