# dddart_events_distributed

Distributed event system for DDDart that extends the local EventBus to enable domain events to be published and subscribed across network boundaries using HTTP polling.

## Features

- **EventBusServer**: Server-side component with automatic event persistence and HTTP endpoints
- **EventBusClient**: Client-side component with HTTP polling and optional event forwarding
- **HTTP Polling**: Reliable event delivery with automatic catch-up capabilities
- **Neutral realtime transport boundary**: Optional best-effort `StoredEvent` notifications without coupling DDDart to
  AppSync, IoT, API Gateway, Flutter, AWS, or any specific runtime
- **Repository Pattern**: Use any database implementation (MongoDB, MySQL, DynamoDB, Redis, etc.)
- **Authorization Filtering**: Control which events each client can receive based on context
- **Automatic Serialization**: Code generation for event serialization/deserialization
- **Bidirectional Flow**: Events can flow from server to client and client to server
- **Event Cleanup**: Automatic deletion of old events based on retention policies

## Realtime notification boundary

`DistributedEventTransport` is the minimal adapter interface for optional realtime notifications.
It publishes and subscribes to `StoredEvent` payloads, and `DistributedEventBusBridge`
deserializes those payloads through your `StoredEventDecoder` before publishing concrete
`DomainEvent`s into the normal local `EventBus`. The realtime transport API stays typed
as `StoredEvent`/`DomainEvent`; raw JSON map handling belongs inside the decoder/codec
layer where applications can use their generated serializers and validation.

Realtime transport implementations are best-effort wake-up paths only: messages can be
missed, duplicated, delayed, or delivered out of order. Keep `/events?since=` as the
durable catch-up/correctness path and dedupe by `eventId` when combining catch-up
with realtime notifications. Transport adapters should not make entity IDs, UUIDv7,
ULID, or client clocks authoritative for event ordering.

### Opt-in AWS AppSync Events smoke test

The package includes an opt-in smoke test for validating a real AWS AppSync Events
API with Cognito user-pool authorization. Normal local and CI runs execute
`dart test`, and `dart_test.yaml` excludes tests tagged `aws` from that default
run. Use the `aws_smoke` preset to run the live AWS test intentionally:

```bash
cd packages/dddart_events_distributed
dart test -P aws_smoke test/appsync_events_aws_smoke_test.dart
```

If the preset is selected but required environment variables are missing, the
smoke test reports a skipped test with the missing configuration names.

The smoke verifies that the Flutter-compatible Dart transport connects with a
Cognito JWT, subscribes to the user's inbox channel, receives and deserializes a
fake `StoredEvent`, and invokes the catch-up callback so applications continue to
use the durable `/events?since=` path after realtime activity or reconnects.

#### AWS resources required

You need an AppSync Events API that allows Cognito User Pool users to subscribe
and publish on per-user inbox channels of this form:

```text
/users/<cognito-sub>/events
```

The test expects authorization rules that allow a user to subscribe to their own
channel and, when the optional second user is configured, deny user A from
subscribing to user B's channel.

#### Required environment variables

- `DDDART_APPSYNC_REALTIME_URL`: AppSync Events realtime WebSocket URL, for
  example `wss://...appsync-realtime-api.../event/realtime`.
- `DDDART_APPSYNC_HTTP_ENDPOINT`: AppSync Events HTTP publish endpoint or domain.
  If a bare domain is supplied, the smoke test posts to `https://<domain>/event`.
- `DDDART_APPSYNC_JWT_A`: Cognito User Pool ID token or access token for test
  user A. The token is never printed by the test.
- `DDDART_APPSYNC_USER_SUB_A`: Cognito `sub` claim for test user A. The smoke
  subscribes to `/users/<sub>/events` and publishes a serialized `StoredEvent`
  to that channel.

#### Optional environment variables

- `DDDART_APPSYNC_AUTH_HOST`: host value to encode in the AppSync realtime
  authorization header. Defaults to the HTTP endpoint host.
- `DDDART_APPSYNC_PUBLISH_JWT`: JWT used for HTTP publish. Defaults to
  `DDDART_APPSYNC_JWT_A`.
- `DDDART_APPSYNC_PUBLISH_API_KEY`: API key used for HTTP publish. When set, this
  is preferred over bearer-token publish auth.
- `DDDART_APPSYNC_JWT_B` and `DDDART_APPSYNC_USER_SUB_B`: second test identity.
  When both are set, the smoke asserts user A cannot subscribe to
  `/users/<subB>/events`.

#### Getting Cognito JWTs

Use a disposable test user; do not use a human's normal production account. The
simplest repeatable CLI path is Cognito's `USER_PASSWORD_AUTH` flow:

```bash
export AWS_REGION=us-east-1
export COGNITO_CLIENT_ID=exampleclientid
export COGNITO_USERNAME_A=dddart-smoke-a@example.com
export COGNITO_PASSWORD_A='replace-with-test-password'

aws cognito-idp initiate-auth \
  --region "$AWS_REGION" \
  --client-id "$COGNITO_CLIENT_ID" \
  --auth-flow USER_PASSWORD_AUTH \
  --auth-parameters USERNAME="$COGNITO_USERNAME_A",PASSWORD="$COGNITO_PASSWORD_A" \
  > /tmp/dddart-smoke-user-a.json

export DDDART_APPSYNC_JWT_A=$(jq -r '.AuthenticationResult.IdToken' /tmp/dddart-smoke-user-a.json)
```

If your app client is configured to use access tokens for AppSync authorization,
export `.AuthenticationResult.AccessToken` instead. If the app client does not
allow `USER_PASSWORD_AUTH`, use the app's normal sign-in path. If the app client
has a client secret, provide the Cognito `SECRET_HASH` parameter required by AWS.

Get the Cognito `sub` claim from the JWT payload:

```bash
export DDDART_APPSYNC_USER_SUB_A=$(
  python3 - <<'PY'
import base64, json, os
payload = os.environ['DDDART_APPSYNC_JWT_A'].split('.')[1]
payload += '=' * (-len(payload) % 4)
print(json.loads(base64.urlsafe_b64decode(payload))['sub'])
PY
)
```

To validate cross-user denial, repeat the same sign-in and `sub` extraction for a
second disposable Cognito user and export `DDDART_APPSYNC_JWT_B` plus
`DDDART_APPSYNC_USER_SUB_B`.

#### Full local run example

```bash
export DDDART_APPSYNC_REALTIME_URL='wss://example.appsync-realtime-api.us-east-1.amazonaws.com/event/realtime'
export DDDART_APPSYNC_HTTP_ENDPOINT='https://example.appsync-api.us-east-1.amazonaws.com/event'
# Export DDDART_APPSYNC_JWT_A and DDDART_APPSYNC_USER_SUB_A as shown above.

cd packages/dddart_events_distributed
dart test -P aws_smoke test/appsync_events_aws_smoke_test.dart
```

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  dddart_events_distributed: ^0.1.0

dev_dependencies:
  build_runner: ^2.4.0
```

Then run:

```bash
dart pub get
```

## Quick Start

### 1. Define Your Domain Events

Create domain events with the `@Serializable` annotation:

```dart
import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';

part 'user_events.g.dart';

@Serializable()
class UserCreatedEvent extends DomainEvent {
  final String email;
  final String name;
  
  UserCreatedEvent({
    required super.aggregateId,
    required this.email,
    required this.name,
    super.context,
  });
}

@Serializable()
class OrderPurchasedEvent extends DomainEvent {
  final double amount;
  final String productId;
  
  OrderPurchasedEvent({
    required super.aggregateId,
    required this.amount,
    required this.productId,
    super.context,
  });
}
```

### 2. Generate Serialization Code

Run the code generator to create serializers and the event registry:

```bash
dart run build_runner build
```

This generates:
- `user_events.g.dart` - Serialization methods for your events
- Event registry map for deserialization

### 3. Set Up the Server

Create an EventBusServer with automatic event persistence:

```dart
import 'package:dddart/dddart.dart';
import 'package:dddart_events_distributed/dddart_events_distributed.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

void main() async {
  // Create local EventBus
  final eventBus = EventBus();
  
  // Create event repository (use any database implementation)
  final repository = InMemoryEventRepository();
  
  // Create EventBusServer with automatic persistence
  final server = EventBusServer<StoredEvent>(
    localEventBus: eventBus,
    eventRepository: repository,
    retentionDuration: const Duration(hours: 24),
    storedEventFactory: StoredEvent.fromDomainEvent,
  );
  
  // Subscribe to events locally
  server.on<UserCreatedEvent>().listen((event) {
    print('User created: ${event.email}');
  });
  
  // Create HTTP endpoints
  final endpoints = EventHttpEndpoints(
    eventRepository: repository,
  );
  
  // Set up HTTP routes
  final router = Router()
    ..get('/events', endpoints.handleGetEvents)
    ..post('/events', (request) => endpoints.handlePostEvent(request, server));
  
  // Start HTTP server
  final httpServer = await shelf_io.serve(router.call, 'localhost', 8080);
  print('Server listening on http://${httpServer.address.host}:${httpServer.port}');
  
  // Publish events - they're automatically persisted
  server.publish(UserCreatedEvent(
    aggregateId: UuidValue.generate(),
    email: 'alice@example.com',
    name: 'Alice',
  ));
}
```

### 4. Set Up the Client

Create an EventBusClient that polls for events:

```dart
import 'package:dddart/dddart.dart';
import 'package:dddart_events_distributed/dddart_events_distributed.dart';
import 'user_events.dart';

void main() async {
  // Create local EventBus
  final eventBus = EventBus();
  
  // Create EventBusClient with polling
  final client = EventBusClient(
    localEventBus: eventBus,
    serverUrl: 'http://localhost:8080',
    eventRegistry: generatedEventRegistry, // Generated by build_runner
    pollingInterval: const Duration(seconds: 5),
    autoForward: true, // Automatically forward local events to server
  );
  
  // Subscribe to events received from server
  client.on<UserCreatedEvent>().listen((event) {
    print('Received user created: ${event.email}');
  });
  
  client.on<OrderPurchasedEvent>().listen((event) {
    print('Received order: \$${event.amount}');
  });
  
  // Publish local events (auto-forwarded to server)
  client.publish(OrderPurchasedEvent(
    aggregateId: UuidValue.generate(),
    amount: 99.99,
    productId: 'product-123',
  ));
}
```

## Core Concepts

### EventBusServer

The server-side component that wraps a local EventBus and adds:
- **Automatic Persistence**: All events published to the local EventBus are automatically persisted
- **HTTP Endpoints**: GET and POST endpoints for event distribution
- **Event Cleanup**: Optional retention policies to delete old events

```dart
final server = EventBusServer<StoredEvent>(
  localEventBus: eventBus,
  eventRepository: repository,
  retentionDuration: const Duration(hours: 24), // Optional
  storedEventFactory: StoredEvent.fromDomainEvent,
);

// Publish events (automatically persisted)
server.publish(myEvent);

// Subscribe to events locally
server.on<MyEvent>().listen((event) { ... });

// Clean up old events
await server.cleanup();

// Close when done
await server.close();
```

### EventBusClient

The client-side component that wraps a local EventBus and adds:
- **HTTP Polling**: Periodically polls the server for new events
- **Automatic Catch-up**: Requests events since last known timestamp
- **Event Forwarding**: Optionally forwards local events to the server

```dart
final client = EventBusClient(
  localEventBus: eventBus,
  serverUrl: 'http://localhost:8080',
  eventRegistry: generatedEventRegistry,
  pollingInterval: const Duration(seconds: 5),
  autoForward: true, // Enable automatic forwarding
  initialTimestamp: DateTime.now().subtract(const Duration(hours: 1)),
);

// Publish events (auto-forwarded if enabled)
client.publish(myEvent);

// Subscribe to events from server
client.on<MyEvent>().listen((event) { ... });

// Close when done
await client.close();
```

### StoredEvent

A wrapper class that stores serialized domain events for network distribution:

```dart
@Serializable()
class StoredEvent extends AggregateRoot {
  final UuidValue aggregateId;
  final String eventType;
  final String eventJson;
  final String? userId;
  final String? tenantId;
  final String? sessionId;
  
  // Create from DomainEvent
  factory StoredEvent.fromDomainEvent(DomainEvent event) { ... }
}
```

**Authorization Fields**: StoredEvent includes common authorization fields (userId, tenantId, sessionId) extracted from the DomainEvent's context map. You can extend StoredEvent to add custom authorization fields.

### EventRepository

An abstract class that extends Repository with time-range queries:

```dart
abstract class EventRepository<T extends StoredEvent> implements Repository<T> {
  Future<List<T>> findSince(DateTime timestamp);
  Future<void> deleteOlderThan(DateTime timestamp);
}
```

## Authorization Filtering

Control which events each client can receive using authorization filters:

```dart
final endpoints = EventHttpEndpoints(
  eventRepository: repository,
  authorizationFilter: (event, request) {
    // Filter by tenant ID from header
    final tenantId = request.headers['x-tenant-id'];
    if (tenantId == null) return true;
    return event.tenantId == tenantId;
  },
);
```

**Authorization Context**: Include authorization data in event context:

```dart
server.publish(UserCreatedEvent(
  aggregateId: userId,
  email: 'alice@example.com',
  name: 'Alice',
  context: {
    'userId': 'user-123',
    'tenantId': 'tenant-1',
    'sessionId': 'session-abc',
  },
));
```

The authorization fields are automatically extracted and stored in StoredEvent for filtering.

## Repository Implementation

Use any database implementation by extending StoredEvent and implementing EventRepository:

### MongoDB Example

```dart
@Serializable()
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

class StoredEventMongoRepository extends EventRepository<StoredEventMongo> {
  // ... generated Repository methods
  
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

### MySQL Example

```dart
@Serializable()
@GenerateMysqlRepository()
class StoredEventMysql extends StoredEvent {
  StoredEventMysql({
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

// Repository implementation with time-range queries
class StoredEventMysqlRepository extends EventRepository<StoredEventMysql> {
  // ... generated Repository methods
  
  @override
  Future<List<StoredEventMysql>> findSince(DateTime timestamp) async {
    final results = await connection.query(
      'SELECT * FROM stored_events WHERE created_at >= ? ORDER BY created_at',
      [timestamp.toIso8601String()],
    );
    return results.map((row) => StoredEventMysql.fromJson(row)).toList();
  }
  
  @override
  Future<void> deleteOlderThan(DateTime timestamp) async {
    await connection.query(
      'DELETE FROM stored_events WHERE created_at < ?',
      [timestamp.toIso8601String()],
    );
  }
}
```

### In-Memory Example

For testing or development:

```dart
class InMemoryEventRepository implements EventRepository<StoredEvent> {
  final List<StoredEvent> _events = [];
  
  @override
  Future<void> save(StoredEvent event) async {
    _events.add(event);
  }
  
  @override
  Future<List<StoredEvent>> findSince(DateTime timestamp) async {
    return _events
        .where((e) => e.createdAt.isAfter(timestamp) || 
                      e.createdAt.isAtSameMomentAs(timestamp))
        .toList();
  }
  
  @override
  Future<void> deleteOlderThan(DateTime timestamp) async {
    _events.removeWhere((e) => e.createdAt.isBefore(timestamp));
  }
  
  // ... other Repository methods
}
```

## Custom Authorization Fields

Extend StoredEvent to add application-specific authorization fields:

```dart
@Serializable()
@GenerateMysqlRepository()
class MyStoredEvent extends StoredEvent {
  final List<String>? userRoles;
  final String? organizationId;
  
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
  
  @override
  List<Object?> get props => [...super.props, userRoles, organizationId];
  
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

// Use in EventBusServer
final server = EventBusServer<MyStoredEvent>(
  localEventBus: eventBus,
  eventRepository: myRepository,
  storedEventFactory: MyStoredEvent.fromDomainEvent,
);
```

## HTTP API

### GET /events?since=<timestamp>

Retrieve events since a specific timestamp:

```bash
curl "http://localhost:8080/events?since=2024-12-04T10:00:00.000Z"
```

Response:
```json
[
  {
    "id": "event-uuid-1",
    "createdAt": "2024-12-04T10:00:05.000Z",
    "aggregateId": "user-123",
    "eventType": "UserCreatedEvent",
    "eventJson": "{\"email\":\"user@example.com\"}",
    "userId": "user-123",
    "tenantId": "tenant-1",
    "sessionId": null
  }
]
```

### POST /events

Post a new event to the server:

```bash
curl -X POST http://localhost:8080/events \
  -H "Content-Type: application/json" \
  -d '{
    "id": "event-uuid",
    "createdAt": "2024-12-04T10:00:15.000Z",
    "aggregateId": "user-789",
    "eventType": "UserUpdatedEvent",
    "eventJson": "{\"email\":\"new@example.com\"}",
    "userId": "user-789"
  }'
```

Response:
```json
{
  "id": "event-uuid",
  "createdAt": "2024-12-04T10:00:15.000Z"
}
```

## Event Cleanup

Configure retention policies to automatically delete old events:

```dart
final server = EventBusServer<StoredEvent>(
  localEventBus: eventBus,
  eventRepository: repository,
  retentionDuration: const Duration(hours: 24),
  storedEventFactory: StoredEvent.fromDomainEvent,
);

// Manually trigger cleanup
await server.cleanup();

// Or schedule periodic cleanup
Timer.periodic(const Duration(hours: 1), (_) async {
  await server.cleanup();
});
```

## Deferred registry generation

The distributed event registry generator is a work-in-progress surface. Its
generated contract and integration with the client and server remain deferred
to EVENT-001 through EVENT-004, so it is not enabled by the active example and
must not be treated as a supported registry workflow yet. The historical
[generator notes](GENERATOR_USAGE.md) describe the intended direction only.

## Examples

See the [example status](example/README.md) for the current boundary. The only
active example is
[`custom_stored_event_json_example.dart`](example/custom_stored_event_json_example.dart),
an independent JSON round-trip that makes no registry, transport, polling, or
bulk-range claim. The former server, client, and end-to-end sketches are
preserved under `example/legacy/` as deferred WIP files.

Run the JSON-only example from this package directory:

```bash
cd example
dart pub get
dart run build_runner build --delete-conflicting-outputs
dart run custom_stored_event_json_example.dart
```

## Architecture

### Event Flow

**Server → Client:**
```
Server EventBus → EventBusServer → Repository → HTTP GET → EventBusClient → Client EventBus
```

**Client → Server:**
```
Client EventBus → EventBusClient → HTTP POST → EventBusServer → Server EventBus → Repository
```

### Bidirectional Flow

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

## Platform Support

Works on all Dart platforms:
- ✅ **Server** - Dart VM and compiled executables
- ✅ **Web** - Dart web applications (client-side)
- ✅ **Mobile** - Flutter iOS and Android apps (client-side)
- ✅ **Desktop** - Flutter desktop applications (client-side)

## Best Practices

### 1. Use Authorization Context

Always include authorization data in event context:

```dart
server.publish(MyEvent(
  aggregateId: id,
  context: {
    'userId': currentUserId,
    'tenantId': currentTenantId,
  },
));
```

### 2. Implement Proper Error Handling

Handle errors gracefully in event handlers:

```dart
client.on<MyEvent>().listen(
  (event) async {
    try {
      await processEvent(event);
    } catch (e) {
      logger.error('Failed to process event', e);
    }
  },
  onError: (error) {
    logger.error('Event handler error', error);
  },
);
```

### 3. Configure Appropriate Polling Intervals

Balance between latency and server load:

```dart
// High-frequency updates (more server load)
pollingInterval: const Duration(seconds: 1)

// Standard updates (balanced)
pollingInterval: const Duration(seconds: 5)

// Low-frequency updates (less server load)
pollingInterval: const Duration(seconds: 30)
```

### 4. Use Retention Policies

Prevent unbounded event storage growth:

```dart
final server = EventBusServer<StoredEvent>(
  // ...
  retentionDuration: const Duration(days: 7),
);

// Schedule periodic cleanup
Timer.periodic(const Duration(hours: 6), (_) async {
  await server.cleanup();
});
```

### 5. Index Database Queries

Ensure your repository implementation has proper indexes:

```sql
-- MySQL example
CREATE INDEX idx_created_at ON stored_events(created_at);
CREATE INDEX idx_tenant_id ON stored_events(tenant_id);
CREATE INDEX idx_user_id ON stored_events(user_id);
```

## Troubleshooting

### Events Not Being Received

1. Check that the server is running and accessible
2. Verify the client's `serverUrl` is correct
3. Check that events are being persisted (query the repository directly)
4. Verify the event registry includes your event types
5. Check for authorization filter issues

### Deserialization Errors

1. Ensure `build_runner` has been run to generate serializers
2. Verify the event registry includes your event types
3. Check that event JSON structure matches the event class
4. Look for type mismatches in event fields

### Authorization Filter Not Working

1. Verify authorization fields are set in event context
2. Check that StoredEvent.fromDomainEvent extracts the fields correctly
3. Test the filter logic independently
4. Check HTTP request headers are being sent correctly

## Contributing

Contributions are welcome! Please read our contributing guidelines and submit pull requests to our repository.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
