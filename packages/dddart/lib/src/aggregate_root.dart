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
  final List<_PendingEvent<I>> _uncommittedEvents = [];

  /// Raises a domain event and adds it to the uncommitted events list.
  ///
  /// This method should be called within domain logic when something
  /// significant happens that other parts of the system need to know about.
  /// Events are collected but not automatically published, allowing for
  /// transaction boundaries and batch publishing.
  void raiseEvent(DomainEvent<I> event) {
    _uncommittedEvents.add(_PendingEvent(event));
  }

  /// Returns an unmodifiable list of uncommitted events.
  ///
  /// These are events that have been raised but not yet published.
  /// This method is typically called by infrastructure code to retrieve
  /// events for publishing to an event bus or message broker.
  List<DomainEvent<I>> getUncommittedEvents() {
    return List.unmodifiable(_uncommittedEvents.map((entry) => entry.event));
  }

  /// Captures the events belonging to one save/publication operation.
  ///
  /// Capture before awaiting persistence. Acknowledging this batch never removes
  /// events raised afterward, even when the same event object is raised again.
  /// Failed publications should remain unacknowledged and available for retry.
  PendingEventBatch<I> captureUncommittedEvents() => PendingEventBatch._(
        this,
        List.unmodifiable(_uncommittedEvents),
        _uncommittedEvents.remove,
      );

  /// Acknowledges a captured batch, or clears current events for legacy callers.
  ///
  /// Infrastructure performing asynchronous work must pass a batch captured
  /// before its first await. For partial success, acknowledge individual events
  /// on [PendingEventBatch] instead. Calling without a batch retains the legacy
  /// immediate clear behavior and is unsuitable for asynchronous saves.
  void markEventsAsCommitted({PendingEventBatch<I>? batch}) {
    if (batch == null) {
      _uncommittedEvents.clear();
      return;
    }
    if (!identical(batch._owner, this)) {
      throw ArgumentError('The event batch belongs to another aggregate');
    }
    batch.acknowledgeAll();
  }
}

/// An immutable event snapshot with occurrence-specific acknowledgment.
///
/// The snapshot is transient infrastructure bookkeeping, not aggregate state or
/// a serialized transport contract. Capture it through [AggregateRoot].
class PendingEventBatch<I extends Identity> {
  PendingEventBatch._(this._owner, this._entries, this._remove)
      : events = List.unmodifiable(_entries.map((entry) => entry.event));

  final Object _owner;
  final List<_PendingEvent<I>> _entries;
  final bool Function(_PendingEvent<I>) _remove;
  final Set<_PendingEvent<I>> _acknowledged = {};

  /// Events present when the batch was captured, in raise order.
  final List<DomainEvent<I>> events;

  /// Acknowledges one captured occurrence of this exact event instance.
  ///
  /// This is idempotent after all captured occurrences of the instance have been
  /// acknowledged. A separately raised event with the same UUID is not matched.
  /// Throws [ArgumentError] when the event was not present in this batch.
  void acknowledge(DomainEvent<I> event) {
    for (final entry in _entries) {
      if (identical(entry.event, event) && !_acknowledged.contains(entry)) {
        _remove(entry);
        _acknowledged.add(entry);
        return;
      }
    }
    if (!_entries.any((entry) => identical(entry.event, event))) {
      throw ArgumentError('The event does not belong to this captured batch');
    }
  }

  /// Acknowledges all occurrences captured in this batch.
  void acknowledgeAll() {
    for (final entry in _entries) {
      if (_acknowledged.add(entry)) _remove(entry);
    }
  }
}

class _PendingEvent<I extends Identity> {
  _PendingEvent(this.event);

  final DomainEvent<I> event;
}

/// An aggregate with a supplied or automatically generated UUID identity.
abstract class UuidAggregateRoot extends AggregateRoot<UuidValue> {
  /// Creates a UUID aggregate, generating [id] when omitted.
  UuidAggregateRoot({UuidValue? id, super.createdAt, super.updatedAt})
      : super(id: id ?? UuidValue.generate());
}
