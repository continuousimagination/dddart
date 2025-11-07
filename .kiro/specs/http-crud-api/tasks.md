# Implementation Plan

- [ ] 1. Set up dddart_http package structure
  - Create package directory and pubspec.yaml with dependencies (shelf, shelf_router, dddart, dddart_serialization)
  - Create lib/dddart_http.dart main export file
  - Create src/ directory for implementation files
  - _Requirements: 1.1, 5.2_

- [ ] 2. Implement core types and interfaces
  - [ ] 2.1 Create QueryResult class
    - Define QueryResult<T> with items list and optional totalCount
    - _Requirements: 7.6, 8.8_
  
  - [ ] 2.2 Create QueryHandler typedef
    - Define QueryHandler<T> function signature with repository, queryParams, skip, take parameters
    - _Requirements: 8.1, 8.3_
  
  - [ ] 2.3 Create UnsupportedMediaTypeException
    - Define exception class for content negotiation failures
    - _Requirements: 2.5, 2.6_

- [ ] 3. Implement ErrorMapper
  - [ ] 3.1 Create ErrorMapper class with mapException method
    - Implement RFC 7807 Problem Details response format
    - Map RepositoryException types to appropriate HTTP status codes (404, 409, 422)
    - Map DeserializationException to 400
    - Map SerializationException to 500
    - Map UnsupportedMediaTypeException to 406
    - Default to 500 for unknown exceptions
    - _Requirements: 4.5, 4.6, 4.7, 4.8, 4.9, 4.10_

- [ ] 4. Implement ResponseBuilder
  - [ ] 4.1 Create ResponseBuilder class
    - Implement ok() method for 200 responses with serialization
    - Implement created() method for 201 responses with serialization
    - Implement okList() method for 200 responses with array serialization and X-Total-Count header
    - Implement noContent() method for 204 responses
    - Implement badRequest() method with RFC 7807 format
    - Implement notFound() method with RFC 7807 format
    - All methods accept serializer and content type parameters
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 7.6_

- [ ] 5. Implement CrudResource class
  - [ ] 5.1 Create CrudResource class with configuration fields
    - Define constructor with path, repository, serializers map, queryHandlers, customExceptionHandlers, pagination config
    - Store configuration in final fields
    - _Requirements: 1.1, 2.1, 2.2, 3.1, 7.3, 7.4, 7.5, 8.1, 9.1_
  
  - [ ] 5.2 Implement content negotiation helper methods
    - Implement _selectSerializer() to parse Accept header and select appropriate serializer
    - Throw UnsupportedMediaTypeException if no matching serializer found
    - Default to first serializer if Accept is */\* or missing
    - _Requirements: 2.4, 2.6, 2.7_
  
  - [ ] 5.3 Implement exception handling helper
    - Implement _handleException() to check customExceptionHandlers first
    - Fall back to ErrorMapper.mapException() if no custom handler found
    - _Requirements: 9.2, 9.3, 9.4, 9.5_
  
  - [ ] 5.4 Implement pagination helper
    - Implement _parsePagination() to extract skip and take from query parameters
    - Apply defaults and enforce maxTake limit
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_
  
  - [ ] 5.5 Implement handleGetById method
    - Parse ID from URL using UuidValue.fromString()
    - Call repository.getById()
    - Select serializer based on Accept header
    - Return 200 response with serialized aggregate
    - Handle exceptions via _handleException()
    - _Requirements: 1.3, 2.4, 2.8, 3.2, 4.1_
  
  - [ ] 5.6 Implement handleQuery method
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
  
  - [ ] 5.7 Implement handleCreate method
    - Check Content-Type header and select request serializer
    - Return 415 if Content-Type not supported
    - Read request body and deserialize using request serializer
    - Call repository.save()
    - Select response serializer based on Accept header
    - Return 201 response with serialized aggregate
    - Handle exceptions via _handleException()
    - _Requirements: 1.4, 2.3, 2.5, 2.8, 3.3, 4.2_
  
  - [ ] 5.8 Implement handleUpdate method
    - Check Content-Type header and select request serializer
    - Return 415 if Content-Type not supported
    - Read request body and deserialize using request serializer
    - Call repository.save()
    - Select response serializer based on Accept header
    - Return 200 response with serialized aggregate
    - Handle exceptions via _handleException()
    - _Requirements: 1.5, 2.3, 2.5, 2.8, 3.4, 4.3_
  
  - [ ] 5.9 Implement handleDelete method
    - Parse ID from URL using UuidValue.fromString()
    - Call repository.deleteById()
    - Return 204 No Content response
    - Handle exceptions via _handleException()
    - _Requirements: 1.6, 3.5, 4.4_

- [ ] 6. Implement HttpServer class
  - [ ] 6.1 Create HttpServer class with port configuration
    - Define constructor with optional port parameter (default 8080)
    - Store list of registered CrudResource instances
    - _Requirements: 5.1_
  
  - [ ] 6.2 Implement registerResource method
    - Accept CrudResource instance and add to internal list
    - _Requirements: 1.1, 1.2_
  
  - [ ] 6.3 Implement start method
    - Create shelf_router Router instance
    - For each registered CrudResource, register routes:
      - GET /{path}/:id → resource.handleGetById
      - GET /{path} → resource.handleQuery
      - POST /{path} → resource.handleCreate
      - PUT /{path}/:id → resource.handleUpdate
      - DELETE /{path}/:id → resource.handleDelete
    - Start shelf server with router on configured port
    - _Requirements: 1.2, 5.1, 5.2, 5.3, 5.4_
  
  - [ ] 6.4 Implement stop method
    - Stop the shelf server
    - Clean up resources
    - _Requirements: 5.1_

- [ ] 7. Create example application
  - [ ] 7.1 Define example aggregate root with child entities
    - Create User aggregate root class extending AggregateRoot
    - Include child entities and value objects in the model
    - _Requirements: 10.1_
  
  - [ ] 7.2 Create JSON serializer for example aggregate
    - Implement JsonSerializer<User> with toJson and fromJson methods
    - _Requirements: 10.2, 10.3_
  
  - [ ] 7.3 Set up example server with CRUD resource
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
  
  - [ ] 7.4 Add example query handler
    - Implement handler for filtering by a field (e.g., firstName)
    - Return QueryResult with filtered items and total count
    - _Requirements: 10.6_
  
  - [ ] 7.5 Add example custom exception handler
    - Define a custom domain exception
    - Register handler that returns appropriate HTTP response with RFC 7807 format
    - _Requirements: 10.8_

- [ ] 8. Update main export file
  - Export all public classes and types from lib/dddart_http.dart
  - Include: CrudResource, HttpServer, QueryHandler, QueryResult, ErrorMapper, ResponseBuilder
  - _Requirements: All_

- [ ] 9. Add package documentation
  - Create README.md with usage examples
  - Document content negotiation support
  - Document custom query handlers
  - Document custom exception handlers
  - Document pagination
  - Include link to example application
  - _Requirements: All_
