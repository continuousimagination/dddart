# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2024-12-05

### Added

#### Core Components
- **StoredEvent**: Aggregate root wrapper class for persisting domain events
  - Includes common authorization fields (userId, tenantId, sessionId)
  - Supports extension for custom authorization fields
  - Automatic extraction from DomainEvent context
  - JSON serialization support via dddart_json

- **EventRepository**: Abstract repository interface with time-range queries
  - `findSince(DateTime)` method for retrieving events after a timestamp
  - `deleteOlderThan(DateTime)` method for cleanup operations
  - Extends standard Repository interface from dddart

- **EventBusServer**: Server-side component for distributed events
  - Wraps local EventBus with automatic event persistence
  - Subscribes to all DomainEvents and persists them automatically
  - Configurable retention duration for event cleanup
  - Generic support for custom StoredEvent subclasses
  - Cleanup method for deleting old events
  - Proper resource cleanup with close() method

- **EventBusClient**: Client-side component for distributed events
  - HTTP polling for retrieving events from server
  - Configurable polling interval (default: 5 seconds)
  - Automatic catch-up from last known timestamp
  - Optional automatic event forwarding to server
  - Event deserialization using generated event registry
  - Graceful handling of unknown event types
  - Proper resource cleanup with close() method

- **EventHttpEndpoints**: HTTP endpoint handlers for event distribution
  - GET /events endpoint with ISO 8601 timestamp parameter
  - POST /events endpoint for receiving events
  - Optional authorization filter support
  - Proper error handling with appropriate HTTP status codes
  - Request logging integration

#### Code Generation
- **Event Registry Generator**: Automatic generation of event deserialization registry
  - Scans for @Serializable DomainEvent subclasses
  - Generates map of event type names to fromJson factory functions
  - Outputs as `generatedEventRegistry` constant
  - Integrates with build_runner workflow

#### Features
- **HTTP Polling Transport**: Reliable event delivery with automatic catch-up
  - ISO 8601 timestamp-based queries
  - Automatic timestamp tracking
  - Resilient to network failures and disconnections

- **Authorization Filtering**: Fine-grained event access control
  - Filter events by userId, tenantId, sessionId
  - Custom filter functions with access to request context
  - Support for custom authorization fields via StoredEvent extension

- **Bidirectional Event Flow**: Events can flow in both directions
  - Server → Client: Automatic polling and deserialization
  - Client → Server: Optional automatic forwarding via HTTP POST
  - Both directions use the same event persistence mechanism

- **Event Cleanup**: Automatic deletion of old events
  - Configurable retention duration
  - Manual cleanup trigger via cleanup() method
  - Supports scheduled cleanup with Timer
  - Logs number of deleted events

- **Repository Pattern Integration**: Works with any database
  - In-memory implementation for testing
  - MongoDB support via @GenerateMongoRepository
  - MySQL support via @GenerateMysqlRepository
  - DynamoDB support via @GenerateDynamoDBRepository
  - SQLite support via @GenerateSqliteRepository
  - No code changes needed when switching databases

#### Testing
- Comprehensive property-based tests for all correctness properties
- Integration tests for end-to-end event flow
- Authorization filtering tests
- Cleanup functionality tests
- Event serialization round-trip tests
- Time-range query tests
- Unknown event type handling tests

#### Examples
- Server example with HTTP endpoints and authorization
- Client example with polling and event forwarding
- End-to-end example demonstrating bidirectional flow
- In-memory repository implementation
- Custom StoredEvent with additional authorization fields
- Example domain events (UserCreatedEvent, OrderPurchasedEvent, etc.)

#### Documentation
- Comprehensive README with quick start guide
- Server setup examples
- Client setup examples
- Authorization filtering examples
- Repository implementation guide for multiple databases
- Custom authorization fields guide
- HTTP API documentation
- Code generation usage guide
- Architecture diagrams
- Best practices and troubleshooting

### Technical Details

#### Dependencies
- dddart: Core DDD framework
- dddart_json: JSON serialization
- dddart_serialization: Serialization annotations
- http: ^1.1.0 - HTTP client for polling
- logging: ^1.2.0 - Diagnostic logging
- shelf: ^1.4.0 - HTTP server framework
- uuid: ^4.0.0 - UUID generation
- analyzer: ^6.0.0 - Code analysis for generator
- build: ^2.4.0 - Build system
- source_gen: ^1.4.0 - Code generation utilities

#### Platform Support
- ✅ Server (Dart VM) - EventBusServer
- ✅ Web - EventBusClient
- ✅ Mobile (Flutter) - EventBusClient
- ✅ Desktop (Flutter) - EventBusClient

#### Breaking Changes
None - initial release

### Known Limitations

- HTTP polling only (WebSocket support planned for future release)
- No built-in retry logic for failed HTTP requests (planned for future release)
- No event type filtering in HTTP queries (planned for future release)
- No pagination support for large event sets (planned for future release)
- Manual implementation of EventRepository time-range queries required

### Migration Guide

This is the initial release, so no migration is needed.

### Future Enhancements

See `future-enhancements.md` for planned features:
- Automatic time-range query generation in repository packages
- WebSocket transport for real-time delivery
- AWS EventBridge/SNS/SQS integrations
- Event type filtering in HTTP queries
- Pagination support for large event sets
- Exponential backoff retry logic
- Event compression for large payloads

[0.1.0]: https://github.com/your-org/dddart/releases/tag/dddart_events_distributed-v0.1.0
