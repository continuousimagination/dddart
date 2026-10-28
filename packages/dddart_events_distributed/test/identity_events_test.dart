import 'dart:async';
import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_events_distributed/dddart_events_distributed.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:fake_async/fake_async.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:test/test.dart';

import 'identity_models.dart';

void main() {
  test('custom stored records require and use a typed ingestion factory',
      () async {
    final codecs = issueIdentityCodecs();
    final registry = createGeneratedEventRegistry(identityCodecs: codecs);
    final record = StoredEvent<Identity>.fromDomainEvent(
      NativeIssueOpened(
        aggregateId: const NativeId('native/issue'),
        title: 'created',
      ),
      registry: registry,
    );
    final wire = record.toJson()..['audit'] = 'retained';
    final repository = _CustomRepository();
    final withoutFactory = EventHttpEndpoints<_CustomRecord>(
      eventRepository: repository,
      identityCodecs: codecs,
    );
    shelf.Request request() => shelf.Request(
          'POST',
          Uri.parse('http://local/events'),
          body: jsonEncode(wire),
        );
    expect(
      (await withoutFactory.handlePostEvent(request(), null)).statusCode,
      400,
    );
    expect(repository.getAllSync(), isEmpty);
    final endpoints = EventHttpEndpoints<_CustomRecord>(
      eventRepository: repository,
      identityCodecs: codecs,
      storedEventFromJson: (json) => _CustomRecord(
        StoredEvent<Identity>.fromJson(json, identityCodecs: codecs),
        json['audit'] as String,
        codecs,
      ),
    );
    expect((await endpoints.handlePostEvent(request(), null)).statusCode, 201);
    final restored = repository.getAllSync().single;
    expect(restored.audit, 'retained');
    expect(restored.aggregateId, record.aggregateId);
    expect(restored.restore(registry).aggregateId, record.aggregateId);
    expect(restored.toJson()['audit'], 'retained');
  });

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

  for (final missingCodec in [false, true]) {
    test(
        'failed ${missingCodec ? 'codec registration' : 'identity payload'} leaves cursor and later events retryable',
        () {
      fakeAsync((clock) {
        final start = DateTime.utc(2026);
        final sender =
            createGeneratedEventRegistry(identityCodecs: issueIdentityCodecs());
        final native = NativeIssueOpened(
          aggregateId: const NativeId('Repo/IssueA %2F, café'),
          title: 'retry',
          occurredAt: start.add(const Duration(seconds: 1)),
        );
        final later = StockChanged(
          aggregateId: UuidValue.generate(),
          occurredAt: start.add(const Duration(seconds: 2)),
        );
        final good =
            StoredEvent<Identity>.fromDomainEvent(native, registry: sender)
                .toJson();
        final bad = Map<String, dynamic>.from(good)
          ..['aggregateId'] = {'type': 'native-issue', 'value': 42};
        final tail =
            StoredEvent<Identity>.fromDomainEvent(later, registry: sender)
                .toJson();
        var fixed = false;
        final queries = <String?>[];
        final bus = EventBus();
        final received = <DomainEvent<Identity>>[];
        bus.on<DomainEvent<Identity>>().listen(received.add);
        final receiver = createGeneratedEventRegistry(
          identityCodecs:
              missingCodec ? IdentityCodecRegistry() : issueIdentityCodecs(),
        );
        final client = EventBusClient(
          localEventBus: bus,
          serverUrl: 'http://local',
          eventRegistry: receiver,
          initialTimestamp: start,
          pollingInterval: const Duration(seconds: 1),
          httpClient: MockClient((request) async {
            queries.add(request.url.queryParameters['since']);
            return http.Response(
              jsonEncode([if (fixed || missingCodec) good else bad, tail]),
              200,
            );
          }),
        );
        clock.elapse(const Duration(seconds: 1));
        expect(received, isEmpty);
        fixed = true;
        if (missingCodec) {
          receiver.identityCodecs
              .register<NativeId>('native-issue', const NativeIdCodec());
        }
        clock.elapse(const Duration(seconds: 1));
        expect(queries, [start.toIso8601String(), start.toIso8601String()]);
        expect(
          received.map((event) => event.aggregateId),
          [native.aggregateId, later.aggregateId],
        );
        clock.elapse(const Duration(seconds: 1));
        expect(received, hasLength(2));
        unawaited(client.close());
        clock.flushMicrotasks();
      });
    });
  }

  test(
      'injected transport forwards and ingests native/scoped envelopes with authorization filtering',
      () async {
    final registry =
        createGeneratedEventRegistry(identityCodecs: issueIdentityCodecs());
    final repository = InMemoryEventRepository();
    final endpoints = EventHttpEndpoints<StoredEvent<Identity>>(
      eventRepository: repository,
      identityCodecs: registry.identityCodecs,
      authorizationFilter: (event, request) => event.tenantId == 'visible',
    );
    final bus = EventBus();
    final posts = Completer<void>();
    final client = EventBusClient(
      localEventBus: bus,
      serverUrl: 'http://local',
      eventRegistry: registry,
      autoForward: true,
      pollingInterval: const Duration(days: 1),
      httpClient: MockClient((request) async {
        final response = await endpoints.handlePostEvent(
          shelf.Request(
            request.method,
            request.url,
            headers: request.headers,
            body: request.body,
          ),
          null,
        );
        expect(response.statusCode, 201);
        if (repository.count == 2 && !posts.isCompleted) posts.complete();
        return http.Response(
          await response.readAsString(),
          response.statusCode,
          headers: response.headers,
        );
      }),
    );
    addTearDown(client.close);
    final native = NativeIssueOpened(
      aggregateId: const NativeId('Repo/IssueA %, café'),
      title: 'visible',
      context: {'tenantId': 'visible'},
    );
    final scoped = ScopedIssueOpened(
      aggregateId: const ScopedId('org/repo', 12),
      title: 'hidden',
      context: {'tenantId': 'hidden'},
    );
    client.publish(native);
    client.publish(scoped);
    await posts.future.timeout(const Duration(seconds: 5));
    final response = await endpoints.handleGetEvents(
      shelf.Request(
        'GET',
        Uri.parse('http://local/events?since=2020-01-01'),
      ),
    );
    expect(response.statusCode, 200);
    final json = jsonDecode(await response.readAsString()) as List<dynamic>;
    expect(json, hasLength(1));
    final stored = StoredEvent<Identity>.fromJson(
      json.single as Map<String, dynamic>,
      identityCodecs: registry.identityCodecs,
    );
    expect(stored.restore(registry).aggregateId, native.aggregateId);
    final malformed = Map<String, dynamic>.from(stored.toJson())
      ..['aggregateId'] = {'type': 'unknown', 'value': 'bad'};
    final bad = await endpoints.handlePostEvent(
      shelf.Request(
        'POST',
        Uri.parse('http://local/events'),
        body: jsonEncode(malformed),
      ),
      null,
    );
    expect(bad.statusCode, 400);
    expect(repository.count, 2);
  });
}

class _CustomRecord extends StoredEvent<Identity> {
  _CustomRecord(
    StoredEvent<Identity> record,
    this.audit,
    IdentityCodecRegistry codecs,
  ) : super(
          id: record.id,
          createdAt: record.createdAt,
          aggregateId: record.aggregateId,
          eventType: record.eventType,
          eventJson: record.eventJson,
          identityCodecs: codecs,
        );
  final String audit;
  @override
  Map<String, dynamic> toJson() => super.toJson()..['audit'] = audit;
}

class _CustomRepository extends InMemoryRepository<_CustomRecord, UuidValue>
    implements EventRepository<_CustomRecord> {
  @override
  Future<List<_CustomRecord>> findSince(DateTime timestamp) async =>
      getAllSync()
          .where((record) => !record.createdAt.isBefore(timestamp))
          .toList();
  @override
  Future<void> deleteOlderThan(DateTime timestamp) async {
    for (final record in getAllSync()) {
      if (record.createdAt.isBefore(timestamp)) await deleteById(record.id);
    }
  }
}
