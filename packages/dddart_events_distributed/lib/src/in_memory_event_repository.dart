import 'package:dddart/dddart.dart';
import 'package:dddart_events_distributed/src/event_repository.dart';
import 'package:dddart_events_distributed/src/stored_event.dart';

/// In-memory implementation of [EventRepository] for testing and development.
///
/// Extends [InMemoryRepository] to add time-based query methods needed for
/// distributed event systems. This implementation is useful for:
/// * Unit testing event distribution logic
/// * Integration testing without database setup
/// * Rapid prototyping and development
/// * Learning and experimentation
///
/// Like [InMemoryRepository], this should not be used in production as data
/// is not persisted and will be lost when the application terminates.
class InMemoryEventRepository extends InMemoryRepository<StoredEvent>
    implements EventRepository<StoredEvent> {
  @override
  Future<List<StoredEvent>> findSince(DateTime timestamp) async {
    final allEvents = getAll();
    return allEvents
        .where((event) => event.createdAt.isAfter(timestamp) ||
            event.createdAt.isAtSameMomentAs(timestamp))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  @override
  Future<void> deleteOlderThan(DateTime timestamp) async {
    final allEvents = getAll();
    final toDelete = allEvents
        .where((event) => event.createdAt.isBefore(timestamp))
        .map((event) => event.id)
        .toList();

    for (final id in toDelete) {
      await deleteById(id);
    }
  }

  /// Returns all events in the repository.
  ///
  /// Useful for testing and debugging.
  Future<List<StoredEvent>> findAll() async {
    return getAll();
  }

  /// Returns the count of stored events.
  ///
  /// Useful for testing and verification.
  int get count => getAll().length;
}
