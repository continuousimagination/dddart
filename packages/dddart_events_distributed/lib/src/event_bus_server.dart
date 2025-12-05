import 'dart:async';

import 'package:dddart/dddart.dart';
import 'package:dddart_events_distributed/src/event_repository.dart';
import 'package:dddart_events_distributed/src/stored_event.dart';

/// Server-side component that wraps EventBus with automatic persistence
/// and HTTP endpoints for event distribution.
///
/// The EventBusServer listens to all events published on the local EventBus
/// and automatically persists them to the configured repository. This enables
/// distributed event systems where clients can poll for events via HTTP.
///
/// Example usage:
/// ```dart
/// final eventBus = EventBus();
/// final repository = InMemoryEventRepository();
///
/// final server = EventBusServer<StoredEvent>(
///   localEventBus: eventBus,
///   eventRepository: repository,
///   storedEventFactory: StoredEvent.fromDomainEvent,
///   retentionDuration: Duration(days: 30),
/// );
///
/// // Publish events - they will be automatically persisted
/// eventBus.publish(UserCreatedEvent(aggregateId: userId));
///
/// // Clean up old events periodically
/// await server.cleanup();
///
/// // Close when done
/// await server.close();
/// ```
class EventBusServer<T extends StoredEvent> {
  /// Creates an EventBusServer.
  ///
  /// [localEventBus] is the local EventBus to wrap with persistence.
  /// [eventRepository] is the repository for storing events.
  /// [storedEventFactory] is a factory function that converts
  /// DomainEvents to StoredEvents.
  /// [retentionDuration] is optional and specifies how long to keep
  /// events before cleanup.
  EventBusServer({
    required this.localEventBus,
    required this.eventRepository,
    required this.storedEventFactory,
    this.retentionDuration,
  }) {
    // Subscribe to all events and persist them
    _subscription = localEventBus.on<DomainEvent>().listen(_persistEvent);
    _logger.info('EventBusServer started');
  }

  /// The local EventBus being wrapped.
  final EventBus localEventBus;

  /// The repository for storing events.
  final EventRepository<T> eventRepository;

  /// Optional retention duration for event cleanup.
  final Duration? retentionDuration;

  /// Factory function to convert DomainEvents to StoredEvents.
  final T Function(DomainEvent) storedEventFactory;

  StreamSubscription<DomainEvent>? _subscription;
  final Logger _logger = Logger('dddart.events.server');

  /// Publishes event to local bus (which triggers persistence).
  void publish(DomainEvent event) {
    localEventBus.publish(event);
  }

  /// Subscribes to events on local bus.
  Stream<E> on<E extends DomainEvent>() {
    return localEventBus.on<E>();
  }

  /// Persists event to repository.
  Future<void> _persistEvent(DomainEvent event) async {
    try {
      final stored = storedEventFactory(event);
      await eventRepository.save(stored);
      _logger.fine('Persisted event: ${event.runtimeType} (${event.eventId})');
    } catch (e, stackTrace) {
      _logger.severe(
        'Failed to persist event: ${event.runtimeType}',
        e,
        stackTrace,
      );
    }
  }

  /// Cleans up old events based on retention duration.
  ///
  /// This method deletes all events older than the configured retention
  /// duration. If no retention duration is configured, this method logs
  /// a warning and returns.
  ///
  /// Throws [StateError] if called when no retentionDuration is configured.
  Future<void> cleanup() async {
    if (retentionDuration == null) {
      _logger.warning('cleanup() called but no retentionDuration configured');
      return;
    }

    final cutoff = DateTime.now().subtract(retentionDuration!);
    try {
      await eventRepository.deleteOlderThan(cutoff);
      _logger.info('Cleaned up events older than $cutoff');
    } catch (e, stackTrace) {
      _logger.severe('Failed to cleanup old events', e, stackTrace);
    }
  }

  /// Closes the server and releases resources.
  ///
  /// Cancels the event subscription and closes the local EventBus.
  /// After calling close(), no more events can be published.
  Future<void> close() async {
    _logger.info('EventBusServer closing');
    await _subscription?.cancel();
    await localEventBus.close();
  }
}
