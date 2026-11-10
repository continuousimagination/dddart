import 'package:dddart/dddart.dart';
import 'package:dddart_events_distributed/src/aggregate_reference.dart';
import 'package:dddart_events_distributed/src/event_envelope.dart';

/// Progress in one logical aggregate stream, independent of channel rotation.
///
/// Transport encodings are opaque to clients and never grant permission. The
/// server must check aggregate access independently of any supplied checkpoint.
class EventCheckpoint {
  /// Describes progress at an ingestion position observed by the server.
  EventCheckpoint({
    required this.streamKey,
    required this.position,
    required DateTime observedAt,
  }) : observedAt = observedAt.toUtc() {
    if (streamKey.isEmpty || position < 0) {
      throw ArgumentError('Invalid event checkpoint');
    }
  }

  /// Canonical key of the logical aggregate stream.
  final String streamKey;

  /// Last considered committed ingestion position, not a client timestamp.
  final int position;

  /// Server recovery anchor; retained across incomplete catch-up pages.
  final DateTime observedAt;
}

/// An accepted event and its server-assigned history metadata.
class RecordedEvent {
  /// Creates a history entry with a positive committed position.
  RecordedEvent({
    required this.envelope,
    required this.position,
    required DateTime ingestedAt,
  }) : ingestedAt = ingestedAt.toUtc() {
    if (position < 1) throw ArgumentError.value(position, 'position');
  }

  /// The separately published event record.
  final EventEnvelope envelope;

  /// Server-assigned position within the aggregate's retained history.
  final int position;

  /// Server ingestion time, independent of the event's occurrence time.
  final DateTime ingestedAt;
}

/// One bounded catch-up page and the next per-aggregate progress checkpoint.
class EventPage {
  /// Freezes the page collection; application code does not own store state.
  EventPage({
    required Iterable<RecordedEvent> events,
    required this.checkpoint,
    required this.hasMore,
  }) : events = List.unmodifiable(events);

  /// Events in stored ingestion-position order, not guaranteed live order.
  final List<RecordedEvent> events;

  /// Position considered by this page, including deliberately skipped entries.
  final EventCheckpoint checkpoint;

  /// Whether more records remain before this read's observed head.
  final bool hasMore;
}

/// Recovery history is no longer sufficient for the supplied checkpoint.
///
/// Applications must reload aggregate state through their repository and start a
/// fresh watch. The event SDK must not silently overwrite application state.
class EventHistoryExpired implements Exception {
  /// Identifies the aggregate requiring explicit application resynchronization.
  const EventHistoryExpired(this.aggregate);

  /// Aggregate whose required retained history has expired or been deleted.
  final AggregateReference<Identity> aggregate;

  @override
  String toString() => 'EventHistoryExpired: ${aggregate.kind}';
}

/// Repository contract for server-side, aggregate-scoped retained event history.
///
/// Implementations must atomically expose committed positions and records. A
/// counter allocated before a delayed record insertion does not meet this
/// contract. Append retries with the same retained UUID/content are idempotent;
/// conflicting UUID reuse is rejected. This does not imply ordered live delivery.
abstract interface class AggregateEventRepository
    implements Repository<EventEnvelope, UuidValue> {
  /// Configured history window; the default implementation uses seven days.
  Duration get retention;

  /// Accepts an occurrence and returns its committed ingestion metadata.
  Future<RecordedEvent> append(EventEnvelope envelope);

  /// Captures a fresh watch's current committed head without replaying history.
  Future<EventCheckpoint> head(AggregateReference<Identity> aggregate);

  /// Reads a bounded history page after one aggregate's checkpoint.
  ///
  /// Throws [EventHistoryExpired] when complete recovery cannot be guaranteed.
  /// Checkpoints cannot be used with a different aggregate or a future position.
  Future<EventPage> read(
    AggregateReference<Identity> aggregate, {
    required EventCheckpoint after,
    int limit = 100,
  });

  /// Deletes records ingested before [timestamp], retaining stream heads.
  Future<void> deleteOlderThan(DateTime timestamp);
}
