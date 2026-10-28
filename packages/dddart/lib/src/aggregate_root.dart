import 'package:dddart/src/domain_event.dart';
import 'package:dddart/src/entity.dart';
import 'package:dddart/src/identity.dart';
import 'package:dddart/src/uuid_value.dart';

/// Base class for aggregate roots in the DDD framework.
///
/// An aggregate root is the entry point to an aggregate and extends UuidEntity
/// to provide identity and lifecycle management. It serves as the boundary
/// for consistency and transaction management within the aggregate.
abstract class AggregateRoot<I extends Identity> extends Entity<I> {
  /// Creates an aggregate root with an explicit identity.
  ///
  /// Use [UuidAggregateRoot] for automatic UUID generation.
  /// If [createdAt] is not provided, the current time will be used.
  /// If [updatedAt] is not provided, the current time will be used.
  AggregateRoot({
    required super.id,
    super.createdAt,
    super.updatedAt,
  });

  /// Private list to store uncommitted domain events.
  final List<DomainEvent<I>> _uncommittedEvents = [];

  /// Raises a domain event and adds it to the uncommitted events list.
  ///
  /// This method should be called within domain logic when something
  /// significant happens that other parts of the system need to know about.
  /// Events are collected but not automatically published, allowing for
  /// transaction boundaries and batch publishing.
  void raiseEvent(DomainEvent<I> event) {
    _uncommittedEvents.add(event);
  }

  /// Returns an unmodifiable list of uncommitted events.
  ///
  /// These are events that have been raised but not yet published.
  /// This method is typically called by infrastructure code to retrieve
  /// events for publishing to an event bus or message broker.
  List<DomainEvent<I>> getUncommittedEvents() {
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

/// An aggregate with a supplied or automatically generated UUID identity.
abstract class UuidAggregateRoot extends AggregateRoot<UuidValue> {
  /// Creates a UUID aggregate, generating [id] when omitted.
  UuidAggregateRoot({UuidValue? id, super.createdAt, super.updatedAt})
      : super(id: id ?? UuidValue.generate());
}
