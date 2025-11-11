import 'dart:async';

import 'package:dddart/src/domain_event.dart';
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
  final Logger _logger = Logger('dddart.eventbus');
  final StreamController<DomainEvent> _controller =
      StreamController<DomainEvent>.broadcast();

  /// Publishes a domain event to all subscribers.
  ///
  /// The event will be delivered to all listeners that have subscribed
  /// to the event's type or any of its supertypes.
  ///
  /// [event] The domain event to publish.
  void publish(DomainEvent event) {
    if (_controller.isClosed) {
      throw StateError('Cannot publish event: EventBus is closed');
    }
    _logger.fine(
        'Publishing event: ${event.runtimeType} for aggregate ${event.aggregateId}',);
    _controller.add(event);
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
  Stream<T> on<T extends DomainEvent>() {
    _logger.fine('Creating subscription for event type: $T');
    final stream = _controller.stream.where((event) => event is T).cast<T>();

    // Wrap the stream to log handler exceptions
    return stream.transform(
      StreamTransformer<T, T>.fromHandlers(
        handleData: (event, sink) {
          sink.add(event);
        },
        handleError: (error, stackTrace, sink) {
          _logger.severe('Event handler threw exception', error, stackTrace);
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
    _logger.info('EventBus closing');
    await _controller.close();
  }

  /// Returns true if the event bus has been closed.
  bool get isClosed => _controller.isClosed;
}
