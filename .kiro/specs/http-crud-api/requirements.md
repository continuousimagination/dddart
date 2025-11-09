# Requirements Document

## Introduction

This feature provides HTTP CRUD API functionality for exposing aggregate roots through RESTful endpoints. The system enables developers to create HTTP APIs that perform Create, Read, Update, and Delete operations on aggregate roots using configurable serializers and the existing repository pattern. The implementation uses the shelf HTTP server framework and integrates with the dddart ecosystem's serialization and repository abstractions.

## Glossary

- **HTTP_API_System**: The system that exposes aggregate roots through HTTP endpoints
- **Aggregate_Root**: A domain-driven design entity that serves as the entry point to an aggregate
- **Repository**: A collection-like interface for persisting and retrieving aggregate roots
- **Serializer**: A component that converts aggregate roots to and from wire format (e.g., JSON, YAML)
- **Route**: A mapping between an HTTP method and URL pattern to a handler function
- **CRUD_Operations**: Create (POST), Read (GET), Update (PUT), Delete (DELETE) operations
- **shelf**: The Dart HTTP server framework used as the underlying web server
- **Request_Handler**: A function that processes an HTTP request and returns a response
- **Resource_Path**: The URL pattern that identifies a collection or individual resource
- **Content_Negotiation**: HTTP mechanism where clients specify preferred content formats via Accept and Content-Type headers
- **RFC_7807**: IETF standard for HTTP API problem details format

## Requirements

### Requirement 1

**User Story:** As a developer, I want to expose an aggregate root through HTTP CRUD endpoints, so that clients can interact with my domain model via REST API

#### Acceptance Criteria

1. THE HTTP_API_System SHALL provide a mechanism to register an Aggregate_Root type with a Resource_Path
2. WHEN an Aggregate_Root is registered, THE HTTP_API_System SHALL create standard CRUD endpoints for that resource
3. THE HTTP_API_System SHALL support GET requests to retrieve individual Aggregate_Root instances by ID
4. THE HTTP_API_System SHALL support POST requests to create new Aggregate_Root instances
5. THE HTTP_API_System SHALL support PUT requests to update existing Aggregate_Root instances
6. THE HTTP_API_System SHALL support DELETE requests to remove Aggregate_Root instances by ID

### Requirement 2

**User Story:** As a developer, I want to support multiple content formats through HTTP content negotiation, so that clients can request and send data in their preferred format

#### Acceptance Criteria

1. WHEN registering an Aggregate_Root, THE HTTP_API_System SHALL accept a map of content types to Serializer instances
2. THE HTTP_API_System SHALL support at least one Serializer per resource
3. WHEN a client sends a POST or PUT request, THE HTTP_API_System SHALL use the Content-Type header to select the appropriate Serializer for deserialization
4. WHEN a client sends a GET request, THE HTTP_API_System SHALL use the Accept header to select the appropriate Serializer for serialization
5. WHEN the Content-Type header specifies an unsupported format, THE HTTP_API_System SHALL return HTTP status 415 Unsupported Media Type
6. WHEN the Accept header specifies an unsupported format, THE HTTP_API_System SHALL return HTTP status 406 Not Acceptable
7. WHEN the Accept header is missing or set to */*, THE HTTP_API_System SHALL use the first registered Serializer as the default
8. THE HTTP_API_System SHALL set the Content-Type response header to match the selected Serializer format

### Requirement 3

**User Story:** As a developer, I want the API to use my repository implementation, so that CRUD operations persist data according to my storage strategy

#### Acceptance Criteria

1. WHEN registering an Aggregate_Root, THE HTTP_API_System SHALL accept a Repository instance
2. WHEN processing a GET request, THE HTTP_API_System SHALL invoke Repository.getById with the ID from the URL
3. WHEN processing a POST request, THE HTTP_API_System SHALL invoke Repository.save with the deserialized Aggregate_Root
4. WHEN processing a PUT request, THE HTTP_API_System SHALL invoke Repository.save with the deserialized Aggregate_Root
5. WHEN processing a DELETE request, THE HTTP_API_System SHALL invoke Repository.deleteById with the ID from the URL

### Requirement 4

**User Story:** As a developer, I want appropriate HTTP status codes and standardized error responses, so that API clients can handle errors correctly

#### Acceptance Criteria

1. WHEN a GET request succeeds, THE HTTP_API_System SHALL return HTTP status 200 with the serialized Aggregate_Root
2. WHEN a POST request succeeds, THE HTTP_API_System SHALL return HTTP status 201 with the serialized Aggregate_Root
3. WHEN a PUT request succeeds, THE HTTP_API_System SHALL return HTTP status 200 with the serialized Aggregate_Root
4. WHEN a DELETE request succeeds, THE HTTP_API_System SHALL return HTTP status 204 with no response body
5. THE HTTP_API_System SHALL format all error responses using RFC 7807 Problem Details format
6. THE HTTP_API_System SHALL set Content-Type to application/problem+json for all error responses
7. THE HTTP_API_System SHALL include type, title, status, and detail fields in all RFC 7807 error responses
8. WHEN a Repository operation throws RepositoryException with type notFound, THE HTTP_API_System SHALL return HTTP status 404
9. WHEN request body deserialization fails, THE HTTP_API_System SHALL return HTTP status 400 with error details
10. WHEN a Repository operation throws an unexpected exception, THE HTTP_API_System SHALL return HTTP status 500

### Requirement 5

**User Story:** As a developer, I want to run the HTTP server with my configured routes, so that I can serve API requests

#### Acceptance Criteria

1. THE HTTP_API_System SHALL provide a method to start the HTTP server on a specified port
2. THE HTTP_API_System SHALL use the shelf framework as the underlying HTTP server
3. WHEN the server starts, THE HTTP_API_System SHALL bind to the specified port and begin accepting requests
4. THE HTTP_API_System SHALL route incoming requests to the appropriate Request_Handler based on HTTP method and Resource_Path

### Requirement 6

**User Story:** As a developer, I want GET requests to collection endpoints to return all resources, so that clients can retrieve the full dataset

#### Acceptance Criteria

1. WHEN a GET request is made to a collection endpoint without query parameters, THE HTTP_API_System SHALL return all Aggregate_Root instances from the Repository
2. THE HTTP_API_System SHALL serialize the collection of Aggregate_Root instances as a JSON array
3. THE HTTP_API_System SHALL return HTTP status 200 for successful collection requests
4. THE HTTP_API_System SHALL return a JSON array for all collection endpoint requests, even when zero or one item matches
5. WHEN a GET request is made to an item endpoint with an ID, THE HTTP_API_System SHALL return a single JSON object (not an array)

### Requirement 7

**User Story:** As a developer, I want collection endpoints to support pagination, so that clients can retrieve large datasets efficiently

#### Acceptance Criteria

1. THE HTTP_API_System SHALL accept a "skip" query parameter to specify the number of items to skip
2. THE HTTP_API_System SHALL accept a "take" query parameter to specify the number of items to return
3. WHEN "skip" is not provided, THE HTTP_API_System SHALL use a configurable default skip value
4. WHEN "take" is not provided, THE HTTP_API_System SHALL use a configurable default take value
5. THE HTTP_API_System SHALL enforce a configurable maximum "take" value to prevent excessive queries
6. THE HTTP_API_System SHALL include an X-Total-Count header in collection responses indicating the total number of items
7. THE HTTP_API_System SHALL apply pagination to both filtered and unfiltered collection requests

### Requirement 8

**User Story:** As a developer, I want to define custom query handlers for collection endpoints, so that clients can filter or search resources using query parameters

#### Acceptance Criteria

1. THE HTTP_API_System SHALL provide a mechanism to register custom query handlers by mapping query parameter names to handler functions
2. WHEN a GET request to a collection endpoint includes exactly one query parameter other than skip and take, THE HTTP_API_System SHALL look up the corresponding handler by parameter name
3. WHEN a query parameter matches a registered handler, THE HTTP_API_System SHALL invoke the handler function with the repository, query parameters, and pagination parameters
4. WHEN a GET request includes multiple query parameters other than skip and take, THE HTTP_API_System SHALL return HTTP status 400 with message indicating parameters cannot be combined
5. WHEN a query parameter does not match any registered handler, THE HTTP_API_System SHALL return HTTP status 400 with message indicating the parameter is unsupported
6. THE HTTP_API_System SHALL allow developers to register the same handler function under multiple parameter names for backward compatibility
7. THE HTTP_API_System SHALL serialize the results from custom query handlers using the configured Serializer
8. THE HTTP_API_System SHALL apply pagination to results from custom query handlers
9. THE HTTP_API_System SHALL return a JSON array for all custom query handler results, regardless of the number of matching items

### Requirement 9

**User Story:** As a developer, I want to register custom exception handlers, so that I can map domain-specific exceptions to appropriate HTTP responses

#### Acceptance Criteria

1. WHEN registering an Aggregate_Root, THE HTTP_API_System SHALL accept a map of exception types to handler functions
2. WHEN an exception is thrown during request processing, THE HTTP_API_System SHALL first check the custom exception handlers map
3. WHEN a custom exception handler is found, THE HTTP_API_System SHALL invoke the handler and return its Response
4. WHEN no custom exception handler is found, THE HTTP_API_System SHALL fall back to built-in exception handling
5. THE HTTP_API_System SHALL provide built-in handling for RepositoryException, DeserializationException, and SerializationException
6. THE HTTP_API_System SHALL allow custom exception handlers to return any HTTP status code and response body
7. THE HTTP_API_System SHALL continue to handle built-in framework exceptions even when custom handlers are registered

### Requirement 10

**User Story:** As a developer, I want a working example that demonstrates the HTTP CRUD API, so that I can understand how to use the feature

#### Acceptance Criteria

1. THE HTTP_API_System SHALL include an example application that defines an Aggregate_Root with child entities and value objects
2. THE example application SHALL configure CRUD routes for the Aggregate_Root
3. THE example application SHALL use InMemoryRepository for data persistence
4. THE example application SHALL demonstrate all CRUD operations (GET by ID, GET collection, POST, PUT, DELETE)
5. THE example application SHALL demonstrate at least two custom query handlers using query parameters
6. THE example application SHALL demonstrate pagination with skip and take parameters
7. THE example application SHALL demonstrate custom exception handling with at least two custom exception types
8. THE example application SHALL seed sample data to enable immediate testing
9. THE example application SHALL include inline comments explaining key concepts

### Requirement 11

**User Story:** As a developer, I want comprehensive unit tests for HttpServer, so that I can trust the server lifecycle and routing behavior

#### Acceptance Criteria

1. THE HTTP_API_System SHALL include unit tests for HttpServer.registerResource method
2. THE HTTP_API_System SHALL include unit tests for HttpServer.start method
3. THE HTTP_API_System SHALL include unit tests for HttpServer.stop method
4. THE HTTP_API_System SHALL include unit tests verifying routes are created for all CRUD operations
5. THE HTTP_API_System SHALL include unit tests verifying multiple resources can be registered without conflicts
6. THE HTTP_API_System SHALL include unit tests for error conditions (starting already-running server, stopping non-running server)

### Requirement 12

**User Story:** As a developer, I want integration tests that verify end-to-end HTTP request/response flows, so that I can trust the complete system works correctly

#### Acceptance Criteria

1. THE HTTP_API_System SHALL include integration tests that start a real HTTP server and make actual HTTP requests
2. THE HTTP_API_System SHALL include integration tests for complete CRUD lifecycle (create, read, update, delete)
3. THE HTTP_API_System SHALL include integration tests for query handlers with filtering and pagination
4. THE HTTP_API_System SHALL include integration tests for content negotiation with multiple serializers
5. THE HTTP_API_System SHALL include integration tests for error scenarios (404, 400, 415, 406, 409)
6. THE HTTP_API_System SHALL include integration tests for custom exception handlers
7. THE HTTP_API_System SHALL include integration tests verifying RFC 7807 error format in actual HTTP responses

### Requirement 13

**User Story:** As a developer, I want CrudResource to handle edge cases gracefully, so that my API is robust and predictable

#### Acceptance Criteria

1. WHEN CrudResource is created with an empty serializers map, THE HTTP_API_System SHALL throw an ArgumentError
2. WHEN CrudResource is created with a null or empty path, THE HTTP_API_System SHALL throw an ArgumentError
3. WHEN pagination skip parameter is negative, THE HTTP_API_System SHALL treat it as zero
4. WHEN pagination take parameter is negative, THE HTTP_API_System SHALL use the defaultTake value
5. WHEN pagination take parameter is zero, THE HTTP_API_System SHALL return an empty array
6. WHEN a query handler returns null totalCount, THE HTTP_API_System SHALL omit the X-Total-Count header
7. WHEN Accept header contains multiple media types with quality values, THE HTTP_API_System SHALL select the highest priority supported type
8. WHEN Content-Type header contains charset or other parameters, THE HTTP_API_System SHALL extract the media type correctly
