import 'dart:async';
import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_events_distributed/dddart_events_distributed.dart';
import 'package:test/test.dart';

void main() {
  group('AppSyncEventsAuthorization', () {
    test('builds AppSync Events header subprotocol', () {
      final authorization = AppSyncEventsAuthorization.cognitoJwt(
        host: 'example.appsync-api.us-east-1.amazonaws.com',
        jwt: 'jwt-token',
      );

      final subprotocol = authorization.websocketSubprotocol;
      expect(subprotocol, startsWith('header-'));
      expect(subprotocol, isNot(contains('=')));

      final encodedHeader = subprotocol.substring('header-'.length);
      final decodedHeader =
          jsonDecode(
                utf8.decode(base64Url.decode(_base64UrlPad(encodedHeader))),
              )
              as Map<String, Object?>;

      expect(
        decodedHeader['host'],
        equals('example.appsync-api.us-east-1.amazonaws.com'),
      );
      expect(decodedHeader['Authorization'], equals('Bearer jwt-token'));
    });
  });

  group('AppSyncEventsTransport', () {
    late EventBus eventBus;
    late _FakeAppSyncWebSocketConnection fakeConnection;
    late List<String> requestedProtocols;
    late Uri requestedUri;

    setUp(() {
      eventBus = EventBus();
      fakeConnection = _FakeAppSyncWebSocketConnection();
      requestedProtocols = [];
      requestedUri = Uri();
    });

    tearDown(() async {
      await eventBus.close();
      await fakeConnection.close();
    });

    AppSyncEventsTransport createTransport({
      AppSyncCatchUpCallback? onCatchUpNeeded,
    }) {
      return AppSyncEventsTransport(
        realtimeEndpoint: Uri.parse(
          'wss://example.appsync-realtime-api.us-east-1.amazonaws.com/'
          'event/realtime',
        ),
        channel: '/domain-events/all',
        authorization: const AppSyncEventsAuthorization({
          'host': 'example.appsync-api.us-east-1.amazonaws.com',
          'Authorization': 'Bearer jwt-token',
        }),
        subscriptionId: 'sub-1',
        connector: (uri, protocols) async {
          requestedUri = uri;
          requestedProtocols = protocols.toList();
          return fakeConnection;
        },
        onCatchUpNeeded: onCatchUpNeeded,
      );
    }

    test('connects with AppSync protocols and subscribes after ack', () async {
      final transport = createTransport();
      final subscription = transport.subscribe().listen((_) {});
      await _flushMicrotasks();

      expect(
        requestedUri.toString(),
        equals(
          'wss://example.appsync-realtime-api.us-east-1.amazonaws.com/'
          'event/realtime',
        ),
      );
      expect(requestedProtocols, hasLength(2));
      expect(requestedProtocols.first, startsWith('header-'));
      expect(
        requestedProtocols.last,
        equals(awsAppSyncEventsWebSocketProtocol),
      );
      expect(fakeConnection.sentJson, [
        {'type': 'connection_init'},
      ]);

      fakeConnection.receive({
        'type': 'connection_ack',
        'connectionTimeoutMs': 300000,
      });
      await _flushMicrotasks();

      expect(fakeConnection.sentJson.last, {
        'type': 'subscribe',
        'id': 'sub-1',
        'channel': '/domain-events/all',
        'authorization': {
          'host': 'example.appsync-api.us-east-1.amazonaws.com',
          'Authorization': 'Bearer jwt-token',
        },
      });

      fakeConnection.receive({'type': 'subscribe_success', 'id': 'sub-1'});
      await _flushMicrotasks();
      await subscription.cancel();
      await transport.close();
    });

    test('publishes incoming serialized StoredEvent to EventBus', () async {
      var catchUpRequests = 0;
      final transport = createTransport(
        onCatchUpNeeded: () {
          catchUpRequests += 1;
        },
      );
      final bridge = DistributedEventBusBridge(
        localEventBus: eventBus,
        transport: transport,
        storedEventDecoder: _decodeAppSyncTestEvent,
      );
      final received = eventBus.on<AppSyncTestEvent>().first;

      bridge.start();
      await _flushMicrotasks();
      fakeConnection.receive({'type': 'connection_ack'});
      await _flushMicrotasks();
      fakeConnection.receive({'type': 'subscribe_success', 'id': 'sub-1'});
      await _flushMicrotasks();

      final event = AppSyncTestEvent(
        aggregateId: UuidValue.fromString(
          'aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa',
        ),
        eventId: UuidValue.fromString('bbbbbbbb-bbbb-4bbb-bbbb-bbbbbbbbbbbb'),
        occurredAt: DateTime.parse('2026-07-09T17:00:00Z'),
        message: 'hello from AppSync',
      );
      final storedEvent = StoredEvent.fromDomainEvent(event);

      fakeConnection.receive({
        'type': 'data',
        'id': 'sub-1',
        'event': [jsonEncode(storedEvent.toJson())],
      });

      final delivered = await received.timeout(const Duration(seconds: 1));
      expect(delivered.message, equals('hello from AppSync'));
      expect(delivered.aggregateId, equals(event.aggregateId));
      expect(catchUpRequests, equals(1));

      await bridge.close();
      await transport.close();
    });

    test('treats keep-alive messages as connection maintenance', () async {
      final transport = createTransport();
      final subscription = transport.subscribe().listen((_) {});
      await _flushMicrotasks();
      fakeConnection.receive({
        'type': 'connection_ack',
        'connectionTimeoutMs': 300000,
      });
      await _flushMicrotasks();
      fakeConnection.receive({'type': 'ka'});
      fakeConnection.receive({'type': 'subscribe_success', 'id': 'sub-1'});
      await _flushMicrotasks();

      expect(fakeConnection.closed, isFalse);
      await subscription.cancel();
      await transport.close();
    });
  });
}

DomainEvent? _decodeAppSyncTestEvent(StoredEvent storedEvent) {
  if (storedEvent.eventType != 'AppSyncTestEvent') {
    return null;
  }

  return AppSyncTestEvent.fromJson(
    jsonDecode(storedEvent.eventJson) as Map<String, Object?>,
  );
}

String _base64UrlPad(String value) {
  final padding = (4 - value.length % 4) % 4;
  return value + ''.padRight(padding, '=');
}

Future<void> _flushMicrotasks() async {
  await Future<void>.delayed(Duration.zero);
}

class _FakeAppSyncWebSocketConnection implements AppSyncWebSocketConnection {
  final _incoming = StreamController<String>.broadcast();
  final sent = <String>[];
  bool closed = false;

  @override
  Stream<String> get stream => _incoming.stream;

  List<Map<String, Object?>> get sentJson => sent
      .map((message) => jsonDecode(message) as Map<String, Object?>)
      .toList();

  @override
  void send(String message) {
    sent.add(message);
  }

  void receive(Map<String, Object?> message) {
    _incoming.add(jsonEncode(message));
  }

  @override
  Future<void> close() async {
    if (closed) {
      return;
    }
    closed = true;
    await _incoming.close();
  }
}

class AppSyncTestEvent extends DomainEvent {
  AppSyncTestEvent({
    required super.aggregateId,
    required this.message,
    super.eventId,
    super.occurredAt,
    super.context = const {},
  });

  factory AppSyncTestEvent.fromJson(Map<String, Object?> json) {
    return AppSyncTestEvent(
      aggregateId: UuidValue.fromString(json['aggregateId']! as String),
      eventId: UuidValue.fromString(json['eventId']! as String),
      occurredAt: DateTime.parse(json['occurredAt']! as String),
      message: json['message']! as String,
    );
  }

  final String message;

  Map<String, Object?> toJson() {
    return {
      'eventId': eventId.toString(),
      'occurredAt': occurredAt.toIso8601String(),
      'aggregateId': aggregateId.toString(),
      'context': context,
      'message': message,
    };
  }
}
