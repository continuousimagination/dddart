import 'dart:async';

import 'package:dddart/dddart.dart';
import 'package:dddart_events_distributed/src/stored_event.dart';

/// Converts a local domain event into the durable stored-event envelope used by
/// distributed notifications.
typedef StoredEventFactory = StoredEvent Function(DomainEvent event);

/// Converts a remote stored-event notification into a local domain event.
///
/// Returning `null` means the receiver intentionally does not understand the
/// event type and should skip it. JSON parsing, generated registry lookup, and
/// schema validation stay behind this codec boundary instead of leaking raw
/// maps into the realtime transport interface.
typedef StoredEventDecoder = DomainEvent? Function(StoredEvent storedEvent);

/// Resolves which recipients should receive a best-effort event notification.
///
/// Implementations can map authorization fields such as tenant, user, or
/// session identifiers to provider-specific recipient/channel IDs. The resolver
/// returns neutral string identifiers so DDDart does not depend on AppSync, IoT,
/// API Gateway, Flutter, AWS, or any other transport/runtime.
// ignore: one_member_abstracts
abstract interface class EventVisibilityResolver {
  /// Returns recipient identifiers that should be notified for [storedEvent].
  Future<List<String>> recipientsFor(StoredEvent storedEvent);
}

/// Subscribe options for a neutral distributed event notification transport.
///
/// This is intentionally small. Realtime notifications are best-effort wake-up
/// signals only; clients must still use the durable `/events?since=` catch-up
/// API for correctness after missed messages, reconnects, or transport loss.
class EventSubscriptionOptions {
  /// Creates subscription options.
  const EventSubscriptionOptions({
    this.topic,
    this.recipientId,
    this.metadata = const {},
  });

  /// Optional logical topic/channel name understood by the adapter layer.
  final String? topic;

  /// Optional logical recipient identifier understood by the adapter layer.
  final String? recipientId;

  /// Adapter-specific metadata that remains outside DDDart core semantics.
  final Map<String, String> metadata;
}

/// Publish options for a neutral distributed event notification transport.
///
/// These options describe notification routing only. They must not be used as
/// authoritative event ordering, storage, or replay metadata; `/events?since=`
/// remains the durable catch-up source and clients should dedupe by eventId.
class EventPublishOptions {
  /// Creates publish options.
  const EventPublishOptions({
    this.topic,
    this.recipients = const <String>[],
    this.metadata = const {},
  });

  /// Optional logical topic/channel name understood by the adapter layer.
  final String? topic;

  /// Optional logical recipient identifiers understood by the adapter layer.
  final List<String> recipients;

  /// Adapter-specific metadata that remains outside DDDart core semantics.
  final Map<String, String> metadata;
}

/// Transport boundary for best-effort distributed event notifications.
///
/// Implementations adapt this interface to concrete transports such as
/// WebSockets, MQTT, AppSync, IoT Core, API Gateway, SSE, or in-memory fakes.
/// The payload is a [StoredEvent], not a transport-specific envelope, so remote
/// notifications can be deserialized and published into the normal local
/// [EventBus].
///
/// Realtime is deliberately not the correctness path: messages may be missed,
/// duplicated, delayed, or delivered out of order. Durable catch-up stays in the
/// repository-backed `/events?since=` path, and consumers must dedupe by
/// `eventId` when combining catch-up and realtime notifications.
abstract interface class DistributedEventTransport {
  /// Subscribes to remote stored-event notifications.
  Stream<StoredEvent> subscribe({
    EventSubscriptionOptions options = const EventSubscriptionOptions(),
  });

  /// Publishes a stored-event notification to the distributed transport.
  Future<void> publish(
    StoredEvent event, {
    EventPublishOptions options = const EventPublishOptions(),
  });

  /// Releases transport resources.
  Future<void> close();
}

/// Publishes local domain events as best-effort distributed notifications.
class EventNotificationPublisher {
  /// Creates an event notification publisher.
  EventNotificationPublisher({
    required DistributedEventTransport transport,
    StoredEventFactory? storedEventFactory,
    EventVisibilityResolver? visibilityResolver,
  })  : _transport = transport,
        _storedEventFactory = storedEventFactory ?? StoredEvent.fromDomainEvent,
        _visibilityResolver = visibilityResolver;

  final DistributedEventTransport _transport;
  final StoredEventFactory _storedEventFactory;
  final EventVisibilityResolver? _visibilityResolver;

  /// Publishes [event] to the transport as a [StoredEvent] notification.
  Future<void> publish(
    DomainEvent event, {
    String? topic,
    Map<String, String> metadata = const {},
  }) async {
    final storedEvent = _storedEventFactory(event);
    final visibilityResolver = _visibilityResolver;
    final recipients = visibilityResolver == null
        ? const <String>[]
        : await visibilityResolver.recipientsFor(storedEvent);

    await _transport.publish(
      storedEvent,
      options: EventPublishOptions(
        topic: topic,
        recipients: recipients,
        metadata: metadata,
      ),
    );
  }
}

/// Bridges remote stored-event notifications into a local [EventBus].
///
/// This adapter keeps DDDart transport-neutral while making the realtime path
/// useful: incoming [StoredEvent] payloads are decoded through the supplied
/// [StoredEventDecoder] and republished on the normal local event bus. Unknown
/// event types are skipped so one service can ignore events it does not
/// understand.
class DistributedEventBusBridge {
  /// Creates a distributed event bus bridge.
  DistributedEventBusBridge({
    required EventBus localEventBus,
    required DistributedEventTransport transport,
    required StoredEventDecoder storedEventDecoder,
    EventSubscriptionOptions subscriptionOptions =
        const EventSubscriptionOptions(),
    bool dedupeByEventId = true,
  })  : _localEventBus = localEventBus,
        _transport = transport,
        _storedEventDecoder = storedEventDecoder,
        _subscriptionOptions = subscriptionOptions,
        _dedupeByEventId = dedupeByEventId;

  final EventBus _localEventBus;
  final DistributedEventTransport _transport;
  final StoredEventDecoder _storedEventDecoder;
  final EventSubscriptionOptions _subscriptionOptions;
  final bool _dedupeByEventId;
  final Set<UuidValue> _seenEventIds = <UuidValue>{};
  final Logger _logger = Logger('dddart.events.distributed.bridge');

  StreamSubscription<StoredEvent>? _subscription;

  /// Starts consuming remote stored-event notifications.
  void start() {
    if (_subscription != null) {
      throw StateError('DistributedEventBusBridge has already been started');
    }

    _subscription = _transport
        .subscribe(options: _subscriptionOptions)
        .listen(_publishStoredEvent, onError: _handleError);
  }

  /// Stops consuming remote notifications.
  Future<void> close() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  void _publishStoredEvent(StoredEvent storedEvent) {
    if (_dedupeByEventId && !_seenEventIds.add(storedEvent.id)) {
      _logger.finer('Skipping duplicate remote event: ${storedEvent.id}');
      return;
    }

    try {
      final event = _storedEventDecoder(storedEvent);
      if (event == null) {
        _logger.fine('Unknown remote event type: ${storedEvent.eventType}');
        return;
      }

      _localEventBus.publish(event);
      _logger.fine('Published remote event: ${storedEvent.eventType}');
    } catch (error, stackTrace) {
      _logger.severe(
        'Failed to process remote event: ${storedEvent.eventType}',
        error,
        stackTrace,
      );
    }
  }

  void _handleError(Object error, StackTrace stackTrace) {
    _logger.severe('Distributed event transport stream error', error, stackTrace);
  }
}
