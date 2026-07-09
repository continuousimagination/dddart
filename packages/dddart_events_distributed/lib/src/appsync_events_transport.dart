import 'dart:async';
import 'dart:convert';

import 'package:dddart_events_distributed/src/distributed_event_transport.dart';
import 'package:dddart_events_distributed/src/stored_event.dart';
import 'package:logging/logging.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// AWS AppSync Events WebSocket subprotocol name.
const awsAppSyncEventsWebSocketProtocol = 'aws-appsync-event-ws';

typedef _JsonObject = Map<String, Object?>;

/// Function that opens an AppSync-compatible WebSocket connection.
typedef AppSyncWebSocketConnector = Future<AppSyncWebSocketConnection> Function(
  Uri uri,
  Iterable<String> protocols,
);

/// Callback used when realtime traffic should trigger HTTP catch-up.
///
/// AppSync realtime delivery is treated as a wake-up/feed path only. The
/// durable recovery path remains the existing `/events?since=` polling model.
typedef AppSyncCatchUpCallback = FutureOr<void> Function();

/// Minimal WebSocket abstraction for fake protocol tests.
abstract interface class AppSyncWebSocketConnection {
  /// Incoming WebSocket text messages.
  ///
  /// AppSync Events messages are JSON text frames. Concrete WebSocket adapters
  /// must normalize provider-specific frame types before they cross this
  /// interface so protocol handling stays statically typed.
  Stream<String> get stream;

  /// Sends a raw WebSocket text message.
  void send(String message);

  /// Closes the underlying WebSocket connection.
  Future<void> close();
}

/// Authorization material for an AppSync Events WebSocket connection.
///
/// This spike supports header/subprotocol shaping and operation-level
/// authorization objects. It intentionally does not implement client-side IAM
/// SigV4 signing; callers that need IAM can provide pre-signed header values.
class AppSyncEventsAuthorization {
  /// Creates authorization from raw AppSync header fields.
  const AppSyncEventsAuthorization(this.headers);

  /// Creates authorization for an API key based AppSync Events API.
  factory AppSyncEventsAuthorization.apiKey({
    required String host,
    required String apiKey,
  }) {
    return AppSyncEventsAuthorization({
      'host': host,
      'x-api-key': apiKey,
    });
  }

  /// Creates authorization for Cognito User Pools or OIDC JWT auth.
  factory AppSyncEventsAuthorization.cognitoJwt({
    required String host,
    required String jwt,
    bool bearer = true,
  }) {
    return AppSyncEventsAuthorization({
      'host': host,
      'Authorization': bearer ? 'Bearer $jwt' : jwt,
    });
  }

  /// Header fields used in both the WebSocket handshake and subscribe message.
  final Map<String, String> headers;

  /// Encoded authorization subprotocol required by AppSync Events.
  String get websocketSubprotocol {
    final encoded = base64Url
        .encode(utf8.encode(jsonEncode(headers)))
        .replaceAll('=', '');
    return 'header-$encoded';
  }

  /// Authorization object sent with subscribe/publish operations.
  Map<String, String> get operationAuthorization => Map.unmodifiable(headers);
}

/// Experimental raw AppSync Events transport for DDDart distributed events.
///
/// This is a spike implementation, not a production-hardened client. It covers
/// the AppSync Events realtime WebSocket handshake, subscribe acknowledgement,
/// keep-alive tracking, and data-message decoding needed to feed serialized
/// [StoredEvent] payloads into the neutral [DistributedEventTransport]
/// interface.
///
/// Recovery remains explicit: realtime messages are best-effort wake/feed
/// signals, and [onCatchUpNeeded] is invoked after realtime activity or
/// connection loss so applications can run their authoritative
/// `/events?since=` catch-up.
class AppSyncEventsTransport implements DistributedEventTransport {
  /// Creates an experimental AppSync Events transport.
  AppSyncEventsTransport({
    required this.realtimeEndpoint,
    required this.channel,
    required this.authorization,
    this.subscriptionId = 'dddart-events',
    this.connector = _connectWebSocketChannel,
    this.onCatchUpNeeded,
    this.connectionAckTimeout = const Duration(seconds: 10),
    this.subscribeAckTimeout = const Duration(seconds: 10),
  });

  /// AppSync Events realtime endpoint, for example:
  /// `wss://example.appsync-realtime-api.us-east-1.amazonaws.com/event/realtime`.
  final Uri realtimeEndpoint;

  /// AppSync Events channel path to subscribe to.
  final String channel;

  /// Authorization used for the WebSocket handshake and subscribe operation.
  final AppSyncEventsAuthorization authorization;

  /// Client-generated subscription id.
  final String subscriptionId;

  /// WebSocket connector. Inject this in tests to avoid real network IO.
  final AppSyncWebSocketConnector connector;

  /// Called when realtime activity should wake the HTTP catch-up path.
  final AppSyncCatchUpCallback? onCatchUpNeeded;

  /// Max time to wait for `connection_ack` after `connection_init`.
  final Duration connectionAckTimeout;

  /// Max time to wait for `subscribe_success` after `subscribe`.
  final Duration subscribeAckTimeout;

  final Logger _logger = Logger('dddart.events.appsync');

  final StreamController<StoredEvent> _events =
      StreamController<StoredEvent>.broadcast();

  AppSyncWebSocketConnection? _connection;
  StreamSubscription<String>? _subscription;
  Completer<void>? _connectionAck;
  Completer<void>? _subscribeAck;
  Timer? _keepAliveTimer;
  Duration _connectionTimeout = const Duration(minutes: 5);
  bool _closed = false;
  bool _connecting = false;

  /// Subscribes to remote stored-event notifications.
  ///
  /// The AppSync channel is configured on the transport. [options.topic] may be
  /// omitted or equal to the configured channel; other topics require a
  /// separate transport instance so the fake/local protocol path stays explicit
  /// for this spike.
  @override
  Stream<StoredEvent> subscribe({
    EventSubscriptionOptions options = const EventSubscriptionOptions(),
  }) {
    final topic = options.topic;
    if (topic != null && topic != channel) {
      throw ArgumentError.value(
        topic,
        'options.topic',
        'AppSyncEventsTransport is configured for channel $channel',
      );
    }

    if (_connection == null && !_connecting && !_closed) {
      unawaited(_connectAndReportErrors());
    }

    return _events.stream;
  }

  /// Publishes a stored event notification over the AppSync Events socket.
  ///
  /// This publish path is intentionally minimal and best-effort. The durable
  /// write path should still persist events before emitting realtime wakes.
  @override
  Future<void> publish(
    StoredEvent event, {
    EventPublishOptions options = const EventPublishOptions(),
  }) async {
    final targetChannel = options.topic ?? channel;
    if (_connection == null) {
      await connect();
    }

    _sendJson({
      'type': 'publish',
      'channel': targetChannel,
      'events': [jsonEncode(event.toJson())],
      'authorization': authorization.operationAuthorization,
    });
  }

  Future<void> _connectAndReportErrors() async {
    try {
      await connect();
    } catch (error, stackTrace) {
      _events.addError(error, stackTrace);
      await _notifyCatchUpNeeded();
    }
  }

  /// Opens the WebSocket and subscribes to [channel].
  Future<void> connect() async {
    if (_connection != null) {
      throw StateError('AppSyncEventsTransport is already connected');
    }
    if (_connecting) {
      throw StateError('AppSyncEventsTransport is already connecting');
    }

    _connecting = true;
    try {
      final protocols = [
        authorization.websocketSubprotocol,
        awsAppSyncEventsWebSocketProtocol,
      ];

      _connection = await connector(realtimeEndpoint, protocols);
      _subscription = _connection!.stream.listen(
        _handleRawMessage,
        onError: (Object error, StackTrace stackTrace) {
          _logger.warning('AppSync realtime stream error', error, stackTrace);
          _events.addError(error, stackTrace);
          unawaited(_notifyCatchUpNeeded());
        },
        onDone: () {
          _logger.info('AppSync realtime stream closed');
          if (!_closed) {
            unawaited(_notifyCatchUpNeeded());
          }
        },
      );

      _connectionAck = Completer<void>();
      _subscribeAck = Completer<void>();

      _sendJson({'type': 'connection_init'});
      await _connectionAck!.future.timeout(connectionAckTimeout);

      _sendJson({
        'type': 'subscribe',
        'id': subscriptionId,
        'channel': channel,
        'authorization': authorization.operationAuthorization,
      });
      await _subscribeAck!.future.timeout(subscribeAckTimeout);
    } finally {
      _connecting = false;
    }
  }

  /// Closes the subscription and WebSocket connection.
  @override
  Future<void> close() async {
    _closed = true;
    _keepAliveTimer?.cancel();

    if (_connection != null) {
      _sendJson({
        'type': 'unsubscribe',
        'id': subscriptionId,
      });
    }

    await _subscription?.cancel();
    await _connection?.close();
    await _events.close();
    _connection = null;
  }

  void _handleRawMessage(String rawMessage) {
    try {
      final message = _decodeMessage(rawMessage);
      final type = message['type'];

      switch (type) {
        case 'connection_ack':
          _handleConnectionAck(message);
        case 'ka':
          _resetKeepAliveTimer();
        case 'subscribe_success':
          if (message['id'] == subscriptionId) {
            _complete(_subscribeAck);
          }
        case 'subscribe_error':
        case 'broadcast_error':
        case 'publish_error':
          _logger.warning('AppSync realtime error message: $message');
          _completeError(_subscribeAck, StateError(message.toString()));
          _events.addError(StateError(message.toString()));
          unawaited(_notifyCatchUpNeeded());
        case 'data':
          unawaited(
            _handleDataMessage(message).catchError(
              _handleAsyncMessageError,
            ),
          );
        default:
          _logger.fine('Ignoring AppSync realtime message: $message');
      }
    } catch (error, stackTrace) {
      _logger.warning(
        'Failed to handle AppSync realtime message',
        error,
        stackTrace,
      );
      _events.addError(error, stackTrace);
      unawaited(_notifyCatchUpNeeded());
    }
  }

  _JsonObject _decodeMessage(String rawMessage) {
    final decoded = jsonDecode(rawMessage);
    return _decodeJsonObject(decoded, 'AppSync message');
  }

  void _handleConnectionAck(_JsonObject message) {
    final timeoutMs = message['connectionTimeoutMs'];
    if (timeoutMs is int && timeoutMs > 0) {
      _connectionTimeout = Duration(milliseconds: timeoutMs);
    }
    _resetKeepAliveTimer();
    _complete(_connectionAck);
  }

  void _handleAsyncMessageError(Object error, StackTrace stackTrace) {
    _logger.warning(
      'Failed to handle AppSync realtime message',
      error,
      stackTrace,
    );
    _events.addError(error, stackTrace);
    unawaited(_notifyCatchUpNeeded());
  }

  Future<void> _handleDataMessage(_JsonObject message) async {
    if (message['id'] != null && message['id'] != subscriptionId) {
      return;
    }

    final events = message['event'];
    if (events is! Iterable<Object?>) {
      throw const FormatException('AppSync data message missing event list');
    }

    for (final event in events) {
      final storedEventJson = _decodeStoredEventPayload(event);
      _events.add(StoredEvent.fromJson(storedEventJson));
    }

    await _notifyCatchUpNeeded();
  }

  _JsonObject _decodeStoredEventPayload(Object? payload) {
    var decoded = payload;

    if (decoded is String) {
      decoded = jsonDecode(decoded);
    }

    return _decodeJsonObject(decoded, 'serialized StoredEvent');
  }

  _JsonObject _decodeJsonObject(Object? decoded, String description) {
    if (decoded is Map<String, Object?>) {
      return decoded;
    }
    if (decoded is Map<Object?, Object?>) {
      return decoded.map((key, value) {
        if (key is! String) {
          throw FormatException(
            'Expected $description object with string keys, got $decoded',
          );
        }
        return MapEntry(key, value);
      });
    }
    throw FormatException('Expected $description object, got $decoded');
  }

  void _resetKeepAliveTimer() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer(_connectionTimeout, () async {
      _logger.warning('AppSync keep-alive timeout after $_connectionTimeout');
      await _connection?.close();
      await _notifyCatchUpNeeded();
    });
  }

  void _sendJson(_JsonObject message) {
    final connection = _connection;
    if (connection == null) {
      throw StateError('AppSyncEventsTransport is not connected');
    }
    connection.send(jsonEncode(message));
  }

  static void _complete(Completer<void>? completer) {
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  static void _completeError(
    Completer<void>? completer,
    Object error,
  ) {
    if (completer != null && !completer.isCompleted) {
      completer.completeError(error);
    }
  }

  Future<void> _notifyCatchUpNeeded() async {
    await onCatchUpNeeded?.call();
  }
}

class _WebSocketChannelConnection implements AppSyncWebSocketConnection {
  _WebSocketChannelConnection(this._channel);

  final WebSocketChannel _channel;

  @override
  Stream<String> get stream => _channel.stream.map(_decodeWebSocketMessage);

  @override
  void send(String message) {
    _channel.sink.add(message);
  }

  @override
  Future<void> close() async {
    await _channel.sink.close();
  }

  static String _decodeWebSocketMessage(Object? message) {
    if (message is String) {
      return message;
    }
    if (message is List<int>) {
      return utf8.decode(message);
    }
    throw FormatException('Expected AppSync WebSocket text frame, got $message');
  }
}

Future<AppSyncWebSocketConnection> _connectWebSocketChannel(
  Uri uri,
  Iterable<String> protocols,
) async {
  final channel = WebSocketChannel.connect(uri, protocols: protocols);
  await channel.ready;
  return _WebSocketChannelConnection(channel);
}
