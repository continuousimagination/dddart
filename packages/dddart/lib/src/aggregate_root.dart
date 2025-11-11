import 'package:dddart/src/domain_event.dart';
import 'package:dddart/src/entity.dart';

/// Base class for aggregate roots in the DDD framework.
///
/// An aggregate root is the entry point to an aggregate and extends Entity
/// to provide identity and lifecycle management. It serves as the boundary
/// for consistency and transaction management within the aggregate.
abstract class AggregateRoot extends Entity {
  /// Creates a new AggregateRoot with optional parameters.
  ///
  /// If [id] is not provided, a new UUID will be generated.
  /// If [createdAt] is not provided, the current time will be used.
  /// If [updatedAt] is not provided, the current time will be used.
  AggregateRoot({
    super.id,
    super.createdAt,
    super.updatedAt,
  });

  /// Private list to store uncommitted domain events.
  final List<DomainEvent> _uncommittedEvents = [];

  /// Raises a domain event and adds it to the uncommitted events list.
  ///
  /// This method should be called within domain logic when something
  /// significant happens that other parts of the system need to know about.
  /// Events are collected but not automatically published, allowing for
  /// transaction boundaries and batch publishing.
  void raiseEvent(DomainEvent event) {
    _uncommittedEvents.add(event);
  }

  /// Returns an unmodifiable list of uncommitted events.
  ///
  /// These are events that have been raised but not yet published.
  /// This method is typically called by infrastructure code to retrieve
  /// events for publishing to an event bus or message broker.
  List<DomainEvent> getUncommittedEvents() {
    return List.unmodifiable(_uncommittedEvents);
  }

  /// Clears the list of uncommitted events.
  ///
  /// This method should be called after events have been successfully
  /// published to prevent duplicate publishing. It marks the events
  /// as committed and removes them from the internal collection.
  void markEventsAsCommitted() {
    _uncommittedEvents.clear();
  }
}
