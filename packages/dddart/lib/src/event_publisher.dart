import 'package:dddart/src/domain_event.dart';
import 'package:dddart/src/identity.dart';

/// Accepts originated events independently of repository or transport details.
///
/// Distributed implementations return true only after durable acceptance, not
/// after consumer handlers finish. They own bounded retry and failure logging.
/// Receiving an event from another publisher must not originate it again.
// A publisher is an injected transport boundary, not a free function.
// ignore: one_member_abstracts
abstract interface class EventPublisher {
  /// Publishes an event, preserving its occurrence ID across attempts.
  ///
  /// Returns false after a logged publication failure. An uncertain remote
  /// outcome may still have accepted the event; retry with the same UUID.
  Future<bool> publish(DomainEvent<Identity> event);
}
