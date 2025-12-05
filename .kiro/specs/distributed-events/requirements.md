# Requirements Document

## Introduction

This specification defines a distributed event system that extends DDDart's existing local EventBus to enable domain events to be published and subscribed across network boundaries. The system supports HTTP polling for reliable event delivery with automatic catch-up capabilities, and uses DDDart's Repository pattern for event storage to leverage existing database implementations. The architecture is designed to support multiple transports (HTTP polling initially, with WebSockets, AWS EventBridge, SNS, SQS, etc. as future additions).

## Glossary

- **EventBus**: The existing local publish/subscribe mechanism in the dddart package for domain events within a single application instance
- **DomainEvent**: Base class for all domain events in DDDart, containing id, createdAt, aggregateId, and context metadata
- **EventBusServer**: Server-side component that wraps EventBus to add automatic event persistence and HTTP endpoints for event distribution
- **EventBusClient**: Client-side component that wraps EventBus to add HTTP polling for remote events and optional automatic event forwarding
- **StoredEvent**: An AggregateRoot wrapper class that stores serialized domain events in a repository for network distribution
- **EventRepository**: A Repository interface extension that provides time-range queries (findSince, deleteOlderThan) for stored events
- **Transport**: The underlying mechanism used to distribute events (HTTP polling, WebSocket, AWS services, etc.)
- **HTTP Polling**: A transport where clients periodically request events since a timestamp, providing automatic catch-up
- **Authorization Filter**: A predicate function that determines whether a specific event should be delivered to a specific client
- **Event Context**: The metadata map on DomainEvent used for authorization and filtering decisions
- **Event Registry**: A generated map that associates event type names with deserialization factory functions
- **Catch-up**: The ability for clients to request all events since a specific timestamp, enabling recovery from disconnections

## Requirements

### Requirement 1

**User Story:** As a backend developer, I want to publish domain events from my server that are automatically persisted, so that clients can retrieve them via HTTP polling.

#### Acceptance Criteria

1. WHEN a DomainEvent is published to an EventBusServer, THEN the system SHALL publish it to the local EventBus
2. WHEN a DomainEvent is published to the local EventBus, THEN the system SHALL automatically wrap it in a StoredEvent and persist it to the event repository
3. WHEN wrapping a DomainEvent, THEN the system SHALL serialize the event including id, createdAt, aggregateId, context, event type, and event-specific data as JSON
4. WHEN event serialization fails, THEN the system SHALL log the error and continue processing other events
5. WHEN event persistence fails, THEN the system SHALL log the error and continue processing other events

### Requirement 2

**User Story:** As a client application developer, I want to poll for domain events from a server via HTTP, so that my application can respond to server-side changes with automatic catch-up.

#### Acceptance Criteria

1. WHEN a client polls the server for events, THEN the system SHALL accept a timestamp parameter indicating the last known event time
2. WHEN the server receives a poll request, THEN the system SHALL query the event repository for all events since the provided timestamp
3. WHEN events are found, THEN the system SHALL return them as a JSON array with event metadata and serialized event data
4. WHEN no events are found, THEN the system SHALL return an empty array
5. WHEN a client reconnects after disconnection, THEN the client SHALL request events since its last known timestamp to catch up on missed events

### Requirement 3

**User Story:** As a client application developer, I want to publish domain events to a server via HTTP POST, so that the server and other clients can react to client-side changes.

#### Acceptance Criteria

1. WHEN a client publishes a DomainEvent to the server, THEN the system SHALL serialize the event and send it via HTTP POST
2. WHEN the server receives a posted event, THEN the system SHALL deserialize it and publish it to the server's EventBusServer
3. WHEN the posted event is published to the server's EventBusServer, THEN the system SHALL persist it via the automatic storage listener
4. WHEN event deserialization fails on the server, THEN the system SHALL return HTTP 400 Bad Request with error details
5. WHEN event publication succeeds, THEN the system SHALL return HTTP 201 Created with the stored event's ID and timestamp

### Requirement 4

**User Story:** As a security-conscious developer, I want to control which events each client can receive, so that sensitive events are only delivered to authorized clients.

#### Acceptance Criteria

1. WHEN configuring HTTP event endpoints, THEN the system SHALL accept an authorization filter function
2. WHEN a client polls for events, THEN the system SHALL invoke the authorization filter for each event before including it in the response
3. WHEN the authorization filter returns false for an event, THEN the system SHALL NOT include the event in the response
4. WHEN the authorization filter returns true for an event, THEN the system SHALL include the event in the response
5. WHEN no authorization filter is configured, THEN the system SHALL return all events to all clients

### Requirement 5

**User Story:** As a developer, I want to use event context metadata for authorization decisions, so that I can implement user-specific, tenant-specific, or session-specific event filtering.

#### Acceptance Criteria

1. WHEN an authorization filter is invoked, THEN the system SHALL provide the StoredEvent including the original DomainEvent's context map
2. WHEN an authorization filter is invoked, THEN the system SHALL provide the HTTP request object for accessing headers, query parameters, and authentication data
3. WHEN a client polls for events, THEN the client SHALL be able to include authentication headers or tokens in the HTTP request
4. WHEN evaluating authorization, THEN the system SHALL have access to both event context and request authentication data
5. WHERE event context contains a userId field, THEN the authorization filter SHALL be able to restrict events to clients with matching authentication credentials

### Requirement 6

**User Story:** As a backend developer, I want to integrate the EventBusServer with my existing local EventBus, so that I can seamlessly bridge local and distributed events.

#### Acceptance Criteria

1. WHEN creating an EventBusServer, THEN the system SHALL accept an existing EventBus instance and an event repository
2. WHEN the EventBusServer is created, THEN the system SHALL automatically subscribe to all DomainEvents on the local EventBus
3. WHEN a DomainEvent is published to the local EventBus, THEN the EventBusServer listener SHALL wrap it in a StoredEvent and persist it to the repository
4. WHEN a client posts an event to the server, THEN the system SHALL publish it to the local EventBus, triggering the storage listener
5. WHEN an event is received from a client, THEN local event handlers SHALL receive it just like locally-published events

### Requirement 7

**User Story:** As a developer, I want HTTP endpoints for event polling and publishing, so that clients can retrieve and submit events using standard HTTP.

#### Acceptance Criteria

1. WHEN configuring HTTP event endpoints, THEN the system SHALL provide a GET endpoint that accepts a "since" timestamp query parameter in ISO 8601 format
2. WHEN a GET request is received, THEN the system SHALL parse the ISO 8601 timestamp and query the event repository using findSince
3. WHEN a GET request is received, THEN the system SHALL apply authorization filters to each event before including it in the response
4. WHEN configuring HTTP event endpoints, THEN the system SHALL provide a POST endpoint that accepts serialized DomainEvent JSON
5. WHEN a POST request is received, THEN the system SHALL deserialize the event and publish it to the local EventBus

### Requirement 8

**User Story:** As a client application developer, I want a client component that polls for events and publishes events via HTTP, so that my application can participate in distributed event flows.

#### Acceptance Criteria

1. WHEN creating an HTTP polling client, THEN the system SHALL accept a server URL and polling interval configuration
2. WHEN the client starts polling, THEN the system SHALL periodically send GET requests with the timestamp of the last received event in ISO 8601 format
3. WHEN events are received from the server, THEN the system SHALL deserialize them and publish them to the client's local EventBus
4. WHEN the client publishes an event, THEN the system SHALL serialize it and send it via HTTP POST to the server
5. WHEN the client starts for the first time, THEN the system SHALL request events from a configurable initial timestamp or current time in ISO 8601 format

### Requirement 9

**User Story:** As a developer, I want the distributed event system to use DDDart's Repository pattern for event storage, so that I can use any database implementation without changing my event distribution code.

#### Acceptance Criteria

1. WHEN implementing event storage, THEN the system SHALL define StoredEvent as an AggregateRoot that can be persisted via Repository
2. WHEN a developer wants to use MongoDB for event storage, THEN the developer SHALL extend StoredEvent and annotate with @GenerateMongoRepository
3. WHEN a developer wants to use DynamoDB for event storage, THEN the developer SHALL extend StoredEvent and annotate with @GenerateDynamoDBRepository
4. WHEN a developer wants to use in-memory storage, THEN the developer SHALL use InMemoryRepository<StoredEvent> without code generation
5. WHEN switching from one database to another, THEN the EventBusServer code SHALL NOT require changes

### Requirement 10

**User Story:** As a developer, I want comprehensive error handling and logging, so that I can diagnose issues with distributed event delivery.

#### Acceptance Criteria

1. WHEN an HTTP request fails, THEN the system SHALL log the error with appropriate severity
2. WHEN serialization or deserialization fails, THEN the system SHALL log the error and the event type
3. WHEN an authorization filter throws an exception, THEN the system SHALL log the error and exclude the event from the response
4. WHEN event persistence fails, THEN the system SHALL log the error with the event details
5. WHEN a client polls for events, THEN the system SHALL log the request with timestamp and number of events returned

### Requirement 11

**User Story:** As a developer, I want to query stored events by time range, so that I can implement catch-up and historical event retrieval.

#### Acceptance Criteria

1. WHEN implementing event storage, THEN the system SHALL provide an EventRepository abstract class that extends Repository and defines time-range query methods
2. WHEN the EventRepository interface is defined, THEN it SHALL include an abstract findSince method that accepts a DateTime parameter
3. WHEN a developer implements findSince, THEN the implementation SHALL return all StoredEvents with createdAt greater than or equal to the provided timestamp
4. WHEN the EventRepository interface is defined, THEN it SHALL include an abstract deleteOlderThan method for cleanup
5. WHEN a developer implements deleteOlderThan, THEN the implementation SHALL remove all StoredEvents with createdAt less than the provided timestamp

### Requirement 12

**User Story:** As a developer, I want to delete old events from storage, so that event storage doesn't grow unbounded.

#### Acceptance Criteria

1. WHEN configuring EventBusServer, THEN the system SHALL accept an optional retention duration parameter
2. WHEN EventBusServer has a retention duration configured, THEN calling the cleanup method SHALL delete all events older than the retention period
3. WHEN the cleanup method is called, THEN the system SHALL invoke the EventRepository's deleteOlderThan method with the calculated cutoff timestamp
4. WHEN events are deleted during cleanup, THEN the system SHALL log the number of events removed
5. WHERE Redis is used for storage, THEN developers SHALL be able to configure TTL on stored events for automatic database-level expiration without calling cleanup

### Requirement 13

**User Story:** As a developer, I want automatic serialization and deserialization of my custom domain events, so that I don't have to write manual serialization code for distributed events.

#### Acceptance Criteria

1. WHEN a developer annotates a DomainEvent subclass with @Serializable, THEN the dddart_json code generator SHALL generate toJson and fromJson methods
2. WHEN the dddart_events_distributed code generator runs, THEN the system SHALL scan for all @Serializable DomainEvent subclasses
3. WHEN @Serializable DomainEvent subclasses are found, THEN the system SHALL generate an event registry map that maps event type names to fromJson factory functions
4. WHEN the generated event registry is used, THEN the system SHALL deserialize events by looking up the factory function by event type string
5. WHEN an unknown event type is encountered during deserialization, THEN the system SHALL skip the event and log a warning

### Requirement 14

**User Story:** As a client developer, I want received events to be automatically deserialized and published to my local EventBus, so that my event handlers work the same way for local and distributed events.

#### Acceptance Criteria

1. WHEN a client receives StoredEvents from the server, THEN the system SHALL use the generated event registry to deserialize each event
2. WHEN an event is successfully deserialized, THEN the system SHALL publish the reconstructed DomainEvent to the client's local EventBus
3. WHEN deserialization fails for an event, THEN the system SHALL log the error and continue processing remaining events
4. WHEN an event type is not in the client's registry, THEN the system SHALL skip the event without error
5. WHEN a deserialized event is published to the local EventBus, THEN local event handlers SHALL receive it as if it were published locally

### Requirement 15

**User Story:** As a client developer, I want locally-published events to be automatically sent to the server, so that I don't have to manually POST each event.

#### Acceptance Criteria

1. WHEN creating an EventBusClient, THEN the system SHALL optionally accept a flag to enable automatic event forwarding to the server
2. WHEN automatic forwarding is enabled, THEN the system SHALL subscribe to all DomainEvents on the client's local EventBus
3. WHEN a DomainEvent is published to the client's local EventBus, THEN the forwarding listener SHALL serialize it and POST it to the server
4. WHEN automatic forwarding is disabled, THEN the client SHALL only send events via explicit API calls
5. WHEN an event POST fails, THEN the system SHALL log the error and optionally retry with exponential backoff
