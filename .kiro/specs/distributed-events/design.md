# Design Document

## Overview

This design implements a distributed event system for DDDart that extends the local EventBus to enable domain events to be published and subscribed across network boundaries. The system uses HTTP polling for reliable event delivery with automatic catch-up, leverages DDDart's Repository pattern for event storage, and provides automatic serialization/deserialization through code generation.

The architecture consists of two main components: **EventBusServer** (wraps local EventBus with automatic persistence and HTTP endpoints) and **EventBusClient** (wraps local EventBus with HTTP polling and optional event forwarding). Events are stored using the Repository pattern, enabling any database implementation (MongoDB, MySQL, DynamoDB, Redis, etc.) without changing application code.

## Architecture

### Package Structure

```
dddart_events_distributed/
  - StoredEvent (AggregateRoot wrapper for events)
  - EventRepository (abstract class with time-range queries)
  - EventBusServer (server-side component)
  - EventBusClient (client-side component)
  - HTTP endpoints (GET /events, POST /events)
  - Event registry code generator

dddart_events_http/
  - HTTP polling transport implementation
  - (Future: dddart_events_websockets, dddart_events_aws, etc.)
```

### Event Flow Architecture

**Server-Side Flow:**
```
Local EventBus
     │
     │ publish(DomainEvent)
     │
     ▼
EventBusServer Listener
     │
     │ wrap in StoredEvent
     │ serialize event data
     │
     ▼
EventRepository
     │
     │ save(StoredEvent)
     │
     ▼
Database (MongoDB/MySQL/Redis/etc.)
     │
     │ HTTP GET /events?since=timestamp
     │
     ▼
HTTP Response (JSON array of StoredEvents)
```

**Client-Side Flow:**
```
HTTP Polling Timer
     │
     │ GET /events?since=lastTimestamp
     │
     ▼
HTTP Response (StoredEvents)
     │
     │ deserialize using event registry
     │
     ▼
Reconstructed DomainEvents
     │
     │ publish to local EventBus
     │
     ▼
Local Event Handlers
```

**Bidirectional Flow:**
```
┌─────────────────┐                    ┌─────────────────┐
│  Client App     │                    │  Server App     │
│                 │                    │                 │
│  EventBus       │                    │  EventBus       │
│    │            │                    │    │            │
│    │ publish    │                    │    │ publish    │
│    ▼            │                    │    ▼            │
│  EventBusClient │◄───HTTP Poll──────┤  EventBusServer │
│    │            │                    │    │            │
│    │ forward    │                    │    │ persist    │
│    │            │                    │    │            │
│    └───HTTP POST──────────────────►│    ▼            │
│                 │                    │  Repository     │
│                 │                    │    │            │
│                 │                    │    ▼            │
│                 │                    │  Database       │
└─────────────────┘                    └─────────────────┘
```

## Components and Interfaces

### StoredEvent (AggregateRoot)

```dart
/// Stored event with common authorization fields.
/// 
/// This class provides standard authorization fields (userId, tenantId, sessionId)
/// that cover most use cases. Developers can extend this class to add additional
/// application-specific authorization fields if needed.
@Serializable()
class StoredEvent extends AggregateRoot {
  StoredEvent({
    required super.id,
    required super.createdAt,
    required this.aggregateId,
    required this.eventType,
    required this.eventJson,
    this.userId,
    this.tenantId,
    this.sessionId,
  }) : super(updatedAt: createdAt); // Events never update
  
  /// Aggregate that raised this event
  final UuidValue aggregateId;
  
  /// Event type name for deserialization (e.g., "UserCreatedEvent")
  final String eventType;
  
  /// Serialized event data as JSON string
  final String eventJson;
  
  /// User identifier for user-specific event filtering
  final String? userId;
  
  /// Tenant identifier for multi-tenant event filtering
  final String? tenantId;
  
  /// Session identifier for session-specific event filtering
  final String? sessionId;
  
  /// Creates StoredEvent from DomainEvent
  factory StoredEvent.fromDomainEvent(DomainEvent event) {
    return StoredEvent(
      id: event.eventId,
      createdAt: event.occurredAt,
      aggregateId: event.aggregateId,
      eventType: event.runtimeType.toString(),
      eventJson: jsonEncode(event.toJson()),
      userId: event.context['userId'] as String?,
      tenantId: event.context['tenantId'] as String?,
      sessionId: event.context['sessionId'] as String?,
    );
  }
  
  @override
  List<Object?> get props => [
    id,
    createdAt,
    aggregateId,
    eventType,
    eventJson,
    userId,
    tenantId,
    sessionId,
  ];
}
```

**Extended StoredEvent Example:**

Developers can extend `StoredEvent` to add custom authorization fields, including collections:

```dart
/// Custom stored event with additional authorization fields
@Serializable()
@GenerateMysqlRepository()
class MyStoredEvent extends StoredEvent {
  MyStoredEvent({
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
  
  /// User roles for role-based authorization
  final List<String>? userRoles;
  
  /// Organization identifier for organization-specific filtering
  final String? organizationId;
  
  @override
  List<Object?> get props => [...super.props, userRoles, organizationId];
  
  /// Extract authorization fields from DomainEvent.context
  factory MyStoredEvent.fromDomainEvent(DomainEvent event) {
    return MyStoredEvent(
      id: event.eventId,
      createdAt: event.occurredAt,
      aggregateId: event.aggregateId,
      eventType: event.runtimeType.toString(),
      eventJson: jsonEncode(event.toJson()),
      userId: event.context['userId'] as String?,
      tenantId: event.context['tenantId'] as String?,
      sessionId: event.context['sessionId'] as String?,
      userRoles: (event.context['userRoles'] as List?)?.cast<String>(),
      organizationId: event.context['organizationId'] as String?,
    );
  }
}
```

### EventRepository (Abstract Class)

```dart
/// Extended repository interface for time-based event queries
abstract class EventRepository<T extends StoredEvent> implements Repository<T> {
  /// Finds all events with createdAt >= timestamp
  /// 
  /// Implementations should use database-specific queries optimized
  /// for time-range lookups (e.g., indexed queries on createdAt field).
  Future<List<T>> findSince(DateTime timestamp);
  
  /// Deletes all events with createdAt < timestamp
  /// 
  /// Used for cleanup of old events. Implementations should handle
  /// large deletions efficiently (batching, etc.).
  Future<void> deleteOlderThan(DateTime timestamp);
}
```

**Developer Implementation Example (MongoDB):**

```dart
@GenerateMongoRepository()
class StoredEventMongo extends StoredEvent {
  StoredEventMongo({
    required super.id,
    required super.createdAt,
    required super.aggregateId,
    required super.eventType,
    required super.eventJson,
    super.userId,
    super.tenantId,
    super.sessionId,
  });
}

// Developer implements EventRepository methods
class StoredEventMongoRepository extends EventRepository<StoredEventMongo> {
  // ... generated Repository methods (save, findById, etc.)
  
  @override
  Future<List<StoredEventMongo>> findSince(DateTime timestamp) async {
    final results = await collection.find({
      'createdAt': {'\$gte': timestamp.toIso8601String()}
    }).toList();
    
    return results.map((doc) => StoredEventMongo.fromJson(doc)).toList();
  }
  
  @override
  Future<void> deleteOlderThan(DateTime timestamp) async {
    await collection.deleteMany({
      'createdAt': {'\$lt': timestamp.toIso8601String()}
    });
  }
}
```

### EventBusServer

```dart
/// Server-side component that wraps EventBus with automatic persistence
/// and HTTP endpoints for event distribution
class EventBusServer<T extends StoredEvent> {
  EventBusServer({
    required this.localEventBus,
    required this.eventRepository,
    this.retentionDuration,
    required this.storedEventFactory,
  }) {
    // Subscribe to all events and persist them
    _subscription = localEventBus.on<DomainEvent>().listen(_persistEvent);
  }
  
  final EventBus localEventBus;
  final EventRepository<T> eventRepository;
  final Duration? retentionDuration;
  final T Function(DomainEvent) storedEventFactory;
  
  StreamSubscription<DomainEvent>? _subscription;
  final Logger _logger = Logger('dddart.events.server');
  
  /// Publishes event to local bus (which triggers persistence)
  void publish(DomainEvent event) {
    localEventBus.publish(event);
  }
  
  /// Subscribes to events on local bus
  Stream<T> on<T extends DomainEvent>() {
    return localEventBus.on<T>();
  }
  
  /// Persists event to repository
  Future<void> _persistEvent(DomainEvent event) async {
    try {
      final stored = storedEventFactory(event);
      await eventRepository.save(stored);
      _logger.fine('Persisted event: ${event.runtimeType} (${event.eventId})');
    } catch (e, stackTrace) {
      _logger.severe('Failed to persist event: ${event.runtimeType}', e, stackTrace);
    }
  }
  
  /// Cleans up old events based on retention duration
  Future<void> cleanup() async {
    if (retentionDuration == null) {
      _logger.warning('cleanup() called but no retentionDuration configured');
      return;
    }
    
    final cutoff = DateTime.now().subtract(retentionDuration!);
    try {
      await eventRepository.deleteOlderThan(cutoff);
      _logger.info('Cleaned up events older than $cutoff');
    } catch (e, stackTrace) {
      _logger.severe('Failed to cleanup old events', e, stackTrace);
    }
  }
  
  /// Closes the server and releases resources
  Future<void> close() async {
    await _subscription?.cancel();
    await localEventBus.close();
  }
}
```

### EventBusClient

```dart
/// Client-side component that polls for events and optionally forwards local events
class EventBusClient {
  EventBusClient({
    required this.localEventBus,
    required this.serverUrl,
    required this.eventRegistry,
    this.pollingInterval = const Duration(seconds: 5),
    this.autoForward = false,
    this.initialTimestamp,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client() {
    _lastTimestamp = initialTimestamp ?? DateTime.now();
    
    // Start polling
    _startPolling();
    
    // Optionally forward local events to server
    if (autoForward) {
      _subscription = localEventBus.on<DomainEvent>().listen(_forwardEvent);
    }
  }
  
  final EventBus localEventBus;
  final String serverUrl;
  final Map<String, DomainEvent Function(Map<String, dynamic>)> eventRegistry;
  final Duration pollingInterval;
  final bool autoForward;
  final http.Client _httpClient;
  
  DateTime _lastTimestamp;
  Timer? _pollingTimer;
  StreamSubscription<DomainEvent>? _subscription;
  final Logger _logger = Logger('dddart.events.client');
  
  /// Starts polling for events
  void _startPolling() {
    _pollingTimer = Timer.periodic(pollingInterval, (_) => _poll());
  }
  
  /// Polls server for new events
  Future<void> _poll() async {
    try {
      final url = Uri.parse('$serverUrl/events').replace(
        queryParameters: {'since': _lastTimestamp.toIso8601String()},
      );
      
      final response = await _httpClient.get(url);
      
      if (response.statusCode == 200) {
        final List<dynamic> eventsJson = jsonDecode(response.body);
        _logger.fine('Received ${eventsJson.length} events from server');
        
        for (final eventJson in eventsJson) {
          await _processEvent(eventJson);
        }
      } else {
        _logger.warning('Poll failed: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      _logger.severe('Poll error', e, stackTrace);
    }
  }
  
  /// Processes received event
  Future<void> _processEvent(Map<String, dynamic> storedEventJson) async {
    try {
      final eventType = storedEventJson['eventType'] as String;
      final eventDataJson = jsonDecode(storedEventJson['eventJson']);
      final timestamp = DateTime.parse(storedEventJson['createdAt']);
      
      // Update last timestamp
      if (timestamp.isAfter(_lastTimestamp)) {
        _lastTimestamp = timestamp;
      }
      
      // Deserialize using registry
      final factory = eventRegistry[eventType];
      if (factory == null) {
        _logger.fine('Unknown event type: $eventType (skipping)');
        return;
      }
      
      final event = factory(eventDataJson);
      
      // Publish to local bus
      localEventBus.publish(event);
      _logger.fine('Published received event: $eventType');
    } catch (e, stackTrace) {
      _logger.severe('Failed to process event', e, stackTrace);
    }
  }
  
  /// Forwards local event to server
  Future<void> _forwardEvent(DomainEvent event) async {
    try {
      final url = Uri.parse('$serverUrl/events');
      final response = await _httpClient.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(event.toJson()),
      );
      
      if (response.statusCode == 201) {
        _logger.fine('Forwarded event: ${event.runtimeType}');
      } else {
        _logger.warning('Forward failed: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      _logger.severe('Failed to forward event', e, stackTrace);
    }
  }
  
  /// Publishes event to local bus (and optionally forwards to server)
  void publish(DomainEvent event) {
    localEventBus.publish(event);
  }
  
  /// Subscribes to events on local bus
  Stream<T> on<T extends DomainEvent>() {
    return localEventBus.on<T>();
  }
  
  /// Closes the client and releases resources
  Future<void> close() async {
    _pollingTimer?.cancel();
    await _subscription?.cancel();
    _httpClient.close();
    await localEventBus.close();
  }
}
```

### HTTP Endpoints

```dart
/// HTTP endpoints for event distribution
class EventHttpEndpoints {
  EventHttpEndpoints({
    required this.eventRepository,
    this.authorizationFilter,
  });
  
  final EventRepository<StoredEvent> eventRepository;
  final bool Function(StoredEvent event, Request request)? authorizationFilter;
  final Logger _logger = Logger('dddart.events.http');
  
  /// GET /events?since=<ISO8601 timestamp>
  Future<Response> handleGetEvents(Request request) async {
    try {
      // Parse timestamp
      final sinceParam = request.url.queryParameters['since'];
      if (sinceParam == null) {
        return Response(400, body: jsonEncode({
          'error': 'Missing required parameter: since',
        }));
      }
      
      final since = DateTime.parse(sinceParam);
      
      // Query events
      final events = await eventRepository.findSince(since);
      
      // Apply authorization filter
      final authorizedEvents = authorizationFilter != null
          ? events.where((event) => authorizationFilter!(event, request)).toList()
          : events;
      
      _logger.info('Returned ${authorizedEvents.length} events (since: $since)');
      
      // Return as JSON
      return Response.ok(
        jsonEncode(authorizedEvents.map((e) => e.toJson()).toList()),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stackTrace) {
      _logger.severe('GET /events failed', e, stackTrace);
      return Response.internalServerError(
        body: jsonEncode({'error': 'Internal server error'}),
      );
    }
  }
  
  /// POST /events
  Future<Response> handlePostEvent(Request request, EventBusServer server) async {
    try {
      // Parse event JSON
      final body = await request.readAsString();
      final eventJson = jsonDecode(body) as Map<String, dynamic>;
      
      // Deserialize and publish to local bus
      // (This triggers automatic persistence via EventBusServer listener)
      final eventType = eventJson['eventType'] as String;
      // Note: Server needs its own event registry for deserialization
      // Or accept pre-serialized StoredEvent
      
      // For now, accept StoredEvent directly
      final stored = StoredEvent.fromJson(eventJson);
      await eventRepository.save(stored);
      
      _logger.info('Received and stored event: $eventType');
      
      return Response(201, body: jsonEncode({
        'id': stored.id.toString(),
        'createdAt': stored.createdAt.toIso8601String(),
      }));
    } catch (e, stackTrace) {
      _logger.severe('POST /events failed', e, stackTrace);
      return Response(400, body: jsonEncode({
        'error': 'Invalid event data',
      }));
    }
  }
}
```

## Data Models

### Design Decision: Flat Authorization Fields

The `StoredEvent` uses flat authorization fields rather than a nested context object or `Map<String, dynamic>` for the following reasons:

1. **SQL Repository Compatibility**: Authorization fields are stored as direct columns, providing proper indexed storage for efficient queries.

2. **Industry Standard**: Follows patterns from CloudEvents, AWS EventBridge, and Azure Event Grid which use flat metadata structures.

3. **Type Safety**: Provides compile-time type checking for authorization fields.

4. **Extensibility**: Developers can extend `StoredEvent` to add custom authorization fields (including collections like `List<String> userRoles`).

5. **Query Performance**: Direct columns enable efficient indexed queries for authorization filtering (`WHERE userId = ?`).

6. **No JSON Blobs**: Avoids storing unstructured JSON in SQL columns, which is an anti-pattern for queryable data.

7. **Collections Support**: Collections work naturally at the aggregate level (e.g., `List<String> userRoles` creates a separate table automatically).

The base `StoredEvent` provides common authorization fields (userId, tenantId, sessionId) that cover most use cases. Developers can use it directly or extend it for application-specific needs.

**Note on DomainEvent Compatibility**: The base `DomainEvent` class in dddart uses `Map<String, dynamic> context` for flexibility. When creating a `StoredEvent`, the `fromDomainEvent` factory extracts authorization fields from the context map. This conversion happens at the boundary between local and distributed events, allowing the core dddart package to remain flexible while the distributed events package enforces proper storage patterns.

### StoredEvent JSON Format

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "createdAt": "2024-12-04T10:00:00.000Z",
  "aggregateId": "660e8400-e29b-41d4-a716-446655440000",
  "eventType": "UserCreatedEvent",
  "eventJson": "{\"email\":\"user@example.com\",\"name\":\"Alice\"}",
  "userId": "user-123",
  "tenantId": "tenant-1",
  "sessionId": null
}
```

### HTTP API

**GET /events?since=<timestamp>**

Request:
```
GET /events?since=2024-12-04T10:00:00.000Z HTTP/1.1
Authorization: Bearer <token>
```

Response (200 OK):
```json
[
  {
    "id": "event-uuid-1",
    "createdAt": "2024-12-04T10:00:05.000Z",
    "aggregateId": "user-123",
    "eventType": "UserCreatedEvent",
    "eventJson": "{\"email\":\"user@example.com\"}",
    "userId": "user-123",
    "tenantId": null,
    "sessionId": null
  },
  {
    "id": "event-uuid-2",
    "createdAt": "2024-12-04T10:00:10.000Z",
    "aggregateId": "order-456",
    "eventType": "OrderPurchasedEvent",
    "eventJson": "{\"amount\":99.99}",
    "userId": "user-123",
    "tenantId": null,
    "sessionId": null
  }
]
```

**POST /events**

Request:
```
POST /events HTTP/1.1
Content-Type: application/json

{
  "id": "event-uuid-3",
  "createdAt": "2024-12-04T10:00:15.000Z",
  "aggregateId": "user-789",
  "eventType": "UserUpdatedEvent",
  "eventJson": "{\"email\":\"newemail@example.com\"}",
  "userId": "user-789",
  "tenantId": null,
  "sessionId": null
}
```

Response (201 Created):
```json
{
  "id": "event-uuid-3",
  "createdAt": "2024-12-04T10:00:15.000Z"
}
```

## Code Generation

### Event Registry Generation

The `dddart_events_distributed` code generator scans for `@Serializable` DomainEvent subclasses and generates an event registry map.

**Developer's Code:**

```dart
import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';

part 'user_events.g.dart';

@Serializable()
class UserCreatedEvent extends DomainEvent {
  UserCreatedEvent({
    super.id,
    super.createdAt,
    required super.aggregateId,
    required this.email,
    required this.name,
  });
  
  final String email;
  final String name;
}

@Serializable()
class UserUpdatedEvent extends DomainEvent {
  UserUpdatedEvent({
    super.id,
    super.createdAt,
    required super.aggregateId,
    required this.email,
  });
  
  final String email;
}
```

**Generated Code (user_events.g.dart):**

```dart
// Generated by dddart_json
extension UserCreatedEventSerializer on UserCreatedEvent {
  Map<String, dynamic> toJson() => {
    'id': id.toString(),
    'createdAt': createdAt.toIso8601String(),
    'aggregateId': aggregateId.toString(),
    'email': email,
    'name': name,
    'context': context,
  };
  
  static UserCreatedEvent fromJson(Map<String, dynamic> json) => UserCreatedEvent(
    id: UuidValue.fromString(json['id']),
    createdAt: DateTime.parse(json['createdAt']),
    aggregateId: UuidValue.fromString(json['aggregateId']),
    email: json['email'],
    name: json['name'],
  );
}

extension UserUpdatedEventSerializer on UserUpdatedEvent {
  Map<String, dynamic> toJson() => {
    'id': id.toString(),
    'createdAt': createdAt.toIso8601String(),
    'aggregateId': aggregateId.toString(),
    'email': email,
    'context': context,
  };
  
  static UserUpdatedEvent fromJson(Map<String, dynamic> json) => UserUpdatedEvent(
    id: UuidValue.fromString(json['id']),
    createdAt: DateTime.parse(json['createdAt']),
    aggregateId: UuidValue.fromString(json['aggregateId']),
    email: json['email'],
  );
}

// Generated by dddart_events_distributed
final generatedEventRegistry = <String, DomainEvent Function(Map<String, dynamic>)>{
  'UserCreatedEvent': UserCreatedEventSerializer.fromJson,
  'UserUpdatedEvent': UserUpdatedEventSerializer.fromJson,
};
```

## Error Handling

### Server-Side Error Handling

1. **Event Persistence Failures**: Log error, continue processing other events
2. **HTTP Request Errors**: Return appropriate HTTP status codes (400, 500)
3. **Authorization Filter Exceptions**: Log error, exclude event from response
4. **Repository Query Failures**: Return 500 Internal Server Error

### Client-Side Error Handling

1. **HTTP Poll Failures**: Log error, retry on next poll interval
2. **Deserialization Failures**: Log error, skip event, continue processing
3. **Unknown Event Types**: Log warning, skip event
4. **Event Forward Failures**: Log error, optionally retry with exponential backoff

### Logging

All components use hierarchical loggers:
- `dddart.events.server` - EventBusServer logging
- `dddart.events.client` - EventBusClient logging
- `dddart.events.http` - HTTP endpoint logging

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Event Persistence Properties

Property 1: Published events are persisted
*For any* DomainEvent published to EventBusServer, the event should be wrapped in a StoredEvent and saved to the repository
**Validates: Requirements 1.2**

Property 2: Serialization preserves event data
*For any* DomainEvent, serializing to StoredEvent and back should preserve all event-specific data
**Validates: Requirements 1.3**

### Event Retrieval Properties

Property 3: findSince returns events in time range
*For any* timestamp T, calling findSince(T) should return only events with createdAt >= T
**Validates: Requirements 11.3**

Property 4: Polling retrieves new events
*For any* client with last timestamp T, polling should retrieve all events with createdAt > T
**Validates: Requirements 2.2**

### Event Deserialization Properties

Property 5: Event registry deserializes correctly
*For any* registered event type, deserializing a StoredEvent should reconstruct the original DomainEvent with equivalent data
**Validates: Requirements 13.4, 14.1**

Property 6: Unknown event types are skipped
*For any* event type not in the registry, deserialization should skip the event without error
**Validates: Requirements 13.5, 14.4**

### Authorization Properties

Property 7: Authorization filter controls event delivery
*For any* event and authorization filter, if the filter returns false, the event should not be included in the HTTP response
**Validates: Requirements 4.3**

Property 8: No filter means all events delivered
*For any* event query without an authorization filter, all matching events should be returned
**Validates: Requirements 4.5**

### Event Forwarding Properties

Property 9: Auto-forward sends events to server
*For any* EventBusClient with autoForward enabled, publishing an event to the local EventBus should result in an HTTP POST to the server
**Validates: Requirements 15.3**

Property 10: Disabled forwarding prevents automatic POST
*For any* EventBusClient with autoForward disabled, publishing an event to the local EventBus should not trigger an HTTP POST
**Validates: Requirements 15.4**

### Cleanup Properties

Property 11: Cleanup deletes old events
*For any* EventBusServer with retention duration D, calling cleanup() should delete all events with createdAt < (now - D)
**Validates: Requirements 12.3**

Property 12: Cleanup logs deletion count
*For any* cleanup operation, the number of deleted events should be logged
**Validates: Requirements 12.4**

## Testing Strategy

### Unit Tests

- **StoredEvent**: Test fromDomainEvent conversion, JSON serialization
- **EventBusServer**: Test event persistence listener, cleanup method
- **EventBusClient**: Test polling logic, deserialization, forwarding
- **EventHttpEndpoints**: Test GET/POST handlers, authorization filtering
- **EventRepository**: Test findSince and deleteOlderThan implementations

### Property-Based Tests

- **Event serialization round-trip**: Generate random events, serialize/deserialize, verify equivalence
- **Time-range queries**: Generate random events with timestamps, verify findSince correctness
- **Authorization filtering**: Generate random events and filters, verify correct filtering
- **Event registry lookup**: Generate random event types, verify registry lookup behavior

### Integration Tests

- **End-to-end event flow**: Publish event on server, poll from client, verify delivery
- **Catch-up after disconnect**: Simulate client disconnect, verify catch-up retrieves missed events
- **Authorization enforcement**: Verify filtered events are not delivered to unauthorized clients
- **Cleanup functionality**: Verify old events are deleted correctly

## Future Enhancements

See `future-enhancements.md` for detailed plans on:
- Automatic time-range query generation in repository packages
- WebSocket transport for real-time delivery
- AWS EventBridge/SNS/SQS integrations
- Event type filtering in HTTP queries
- Pagination support for large event sets
