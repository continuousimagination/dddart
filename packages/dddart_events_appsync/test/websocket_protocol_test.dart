import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:dddart/dddart.dart';
import 'package:dddart_events_appsync/dddart_events_appsync.dart';
import 'package:dddart_events_distributed/dddart_events_distributed.dart';
import 'package:test/test.dart';

import 'event_fixture.dart';

void main() {
  late EventFixture fixture;
  late _Server server;
  late _Control control;
  late AppSyncEventTransport transport;
  late AggregateEventClient client;
  var token = 'valid:alice';
  setUp(() async {
    fixture = EventFixture();
    server = await _Server.start(fixture);
    control = _Control(fixture);
    token = 'valid:alice';
    transport = AppSyncEventTransport(
      httpEndpoint: Uri.parse('https://example.appsync-api.test/event'),
      realtimeEndpoint:
          Uri.parse('ws://localhost:${server.http.port}/event/realtime'),
      namespace: 'aggregates',
      control: control,
      wire: fixture.wire,
      authorization: () async => {'Authorization': token},
      operationTimeout: const Duration(seconds: 1),
      maxConnectAttempts: 2,
    );
    client = AggregateEventClient(
      transport: transport,
      registry: fixture.registry,
      aggregateKind: (_) => 'game',
      interval: const Duration(hours: 1),
      retryPolicy: EventRetryPolicy(initialDelay: Duration.zero, jitter: 0),
    );
  });
  tearDown(() async {
    await client.close();
    await server.close();
  });

  test('native handshake multiplexes watches and deduplicates unordered replay',
      () async {
    final game = fixture.reference();
    final document = fixture.reference('document');
    final first = client.watch(game);
    final shared = client.watch(game);
    final second = client.watch(document);
    await client.synchronize();
    expect(server.peers, hasLength(1));
    expect(server.peers.single.subscriptions, hasLength(2));
    final headers = server.connectionHeaders.single;
    expect(headers['host'], 'example.appsync-api.test');
    expect(headers['Authorization'], 'valid:alice');
    final received = <UuidValue>[];
    first.events.listen((event) => received.add(event.eventId));
    final a = await fixture.history.append(fixture.envelope(game));
    final b = await fixture.history.append(fixture.envelope(game));
    final channel = await fixture.channels.resolve(game);
    server
      ..broadcast(
        channel,
        {'kind': 'record', 'record': fixture.wire.record(b)},
      )
      ..broadcast(
        channel,
        {'kind': 'record', 'record': fixture.wire.record(a)},
      );
    await _until(() => received.length == 2);
    await client.synchronize();
    expect(received, [b.envelope.id, a.envelope.id]);
    expect(fixture.wire.parseCheckpoint(first.checkpoint!).position, 2);
    await shared.close();
    expect(first.status, EventWatchStatus.active);
    await first.close();
    expect(server.peers.single.subscriptions, hasLength(1));
    await second.close();
    await _until(() => server.peers.every((peer) => peer.closed));
  });

  test(
      'event-driven rotations preserve watch streams and deny a removed player',
      () async {
    final game = fixture.reference();
    final watch = client.watch(game);
    final other = client.watch(fixture.reference('document'));
    final labels = <String>[];
    watch.events.listen((event) => labels.add((event as Changed).label));
    await client.synchronize();
    final original = await fixture.channels.resolve(game);
    expect(
      await client.publisher
          .publish(Changed(aggregateId: game.id, label: 'removed')),
      isTrue,
    );
    await client.synchronize();
    final rotated = await fixture.channels.resolve(game);
    expect(rotated.id, isNot(original.id));
    expect(await fixture.channels.find(original.id), isNull);
    expect(
      await client.publisher
          .publish(Changed(aggregateId: game.id, label: 'new-channel')),
      isTrue,
    );
    await _until(() => labels.contains('new-channel'));
    expect(watch.status, EventWatchStatus.active);
    // Miss the refresh hint deliberately, then reconcile the stable watch.
    await fixture.channels.rotate(game, UuidValue.generate());
    await client.synchronize();
    expect(
      await client.publisher
          .publish(Changed(aggregateId: game.id, label: 'reconciled')),
      isTrue,
    );
    await _until(() => labels.contains('reconciled'));
    fixture.policy.members[game] = {'bob'};
    await client.synchronize();
    expect(watch.status, EventWatchStatus.revoked);
    expect(other.status, EventWatchStatus.active);
  });

  test(
      'partial failures stop permanent errors and retry preserved occurrence IDs',
      () async {
    final game = fixture.reference();
    final watch = client.watch(game);
    await watch.ready;
    final event = Changed(aggregateId: game.id);
    server
      ..failure = 'FORBIDDEN'
      ..failures = 1;
    expect(await client.publisher.publish(event), isFalse);
    expect(server.published, hasLength(1));
    server
      ..failure = 'RETRYABLE_ACCEPTANCE'
      ..failures = 1;
    expect(await client.publisher.publish(event), isTrue);
    expect(server.published, hasLength(3));
    expect(
      server.published
          .map((value) => ((value['envelope'] as Map)['event'] as Map)['id']),
      everyElement(event.eventId.uuid),
    );
    expect((await fixture.history.head(game)).position, 1);
  });

  test('keepalive loss reconnects and pause closes sockets until resumed',
      () async {
    server.keepalive = 60;
    final game = fixture.reference();
    final watch = client.watch(game);
    await watch.ready;
    await _until(() => server.peers.length >= 2);
    await client.pause();
    final count = server.peers.length;
    await Future<void>.delayed(const Duration(milliseconds: 160));
    expect(server.peers.length, count);
    expect(server.peers.every((peer) => peer.closed), isTrue);
    token = 'valid:bob';
    server.keepalive = 300000;
    await client.resume();
    expect(server.connectionHeaders.last['Authorization'], 'valid:bob');
    expect(watch.status, EventWatchStatus.active);
  });

  test('suspend during reconnect backoff prevents another connection attempt',
      () async {
    var attempts = 0;
    final retrying = AppSyncEventTransport(
      httpEndpoint: Uri.parse('https://example.appsync-api.test/event'),
      realtimeEndpoint:
          Uri.parse('wss://example.appsync-realtime.test/event/realtime'),
      namespace: 'aggregates',
      control: control,
      wire: fixture.wire,
      authorization: () async => {'Authorization': token},
      connect: (_, __) async {
        attempts++;
        throw const EventPublicationException('Unavailable', retryable: true);
      },
    );
    addTearDown(retrying.close);
    final rejected = expectLater(
      retrying.subscribe(
        await fixture.channels.resolve(fixture.reference()),
        onEvent: (_) {},
        onRefresh: () {},
        onDisconnect: () {},
      ),
      throwsA(isA<EventPublicationException>()),
    );
    await _until(() => attempts == 1);
    await retrying.suspend();
    await rejected;
    expect(attempts, 1);
  });

  test('pause during subscription acknowledgment discards the stale operation',
      () async {
    server.holdSubscriptions = true;
    final watch = client.watch(fixture.reference());
    await _until(
      () => server.frames.any((frame) => frame['type'] == 'subscribe'),
    );
    await client.pause();
    server.holdSubscriptions = false;
    await client.resume();
    await watch.ready;
    expect(watch.status, EventWatchStatus.active);
    expect(server.peers.where((peer) => !peer.closed), hasLength(1));
  });
}

Future<void> _until(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 4));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Protocol condition did not settle');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

class _Control implements AggregateEventTransport, EventPublicationResolver {
  _Control(this.fixture);
  final EventFixture fixture;
  @override
  Future<List<EventWatchResult>> resolve(
    List<EventWatchRequest> watches,
  ) async {
    final principal = (await fixture.authenticate('valid:alice'))!;
    return Future.wait(
      watches.map((watch) async {
        try {
          final channel =
              await fixture.service.resolve(principal, watch.aggregate);
          final checkpoint = watch.checkpoint ??
              fixture.wire
                  .checkpoint(await fixture.history.head(watch.aggregate));
          return EventWatchResult(
            aggregate: watch.aggregate,
            status: EventWatchStatus.active,
            channel: channel,
            checkpoint: checkpoint,
          );
        } on EventAccessDenied {
          return EventWatchResult(
            aggregate: watch.aggregate,
            status: EventWatchStatus.revoked,
          );
        }
      }),
    );
  }

  @override
  Future<List<EventWatchResult>> read(List<EventWatchRequest> watches) =>
      Future.wait(
        watches.map((watch) async {
          final page = await fixture.history.read(
            watch.aggregate,
            after: fixture.wire.parseCheckpoint(watch.checkpoint!),
          );
          return EventWatchResult(
            aggregate: watch.aggregate,
            status: EventWatchStatus.active,
            checkpoint: fixture.wire.checkpoint(page.checkpoint),
            events: page.events,
            hasMore: page.hasMore,
          );
        }),
      );
  @override
  Future<EventChannel> publicationTarget(EventEnvelope envelope) =>
      fixture.channels.resolve(envelope.aggregate);
  @override
  Future<void> publish(EventEnvelope envelope) async {
    throw StateError('Expected native AppSync publication');
  }

  @override
  Future<void> close() async {}
}

class _Server {
  _Server(this.fixture, this.http);
  final EventFixture fixture;
  final io.HttpServer http;
  final peers = <_Peer>[];
  final frames = <Map<String, dynamic>>[];
  final connectionHeaders = <Map<String, dynamic>>[];
  final published = <Map<String, dynamic>>[];
  int keepalive = 300000;
  int failures = 0;
  String failure = 'FORBIDDEN';
  bool holdSubscriptions = false;
  static Future<_Server> start(EventFixture fixture) async {
    final server = _Server(
      fixture,
      await io.HttpServer.bind(io.InternetAddress.loopbackIPv4, 0),
    );
    fixture
      ..onBroadcast = ((channel, record) async => server.broadcast(
            channel,
            {'kind': 'record', 'record': fixture.wire.record(record)},
          ))
      ..onRefresh =
          ((channel) async => server.broadcast(channel, {'kind': 'refresh'}));
    server.http.listen((request) async {
      final protocols = request.headers
          .value('sec-websocket-protocol')!
          .split(',')
          .map((value) => value.trim())
          .toList();
      expect(protocols, contains('aws-appsync-event-ws'));
      final encoded = protocols
          .singleWhere((value) => value.startsWith('header-'))
          .substring(7);
      final headers = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(encoded))),
      ) as Map<String, dynamic>;
      server.connectionHeaders.add(headers);
      final socket = await io.WebSocketTransformer.upgrade(
        request,
        protocolSelector: (_) => 'aws-appsync-event-ws',
      );
      final peer = _Peer(socket);
      server.peers.add(peer);
      socket.listen(
        (raw) async {
          final frame = jsonDecode(raw as String) as Map<String, dynamic>;
          server.frames.add(frame);
          final type = frame['type'];
          final id = frame['id'];
          if (type == 'connection_init') {
            peer.send({
              'type': 'connection_ack',
              'connectionTimeoutMs': server.keepalive,
            });
            return;
          }
          if (type == 'unsubscribe') {
            peer.subscriptions.remove(id);
            peer.send({'type': 'unsubscribe_success', 'id': id});
            return;
          }
          final path = frame['channel'] as String;
          final auth = frame['authorization'] as Map;
          final handlers = fixture.handlers();
          final authorized = await handlers.authorize({
            'authorizationToken': auth['Authorization'],
            'requestContext': {
              'operation':
                  type == 'subscribe' ? 'EVENT_SUBSCRIBE' : 'EVENT_PUBLISH',
              'channel': path,
            },
          });
          final identity = <String, dynamic>{
            'handlerContext': authorized['handlerContext'],
          };
          final context = <String, dynamic>{
            'identity': identity,
            'info': {
              'operation': type == 'subscribe' ? 'SUBSCRIBE' : 'PUBLISH',
              'channel': {'path': path},
            },
          };
          if (authorized['isAuthorized'] != true) {
            peer.send({
              'type': '${type}_error',
              'id': id,
              'errors': [
                {'errorType': 'Unauthorized'},
              ],
            });
            return;
          }
          if (type == 'subscribe') {
            final response = await handlers.onSubscribe(context);
            if (response != null) {
              peer.send({
                'type': 'subscribe_error',
                'id': id,
                'errors': [response],
              });
              return;
            }
            peer.subscriptions[id as String] = path;
            if (!server.holdSubscriptions) {
              peer.send({'type': 'subscribe_success', 'id': id});
            }
          } else if (type == 'publish') {
            final events = (frame['events'] as List).cast<String>();
            server.published.addAll(
              events.map((event) => jsonDecode(event) as Map<String, dynamic>),
            );
            if (server.failures-- > 0) {
              peer.send({
                'type': 'publish_success',
                'id': id,
                'successful': <Object?>[],
                'failed': [
                  {'index': 0, 'errorMessage': server.failure},
                ],
              });
              return;
            }
            context['events'] = [
              for (var index = 0; index < events.length; index++)
                {'id': 'aws-$index', 'payload': jsonDecode(events[index])},
            ];
            final result = await handlers.onPublish(context);
            final outgoing =
                (result['events'] as List).cast<Map<String, dynamic>>();
            final successful = <Map<String, dynamic>>[];
            final failed = <Map<String, dynamic>>[];
            for (var index = 0; index < outgoing.length; index++) {
              final item = outgoing[index];
              if (item['error'] != null) {
                failed.add({'index': index, 'errorMessage': item['error']});
              } else {
                successful.add({'identifier': item['id'], 'index': index});
                server.broadcastPath(
                  path,
                  Map<String, dynamic>.from(item['payload'] as Map),
                );
              }
            }
            peer.send({
              'type': 'publish_success',
              'id': id,
              'successful': successful,
              'failed': failed,
            });
          }
        },
        onDone: () {
          peer.closed = true;
        },
      );
    });
    return server;
  }

  void broadcast(EventChannel channel, Map<String, dynamic> payload) =>
      broadcastPath(channel.path('aggregates'), payload);
  void broadcastPath(String path, Map<String, dynamic> payload) {
    for (final peer in peers.where((peer) => !peer.closed)) {
      for (final subscription in peer.subscriptions.entries.toList()) {
        if (subscription.value == path) {
          peer.send({
            'type': 'data',
            'id': subscription.key,
            'event': [jsonEncode(payload)],
          });
        }
      }
    }
  }

  Future<void> close() async {
    for (final peer in peers) {
      await peer.socket.close();
    }
    await http.close(force: true);
  }
}

class _Peer {
  _Peer(this.socket);
  final io.WebSocket socket;
  final subscriptions = <String, String>{};
  bool closed = false;
  void send(Map<String, dynamic> frame) {
    if (!closed) socket.add(jsonEncode(frame));
  }
}
