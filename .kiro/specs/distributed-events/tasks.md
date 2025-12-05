# Implementation Plan

- [x] 1. Set up package structure and core data models
- [x] 1.1 Create dddart_events_distributed package structure
  - Create lib/, test/, example/ directories
  - Create pubspec.yaml with dependencies (dddart, dddart_json, uuid, logging)
  - Create analysis_options.yaml with very_good_analysis
  - _Requirements: 1.1, 1.2, 1.3_

- [x] 1.2 Implement StoredEvent aggregate root
  - Create StoredEvent class extending AggregateRoot
  - Add fields: aggregateId, eventType, eventJson, userId, tenantId, sessionId
  - Implement fromDomainEvent factory constructor that extracts authorization fields from DomainEvent.context
  - Add @Serializable annotation for JSON generation
  - _Requirements: 1.2, 1.3, 9.1_

- [x] 1.3 Write property test for StoredEvent serialization
  - **Property 2: Serialization preserves event data**
  - **Validates: Requirements 1.3**

- [x] 1.4 Implement EventRepository abstract class
  - Create EventRepository interface extending Repository
  - Add abstract findSince(DateTime) method
  - Add abstract deleteOlderThan(DateTime) method
  - _Requirements: 11.1, 11.2, 11.4_

- [x] 2. Implement EventBusServer component
- [x] 2.1 Create EventBusServer class with event persistence
  - Make EventBusServer generic: EventBusServer<T extends StoredEvent>
  - Accept localEventBus, eventRepository, and storedEventFactory in constructor
  - Subscribe to all DomainEvents on local EventBus
  - Implement _persistEvent listener that uses storedEventFactory to create StoredEvent
  - Add error handling and logging for persistence failures
  - _Requirements: 1.1, 1.2, 6.1, 6.2, 6.3_

- [x] 2.2 Write property test for event persistence
  - **Property 1: Published events are persisted**
  - **Validates: Requirements 1.2**

- [x] 2.3 Add cleanup functionality to EventBusServer
  - Accept optional retentionDuration parameter
  - Implement cleanup() method using deleteOlderThan
  - Add logging for cleanup operations
  - _Requirements: 12.1, 12.2, 12.3, 12.4_

- [x] 2.4 Write property test for cleanup
  - **Property 11: Cleanup deletes old events**
  - **Validates: Requirements 12.3**

- [x] 2.5 Add close() method to EventBusServer
  - Cancel event subscription
  - Close local EventBus
  - _Requirements: 6.1_

- [x] 3. Implement HTTP endpoints for event distribution
- [x] 3.1 Create EventHttpEndpoints class
  - Accept eventRepository and optional authorizationFilter
  - Add Logger for HTTP operations
  - _Requirements: 7.1, 7.4, 10.5_

- [x] 3.2 Implement GET /events endpoint
  - Parse "since" query parameter as ISO 8601 timestamp
  - Query eventRepository.findSince(timestamp)
  - Apply authorization filter if configured
  - Return JSON array of StoredEvents
  - Handle errors with appropriate HTTP status codes
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 7.1, 7.2, 7.3_

- [x] 3.3 Write property test for authorization filtering
  - **Property 7: Authorization filter controls event delivery**
  - **Validates: Requirements 4.3**

- [x] 3.4 Write property test for no-filter behavior
  - **Property 8: No filter means all events delivered**
  - **Validates: Requirements 4.5**

- [x] 3.5 Implement POST /events endpoint
  - Parse JSON body as StoredEvent
  - Save to eventRepository
  - Return 201 Created with event ID and timestamp
  - Handle deserialization errors with 400 Bad Request
  - _Requirements: 3.1, 3.2, 3.4, 3.5, 7.4, 7.5_

- [x] 3.6 Write unit tests for HTTP endpoints
  - Test GET with valid timestamp
  - Test GET with missing timestamp (400 error)
  - Test POST with valid event
  - Test POST with invalid JSON (400 error)
  - Test authorization filter integration
  - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_

- [x] 4. Implement EventBusClient component
- [x] 4.1 Create EventBusClient class with polling
  - Accept localEventBus, serverUrl, eventRegistry, pollingInterval
  - Accept optional autoForward flag and initialTimestamp
  - Initialize _lastTimestamp from initialTimestamp or current time
  - Start polling timer in constructor
  - _Requirements: 8.1, 8.2, 8.5, 15.1_

- [x] 4.2 Implement HTTP polling logic
  - Create _poll() method called by timer
  - Build GET request with "since" query parameter (ISO 8601)
  - Parse JSON response as list of StoredEvents
  - Call _processEvent for each received event
  - Handle HTTP errors with logging
  - _Requirements: 2.1, 2.5, 8.2, 8.5_

- [x] 4.3 Write property test for polling retrieval
  - **Property 4: Polling retrieves new events**
  - **Validates: Requirements 2.2**

- [x] 4.4 Implement event deserialization and publishing
  - Create _processEvent method
  - Extract eventType and eventJson from StoredEvent
  - Look up factory function in eventRegistry
  - Deserialize event using factory
  - Publish to local EventBus
  - Update _lastTimestamp
  - Handle unknown event types gracefully
  - _Requirements: 13.4, 14.1, 14.2, 14.3, 14.4, 14.5_

- [x] 4.5 Write property test for event registry deserialization
  - **Property 5: Event registry deserializes correctly**
  - **Validates: Requirements 13.4, 14.1**

- [x] 4.6 Write property test for unknown event types
  - **Property 6: Unknown event types are skipped**
  - **Validates: Requirements 13.5, 14.4**

- [x] 4.7 Implement automatic event forwarding
  - Subscribe to local EventBus if autoForward is true
  - Create _forwardEvent listener
  - Serialize event and POST to server
  - Handle POST errors with logging
  - _Requirements: 3.1, 8.4, 15.2, 15.3, 15.5_

- [x] 4.8 Write property test for auto-forward
  - **Property 9: Auto-forward sends events to server**
  - **Validates: Requirements 15.3**

- [x] 4.9 Write property test for disabled forwarding
  - **Property 10: Disabled forwarding prevents automatic POST**
  - **Validates: Requirements 15.4**

- [x] 4.10 Add close() method to EventBusClient
  - Cancel polling timer
  - Cancel event subscription
  - Close HTTP client
  - Close local EventBus
  - _Requirements: 8.1_

- [x] 5. Implement event registry code generation
- [x] 5.1 Create code generator for event registry
  - Scan for @Serializable DomainEvent subclasses
  - Generate map of event type names to fromJson factory functions
  - Output as generatedEventRegistry constant
  - _Requirements: 13.2, 13.3, 13.4_

- [x] 5.2 Write unit tests for code generator
  - Test scanning for @Serializable events
  - Test registry map generation
  - Test handling of multiple event types
  - _Requirements: 13.2, 13.3_

- [x] 6. Create example implementations
- [x] 6.1 Create example domain events and custom StoredEvent
  - Define UserCreatedEvent with @Serializable
  - Define OrderPurchasedEvent with @Serializable
  - Create example of extended StoredEvent with custom authorization fields (e.g., userRoles collection)
  - Run code generator to create serializers and registry
  - _Requirements: 13.1, 13.2_

- [x] 6.2 Create in-memory repository example
  - Implement InMemoryEventRepository extending EventRepository
  - Implement findSince using in-memory filtering
  - Implement deleteOlderThan using in-memory filtering
  - _Requirements: 9.4, 11.3, 11.5_

- [x] 6.3 Write property test for time-range queries
  - **Property 3: findSince returns events in time range**
  - **Validates: Requirements 11.3**

- [x] 6.4 Create server example
  - Set up EventBusServer with in-memory repository
  - Configure HTTP endpoints with shelf
  - Demonstrate event publishing and persistence
  - _Requirements: 1.1, 6.1, 7.1, 7.4_

- [x] 6.5 Create client example
  - Set up EventBusClient with polling
  - Configure event registry
  - Demonstrate event subscription and forwarding
  - _Requirements: 8.1, 8.2, 14.1, 15.1_

- [x] 6.6 Create end-to-end example
  - Start server with EventBusServer
  - Connect client with EventBusClient
  - Publish events from both sides
  - Demonstrate bidirectional event flow
  - _Requirements: 2.5, 3.1, 6.4, 6.5_

- [x] 7. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 8. Integration testing
- [x] 8.1 Write end-to-end integration test
  - Test server publishes event, client receives it
  - Test client publishes event, server receives it
  - Test catch-up after simulated disconnect
  - Test authorization filtering
  - _Requirements: 2.5, 3.1, 4.1, 4.2, 4.3, 6.4, 6.5_

- [x] 8.2 Write authorization integration test
  - Test events filtered by user context
  - Test events filtered by tenant context
  - Test no filter returns all events
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 5.1, 5.2, 5.3_

- [x] 8.3 Write cleanup integration test
  - Publish events with various timestamps
  - Call cleanup with retention duration
  - Verify old events deleted, recent events retained
  - _Requirements: 12.1, 12.2, 12.3_

- [x] 9. Documentation and README
- [x] 9.1 Create package README
  - Overview of distributed events system
  - Quick start guide
  - Server setup example
  - Client setup example
  - Authorization example
  - Repository implementation guide
  - _Requirements: All_

- [x] 9.2 Create CHANGELOG
  - Document initial release features
  - _Requirements: All_

- [x] 10. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.
