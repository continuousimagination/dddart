# Implementation Plan

- [x] 1. Set up dddart_http package structure
  - Create package directory and pubspec.yaml with dependencies (shelf, shelf_router, dddart, dddart_serialization)
  - Create lib/dddart_http.dart main export file
  - Create src/ directory for implementation files
  - _Requirements: 1.1, 5.2_

- [x] 2. Implement core types and interfaces
  - [x] 2.1 Create QueryResult class
    - Define QueryResult<T> with items list and optional totalCount
    - _Requirements: 7.6, 8.8_
  
  - [x] 2.2 Create QueryHandler typedef
    - Define QueryHandler<T> function signature with repository, queryParams, skip, take parameters
    - _Requirements: 8.1, 8.3_
  
  - [x] 2.3 Create UnsupportedMediaTypeException
    - Define exception class for content negotiation failures
    - _Requirements: 2.5, 2.6_

- [x] 3. Implement ErrorMapper
  - [x] 3.1 Create ErrorMapper class with mapException method
    - Implement RFC 7807 Problem Details response format
    - Map RepositoryException types to appropriate HTTP status codes (404, 409, 422)
    - Map DeserializationException to 400
    - Map SerializationException to 500
    - Map UnsupportedMediaTypeException to 406
    - Default to 500 for unknown exceptions
    - _Requirements: 4.5, 4.6, 4.7, 4.8, 4.9, 4.10_

- [x] 4. Implement ResponseBuilder
  - [x] 4.1 Create ResponseBuilder class
    - Implement ok() method for 200 responses with serialization
    - Implement created() method for 201 responses with serialization
    - Implement okList() method for 200 responses with array serialization and X-Total-Count header
    - Implement noContent() method for 204 responses
    - Implement badRequest() method with RFC 7807 format
    - Implement notFound() method with RFC 7807 format
    - All methods accept serializer and content type parameters
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 7.6_

- [x] 5. Implement CrudResource class
  - [x] 5.1 Create CrudResource class with configuration fields
    - Define constructor with path, repository, serializers map, queryHandlers, customExceptionHandlers, pagination config
    - Store configuration in final fields
    - _Requirements: 1.1, 2.1, 2.2, 3.1, 7.3, 7.4, 7.5, 8.1, 9.1_
  
  - [x] 5.2 Implement content negotiation helper methods
    - Implement _selectSerializer() to parse Accept header and select appropriate serializer
    - Throw UnsupportedMediaTypeException if no matching serializer found
    - Default to first serializer if Accept is */\* or missing
    - _Requirements: 2.4, 2.6, 2.7_
  
  - [x] 5.3 Implement exception handling helper
    - Implement _handleException() to check customExceptionHandlers first
    - Fall back to ErrorMapper.mapException() if no custom handler found
    - _Requirements: 9.2, 9.3, 9.4, 9.5_
  
  - [x] 5.4 Implement pagination helper
    - Implement _parsePagination() to extract skip and take from query parameters
    - Apply defaults and enforce maxTake limit
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_
  
  - [x] 5.5 Implement handleGetById method
    - Parse ID from URL using UuidValue.fromString()
    - Call repository.getById()
    - Select serializer based on Accept header
    - Return 200 response with serialized aggregate
    - Handle exceptions via _handleException()
    - _Requirements: 1.3, 2.4, 2.8, 3.2, 4.1_
  
  - [x] 5.6 Implement handleQuery method
    - Parse query parameters and extract pagination params
    - If no filter params: call _getAllItems() with pagination
    - If multiple filter params: return 400 error
    - If one filter param: look up handler in queryHandlers map
    - If handler not found: return 400 error
    - If handler found: invoke with repository, params, skip, take
    - Select serializer based on Accept header
    - Return 200 response with serialized array and X-Total-Count header
    - Handle exceptions via _handleException()
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 7.7, 8.2, 8.3, 8.4, 8.5, 8.7, 8.8, 8.9_
  
  - [x] 5.7 Implement handleCreate method
    - Check Content-Type header and select request serializer
    - Return 415 if Content-Type not supported
    - Read request body and deserialize using request serializer
    - Call repository.save()
    - Select response serializer based on Accept header
    - Return 201 response with serialized aggregate
    - Handle exceptions via _handleException()
    - _Requirements: 1.4, 2.3, 2.5, 2.8, 3.3, 4.2_
  
  - [x] 5.8 Implement handleUpdate method
    - Check Content-Type header and select request serializer
    - Return 415 if Content-Type not supported
    - Read request body and deserialize using request serializer
    - Call repository.save()
    - Select response serializer based on Accept header
    - Return 200 response with serialized aggregate
    - Handle exceptions via _handleException()
    - _Requirements: 1.5, 2.3, 2.5, 2.8, 3.4, 4.3_
  
  - [x] 5.9 Implement handleDelete method
    - Parse ID from URL using UuidValue.fromString()
    - Call repository.deleteById()
    - Return 204 No Content response
    - Handle exceptions via _handleException()
    - _Requirements: 1.6, 3.5, 4.4_

- [x] 6. Implement HttpServer class
  - [x] 6.1 Create HttpServer class with port configuration
    - Define constructor with optional port parameter (default 8080)
    - Store list of registered CrudResource instances
    - _Requirements: 5.1_
  
  - [x] 6.2 Implement registerResource method
    - Accept CrudResource instance and add to internal list
    - _Requirements: 1.1, 1.2_
  
  - [x] 6.3 Implement start method
    - Create shelf_router Router instance
    - For each registered CrudResource, register routes:
      - GET /{path}/:id → resource.handleGetById
      - GET /{path} → resource.handleQuery
      - POST /{path} → resource.handleCreate
      - PUT /{path}/:id → resource.handleUpdate
      - DELETE /{path}/:id → resource.handleDelete
    - Start shelf server with router on configured port
    - _Requirements: 1.2, 5.1, 5.2, 5.3, 5.4_
  
  - [x] 6.4 Implement stop method
    - Stop the shelf server
    - Clean up resources
    - _Requirements: 5.1_

- [x] 7. Create example application
  - [x] 7.1 Define example aggregate root with child entities
    - Create User aggregate root class extending AggregateRoot
    - Include child entities and value objects in the model
    - _Requirements: 10.1_
  
  - [x] 7.2 Create JSON serializer for example aggregate
    - Implement JsonSerializer<User> with toJson and fromJson methods
    - _Requirements: 10.2, 10.3_
  
  - [x] 7.3 Set up example server with CRUD resource
    - Create InMemoryRepository<User> instance
    - Create HttpServer instance
    - Register CrudResource with:
      - Path: '/users'
      - Repository: InMemoryRepository
      - Serializers: JSON (and optionally YAML for demonstration)
      - Query handlers: at least one custom handler (e.g., firstName)
      - Custom exception handlers: at least one example
      - Pagination configuration
    - Start server
    - _Requirements: 10.2, 10.3, 10.4, 10.5, 10.6, 10.7, 10.8_
  
  - [x] 7.4 Add example query handler
    - Implement handler for filtering by a field (e.g., firstName)
    - Return QueryResult with filtered items and total count
    - _Requirements: 10.6_
  
  - [x] 7.5 Add example custom exception handler
    - Define a custom domain exception
    - Register handler that returns appropriate HTTP response with RFC 7807 format
    - _Requirements: 10.8_

- [x] 8. Update main export file
  - Export all public classes and types from lib/dddart_http.dart
  - Include: CrudResource, HttpServer, QueryHandler, QueryResult, ErrorMapper, ResponseBuilder
  - _Requirements: All_

- [x] 9. Add package documentation
  - Create README.md with usage examples
  - Document content negotiation support
  - Document custom query handlers
  - Document custom exception handlers
  - Document pagination
  - Include link to example application
  - _Requirements: All_

- [x] 10. Implement unit tests for ErrorMapper
  - [x] 10.1 Test RepositoryException mapping
    - Test notFound exception maps to 404
    - Test duplicate exception maps to 409
    - Test constraint exception maps to 422
    - Verify RFC 7807 response format
    - _Requirements: 4.5, 4.6, 4.7_
  
  - [x] 10.2 Test serialization exception mapping
    - Test DeserializationException maps to 400
    - Test SerializationException maps to 500
    - Verify error message formatting
    - _Requirements: 4.8, 4.9_
  
  - [x] 10.3 Test content negotiation exception mapping
    - Test UnsupportedMediaTypeException maps to 406
    - Verify RFC 7807 response format
    - _Requirements: 4.10_
  
  - [x] 10.4 Test unknown exception handling
    - Test generic exceptions map to 500
    - Verify default error response format
    - _Requirements: 4.10_

- [x] 11. Implement unit tests for ResponseBuilder
  - [x] 11.1 Test single aggregate responses
    - Test ok() method returns 200 with serialized body
    - Test created() method returns 201 with serialized body
    - Verify Content-Type header is set correctly
    - _Requirements: 4.1, 4.2_
  
  - [x] 11.2 Test aggregate list responses
    - Test okList() method returns 200 with serialized array
    - Test X-Total-Count header is included when totalCount provided
    - Test X-Total-Count header is omitted when totalCount is null
    - Verify Content-Type header is set correctly
    - _Requirements: 4.3, 7.6_
  
  - [x] 11.3 Test empty and error responses
    - Test noContent() method returns 204 with empty body
    - Test badRequest() method returns 400 with RFC 7807 format
    - Test notFound() method returns 404 with RFC 7807 format
    - _Requirements: 4.4_

- [x] 12. Implement unit tests for CrudResource
  - [x] 12.1 Test handleGetById operation
    - Test successful retrieval returns 200 with serialized aggregate
    - Test ID parsing with valid UUID
    - Test repository.getById() is called with correct ID
    - Test Accept header content negotiation
    - Test 404 response when aggregate not found
    - Test exception handling via _handleException()
    - _Requirements: 1.3, 2.4, 2.8, 3.2, 4.1_
  
  - [x] 12.2 Test handleQuery with no filters
    - Test returns all items with pagination
    - Test default skip and take values are applied
    - Test X-Total-Count header is included
    - Test Accept header content negotiation
    - _Requirements: 6.1, 7.1, 7.2, 7.3, 7.6_
  
  - [x] 12.3 Test handleQuery with single filter
    - Test query handler is invoked with correct parameters
    - Test pagination parameters are passed to handler
    - Test 400 response when handler not found
    - Test successful response with filtered results
    - _Requirements: 8.2, 8.3, 8.4, 8.5, 8.7, 8.8_
  
  - [x] 12.4 Test handleQuery with multiple filters
    - Test returns 400 error when multiple filter params provided
    - Test pagination params don't count as filter params
    - Verify error message follows RFC 7807 format
    - _Requirements: 8.9_
  
  - [x] 12.5 Test handleCreate operation
    - Test successful creation returns 201 with serialized aggregate
    - Test Content-Type header parsing for request
    - Test Accept header parsing for response
    - Test 415 response for unsupported Content-Type
    - Test deserialization of request body
    - Test repository.save() is called
    - Test exception handling via _handleException()
    - _Requirements: 1.4, 2.3, 2.5, 2.8, 3.3, 4.2_
  
  - [x] 12.6 Test handleUpdate operation
    - Test successful update returns 200 with serialized aggregate
    - Test Content-Type header parsing for request
    - Test Accept header parsing for response
    - Test 415 response for unsupported Content-Type
    - Test deserialization of request body
    - Test repository.save() is called
    - Test exception handling via _handleException()
    - _Requirements: 1.5, 2.3, 2.5, 2.8, 3.4, 4.3_
  
  - [x] 12.7 Test handleDelete operation
    - Test successful deletion returns 204 No Content
    - Test ID parsing with valid UUID
    - Test repository.deleteById() is called with correct ID
    - Test 404 response when aggregate not found
    - Test exception handling via _handleException()
    - _Requirements: 1.6, 3.5, 4.4_
  
  - [x] 12.8 Test content negotiation helpers
    - Test _selectSerializer() with various Accept headers
    - Test default serializer selection when Accept is */*
    - Test default serializer selection when Accept is missing
    - Test UnsupportedMediaTypeException when Accept not supported
    - _Requirements: 2.4, 2.6, 2.7_
  
  - [x] 12.9 Test pagination helpers
    - Test _parsePagination() with valid skip and take params
    - Test default values when params missing
    - Test maxTake enforcement
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_
  
  - [x] 12.10 Test custom exception handling
    - Test _handleException() checks customExceptionHandlers first
    - Test fallback to ErrorMapper when no custom handler found
    - Test custom handler is invoked with correct exception
    - _Requirements: 9.2, 9.3, 9.4, 9.5_

- [x] 13. Implement unit tests for HttpServer
  - [x] 13.1 Test resource registration
    - Test registerResource() adds resource to internal list
    - Test multiple resources can be registered
    - _Requirements: 11.1, 11.5_
  
  - [x] 13.2 Test server lifecycle
    - Test start() creates router and starts shelf server on configured port
    - Test stop() closes shelf server cleanly
    - Test starting already-running server throws StateError
    - Test stopping non-running server throws StateError
    - _Requirements: 11.2, 11.3, 11.6_
  
  - [x] 13.3 Test route registration
    - Test routes are created for all CRUD operations (GET, POST, PUT, DELETE)
    - Test routes for multiple resources don't conflict
    - Verify route patterns match expected format
    - _Requirements: 11.4, 11.5_

- [x] 14. Implement end-to-end integration tests
  - [x] 14.1 Test complete CRUD lifecycle
    - Start test HTTP server with InMemoryRepository
    - Create aggregate via POST request using HTTP client
    - Retrieve aggregate via GET by ID
    - Update aggregate via PUT request
    - List aggregates via GET collection
    - Delete aggregate via DELETE request
    - Verify 404 after deletion
    - Stop test server
    - _Requirements: 12.1, 12.2_
  
  - [x] 14.2 Test query handlers end-to-end
    - Register custom query handler
    - Create multiple test aggregates
    - Query with filter parameter via HTTP client
    - Verify filtered results are returned
    - Test pagination with query filters
    - Verify X-Total-Count header in HTTP response
    - _Requirements: 12.3_
  
  - [x] 14.3 Test content negotiation end-to-end
    - Register multiple serializers (JSON and test format)
    - Test POST with different Content-Type headers
    - Test GET with different Accept headers
    - Verify correct serializer is used for each request
    - Test 415 response for unsupported Content-Type
    - Test 406 response for unsupported Accept
    - _Requirements: 12.4_
  
  - [x] 14.4 Test error scenarios end-to-end
    - Test 404 response for non-existent aggregate
    - Test 400 response for invalid JSON in request body
    - Test 400 response for invalid UUID format
    - Test 400 response for unsupported query parameters
    - Test 400 response for multiple query parameters
    - Verify all errors follow RFC 7807 format in HTTP responses
    - _Requirements: 12.5, 12.7_
  
  - [x] 14.5 Test custom exception handlers end-to-end
    - Register custom exception handler
    - Trigger custom exception in repository operation
    - Verify custom handler response is returned via HTTP
    - Test fallback to default error handling
    - _Requirements: 12.6_
  
  - [x] 14.6 Test pagination end-to-end
    - Create multiple test aggregates
    - Test GET collection with skip and take parameters
    - Verify X-Total-Count header is correct
    - Test maxTake enforcement
    - Test pagination with query filters
    - _Requirements: 12.3_

- [x] 15. Implement edge case handling in CrudResource
  - [x] 15.1 Add configuration validation
    - Validate serializers map is not empty in constructor
    - Validate path is not null or empty in constructor
    - Throw ArgumentError with descriptive message for invalid config
    - _Requirements: 13.1, 13.2_
  
  - [x] 15.2 Handle pagination edge cases
    - Treat negative skip as zero
    - Treat negative take as defaultTake
    - Handle zero take by returning empty array
    - Ensure maxTake enforcement works correctly
    - _Requirements: 13.3, 13.4, 13.5_
  
  - [x] 15.3 Handle content negotiation edge cases
    - Parse Accept header with quality values and select highest priority
    - Extract media type from Content-Type with charset parameters
    - Handle case-insensitive media type matching
    - _Requirements: 13.7, 13.8_
  
  - [x] 15.4 Handle query handler edge cases
    - Omit X-Total-Count header when totalCount is null
    - Handle empty results from query handlers
    - _Requirements: 13.6_

- [x] 16. Add unit tests for edge cases
  - [x] 16.1 Test configuration validation
    - Test empty serializers map throws ArgumentError
    - Test null path throws ArgumentError
    - Test empty path throws ArgumentError
    - _Requirements: 13.1, 13.2_
  
  - [x] 16.2 Test pagination edge cases
    - Test negative skip is treated as zero
    - Test negative take uses defaultTake
    - Test zero take returns empty array
    - Test very large skip returns empty array
    - _Requirements: 13.3, 13.4, 13.5_
  
  - [x] 16.3 Test content negotiation edge cases
    - Test Accept header with quality values
    - Test Content-Type with charset parameter
    - Test case-insensitive media type matching
    - _Requirements: 13.7, 13.8_
  
  - [x] 16.4 Test query handler edge cases
    - Test null totalCount omits X-Total-Count header
    - Test empty results from query handler
    - _Requirements: 13.6_

- [x] 17. Enhance example application
  - [x] 17.1 Add more comprehensive domain model
    - Ensure User aggregate has child entities (e.g., Address)
    - Ensure User aggregate has value objects (e.g., Email)
    - Add inline comments explaining aggregate structure
    - _Requirements: 10.1, 10.9_
  
  - [x] 17.2 Add multiple query handlers
    - Implement at least two custom query handlers (e.g., firstName, email)
    - Add inline comments explaining query handler implementation
    - _Requirements: 10.5, 10.9_
  
  - [x] 17.3 Add multiple custom exception handlers
    - Define at least two custom domain exceptions
    - Implement handlers that return appropriate HTTP responses
    - Add inline comments explaining exception handling flow
    - _Requirements: 10.7, 10.9_
  
  - [x] 17.4 Add sample data seeding
    - Seed multiple users with varied data
    - Include users that match query handler filters
    - Add inline comments explaining data setup
    - _Requirements: 10.8, 10.9_
  
  - [x] 17.5 Add usage instructions
    - Add README.md in example directory
    - Document how to run the example
    - Document example API endpoints to test
    - Provide curl commands for testing
    - _Requirements: 10.4, 10.5, 10.6, 10.7_
