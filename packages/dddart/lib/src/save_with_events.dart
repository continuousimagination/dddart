import 'package:dddart/src/aggregate_root.dart';
import 'package:dddart/src/event_publisher.dart';
import 'package:dddart/src/identity.dart';
import 'package:logging/logging.dart';

/// Persists an aggregate and attempts publication of its captured pending events.
///
/// Capture occurs before [persist] is invoked. A persistence failure propagates
/// without publishing or acknowledging events. After successful persistence,
/// publication failure never turns the save into a failure. The publisher owns
/// retry policy and logs rejected publication; unexpected exceptions are logged
/// here and leave the affected event pending. Later events are still attempted.
///
/// Transactional adapters can supply [afterCommit] to defer publication until
/// the enclosing transaction commits. The callback must discard deferred work
/// on rollback and invoke publication outside the transaction context.
///
/// Without [publisher], this preserves an ordinary repository's save behavior.
/// This operation does not make persistence and network publication atomic, and
/// an unaccepted event is not covered by retained distributed history.
Future<void> saveWithEvents<I extends Identity>({
  required AggregateRoot<I> aggregate,
  required Future<void> Function() persist,
  EventPublisher? publisher,
  Logger? logger,
  Future<void> Function(Future<void> Function())? afterCommit,
}) async {
  final batch = publisher == null ? null : aggregate.captureUncommittedEvents();
  await persist();
  if (batch == null || publisher == null) return;

  Future<void> publish() async {
    final log = logger ?? Logger('dddart.events.publisher');
    for (final event in batch.events) {
      try {
        if (await publisher.publish(event)) batch.acknowledge(event);
      } catch (error, stackTrace) {
        log.severe(
          'Publication failed after aggregate save: ${event.eventId}',
          error,
          stackTrace,
        );
      }
    }
  }

  if (afterCommit == null) {
    await publish();
  } else {
    await afterCommit(publish);
  }
}
