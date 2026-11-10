import 'dart:async';

import 'package:dddart/src/domain_event.dart';
import 'package:dddart/src/identity.dart';
import 'package:logging/logging.dart';

/// A local event bus for publishing and subscribing to domain events.
///
/// The EventBus provides a simple publish/subscribe mechanism for domain events
/// within a single application instance. It uses Dart's StreamController for
/// efficient, type-safe event distribution.
///
/// Example usage:
/// ```dart
/// final eventBus = EventBus();
///
/// // Subscribe to specific event types
/// eventBus.on<UserRegistered>().listen((event) {
///   print('User registered: ${event.userId}');
/// });
///
/// // Publish events
/// eventBus.publish(UserRegistered(userId: '123'));
///
/// // Clean up when done
/// eventBus.close();
/// ```
class EventBus {
  /// Creates a local bus with an optional application-provided logger.
  EventBus({Logger? logger}) : logger = logger ?? Logger('dddart.eventbus');

  /// Logger used for local delivery and lifecycle diagnostics.
  final Logger logger;
  final StreamController<_EventDelivery> _controller =
      StreamController<_EventDelivery>.broadcast();

  /// Publishes a domain event to all subscribers.
  ///
  /// The event will be delivered to all listeners that have subscribed
  /// to the event's type or any of its supertypes.
  ///
  /// [event] The domain event to publish.
  void publish(DomainEvent<Identity> event) {
    _dispatch(event, originated: true);
  }

  /// Delivers a received event without originating an outgoing publication.
  ///
  /// Transport adapters use this for remote receipt. Ordinary application
  /// subscribers still receive the event through [on], while forwarding and
  /// persistence bridges listening through [onPublished] do not re-originate it.
  /// Origin is delivery metadata, never a field in the domain event payload.
  void deliver(DomainEvent<Identity> event) {
    _dispatch(event, originated: false);
  }

  void _dispatch(DomainEvent<Identity> event, {required bool originated}) {
    if (_controller.isClosed) {
      throw StateError('Cannot publish event: EventBus is closed');
    }
    logger.fine(
      'Publishing event: ${event.runtimeType} for aggregate ${event.aggregateId}',
    );
    _controller.add(_EventDelivery(event, originated: originated));
  }

  /// Subscribes to events of a specific type.
  ///
  /// Returns a Stream that emits only events of type [T] or its subtypes.
  /// Multiple subscriptions can be created for the same or different event types.
  ///
  /// Type parameter [T] must extend [DomainEvent].
  ///
  /// Example:
  /// ```dart
  /// eventBus.on<UserRegistered>().listen((event) {
  ///   // Handle UserRegistered events
  /// });
  /// ```
  Stream<T> on<T extends DomainEvent<Identity>>() {
    return _events<T>(originatedOnly: false);
  }

  /// Subscribes only to events originated through [publish] on this bus.
  ///
  /// Infrastructure bridges use this to avoid forwarding remote deliveries.
  /// Application event handlers normally use [on] to see both kinds of delivery.
  Stream<T> onPublished<T extends DomainEvent<Identity>>() {
    return _events<T>(originatedOnly: true);
  }

  Stream<T> _events<T extends DomainEvent<Identity>>({
    required bool originatedOnly,
  }) {
    logger.fine('Creating subscription for event type: $T');
    final stream = _controller.stream
        .where((delivery) => !originatedOnly || delivery.originated)
        .map((delivery) => delivery.event)
        .where((event) => event is T)
        .cast<T>();

    // Wrap the stream to log handler exceptions
    return stream.transform(
      StreamTransformer<T, T>.fromHandlers(
        handleData: (event, sink) {
          sink.add(event);
        },
        handleError: (error, stackTrace, sink) {
          logger.severe('Event handler threw exception', error, stackTrace);
          sink.addError(error, stackTrace);
        },
      ),
    );
  }

  /// Closes the event bus and releases resources.
  ///
  /// After calling close(), no more events can be published.
  /// Any active subscriptions will be completed.
  Future<void> close() async {
    logger.info('EventBus closing');
    await _controller.close();
  }

  /// Returns true if the event bus has been closed.
  bool get isClosed => _controller.isClosed;
}

class _EventDelivery {
  _EventDelivery(this.event, {required this.originated});

  final DomainEvent<Identity> event;
  final bool originated;
}
