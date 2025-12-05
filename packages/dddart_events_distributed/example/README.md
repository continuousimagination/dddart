# Examples

This directory contains examples demonstrating the distributed events system.

## Example Files

### Domain Models

- **`lib/example_events.dart`** - Example domain events (UserCreatedEvent, OrderPurchasedEvent, etc.)
- **`lib/custom_stored_event.dart`** - Example of extending StoredEvent with custom authorization fields
- **`lib/in_memory_event_repository.dart`** - In-memory implementation of EventRepository
- **`lib/event_registry.dart`** - Event registry for deserialization

### Runnable Examples

- **`server_example.dart`** - EventBusServer with HTTP endpoints
- **`client_example.dart`** - EventBusClient with polling (requires server_example.dart running)
- **`end_to_end_example.dart`** - Complete bidirectional event flow demonstration

## Running the Examples

### 1. Server Example

Start the server that publishes events and provides HTTP endpoints:

```bash
dart run server_example.dart
```

The server will:
- Listen on http://localhost:8080
- Publish example events
- Persist events to in-memory repository
- Provide GET /events and POST /events endpoints

Try these commands while the server is running:

```bash
# Get all events
curl "http://localhost:8080/events?since=2024-01-01T00:00:00.000Z"

# Get events for specific tenant
curl -H "x-tenant-id: tenant-1" "http://localhost:8080/events?since=2024-01-01T00:00:00.000Z"
```

### 2. Client Example

In a separate terminal, start the client that polls for events:

```bash
dart run client_example.dart
```

The client will:
- Poll the server every 5 seconds
- Receive and deserialize events
- Publish them to local EventBus
- Auto-forward local events to server

### 3. End-to-End Example

Run a complete demonstration in a single process:

```bash
dart run end_to_end_example.dart
```

This example demonstrates:
- Server publishes event → Client receives it via polling
- Client publishes event → Server receives it via HTTP POST
- Bidirectional event flow
- Event persistence

## Event Registry Generator

The event registry generator automatically creates a map of event type names to their `fromJson` factory functions.

### Usage

1. Annotate your DomainEvent subclasses with `@Serializable`:

```dart
import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

@Serializable()
class UserCreatedEvent extends DomainEvent {
  UserCreatedEvent({
    required super.aggregateId,
    required this.email,
    required this.name,
  });

  final String email;
  final String name;

  static UserCreatedEvent fromJson(Map<String, dynamic> json) {
    return UserCreatedEvent(
      aggregateId: UuidValue.fromString(json['aggregateId'] as String),
      email: json['email'] as String,
      name: json['name'] as String,
    );
  }
}
```

2. Run the code generator:

```bash
dart run build_runner build
```

3. Use the generated registry with EventBusClient:

```dart
final client = EventBusClient(
  localEventBus: eventBus,
  serverUrl: 'http://localhost:8080',
  eventRegistry: generatedEventRegistry,
  pollingInterval: const Duration(seconds: 5),
);
```

## Custom StoredEvent

The `lib/custom_stored_event.dart` file demonstrates how to extend StoredEvent with additional authorization fields:

```dart
@Serializable()
class CustomStoredEvent extends StoredEvent {
  CustomStoredEvent({
    required super.id,
    required super.createdAt,
    required super.aggregateId,
    required super.eventType,
    required super.eventJson,
    super.userId,
    super.tenantId,
    super.sessionId,
    this.userRoles,
    this.organizationId,
  });

  final List<String>? userRoles;
  final String? organizationId;
  
  // ... factory and methods
}
```

This allows you to add application-specific authorization fields for more complex filtering scenarios.
