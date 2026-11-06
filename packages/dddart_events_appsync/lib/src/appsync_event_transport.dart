import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dddart/dddart.dart';
import 'package:dddart_events_distributed/dddart_events_distributed.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Portable injectable WebSocket factory for real AWS-frame protocol tests.
typedef AppSyncSocketFactory = Future<WebSocketChannel> Function(
  Uri uri,
  List<String> protocols,
);

/// One multiplexed AppSync Events socket, with HTTP membership/history recovery.
class AppSyncEventTransport
    implements LiveAggregateEventTransport, SuspendableEventTransport {
  AppSyncEventTransport({
    required this.httpEndpoint,
    required this.realtimeEndpoint,
    required this.namespace,
    required this.control,
    required this.wire,
    required this.authorization,
    AppSyncSocketFactory? connect,
    EventPublicationResolver? publicationResolver,
    this.operationTimeout = const Duration(seconds: 5),
    this.maxConnectAttempts = 3,
    this.maxSubscriptions = 100,
    Logger? logger,
  })  : _connect = connect ??
            ((uri, protocols) async =>
                WebSocketChannel.connect(uri, protocols: protocols)),
        _publicationResolver = publicationResolver ??
            (control is EventPublicationResolver
                ? control as EventPublicationResolver
                : null),
        logger = logger ?? Logger('dddart.events.appsync') {
    validateEventNamespace(namespace);
    if (operationTimeout <= Duration.zero ||
        maxConnectAttempts < 1 ||
        maxSubscriptions < 1 ||
        maxSubscriptions > 200) {
      throw ArgumentError('Invalid AppSync limits');
    }
    if (httpEndpoint.scheme != 'https' && httpEndpoint.host != 'localhost') {
      throw ArgumentError('AppSync HTTP endpoint must use HTTPS');
    }
    if (realtimeEndpoint.scheme != 'wss' &&
        realtimeEndpoint.host != 'localhost') {
      throw ArgumentError('AppSync realtime endpoint must use WSS');
    }
  }
  final Uri httpEndpoint;
  final Uri realtimeEndpoint;
  final String namespace;
  final AggregateEventTransport control;
  final AggregateEventWire wire;

  /// Current native authorization fields (Authorization or x-api-key), per operation.
  /// Cognito/OIDC and custom Lambda JWTs use the existing application's token callback.
  final Future<Map<String, String>> Function() authorization;
  final AppSyncSocketFactory _connect;
  final EventPublicationResolver? _publicationResolver;
  final Duration operationTimeout;
  final int maxConnectAttempts;
  final int maxSubscriptions;
  final Logger logger;
  final Map<String, _Subscription> _subscriptions = {};
  final Map<String, Completer<Map<String, dynamic>>> _operations = {};
  final Map<String, String> _expected = {};
  WebSocketChannel? _socket;
  // Ownership transfers to a local and is awaited/cancelled in _disconnect.
  // ignore: cancel_subscriptions
  StreamSubscription<dynamic>? _reader;
  Completer<void>? _ack;
  Future<void>? _connecting;
  Timer? _keepalive;
  Timer? _lifetime;
  Duration _keepaliveTimeout = const Duration(minutes: 5);
  int _generation = 0;
  int _lifecycle = 0;
  bool _closed = false;

  Future<Map<String, String>> _authorization() async => {
        ...await authorization().timeout(operationTimeout),
        'host': httpEndpoint.host,
      };

  Future<void> _ensureConnected() async {
    if (_closed) {
      throw const EventPublicationException('AppSync transport closed');
    }
    if (_connecting != null) return _connecting;
    if (_socket != null && (_ack?.isCompleted ?? false)) return;
    final completer = Completer<void>();
    final lifecycle = _lifecycle;
    _connecting = completer.future;
    unawaited(() async {
      try {
        for (var attempt = 0; attempt < maxConnectAttempts; attempt++) {
          if (_closed || lifecycle != _lifecycle) {
            completer.completeError(
              const EventPublicationException('Connection cancelled'),
            );
            return;
          }
          try {
            await _open();
            completer.complete();
            return;
          } catch (error, stack) {
            await _disconnect(notify: false);
            if (_closed ||
                lifecycle != _lifecycle ||
                attempt == maxConnectAttempts - 1 ||
                (error is EventPublicationException && !error.retryable)) {
              completer.completeError(error, stack);
              return;
            }
            await Future<void>.delayed(
              Duration(
                milliseconds:
                    min(1000, 100 * (1 << attempt)) + Random().nextInt(100),
              ),
            );
          }
        }
      } finally {
        _connecting = null;
      }
    }());
    return completer.future;
  }

  Future<void> _open() async {
    final generation = ++_generation;
    final headers = await _authorization();
    if (_closed || generation != _generation) {
      throw const EventPublicationException('Connection cancelled');
    }
    final encoded =
        base64Url.encode(utf8.encode(jsonEncode(headers))).replaceAll('=', '');
    final socket = await _connect(
      realtimeEndpoint,
      ['aws-appsync-event-ws', 'header-$encoded'],
    ).then((socket) async {
      if (_closed || generation != _generation) {
        await socket.sink.close();
        throw const EventPublicationException('Connection cancelled');
      }
      return socket;
    }).timeout(operationTimeout);
    if (_closed || generation != _generation) {
      await socket.sink.close();
      throw const EventPublicationException('Connection cancelled');
    }
    _socket = socket;
    final ack = Completer<void>();
    _ack = ack;
    // ready may fail before we await the protocol acknowledgment.
    unawaited(
      ack.future
          .then<void>((_) {}, onError: (Object error, StackTrace stack) {}),
    );
    _reader = socket.stream.listen(
      (frame) {
        if (generation == _generation) _frame(frame);
      },
      onError: (Object error, StackTrace stack) {
        if (generation == _generation) unawaited(_disconnect());
      },
      onDone: () {
        if (generation == _generation) unawaited(_disconnect());
      },
    );
    await socket.ready.timeout(operationTimeout);
    socket.sink.add(jsonEncode({'type': 'connection_init'}));
    await ack.future.timeout(operationTimeout);
    _lifetime = Timer(
      const Duration(hours: 23, minutes: 55),
      () => unawaited(_disconnect()),
    );
  }

  void _heartbeat() {
    _keepalive?.cancel();
    _keepalive = Timer(_keepaliveTimeout, () => unawaited(_disconnect()));
  }

  void _frame(dynamic raw) {
    try {
      if (raw is! String || utf8.encode(raw).length > 2 * 1024 * 1024) {
        throw const FormatException('Invalid AppSync frame');
      }
      final frame = jsonDecode(raw) as Map<String, dynamic>;
      final type = frame['type'] as String;
      if (type == 'connection_ack') {
        final milliseconds = frame['connectionTimeoutMs'] as int;
        if (milliseconds < 1 || milliseconds > 600000) {
          throw const FormatException('Invalid keepalive deadline');
        }
        _keepaliveTimeout = Duration(milliseconds: milliseconds);
        _heartbeat();
        if (!(_ack?.isCompleted ?? true)) _ack!.complete();
        return;
      }
      if (type == 'ka') {
        _heartbeat();
        return;
      }
      if (type == 'connection_error') {
        unawaited(_disconnect());
        return;
      }
      final id = frame['id'] as String?;
      final operation = _operations[id];
      if (type == _expected[id] &&
          operation != null &&
          !operation.isCompleted) {
        operation.complete(frame);
        return;
      }
      if (type.endsWith('_error')) {
        if (operation != null && !operation.isCompleted) {
          operation.completeError(
            EventPublicationException(
              'AppSync operation rejected',
              retryable: _transient(frame),
            ),
          );
        }
        if (type == 'broadcast_error') {
          final subscription = _subscriptions[id];
          if (subscription != null) {
            unawaited(() async {
              await subscription.cancel();
              subscription.onDisconnect();
            }());
          }
        }
        return;
      }
      if (type == 'data') {
        final subscription = _subscriptions[id];
        if (subscription == null) return;
        final events = frame['event'] as List;
        if (events.length > 5) {
          throw const FormatException('Oversized AppSync batch');
        }
        for (final item in events) {
          try {
            final payload = jsonDecode(item as String) as Map<String, dynamic>;
            if (payload['kind'] == 'refresh') {
              subscription.onRefresh();
            } else if (payload['kind'] == 'record') {
              subscription.onEvent(
                wire.parseRecord(
                  Map<String, dynamic>.from(payload['record'] as Map),
                ),
              );
            } else {
              logger.warning('Unknown AppSync control payload skipped');
            }
          } catch (error, stack) {
            logger.severe('Malformed AppSync data skipped', error, stack);
          }
        }
      }
    } catch (error, stack) {
      logger.severe('Malformed AppSync frame skipped', error, stack);
    }
  }

  bool _transient(Map<String, dynamic> frame) {
    final text =
        jsonEncode(frame['errors'] ?? frame['failed'] ?? '').toLowerCase();
    return text.contains('retryable') ||
        text.contains('throttl') ||
        text.contains('timeout') ||
        text.contains('internal') ||
        text.contains('serviceunavailable');
  }

  Future<Map<String, dynamic>> _request(Map<String, dynamic> frame) async {
    final id = frame['id'] as String;
    final pending = Completer<Map<String, dynamic>>();
    _operations[id] = pending;
    _expected[id] = '${frame['type']}_success';
    try {
      final socket = _socket;
      if (socket == null) {
        throw const EventPublicationException(
          'AppSync disconnected',
          retryable: true,
        );
      }
      socket.sink.add(jsonEncode(frame));
      return await pending.future.timeout(operationTimeout);
    } finally {
      _operations.remove(id);
      _expected.remove(id);
    }
  }

  @override
  Future<EventLiveSubscription> subscribe(
    EventChannel channel, {
    required void Function(RecordedEvent) onEvent,
    required void Function() onRefresh,
    required void Function() onDisconnect,
  }) async {
    if (_subscriptions.length >= maxSubscriptions) {
      throw const EventPublicationException(
        'AppSync subscription limit exceeded',
      );
    }
    await _ensureConnected();
    final id = UuidValue.generate().uuid;
    final subscription =
        _Subscription(this, id, onEvent, onRefresh, onDisconnect);
    _subscriptions[id] = subscription;
    try {
      final credentials = await _authorization();
      await _request({
        'type': 'subscribe',
        'id': id,
        'channel': channel.path(namespace),
        'authorization': credentials,
      });
      return subscription;
    } catch (_) {
      _subscriptions.remove(id);
      await _idle();
      rethrow;
    }
  }

  @override
  Future<void> publish(EventEnvelope envelope) async {
    final resolver = _publicationResolver;
    if (resolver == null) {
      throw const EventPublicationException(
        'A publish-authorized target resolver is required',
      );
    }
    final channel = await resolver.publicationTarget(envelope);
    final payload = jsonEncode(
      {'kind': 'event', 'envelope': envelope.toJson(wire.identities)},
    );
    if (utf8.encode(payload).length > 240 * 1024) {
      throw const EventPublicationException('AppSync payload too large');
    }
    await _ensureConnected();
    try {
      final result = await _request({
        'type': 'publish',
        'id': UuidValue.generate().uuid,
        'channel': channel.path(namespace),
        'events': [payload],
        'authorization': await _authorization(),
      });
      final failed = result['failed'] as List?;
      final successful = result['successful'] as List?;
      if (failed == null || failed.isNotEmpty || successful?.length != 1) {
        throw EventPublicationException(
          'AppSync publication not accepted',
          retryable: _transient(result),
        );
      }
    } finally {
      await _idle();
    }
  }

  Future<void> _cancel(String id) async {
    if (_subscriptions.remove(id) == null) return;
    try {
      if (_socket != null) await _request({'type': 'unsubscribe', 'id': id});
    } catch (error, stack) {
      logger.fine('AppSync unsubscribe interrupted', error, stack);
    } finally {
      await _idle();
    }
  }

  Future<void> _idle() async {
    if (_subscriptions.isEmpty && _operations.isEmpty && _connecting == null) {
      await _disconnect(notify: false);
    }
  }

  Future<void> _disconnect({bool notify = true}) async {
    _generation++;
    _keepalive?.cancel();
    _lifetime?.cancel();
    final socket = _socket;
    _socket = null;
    final reader = _reader;
    _reader = null;
    const error = EventPublicationException(
      'AppSync connection interrupted',
      retryable: true,
    );
    final ack = _ack;
    _ack = null;
    if (ack != null && !ack.isCompleted) ack.completeError(error);
    for (final operation in _operations.values.toList()) {
      if (!operation.isCompleted) operation.completeError(error);
    }
    final subscriptions = _subscriptions.values.toList();
    _subscriptions.clear();
    await reader?.cancel();
    await socket?.sink.close();
    if (notify && !_closed) {
      for (final subscription in subscriptions) {
        subscription.onDisconnect();
      }
    }
  }

  @override
  Future<List<EventWatchResult>> resolve(List<EventWatchRequest> watches) =>
      control.resolve(watches);
  @override
  Future<List<EventWatchResult>> read(List<EventWatchRequest> watches) =>
      control.read(watches);
  @override
  Future<void> suspend() async {
    _lifecycle++;
    await _disconnect();
    if (control is SuspendableEventTransport) {
      await (control as SuspendableEventTransport).suspend();
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _lifecycle++;
    await _disconnect(notify: false);
    await control.close();
  }
}

class _Subscription implements EventLiveSubscription {
  _Subscription(
    this.transport,
    this.id,
    this.onEvent,
    this.onRefresh,
    this.onDisconnect,
  );
  final AppSyncEventTransport transport;
  final String id;
  final void Function(RecordedEvent) onEvent;
  final void Function() onRefresh;
  final void Function() onDisconnect;
  @override
  Future<void> cancel() => transport._cancel(id);
}
