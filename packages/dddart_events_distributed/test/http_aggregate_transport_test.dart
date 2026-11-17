import 'dart:convert';
import 'dart:io' as io;

import 'package:dddart/dddart.dart';
import 'package:dddart_events_distributed/dddart_events_distributed.dart';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';

import 'identity_models.dart';

void main() {
  late _HttpFixture fixture;
  setUp(() async {
    fixture = _HttpFixture();
    await fixture.start();
  });
  tearDown(() => fixture.close());

  test(
      'real HTTP retries accepted occurrences and delivers native/scoped events without echo',
      () async {
    final bus = EventBus();
    addTearDown(bus.close);
    final published = <DomainEvent<Identity>>[];
    final delivered = <DomainEvent<Identity>>[];
    final local =
        bus.onPublished<DomainEvent<Identity>>().listen(published.add);
    final all = bus.on<DomainEvent<Identity>>().listen(delivered.add);
    addTearDown(local.cancel);
    addTearDown(all.cancel);
    final client = fixture.client(bus: bus);
    final events = <DomainEvent<Identity>>[
      NativeIssueOpened(
        aggregateId: const NativeId('Repo/IssueA %, café'),
        title: 'native',
        occurredAt: DateTime.utc(2000),
        context: {'tenantId': 'one'},
      ),
      ScopedIssueOpened(
        aggregateId: const ScopedId('Org/Repo %, café', 42),
        title: 'scoped',
        occurredAt: DateTime.utc(1990),
        context: {
          'roles': ['editor'],
        },
      ),
    ];
    final watches =
        events.map((event) => client.watch(fixture.reference(event))).toList();
    await Future.wait(watches.map((watch) => watch.ready));
    final received = <DomainEvent<Identity>>[];
    for (final watch in watches) {
      final subscription = watch.events.listen(received.add);
      addTearDown(subscription.cancel);
    }
    // The first response fails after acceptance. A retry must reuse the UUID.
    fixture.failAfterAcceptance = true;
    final publisher = client.publisher;
    for (final event in events) {
      expect(await publisher.publish(event), isTrue);
    }
    await client.synchronize();
    await client.synchronize();
    await Future<void>.delayed(Duration.zero);
    expect(fixture.publicationIds, [
      events[0].eventId.uuid,
      events[0].eventId.uuid,
      events[1].eventId.uuid,
    ]);
    expect(received, hasLength(2));
    expect(delivered, hasLength(2));
    expect(published, isEmpty);
    for (var i = 0; i < events.length; i++) {
      final actual =
          received.singleWhere((event) => event.eventId == events[i].eventId);
      expect(actual.runtimeType, events[i].runtimeType);
      expect(actual.aggregateId, events[i].aggregateId);
      expect(actual.occurredAt, events[i].occurredAt);
      expect(actual.context, events[i].context);
      expect(
        (await fixture.history.head(fixture.reference(events[i]))).position,
        1,
      );
    }
    // The same bus still exposes intentional local publication to a bridge.
    bus.publish(StockChanged(aggregateId: UuidValue.generate()));
    await Future<void>.delayed(Duration.zero);
    expect(published, hasLength(1));
    expect(fixture.publicationIds, hasLength(3));
  });

  test('bounded publication retries refresh credentials and stop on denial',
      () async {
    final client = fixture.client();
    final event = NativeIssueOpened(
      aggregateId: const NativeId('native'),
      title: 'retry',
    );
    fixture.forcedPublishStatus = 503;
    expect(await client.publisher.publish(event), isFalse);
    expect(fixture.publicationIds, List.filled(3, event.eventId.uuid));
    expect((await fixture.history.head(fixture.reference(event))).position, 0);
    fixture.forcedPublishStatus = null;
    fixture.token = 'bob';
    expect(await client.publisher.publish(event), isFalse);
    expect(fixture.publicationIds, hasLength(4));
    expect(fixture.credentials.last, 'Bearer bob');
    fixture.token = null;
    expect(await client.publisher.publish(event), isFalse);
    expect(fixture.publicationIds, hasLength(4));
    fixture.token = 'alice';
    expect(await client.publisher.publish(event), isTrue);
    expect(fixture.credentials.last, 'Bearer alice');
    expect((await fixture.history.head(fixture.reference(event))).position, 1);
  });

  test('HTTP authenticates every route and conceals denied history', () async {
    final event = NativeIssueOpened(
      aggregateId: const NativeId('private'),
      title: 'secret',
    );
    final envelope = fixture.envelope(event);
    final watch = {
      'watches': [
        {
          'aggregate':
              envelope.aggregate.toJson(fixture.registry.identityCodecs),
        }
      ],
    };
    final wire = envelope.toJson(fixture.registry.identityCodecs);
    for (final action in ['resolve', 'read', 'publish', 'target']) {
      final body = action == 'resolve' || action == 'read' ? watch : wire;
      for (final token in [null, 'expired']) {
        expect((await fixture.raw(action, body, token: token)).statusCode, 401);
      }
    }
    expect(
      (await fixture.raw('publish', wire, token: 'alice')).statusCode,
      201,
    );
    for (final action in ['resolve', 'read']) {
      final response = await fixture.raw(action, watch, token: 'bob');
      expect(response.statusCode, 200);
      final result =
          ((jsonDecode(response.body) as Map)['watches'] as List).single as Map;
      expect(result['status'], 'revoked');
      expect(result.keys, unorderedEquals(['aggregate', 'status']));
      expect(response.body, isNot(contains('secret')));
    }
    for (final action in ['publish', 'target']) {
      expect((await fixture.raw(action, wire, token: 'bob')).statusCode, 403);
    }
    expect((await fixture.history.head(envelope.aggregate)).position, 1);
  });

  test('thrown event policies fail closed without leaking or accepting data',
      () async {
    final event = NativeIssueOpened(
      aggregateId: const NativeId('private'),
      title: 'secret',
    );
    final envelope = fixture.envelope(event);
    final watch = {
      'watches': [
        {
          'aggregate':
              envelope.aggregate.toJson(fixture.registry.identityCodecs),
        }
      ],
    };
    fixture.policyThrows = true;
    for (final action in ['resolve', 'read', 'publish', 'target']) {
      final response = await fixture.raw(
        action,
        action == 'resolve' || action == 'read'
            ? watch
            : envelope.toJson(fixture.registry.identityCodecs),
        token: 'alice',
      );
      expect(
        response.statusCode,
        action == 'publish'
            ? 503
            : action == 'target'
                ? 400
                : 500,
      );
      expect(response.body, isNot(contains('private-policy-detail')));
      expect(response.body, isNot(contains('secret')));
      expect((await fixture.history.head(envelope.aggregate)).position, 0);
    }
  });

  test('malformed known identities and envelopes fail before HTTP persistence',
      () async {
    final event = NativeIssueOpened(
      aggregateId: const NativeId('native'),
      title: 'valid',
    );
    final envelope = fixture.envelope(event);
    for (final mutation in <void Function(Map<String, dynamic>)>[
      (json) => json['version'] = 99,
      (json) => (json['event'] as Map)['aggregateId'] = {
            'type': 'native-issue',
            'value': 42,
          },
      (json) => (json['event'] as Map)['aggregateId'] = {
            'type': 'unknown',
            'value': 'native',
          },
      (json) => (json['event'] as Map)['eventJson'] = '{malformed',
    ]) {
      final json = envelope.toJson(fixture.registry.identityCodecs);
      mutation(json);
      expect(
        (await fixture.raw('publish', json, token: 'alice')).statusCode,
        400,
      );
      expect((await fixture.history.head(envelope.aggregate)).position, 0);
    }
  });
}

class _HttpFixture implements AggregateEventPolicy<String> {
  final registry =
      createGeneratedEventRegistry(identityCodecs: issueIdentityCodecs());
  late final history =
      InMemoryAggregateEventRepository(identityCodecs: registry.identityCodecs);
  late final service = AggregateEventService<String>(
    history: history,
    channels:
        InMemoryEventChannelRepository(identityCodecs: registry.identityCodecs),
    registry: registry,
    policy: this,
  );
  late final endpoints = AggregateEventHttpEndpoints(
    service: service,
    authenticate: (token) async => ['alice', 'bob'].contains(token)
        ? EventPrincipal(userId: token, claims: token)
        : null,
  );
  late io.HttpServer server;
  final clients = <AggregateEventClient>[];
  final rawClient = http.Client();
  final publicationIds = <String>[];
  final credentials = <String?>[];
  String? token = 'alice';
  bool policyThrows = false;
  bool failAfterAcceptance = false;
  int? forcedPublishStatus;
  Uri get baseUrl => Uri.parse('http://127.0.0.1:${server.port}/events');

  AggregateReference<Identity> reference(DomainEvent<Identity> event) =>
      AggregateReference(kind: 'issue', id: event.aggregateId);
  EventEnvelope envelope(DomainEvent<Identity> event) => EventEnvelope(
        aggregate: reference(event),
        event: StoredEvent<Identity>.fromDomainEvent(event, registry: registry),
      );
  Future<void> start() async {
    server = await shelf_io.serve(
      (incoming) async {
        var request = incoming;
        credentials.add(request.headers['authorization']);
        final action = request.url.pathSegments.last;
        if (action == 'publish') {
          final body = await request.readAsString();
          publicationIds
              .add(((jsonDecode(body) as Map)['event'] as Map)['id'] as String);
          request = request.change(body: body);
          if (forcedPublishStatus != null) {
            return shelf.Response(forcedPublishStatus!);
          }
        }
        final handler = <String, shelf.Handler>{
          'resolve': endpoints.resolve,
          'read': endpoints.read,
          'publish': endpoints.publish,
          'target': endpoints.target,
        }[action]!;
        final response = await handler(request);
        if (action == 'publish' &&
            response.statusCode == 201 &&
            failAfterAcceptance) {
          failAfterAcceptance = false;
          await response.readAsString();
          return shelf.Response(503);
        }
        return response;
      },
      io.InternetAddress.loopbackIPv4,
      0,
    );
  }

  AggregateEventClient client({EventBus? bus}) {
    final AggregateEventTransport transport = HttpAggregateEventTransport(
      baseUrl: baseUrl,
      wire: AggregateEventWire(registry.identityCodecs),
      tokenProvider: () async => token,
    );
    final client = AggregateEventClient(
      transport: transport,
      registry: registry,
      aggregateKind: (_) => 'issue',
      localEventBus: bus,
      interval: const Duration(hours: 1),
      retryPolicy: EventRetryPolicy(initialDelay: Duration.zero, jitter: 0),
    );
    clients.add(client);
    return client;
  }

  Future<http.Response> raw(
    String action,
    Map<String, dynamic> body, {
    String? token,
  }) =>
      rawClient.post(
        baseUrl.replace(path: '/events/$action'),
        headers: {
          if (token != null) 'authorization': 'Bearer $token',
          'content-type': 'application/json',
        },
        body: jsonEncode(body),
      );
  Future<void> close() async {
    for (final client in clients) {
      await client.close();
    }
    rawClient.close();
    await server.close(force: true);
  }

  @override
  Future<bool> canSubscribe(
    EventPrincipal<String> principal,
    AggregateReference<Identity> aggregate,
  ) async {
    if (policyThrows) throw StateError('private-policy-detail');
    return principal.userId == 'alice';
  }

  @override
  Future<bool> canPublish(
    EventPrincipal<String> principal,
    EventEnvelope envelope,
  ) =>
      canSubscribe(principal, envelope.aggregate);
}
