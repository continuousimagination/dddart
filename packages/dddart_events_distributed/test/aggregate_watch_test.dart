import 'dart:async';
import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_events_distributed/dddart_events_distributed.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:test/test.dart';

void main() {
  late _Fixture fixture;
  setUp(() {
    fixture = _Fixture();
  });
  tearDown(() async {
    for (final client in fixture.clients) {
      await client.close();
    }
  });

  for (final action in ['resolve', 'read']) {
    test(
        'transient $action failure signals recovery and retains the checkpoint',
        () async {
      final reference = fixture.reference('game');
      fixture.allow(reference, ['alice']);
      final client = fixture.client('alice');
      final watch = client.watch(reference);
      final denied = client.watch(fixture.reference('game'));
      final states = <EventWatchStatus>[];
      watch.signals.listen(states.add);
      await client.synchronize();
      final checkpoint = watch.checkpoint;
      expect(watch.status, EventWatchStatus.active);
      expect(denied.status, EventWatchStatus.revoked);
      final received = <DomainEvent<Identity>>[];
      watch.events.listen(received.add);
      await fixture.accept(reference, label: 'missed');
      fixture.failingAction = action;
      await client.synchronize();
      await Future<void>.delayed(Duration.zero);
      expect(watch.status, EventWatchStatus.connecting);
      expect(states, contains(EventWatchStatus.connecting));
      expect(watch.checkpoint, checkpoint);
      expect(denied.status, EventWatchStatus.revoked);
      fixture.failingAction = null;
      await client.synchronize();
      await Future<void>.delayed(Duration.zero);
      expect(watch.status, EventWatchStatus.active);
      expect(received, hasLength(1));
      expect((received.single as _Changed).label, 'missed');
      expect(watch.checkpoint, isNot(checkpoint));
    });
  }

  test('live disconnect signals recovery before a failed rejoin', () async {
    final reference = fixture.reference('game');
    fixture.allow(reference, ['alice']);
    final transport = _LiveControl(
      HttpAggregateEventTransport(
        baseUrl: Uri.parse('http://local/events'),
        wire: fixture.wire,
        tokenProvider: () async => 'alice',
        client: MockClient(fixture.route),
      ),
    );
    final client = AggregateEventClient(
      transport: transport,
      registry: fixture.registry,
      aggregateKind: (_) => 'game',
      interval: const Duration(hours: 1),
    );
    fixture.clients.add(client);
    final watch = client.watch(reference);
    await watch.ready;
    final checkpoint = watch.checkpoint;
    final states = <EventWatchStatus>[];
    watch.signals.listen(states.add);
    fixture.failingAction = 'resolve';
    transport.disconnected();
    await client.synchronize();
    await Future<void>.delayed(Duration.zero);
    expect(watch.status, EventWatchStatus.connecting);
    expect(states.first, EventWatchStatus.connecting);
    expect(watch.checkpoint, checkpoint);
    fixture.failingAction = null;
    await client.synchronize();
    expect(watch.status, EventWatchStatus.active);
  });

  for (final terminal in [
    EventWatchStatus.revoked,
    EventWatchStatus.resyncRequired,
  ]) {
    test('delayed disconnect cannot resurrect a $terminal watch', () async {
      final reference = fixture.reference('game');
      fixture.allow(reference, ['alice']);
      final transport = _LiveControl(
        HttpAggregateEventTransport(
          baseUrl: Uri.parse('http://local/events'),
          wire: fixture.wire,
          tokenProvider: () async => 'alice',
          client: MockClient(fixture.route),
        ),
      );
      final client = AggregateEventClient(
        transport: transport,
        registry: fixture.registry,
        aggregateKind: (_) => 'game',
        interval: const Duration(hours: 1),
      );
      fixture.clients.add(client);
      final watch = client.watch(reference);
      await watch.ready;
      final lateDisconnect = transport.disconnected;
      final signals = <EventWatchStatus>[];
      watch.signals.listen(signals.add);
      if (terminal == EventWatchStatus.revoked) {
        fixture.allow(reference, []);
      } else {
        fixture.now = fixture.now.add(const Duration(days: 8));
      }
      await client.synchronize();
      expect(watch.status, terminal);
      await Future<void>.delayed(Duration.zero);
      signals.clear();
      final requests = fixture.requests.length;
      lateDisconnect();
      await Future<void>.delayed(Duration.zero);
      await client.synchronize();
      expect(watch.status, terminal);
      expect(signals, isEmpty);
      expect(fixture.requests.length, requests);
    });
  }

  test('a replaced subscription cannot disconnect the new channel', () async {
    final reference = fixture.reference('game');
    fixture.allow(reference, ['alice']);
    final transport = _LiveControl(
      HttpAggregateEventTransport(
        baseUrl: Uri.parse('http://local/events'),
        wire: fixture.wire,
        tokenProvider: () async => 'alice',
        client: MockClient(fixture.route),
      ),
    );
    final client = AggregateEventClient(
      transport: transport,
      registry: fixture.registry,
      aggregateKind: (_) => 'game',
      interval: const Duration(hours: 1),
    );
    fixture.clients.add(client);
    final watch = client.watch(reference);
    await watch.ready;
    final staleDisconnect = transport.disconnected;
    await fixture.channels.rotate(reference, UuidValue.generate());
    await client.synchronize();
    final requests = fixture.requests.length;
    staleDisconnect();
    await Future<void>.delayed(Duration.zero);
    expect(watch.status, EventWatchStatus.active);
    expect(fixture.requests.length, requests);
    fixture.failingAction = 'resolve';
    transport.disconnected();
    await client.synchronize();
    expect(watch.status, EventWatchStatus.connecting);
  });

  test('two game players, selective documents and one shared daily puzzle',
      () async {
    final game = fixture.reference('game');
    fixture.allow(game, ['alice', 'bob']);
    final puzzle = fixture.reference('puzzle');
    fixture.allow(puzzle, List.generate(1000, (index) => 'player$index'));
    final documents = List.generate(100, (_) => fixture.reference('document'));
    for (final document in documents) {
      fixture.allow(document, ['alice']);
    }
    final alice = fixture.client('alice');
    final bob = fixture.client('bob');
    final eve = fixture.client('eve');
    final aliceGame = alice.watch(game);
    final bobGame = bob.watch(game);
    final forbidden = eve.watch(game);
    final activeDocuments = documents.take(2).map(alice.watch).toList();
    final puzzleOne = fixture.client('player1').watch(puzzle);
    final puzzleMany = fixture.client('player999').watch(puzzle);
    await Future.wait([
      alice.synchronize(),
      bob.synchronize(),
      eve.synchronize(),
      puzzleOne.ready,
      puzzleMany.ready,
    ]);
    expect(forbidden.status, EventWatchStatus.revoked);
    final received = <String>[];
    aliceGame.events.listen((event) => received.add('alice'));
    bobGame.events.listen((event) => received.add('bob'));
    forbidden.events.listen((event) => received.add('eve'));
    activeDocuments.first.events.listen((event) => received.add('document'));
    puzzleMany.events.listen((event) => received.add('puzzle'));
    await fixture.accept(game);
    await fixture.accept(documents.first);
    await fixture.accept(documents.last);
    await fixture.accept(puzzle);
    for (final client in fixture.clients) {
      await client.synchronize();
    }
    await Future<void>.delayed(Duration.zero);
    expect(received.toSet(), {'alice', 'bob', 'document', 'puzzle'});
    final aliceRequests = fixture.requests.where(
      (request) =>
          request.headers['authorization'] == 'Bearer alice' &&
          request.url.path.endsWith('/read'),
    );
    expect(
      aliceRequests.every(
        (request) =>
            ((jsonDecode(request.body) as Map)['watches'] as List).length <= 3,
      ),
      isTrue,
    );
    expect(
      (await fixture.channels.resolve(puzzle)).id,
      (await fixture.channels.resolve(puzzle)).id,
    );
  });

  test('fresh heads, resumed recovery, unknown/malformed skip and expiration',
      () async {
    final reference = fixture.reference('game');
    fixture.allow(reference, ['alice']);
    await fixture.accept(reference, label: 'before');
    final client = fixture.client('alice');
    final watch = client.watch(reference);
    final labels = <String>[];
    watch.events.listen((event) => labels.add((event as _Changed).label));
    await client.synchronize();
    expect(labels, isEmpty);
    final checkpoint = watch.checkpoint;
    await client.pause();
    await fixture.accept(reference, label: 'offline');
    await fixture.history
        .append(fixture.envelope(reference, type: 'future.v1'));
    await fixture.history
        .append(fixture.envelope(reference, body: '{malformed'));
    await fixture.accept(reference, label: 'after-malformed');
    await client.resume();
    await Future<void>.delayed(Duration.zero);
    expect(labels, ['offline', 'after-malformed']);
    expect(watch.checkpoint, isNot(checkpoint));
    await watch.close();
    final resumed = client.watch(reference, checkpoint: checkpoint);
    final replay = <DomainEvent<Identity>>[];
    resumed.events.listen(replay.add);
    await client.synchronize();
    await Future<void>.delayed(Duration.zero);
    expect(replay, hasLength(2));
    fixture.now = fixture.now.add(const Duration(days: 8));
    await client.synchronize();
    expect(resumed.status, EventWatchStatus.resyncRequired);
  });

  test(
      'leases, cancellation, current access and publish rights are independent',
      () async {
    final reference = fixture.reference('game');
    fixture.allow(reference, ['alice', 'bob']);
    final alice = fixture.client('alice');
    final first = alice.watch(reference);
    final second = alice.watch(reference);
    await alice.synchronize();
    await first.close();
    final received = <DomainEvent<Identity>>[];
    second.events.listen(received.add);
    await fixture.accept(reference);
    await alice.synchronize();
    await Future<void>.delayed(Duration.zero);
    expect(received, hasLength(1));
    // Bob can subscribe but policy explicitly denies his publication.
    final envelope = fixture.envelope(reference);
    await expectLater(
      fixture.service
          .accept(EventPrincipal(userId: 'bob', claims: 'bob'), envelope),
      throwsA(isA<EventAccessDenied>()),
    );
    fixture.allow(reference, ['bob']);
    await alice.synchronize();
    expect(second.status, EventWatchStatus.revoked);
    final requests = fixture.requests.length;
    await alice.pause();
    await alice.synchronize();
    expect(fixture.requests.length, requests);
    await alice.close();
    await alice.synchronize();
    expect(fixture.requests.length, requests);
  });

  test('HTTP acceptance awaits handlers and shares event-driven rotation',
      () async {
    final reference = fixture.reference('game');
    fixture.allow(reference, ['alice']);
    final before = await fixture.channels.resolve(reference);
    final processed = Completer<void>();
    final release = Completer<void>();
    final service = AggregateEventService<String>(
      history: fixture.history,
      channels: fixture.channels,
      registry: fixture.registry,
      policy: fixture.policy,
      rotatesAccess: (_) => true,
      onEvent: (_) async {
        processed.complete();
        await release.future;
      },
    );
    final endpoints = AggregateEventHttpEndpoints(
      service: service,
      authenticate: fixture.authenticate,
    );
    var complete = false;
    final envelope = fixture.envelope(reference);
    final response = endpoints
        .publish(
      shelf.Request(
        'POST',
        Uri.parse('http://local/events/publish'),
        headers: {'authorization': 'Bearer alice'},
        body: jsonEncode(envelope.toJson(fixture.registry.identityCodecs)),
      ),
    )
        .then((value) {
      complete = true;
      return value;
    });
    await processed.future;
    expect(complete, isFalse);
    expect((await fixture.channels.resolve(reference)).id, isNot(before.id));
    release.complete();
    expect((await response).statusCode, 201);
    expect(await fixture.channels.find(before.id), isNull);
    final again = await fixture.channels.rotate(reference, envelope.id);
    expect(again.previous.id, before.id);
    expect((await fixture.channels.resolve(reference)).id, again.current.id);
  });

  test('bounded catch-up rotates deferred watches without skipping progress',
      () async {
    fixture.endpoints = AggregateEventHttpEndpoints(
      service: fixture.service,
      authenticate: fixture.authenticate,
      pageSize: 1,
      maxEventsPerResponse: 1,
      maxResponseBytes: 512 * 1024,
    );
    final references = List.generate(3, (_) => fixture.reference('document'));
    final client = fixture.client('alice');
    final received = <UuidValue>[];
    final watches = references.map((reference) {
      fixture.allow(reference, ['alice']);
      final watch = client.watch(reference);
      watch.events.listen((event) => received.add(event.eventId));
      return watch;
    }).toList();
    await client.synchronize();
    for (final reference in references) {
      await fixture.accept(reference);
      await fixture.accept(reference);
    }
    fixture.requests.clear();
    await client.synchronize();
    await Future<void>.delayed(Duration.zero);
    expect(received.toSet(), hasLength(6));
    expect(
      watches.map(
        (watch) => fixture.wire.parseCheckpoint(watch.checkpoint!).position,
      ),
      everyElement(2),
    );
    final reads = fixture.requests
        .where((request) => request.url.path.endsWith('/read'))
        .toList();
    expect(reads.length, greaterThanOrEqualTo(6));
    final first =
        ((jsonDecode(reads.first.body) as Map)['watches'] as List).first;
    final second =
        ((jsonDecode(reads[1].body) as Map)['watches'] as List).first;
    expect(second['aggregate'], isNot(first['aggregate']));
  });

  test('publish-only principals can resolve a target without acquiring a watch',
      () async {
    final reference = fixture.reference('game');
    final transport = HttpAggregateEventTransport(
      baseUrl: Uri.parse('http://local/events'),
      wire: fixture.wire,
      tokenProvider: () async => 'writer',
      client: MockClient(fixture.route),
    );
    final envelope = fixture.envelope(reference);
    final target = await transport.publicationTarget(envelope);
    expect(target.aggregate, reference);
    final result = await transport.resolve([EventWatchRequest(reference)]);
    expect(result.single.status, EventWatchStatus.revoked);
    await transport.publish(envelope);
    expect((await fixture.history.head(reference)).position, 1);
    await transport.close();
  });

  test('pause during credential refresh prevents a late HTTP request',
      () async {
    final reference = fixture.reference('game');
    fixture.allow(reference, ['alice']);
    final refreshing = Completer<void>();
    final credential = Completer<String?>();
    var calls = 0;
    final transport = HttpAggregateEventTransport(
      baseUrl: Uri.parse('http://local/events'),
      wire: fixture.wire,
      tokenProvider: () {
        if (calls++ == 0) {
          refreshing.complete();
          return credential.future;
        }
        return Future.value('alice');
      },
      client: MockClient(fixture.route),
    );
    final client = AggregateEventClient(
      transport: transport,
      registry: fixture.registry,
      aggregateKind: (_) => 'game',
      interval: const Duration(hours: 1),
    );
    fixture.clients.add(client);
    final watch = client.watch(reference);
    final syncing = client.synchronize();
    await refreshing.future;
    await client.pause();
    credential.complete('alice');
    await syncing;
    expect(fixture.requests, isEmpty);
    await client.resume();
    expect(watch.status, EventWatchStatus.active);
  });

  test('a newer pause cancels resume waiting for an old synchronization',
      () async {
    final reference = fixture.reference('game');
    fixture.allow(reference, ['alice']);
    Completer<void>? gate;
    var calls = 0;
    final transport = _LiveControl(
      HttpAggregateEventTransport(
        baseUrl: Uri.parse('http://local/events'),
        wire: fixture.wire,
        tokenProvider: () async => 'alice',
        client: MockClient((request) async {
          calls++;
          await gate?.future;
          return fixture.route(request);
        }),
      ),
    );
    final client = AggregateEventClient(
      transport: transport,
      registry: fixture.registry,
      aggregateKind: (_) => 'game',
      interval: const Duration(hours: 1),
    );
    fixture.clients.add(client);
    final watch = client.watch(reference);
    await watch.ready;
    gate = Completer<void>();
    final syncing = client.synchronize();
    await Future<void>.delayed(Duration.zero);
    await client.pause();
    final resuming = client.resume();
    await Future<void>.delayed(Duration.zero);
    await client.pause();
    final pausedCalls = calls;
    gate.complete();
    await Future.wait([syncing, resuming]);
    expect(watch.status, EventWatchStatus.paused);
    expect(calls, pausedCalls);
    await client.resume();
    expect(watch.status, EventWatchStatus.active);
  });

  test('resume waits for asynchronous transport suspension to finish',
      () async {
    final reference = fixture.reference('game');
    fixture.allow(reference, ['alice']);
    final transport = _SuspendingLiveControl(
      HttpAggregateEventTransport(
        baseUrl: Uri.parse('http://local/events'),
        wire: fixture.wire,
        tokenProvider: () async => 'alice',
        client: MockClient(fixture.route),
      ),
    );
    final client = AggregateEventClient(
      transport: transport,
      registry: fixture.registry,
      aggregateKind: (_) => 'game',
      interval: const Duration(hours: 1),
    );
    fixture.clients.add(client);
    final watch = client.watch(reference);
    await watch.ready;
    final paused = client.pause();
    final resuming = client.resume();
    final calls = fixture.requests.length;
    await Future<void>.delayed(Duration.zero);
    expect(fixture.requests.length, calls);
    transport.suspending.complete();
    await Future.wait([paused, resuming]);
    expect(watch.status, EventWatchStatus.active);
    expect(fixture.requests.length, greaterThan(calls));
  });

  test('refresh credentials per request and single flight through slow HTTP',
      () async {
    final reference = fixture.reference('game');
    fixture.allow(reference, ['alice']);
    var token = 'alice';
    final barrier = Completer<void>();
    var concurrent = 0;
    var maximum = 0;
    var calls = 0;
    final transport = HttpAggregateEventTransport(
      baseUrl: Uri.parse('http://local/events'),
      wire: fixture.wire,
      tokenProvider: () async => token,
      client: MockClient((request) async {
        calls++;
        concurrent++;
        if (concurrent > maximum) maximum = concurrent;
        if (calls == 1) await barrier.future;
        final response = await fixture.route(request);
        concurrent--;
        return response;
      }),
    );
    final client = AggregateEventClient(
      transport: transport,
      registry: fixture.registry,
      aggregateKind: (_) => 'game',
      interval: const Duration(hours: 1),
    );
    fixture.clients.add(client);
    final watch = client.watch(reference);
    final sync = client.synchronize();
    await Future<void>.delayed(Duration.zero);
    final overlap = client.synchronize();
    barrier.complete();
    await Future.wait([sync, overlap]);
    expect(maximum, 1);
    token = 'eve';
    await client.synchronize();
    expect(watch.status, EventWatchStatus.revoked);
  });
}

class _Fixture {
  _Fixture() {
    registry.register<_Changed>(
      'changed.v1',
      encode: (event) => event.toJson(),
      decode: _Changed.fromJson,
    );
    history = InMemoryAggregateEventRepository(clock: () => now);
    channels = InMemoryEventChannelRepository();
    policy = _Policy(members);
    service = AggregateEventService(
      history: history,
      channels: channels,
      registry: registry,
      policy: policy,
    );
    endpoints = AggregateEventHttpEndpoints(
      service: service,
      authenticate: authenticate,
    );
  }
  DateTime now = DateTime.now().toUtc();
  final registry = EventRegistry();
  final Map<AggregateReference<Identity>, Set<String>> members = {};
  final clients = <AggregateEventClient>[];
  final requests = <http.Request>[];
  String? failingAction;
  late final InMemoryAggregateEventRepository history;
  late final InMemoryEventChannelRepository channels;
  late final _Policy policy;
  late final AggregateEventService<String> service;
  late AggregateEventHttpEndpoints<String> endpoints;
  AggregateEventWire get wire => AggregateEventWire(registry.identityCodecs);
  AggregateReference<UuidValue> reference(String kind) =>
      AggregateReference(kind: kind, id: UuidValue.generate());
  void allow(AggregateReference<Identity> reference, List<String> users) {
    members[reference] = users.toSet();
  }

  Future<EventPrincipal<String>?> authenticate(String token) async =>
      token.isEmpty ? null : EventPrincipal(userId: token, claims: token);
  EventEnvelope envelope(
    AggregateReference<Identity> reference, {
    String label = 'changed',
    String? body,
    String type = 'changed.v1',
  }) {
    final event =
        _Changed(aggregateId: reference.id as UuidValue, label: label);
    return EventEnvelope(
      aggregate: reference,
      event: StoredEvent<Identity>(
        id: event.eventId,
        createdAt: event.occurredAt,
        aggregateId: reference.id,
        eventType: type,
        eventJson: body ?? jsonEncode(event.toJson()),
      ),
    );
  }

  Future<RecordedEvent> accept(
    AggregateReference<Identity> reference, {
    String label = 'changed',
  }) =>
      service.accept(
        EventPrincipal(userId: 'server', claims: 'server'),
        envelope(reference, label: label),
      );
  Future<http.Response> route(http.Request request) async {
    requests.add(request);
    if (request.url.pathSegments.last == failingAction) {
      return http.Response(
        '{"error":"Synthetic unavailable control transport"}',
        503,
      );
    }
    final incoming = shelf.Request(
      request.method,
      request.url,
      headers: request.headers,
      body: request.body,
    );
    final action = request.url.pathSegments.last;
    final handler = {
      'resolve': endpoints.resolve,
      'read': endpoints.read,
      'publish': endpoints.publish,
      'target': endpoints.target,
    }[action]!;
    final response = await handler(incoming);
    return http.Response(
      await response.readAsString(),
      response.statusCode,
      headers: response.headers,
    );
  }

  AggregateEventClient client(String user) {
    final transport = HttpAggregateEventTransport(
      baseUrl: Uri.parse('http://local/events'),
      wire: wire,
      tokenProvider: () async => user,
      client: MockClient(route),
    );
    final client = AggregateEventClient(
      transport: transport,
      registry: registry,
      aggregateKind: (_) => 'game',
      interval: const Duration(hours: 1),
    );
    clients.add(client);
    return client;
  }
}

class _LiveControl implements LiveAggregateEventTransport {
  _LiveControl(this.control);
  final AggregateEventTransport control;
  late void Function() disconnected;
  @override
  Future<List<EventWatchResult>> resolve(List<EventWatchRequest> watches) =>
      control.resolve(watches);
  @override
  Future<List<EventWatchResult>> read(List<EventWatchRequest> watches) =>
      control.read(watches);
  @override
  Future<void> publish(EventEnvelope envelope) => control.publish(envelope);
  @override
  Future<void> close() => control.close();
  @override
  Future<EventLiveSubscription> subscribe(
    EventChannel channel, {
    required void Function(RecordedEvent) onEvent,
    required void Function() onRefresh,
    required void Function() onDisconnect,
  }) async {
    disconnected = onDisconnect;
    return _LiveLease();
  }
}

class _SuspendingLiveControl extends _LiveControl
    implements SuspendableEventTransport {
  _SuspendingLiveControl(super.control);
  final suspending = Completer<void>();
  @override
  Future<void> suspend() => suspending.future;
}

class _LiveLease implements EventLiveSubscription {
  @override
  Future<void> cancel() async {}
}

class _Policy implements AggregateEventPolicy<String> {
  _Policy(this.members);
  final Map<AggregateReference<Identity>, Set<String>> members;
  @override
  Future<bool> canSubscribe(
    EventPrincipal<String> principal,
    AggregateReference<Identity> aggregate,
  ) async =>
      members[aggregate]?.contains(principal.userId) ?? false;
  @override
  Future<bool> canPublish(
    EventPrincipal<String> principal,
    EventEnvelope envelope,
  ) async =>
      principal.userId == 'server' ||
      principal.userId == 'writer' ||
      (principal.userId == 'alice' &&
          await canSubscribe(principal, envelope.aggregate));
}

class _Changed extends DomainEvent<UuidValue> {
  _Changed({
    required super.aggregateId,
    required this.label,
    super.eventId,
    super.occurredAt,
    super.context,
  });
  final String label;
  Map<String, dynamic> toJson() => {
        'eventId': eventId.uuid,
        'aggregateId': aggregateId.uuid,
        'occurredAt': occurredAt.toIso8601String(),
        'context': context,
        'label': label,
      };
  static _Changed fromJson(Map<String, dynamic> json) => _Changed(
        aggregateId: UuidValue.fromString(json['aggregateId'] as String),
        eventId: UuidValue.fromString(json['eventId'] as String),
        occurredAt: DateTime.parse(json['occurredAt'] as String),
        context: Map<String, dynamic>.from(json['context'] as Map),
        label: json['label'] as String,
      );
}
