# Design Document

## Overview

The domain events system provides a foundation for event-driven architecture within the DDDart framework. The design emphasizes simplicity for local events while establishing interfaces that enable future remote event distribution. The system uses Dart's native Stream capabilities for efficient, type-safe event handling across all supported platforms.

## Architecture

### Core Components

The event system consists of three main layers:

1. **Domain Layer**: Domain events and aggregate event collection
2. **Application Layer**: Local event bus for publishing and subscribing  
3. **Infrastructure Layer**: Future remote event transport implementations

### Event Flow

```
Aggregate -> raises -> DomainEvent -> published to -> EventBus -> delivers to -> Listeners
                                         |
                                         v
                                   Future: RemoteEventPublisher -> EventTransport -> Remote Systems
```

## Components and Interfaces

### 1. Domain Event Base Class

```dart
abstract class DomainEvent {
  final String eventId;
  final DateTime occurredAt;
  final String aggregateId;
  final Map<String, dynamic> context;
  
  DomainEvent({
    required this.aggregateId,
    String? eventId,
    DateTime? occurredAt,
    this.context = const {},
  }) : eventId = eventId ?? Uuid().v4(),
       occurredAt = occurredAt ?? DateTime.now();
}
```

**Design Decisions:**
- Uses UUID for globally unique event identifiers
- Includes timestamp for event ordering and audit trails
- Context map enables future filtering capabilities
- Immutable design prevents event tampering

### 2. Enhanced Aggregate Root

```dart
abstract class AggregateRoot extends Entity {
  final List<DomainEvent> _uncommittedEvents = [];
  
  void raiseEvent(DomainEvent event);
  List<DomainEvent> getUncommittedEvents();
  void markEventsAsCommitted();
}
```

**Design Decisions:**
- Events are collected but not automatically published
- Separation between raising and publishing enables transaction boundaries
- Uncommitted events can be inspected before publishing
- Clear lifecycle management for event publishing

### 3. Local Event Bus

```dart
class EventBus {
  final StreamController<DomainEvent> _controller = 
    StreamController.broadcast();
  
  Stream<T> on<T extends DomainEvent>();
  void publish(DomainEvent event);
  void close();
}
```

**Design Decisions:**
- Uses Dart's StreamController for native async support
- Broadcast streams allow multiple listeners
- Type-safe subscriptions using generic constraints
- Simple API with publish/subscribe pattern

### 4. Future Remote Event Interfaces

```dart
// Event Transport Interface (Future Implementation)
abstract interface class EventTransport {
  Future<void> send(DomainEvent event);
  Stream<DomainEvent> receive();
  Future<void> subscribe(EventSubscription subscription);
  Future<void> close();
}

// Event Subscription (Future Implementation)  
class EventSubscription {
  final Type eventType;
  final String clientId;
  final Map<String, dynamic> filters;
  
  EventSubscription({
    required this.eventType,
    required this.clientId,
    this.filters = const {},
  });
}

// Remote Event Client (Future Implementation)
abstract interface class RemoteEventClient {
  Future<void> subscribe(EventSubscription subscription);
  Future<void> unsubscribe(Type eventType);
  Stream<T> on<T extends DomainEvent>();
}
```

**Design Decisions:**
- Interfaces defined but not implemented in initial version
- EventTransport abstracts network communication details
- EventSubscription enables filtered event delivery
- RemoteEventClient provides same API as local EventBus

## Data Models

### Event Metadata Structure

```dart
class EventMetadata {
  final String eventId;
  final DateTime occurredAt;
  final String aggregateId;
  final String eventType;
  final Map<String, dynamic> context;
}
```

### Event Serialization

Events will integrate with the existing `dddart_serialization` framework:

```dart
@Serializable()
class UserRegistered extends DomainEvent {
  final String email;
  final String organizationId;
  
  UserRegistered({
    required String userId,
    required this.email,
    required this.organizationId,
  }) : super(
    aggregateId: userId,
    context: {'organizationId': organizationId},
  );
}
```

## Error Handling

### Event Publishing Errors

```dart
class EventPublishingException implements Exception {
  final String message;
  final DomainEvent event;
  final Exception? cause;
  
  EventPublishingException(this.message, this.event, [this.cause]);
}
```

### Event Handling Errors

- Individual listener failures do not affect other listeners
- EventBus continues operating even if some listeners throw exceptions
- Error logging and monitoring hooks for production debugging

## Testing Strategy

### Unit Testing Approach

1. **Event Collection Testing**: Verify aggregates collect events correctly
2. **Event Bus Testing**: Test publish/subscribe functionality with mock events
3. **Event Serialization Testing**: Validate events serialize/deserialize properly
4. **Error Handling Testing**: Ensure graceful failure handling

### Integration Testing

1. **End-to-End Event Flow**: Test complete event lifecycle from aggregate to listener
2. **Multiple Listener Testing**: Verify events reach all registered listeners
3. **Event Ordering Testing**: Ensure events are delivered in correct order

### Future Remote Testing Strategy

When remote functionality is implemented:
- Mock EventTransport implementations for testing
- Network failure simulation and recovery testing
- Event filtering and subscription testing
- Cross-platform compatibility testing

## Implementation Notes

### Phase 1: Local Events Only

The initial implementation will include:
- DomainEvent base class
- Enhanced AggregateRoot with event collection
- Local EventBus implementation
- Integration with existing dddart serialization

### Phase 2: Remote Event Foundation (Future)

Future implementation will add:
- EventTransport interface implementations
- RemoteEventClient implementations  
- Event filtering and subscription management
- Network-specific transport packages

### Package Organization

- **dddart**: Core event classes (DomainEvent, EventBus, enhanced AggregateRoot)
- **dddart_remote_events**: Remote event interfaces and utilities (future)
- **dddart_events_websocket**: WebSocket transport implementation (future)
- **dddart_events_aws**: AWS SNS/SQS transport implementation (future)

This design provides a solid foundation for local event-driven architecture while establishing clear interfaces for future distributed event capabilities.