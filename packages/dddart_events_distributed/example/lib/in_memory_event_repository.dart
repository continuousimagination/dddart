/// In-memory implementation of EventRepository for examples and testing.
library;

import 'package:dddart/dddart.dart';
import 'package:dddart_events_distributed/dddart_events_distributed.dart';

/// In-memory implementation of EventRepository.
///
/// This implementation stores events in memory and provides time-range
/// queries using in-memory filtering. Suitable for examples, testing,
/// and development.
class InMemoryEventRepository extends EventRepository<StoredEvent> {
  InMemoryEventRepository() : _events = [];

  final List<StoredEvent> _events;

  @override
  Future<void> save(StoredEvent entity) async {
    // Remove existing event with same ID if present
    _events.removeWhere((e) => e.id == entity.id);
    // Add the new event
    _events.add(entity);
  }

  Future<StoredEvent?> findById(UuidValue id) async {
    try {
      return _events.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<StoredEvent> getById(UuidValue id) async {
    final event = await findById(id);
    if (event == null) {
      throw RepositoryException('Event not found: $id');
    }
    return event;
  }

  Future<List<StoredEvent>> findAll() async {
    return List.from(_events);
  }

  Future<void> delete(UuidValue id) async {
    _events.removeWhere((e) => e.id == id);
  }

  @override
  Future<void> deleteById(UuidValue id) async {
    await delete(id);
  }

  @override
  Future<List<StoredEvent>> findSince(DateTime timestamp) async {
    return _events
        .where(
          (event) =>
              event.createdAt.isAfter(timestamp) ||
              event.createdAt.isAtSameMomentAs(timestamp),
        )
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  @override
  Future<void> deleteOlderThan(DateTime timestamp) async {
    _events.removeWhere((event) => event.createdAt.isBefore(timestamp));
  }

  /// Clear all events (useful for testing).
  void clear() {
    _events.clear();
  }

  /// Get the count of stored events.
  int get count => _events.length;
}
