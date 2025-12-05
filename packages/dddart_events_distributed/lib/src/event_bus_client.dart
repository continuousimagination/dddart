import 'dart:async';
import 'dart:convert';

import 'package:dddart/dddart.dart';
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
/// final eventRegistry = {
///   'UserCreatedEvent': UserCreatedEvent.fromJson,
///   'OrderPurchasedEvent': OrderPurchasedEvent.fromJson,
/// };
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
  /// [eventRegistry] maps event type names to deserialization functions.
  /// [pollingInterval] specifies how often to poll for new events.
  /// [autoForward] enables automatic forwarding of local events to server.
  /// [initialTimestamp] sets the starting point for event retrieval.
  /// [httpClient] is optional and allows injecting a custom HTTP client.
  EventBusClient({
    required this.localEventBus,
    required this.serverUrl,
    required this.eventRegistry,
    this.pollingInterval = const Duration(seconds: 5),
    this.autoForward = false,
    DateTime? initialTimestamp,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client() {
    _lastTimestamp = initialTimestamp ?? DateTime.now();
    _logger.info('EventBusClient starting with lastTimestamp: $_lastTimestamp');

    // Start polling
    _startPolling();

    // Optionally forward local events to server
    if (autoForward) {
      _subscription = localEventBus.on<DomainEvent>().listen(_forwardEvent);
      _logger.info('Auto-forward enabled');
    }
  }

  /// The local EventBus being wrapped.
  final EventBus localEventBus;

  /// The base URL of the event server.
  final String serverUrl;

  /// Map of event type names to deserialization factory functions.
  final Map<String, DomainEvent Function(Map<String, dynamic>)> eventRegistry;

  /// How often to poll for new events.
  final Duration pollingInterval;

  /// Whether to automatically forward local events to the server.
  final bool autoForward;

  /// HTTP client for making requests.
  final http.Client _httpClient;

  /// Timestamp of the last received event.
  late DateTime _lastTimestamp;

  /// Timer for periodic polling.
  Timer? _pollingTimer;

  /// Subscription to local EventBus for forwarding.
  StreamSubscription<DomainEvent>? _subscription;

  final Logger _logger = Logger('dddart.events.client');

  /// Starts polling for events.
  void _startPolling() {
    _pollingTimer = Timer.periodic(pollingInterval, (_) => _poll());
    _logger.fine('Polling started with interval: $pollingInterval');
  }

  /// Polls server for new events.
  Future<void> _poll() async {
    try {
      final url = Uri.parse('$serverUrl/events').replace(
        queryParameters: {'since': _lastTimestamp.toIso8601String()},
      );

      _logger.finest('Polling: $url');

      final response = await _httpClient.get(url);

      if (response.statusCode == 200) {
        final eventsJson = jsonDecode(response.body) as List;
        _logger.fine('Received ${eventsJson.length} events from server');

        for (final eventJson in eventsJson) {
          await _processEvent(eventJson as Map<String, dynamic>);
        }
      } else {
        _logger.warning('Poll failed: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      _logger.severe('Poll error', e, stackTrace);
    }
  }

  /// Processes received event.
  Future<void> _processEvent(Map<String, dynamic> storedEventJson) async {
    try {
      final eventType = storedEventJson['eventType'] as String;
      final eventDataJson = jsonDecode(storedEventJson['eventJson'] as String)
          as Map<String, dynamic>;
      final timestamp = DateTime.parse(storedEventJson['createdAt'] as String);

      // Update last timestamp to be after this event to avoid re-processing
      // Since findSince uses >=, we need to move past this timestamp
      if (timestamp.isAfter(_lastTimestamp) ||
          timestamp.isAtSameMomentAs(_lastTimestamp)) {
        _lastTimestamp = timestamp.add(const Duration(microseconds: 1));
      }

      // Deserialize using registry
      final factory = eventRegistry[eventType];
      if (factory == null) {
        _logger.fine('Unknown event type: $eventType (skipping)');
        return;
      }

      final event = factory(eventDataJson);

      // Publish to local bus
      localEventBus.publish(event);
      _logger.fine('Published received event: $eventType');
    } catch (e, stackTrace) {
      _logger.severe('Failed to process event', e, stackTrace);
    }
  }

  /// Forwards local event to server.
  Future<void> _forwardEvent(DomainEvent event) async {
    try {
      // Convert DomainEvent to StoredEvent for transmission
      final storedEventJson = _domainEventToStoredEvent(event);

      final url = Uri.parse('$serverUrl/events');
      final response = await _httpClient.post(
        url,
        headers: {'Content-Type': 'application/json'},
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
  Map<String, dynamic> _domainEventToStoredEvent(DomainEvent event) {
    // Serialize the event data
    final eventJson = <String, dynamic>{
      'eventId': event.eventId.toString(),
      'occurredAt': event.occurredAt.toIso8601String(),
      'aggregateId': event.aggregateId.toString(),
      'context': event.context,
    };

    // Try to call toJson if available (for @Serializable events)
    try {
      final dynamic dynamicEvent = event;
      // ignore: avoid_dynamic_calls
      if (dynamicEvent.toJson != null) {
        // ignore: avoid_dynamic_calls
        final eventData = dynamicEvent.toJson() as Map<String, dynamic>;
        eventJson.addAll(eventData);
      }
    } catch (_) {
      // If toJson is not available, just use base fields
    }

    // Create StoredEvent structure
    return {
      'id': event.eventId.toString(),
      'createdAt': event.occurredAt.toIso8601String(),
      'updatedAt': event.occurredAt.toIso8601String(),
      'aggregateId': event.aggregateId.toString(),
      'eventType': event.runtimeType.toString(),
      'eventJson': jsonEncode(eventJson),
      if (event.context['userId'] != null) 'userId': event.context['userId'],
      if (event.context['tenantId'] != null)
        'tenantId': event.context['tenantId'],
      if (event.context['sessionId'] != null)
        'sessionId': event.context['sessionId'],
    };
  }

  /// Publishes event to local bus (and optionally forwards to server).
  void publish(DomainEvent event) {
    localEventBus.publish(event);
  }

  /// Subscribes to events on local bus.
  Stream<E> on<E extends DomainEvent>() {
    return localEventBus.on<E>();
  }

  /// Closes the client and releases resources.
  ///
  /// Cancels the polling timer, event subscription, closes the HTTP client,
  /// and closes the local EventBus.
  /// After calling close(), no more events can be published or received.
  Future<void> close() async {
    _logger.info('EventBusClient closing');
    _pollingTimer?.cancel();
    await _subscription?.cancel();
    _httpClient.close();
    await localEventBus.close();
  }
}
