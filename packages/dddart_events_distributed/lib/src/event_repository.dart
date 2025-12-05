import 'package:dddart/dddart.dart';
import 'package:dddart_events_distributed/src/stored_event.dart';

/// Extended repository interface for time-based event queries.
///
/// This abstract class extends the base Repository interface to add
/// time-range query methods needed for distributed event systems.
abstract class EventRepository<T extends StoredEvent> implements Repository<T> {
  /// Finds all events with createdAt >= timestamp.
  ///
  /// Implementations should use database-specific queries optimized
  /// for time-range lookups (e.g., indexed queries on createdAt field).
  ///
  /// Returns a list of events ordered by createdAt ascending.
  Future<List<T>> findSince(DateTime timestamp);

  /// Deletes all events with createdAt < timestamp.
  ///
  /// Used for cleanup of old events. Implementations should handle
  /// large deletions efficiently (batching, etc.).
  ///
  /// This method is typically called periodically to prevent unbounded
  /// growth of the event store.
  Future<void> deleteOlderThan(DateTime timestamp);
}
