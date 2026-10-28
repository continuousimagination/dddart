import 'dart:async';
import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_events_distributed/src/event_registry.dart';
import 'package:dddart_events_distributed/src/stored_event.dart';
import 'package:http/http.dart' as http;

/// Client-side component that polls for events and optionally forwards
/// local events.
///
/// The EventBusClient wraps a local EventBus and adds HTTP polling to
/// retrieve events from a remote server. It can also optionally forward
/// locally-published events to the server.
///
/// Example usage:
/// ```dart
/// final eventBus = EventBus();
/// final eventRegistry = EventRegistry()
///   ..registerSerializer<UserCreatedEvent>(
///     'user.created.v1', UserCreatedEventJsonSerializer(),
///   );
///
/// final client = EventBusClient(
///   localEventBus: eventBus,
///   serverUrl: 'http://localhost:8080',
///   eventRegistry: eventRegistry,
///   pollingInterval: Duration(seconds: 5),
///   autoForward: true,
/// );
///
/// // Subscribe to events (local and remote)
/// eventBus.on<UserCreatedEvent>().listen((event) {
///   print('User created: ${event.userId}');
/// });
///
/// // Close when done
/// await client.close();
/// ```
class EventBusClient {
  /// Creates an EventBusClient.
  ///
  /// [localEventBus] is the local EventBus to wrap with polling.
  /// [serverUrl] is the base URL of the event server.
  /// [eventRegistry] supplies explicit stable event codecs and identity codecs.
  /// [pollingInterval] specifies how often to poll for new events.
  /// [autoForward] enables automatic forwarding of local events to server.
  /// [initialTimestamp] sets the starting point for event retrieval.
  /// [httpClient] is optional and allows injecting a custom HTTP client.
  /// [authToken] is an optional authentication token (e.g., JWT) to include
  /// in requests as a Bearer token.
  EventBusClient({
    required this.localEventBus,
    required this.serverUrl,
    required this.eventRegistry,
    this.pollingInterval = const Duration(seconds: 5),
    this.autoForward = false,
    DateTime? initialTimestamp,
    http.Client? httpClient,
    String? authToken,
    this.authTokenProvider,
    this.requestTimeout = const Duration(seconds: 2),
  })  : _httpClient = httpClient ?? http.Client(),
        _authToken = authToken {
    _lastTimestamp = initialTimestamp ?? DateTime.now().toUtc();
    _logger.info('EventBusClient starting with lastTimestamp: $_lastTimestamp');

    // Start polling
    _startPolling();

    // Optionally forward local events to server
    if (autoForward) {
      _subscription =
          localEventBus.on<DomainEvent<Identity>>().listen(_forwardEvent);
      _logger.info('Auto-forward enabled');
    }
  }

  /// The local EventBus being wrapped.
  final EventBus localEventBus;

  /// The base URL of the event server.
  final String serverUrl;

  /// Explicit event serializers/factories with stable wire discriminators.
  final EventRegistry eventRegistry;

  /// How often to poll for new events.
  final Duration pollingInterval;

  /// Whether to automatically forward local events to the server.
  final bool autoForward;

  /// HTTP client for making requests.
  final http.Client _httpClient;

  /// Optional authentication token for requests.
  final String? _authToken;

  /// Acquire current credentials for each request instead of retaining a token.
  final Future<String?> Function()? authTokenProvider;

  /// Time allowed for a complete polling response before requesting cancellation.
  ///
  /// The default is two seconds. Increase this for slower endpoints. Late
  /// responses are ignored. A custom HTTP client that does not support aborting
  /// requests keeps the polling slot until its outstanding request settles.
  final Duration requestTimeout;
  bool _polling = false;
  bool _closed = false;
  Completer<void>? _pollAbort;
  final Set<String> _seenAtTimestamp = {};

  /// Timestamp of the last received event.
  late DateTime _lastTimestamp;

  /// Timer for periodic polling.
  Timer? _pollingTimer;

  /// Subscription to local EventBus for forwarding.
  StreamSubscription<DomainEvent<Identity>>? _subscription;

  final Logger _logger = Logger('dddart.events.client');

  /// Starts polling for events.
  void _startPolling() {
    _pollingTimer = Timer.periodic(pollingInterval, (_) => _poll());
    _logger.fine('Polling started with interval: $pollingInterval');
  }

  /// Polls server for new events.
  Future<void> _poll() async {
    if (_closed || _polling) return;
    _polling = true;
    Timer? timeout;
    try {
      final url = Uri.parse('$serverUrl/events').replace(
        queryParameters: {'since': _lastTimestamp.toIso8601String()},
      );

      _logger.finest('Polling: $url');

      // Build headers with optional authentication
      final headers = <String, String>{};
      final token =
          authTokenProvider == null ? _authToken : await authTokenProvider!();
      if (_closed) return;
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final abort = Completer<void>();
      _pollAbort = abort;
      var timedOut = false;
      timeout = Timer(requestTimeout, () {
        timedOut = true;
        if (!abort.isCompleted) abort.complete();
        _logger.warning('Poll timed out; awaiting transport cancellation.');
      });
      final request = http.AbortableRequest(
        'GET',
        url,
        abortTrigger: abort.future,
      )..headers.addAll(headers);
      // Keep single-flight ownership through both headers and response body.
      // A timeout requests cancellation; it never releases a still-live request.
      final response = await http.Response.fromStream(
        await _httpClient.send(request),
      );
      timeout.cancel();
      if (_closed || timedOut) return;

      if (response.statusCode == 200) {
        final eventsJson = (jsonDecode(response.body) as List)
            .map((value) => Map<String, dynamic>.from(value as Map))
            .toList();
        // A server batch may be unordered. Advance the inclusive cursor only
        // after earlier entries in that same batch have been considered.
        DateTime timestamp(Map<String, dynamic> event) =>
            DateTime.tryParse(event['createdAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        eventsJson
            .sort((left, right) => timestamp(left).compareTo(timestamp(right)));

        // Use FINEST for empty polls to reduce noise, FINE for actual events
        if (eventsJson.isEmpty) {
          _logger.finest('Received 0 events from server');
        } else {
          _logger.fine('Received ${eventsJson.length} events from server');
        }

        for (final eventJson in eventsJson) {
          await _processEvent(eventJson);
        }
      } else {
        _logger.warning('Poll failed: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      _logger.severe('Poll error', e, stackTrace);
    } finally {
      timeout?.cancel();
      _pollAbort = null;
      _polling = false;
    }
  }

  /// Processes received event.
  Future<void> _processEvent(Map<String, dynamic> storedEventJson) async {
    final stored = StoredEvent<Identity>.fromJson(
      storedEventJson,
      identityCodecs: eventRegistry.identityCodecs,
    );
    final timestamp = stored.createdAt;
    final id = stored.id.uuid;
    if (_closed || timestamp.isBefore(_lastTimestamp)) return;
    if (timestamp == _lastTimestamp && _seenAtTimestamp.contains(id)) return;

    // Unknown event types retain the existing explicit skip policy. Known
    // malformed payloads throw to _poll, stop the batch and remain retryable.
    if (eventRegistry.containsKey(stored.eventType)) {
      final event = stored.restore(eventRegistry);
      localEventBus.publish(event);
      _logger.fine('Published received event: ${stored.eventType}');
    } else {
      _logger.fine('Unknown event type: ${stored.eventType} (skipping)');
    }
    if (timestamp.isAfter(_lastTimestamp)) {
      _lastTimestamp = timestamp;
      _seenAtTimestamp.clear();
    }
    _seenAtTimestamp.add(id);
  }

  /// Forwards local event to server.
  Future<void> _forwardEvent(DomainEvent<Identity> event) async {
    try {
      // Convert DomainEvent to StoredEvent for transmission
      final storedEventJson = _domainEventToStoredEvent(event);

      final url = Uri.parse('$serverUrl/events');

      // Build headers with optional authentication
      final headers = <String, String>{'Content-Type': 'application/json'};
      final token =
          authTokenProvider == null ? _authToken : await authTokenProvider!();
      if (_closed) return;
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await _httpClient.post(
        url,
        headers: headers,
        body: jsonEncode(storedEventJson),
      );

      if (response.statusCode == 201) {
        _logger.fine('Forwarded event: ${event.runtimeType}');
      } else {
        _logger.warning('Forward failed: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      _logger.severe('Failed to forward event', e, stackTrace);
    }
  }

  /// Converts a DomainEvent to a StoredEvent for transmission.
  Map<String, dynamic> _domainEventToStoredEvent(DomainEvent<Identity> event) =>
      StoredEvent<Identity>.fromDomainEvent(event, registry: eventRegistry)
          .toJson();

  /// Publishes event to local bus (and optionally forwards to server).
  void publish(DomainEvent<Identity> event) {
    localEventBus.publish(event);
  }

  /// Subscribes to events on local bus.
  Stream<E> on<E extends DomainEvent<Identity>>() {
    return localEventBus.on<E>();
  }

  /// Closes the client and releases resources.
  ///
  /// Cancels the polling timer, event subscription, closes the HTTP client,
  /// and closes the local EventBus.
  /// After calling close(), no more events can be published or received.
  Future<void> close() async {
    _closed = true;
    _logger.info('EventBusClient closing');
    _pollingTimer?.cancel();
    final abort = _pollAbort;
    if (abort != null && !abort.isCompleted) abort.complete();
    await _subscription?.cancel();
    _httpClient.close();
    await localEventBus.close();
  }
}
