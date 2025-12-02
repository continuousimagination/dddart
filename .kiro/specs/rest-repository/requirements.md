# Requirements Document

## Introduction

This document specifies the requirements for `dddart_repository_rest`, a REST API-backed repository implementation for DDDart aggregate roots. The package will provide code-generated repository implementations that communicate with remote REST APIs, enabling distributed domain-driven design architectures where aggregates are persisted via HTTP rather than direct database access.

## Glossary

- **Aggregate Root**: A domain entity that serves as the entry point to an aggregate, extending the `AggregateRoot` base class from `dddart`
- **Repository**: An abstraction for persisting and retrieving aggregate roots, implementing the `Repository<T>` interface from `dddart`
- **REST API**: A web service following RESTful conventions using HTTP methods (GET, POST, PUT, DELETE) for CRUD operations
- **Code Generation**: The process of automatically creating Dart source code from annotated classes using `build_runner`
- **JSON Serialization**: Converting Dart objects to/from JSON format using `dddart_json` serializers
- **HTTP Client**: A component that makes HTTP requests to remote servers, specifically `dddart_rest_client`
- **Base URL**: The root URL of the REST API (e.g., `https://api.example.com`)
- **Resource Path**: The URL path segment for a specific aggregate type (e.g., `/users`, `/orders`)
- **Authentication**: The process of verifying identity and obtaining access tokens for API requests
- **Repository Exception**: A standardized exception type from `dddart` for repository operation failures
- **Custom Repository Interface**: A user-defined interface extending `Repository<T>` with domain-specific query methods

## Requirements

### Requirement 1

**User Story:** As a developer, I want to annotate my aggregate roots to generate REST-backed repositories, so that I can persist aggregates via HTTP APIs with minimal boilerplate.

#### Acceptance Criteria

1. WHEN a class extends `AggregateRoot` and is annotated with `@Serializable()` and `@GenerateRestRepository()` THEN the system SHALL generate a repository implementation that communicates with a REST API
2. WHEN the annotation specifies a `resourcePath` parameter THEN the system SHALL use that path for API requests
3. WHEN the annotation omits the `resourcePath` parameter THEN the system SHALL generate a path from the class name converted to lowercase plural form
4. WHEN the annotation specifies a custom interface via the `implements` parameter THEN the system SHALL generate an abstract base class requiring custom method implementation
5. WHEN the annotation omits the `implements` parameter THEN the system SHALL generate a concrete repository class ready for direct use

### Requirement 2

**User Story:** As a developer, I want the generated repository to perform CRUD operations via HTTP, so that I can interact with remote aggregate storage without writing HTTP code.

#### Acceptance Criteria

1. WHEN `getById(id)` is called THEN the system SHALL send a GET request to `{baseUrl}/{resourcePath}/{id}` and deserialize the JSON response to the aggregate type
2. WHEN `save(aggregate)` is called THEN the system SHALL serialize the aggregate to JSON and send a PUT request to `{baseUrl}/{resourcePath}/{id}` with the JSON body
3. WHEN `deleteById(id)` is called THEN the system SHALL send a DELETE request to `{baseUrl}/{resourcePath}/{id}`
4. WHEN any CRUD operation completes successfully THEN the system SHALL return the expected result without throwing exceptions
5. WHEN the aggregate does not exist on the server THEN the system SHALL throw a `RepositoryException` with type `notFound`

### Requirement 3

**User Story:** As a developer, I want the repository to use existing JSON serializers, so that I can reuse my serialization logic without duplication.

#### Acceptance Criteria

1. WHEN generating a repository THEN the system SHALL use the `{ClassName}JsonSerializer` from `dddart_json` for serialization
2. WHEN serializing an aggregate for save operations THEN the system SHALL invoke the serializer's `toJson()` method
3. WHEN deserializing a response for retrieval operations THEN the system SHALL invoke the serializer's `fromJson()` method
4. WHEN the aggregate class lacks a `@Serializable()` annotation THEN the system SHALL fail code generation with a clear error message
5. WHEN serialization or deserialization fails THEN the system SHALL throw a `RepositoryException` with type `unknown`

### Requirement 4

**User Story:** As a developer, I want the repository to handle HTTP errors gracefully, so that I can respond appropriately to different failure scenarios.

#### Acceptance Criteria

1. WHEN the server returns a 404 status code THEN the system SHALL throw a `RepositoryException` with type `notFound`
2. WHEN the server returns a 409 status code THEN the system SHALL throw a `RepositoryException` with type `duplicate`
3. WHEN the server returns a 408 or 504 status code THEN the system SHALL throw a `RepositoryException` with type `timeout`
4. WHEN the server returns a 5xx status code THEN the system SHALL throw a `RepositoryException` with type `connection`
5. WHEN a network error occurs THEN the system SHALL throw a `RepositoryException` with type `connection`

### Requirement 5

**User Story:** As a developer, I want to configure the REST connection with base URL and authentication, so that I can connect to different API environments securely.

#### Acceptance Criteria

1. WHEN creating a `RestConnection` with a base URL THEN the system SHALL store the base URL for use in all HTTP requests
2. WHEN creating a `RestConnection` with an `AuthProvider` THEN the system SHALL use the provider to obtain access tokens for authenticated requests
3. WHEN creating a `RestConnection` without an `AuthProvider` THEN the system SHALL make unauthenticated HTTP requests
4. WHEN the `RestConnection` is disposed THEN the system SHALL close the underlying HTTP client and release resources
5. WHEN multiple repositories share a `RestConnection` THEN the system SHALL reuse the same HTTP client and authentication state

### Requirement 6

**User Story:** As a developer, I want to extend generated repositories with custom query methods, so that I can implement domain-specific queries beyond basic CRUD.

#### Acceptance Criteria

1. WHEN a custom interface is specified with additional methods THEN the system SHALL generate an abstract base class with concrete CRUD methods and abstract custom methods
2. WHEN a custom interface contains only base `Repository<T>` methods THEN the system SHALL generate a concrete repository class
3. WHEN extending the generated base class THEN the system SHALL provide access to protected members including `_connection`, `_serializer`, and `_resourcePath`
4. WHEN implementing custom methods THEN the system SHALL allow direct use of the `RestClient` for custom HTTP requests
5. WHEN custom methods throw exceptions THEN the system SHALL provide a `_mapHttpException` helper for consistent error mapping

### Requirement 7

**User Story:** As a developer, I want the repository to integrate with `dddart_rest_client`, so that I can leverage automatic authentication and token management.

#### Acceptance Criteria

1. WHEN the repository makes HTTP requests THEN the system SHALL use the `RestClient` from `dddart_rest_client`
2. WHEN an `AuthProvider` is configured THEN the system SHALL automatically include access tokens in all HTTP requests
3. WHEN an access token expires THEN the system SHALL automatically refresh the token before retrying the request
4. WHEN authentication fails THEN the system SHALL throw a `RepositoryException` with type `connection`
5. WHEN no authentication is configured THEN the system SHALL make requests without authorization headers

### Requirement 8

**User Story:** As a developer, I want clear error messages for code generation failures, so that I can quickly fix annotation or configuration issues.

#### Acceptance Criteria

1. WHEN a non-class element is annotated with `@GenerateRestRepository()` THEN the system SHALL fail with an error message stating only classes can be annotated
2. WHEN an annotated class does not extend `AggregateRoot` THEN the system SHALL fail with an error message requiring `AggregateRoot` extension
3. WHEN an annotated class lacks `@Serializable()` THEN the system SHALL fail with an error message requiring the annotation
4. WHEN code generation encounters an unexpected error THEN the system SHALL provide a descriptive error message with context
5. WHEN validation passes THEN the system SHALL generate repository code without warnings

### Requirement 9

**User Story:** As a developer, I want comprehensive examples and documentation, so that I can quickly understand how to use REST repositories in my application.

#### Acceptance Criteria

1. WHEN reading the package README THEN the system SHALL provide a quick start guide with basic CRUD examples
2. WHEN reading the package README THEN the system SHALL document connection configuration including authentication setup
3. WHEN reading the package README THEN the system SHALL provide examples of custom repository interfaces and implementations
4. WHEN reading the package README THEN the system SHALL document error handling patterns and exception types
5. WHEN examining the example directory THEN the system SHALL include runnable examples demonstrating basic usage, authentication, and custom queries

### Requirement 10

**User Story:** As a developer, I want the repository to follow the same patterns as other DDDart repository packages, so that I can easily swap implementations.

#### Acceptance Criteria

1. WHEN comparing with `dddart_repository_mongodb` THEN the system SHALL use the same annotation pattern with `resourcePath` analogous to `collectionName`
2. WHEN comparing with `dddart_repository_dynamodb` THEN the system SHALL use the same connection abstraction pattern
3. WHEN comparing with `dddart_repository_sqlite` THEN the system SHALL use the same custom interface extension pattern
4. WHEN swapping repository implementations THEN the system SHALL require only changing the repository instantiation code
5. WHEN using any repository implementation THEN the system SHALL provide the same `Repository<T>` interface methods

### Requirement 11

**User Story:** As a developer, I want comprehensive integration tests that verify end-to-end functionality, so that I can be confident the REST repository works correctly with real HTTP communication.

#### Acceptance Criteria

1. WHEN running integration tests THEN the system SHALL start a test REST API server using `dddart_rest` with in-memory repositories
2. WHEN the test API server is running THEN the system SHALL use the REST repository to perform CRUD operations against the server
3. WHEN integration tests execute THEN the system SHALL verify that data flows correctly from REST repository through HTTP to in-memory repository and back
4. WHEN integration tests complete THEN the system SHALL shut down the test server and clean up resources
5. WHEN integration tests run THEN the system SHALL verify authentication flows including token refresh scenarios

### Requirement 12

**User Story:** As a developer, I want comprehensive unit tests for all generated code paths, so that I can trust the code generation produces correct implementations.

#### Acceptance Criteria

1. WHEN testing the generator THEN the system SHALL verify correct code generation for classes with and without custom interfaces
2. WHEN testing error handling THEN the system SHALL verify all HTTP status codes map to correct repository exception types
3. WHEN testing serialization THEN the system SHALL verify aggregates are correctly serialized and deserialized
4. WHEN testing connection management THEN the system SHALL verify proper resource cleanup and connection reuse
5. WHEN testing validation THEN the system SHALL verify all code generation validation rules produce appropriate error messages

### Requirement 13

**User Story:** As a developer, I want comprehensive documentation with practical examples, so that I can quickly learn and effectively use the REST repository package.

#### Acceptance Criteria

1. WHEN reading the README THEN the system SHALL provide a complete quick start guide with installation, annotation, code generation, and usage steps
2. WHEN reading the README THEN the system SHALL document all annotation parameters with examples and default behaviors
3. WHEN reading the README THEN the system SHALL provide examples of both authenticated and unauthenticated REST connections
4. WHEN examining the example directory THEN the system SHALL include a basic CRUD example demonstrating all repository operations
5. WHEN examining the example directory THEN the system SHALL include an authentication example showing integration with `dddart_rest_client`
6. WHEN examining the example directory THEN the system SHALL include a custom repository example demonstrating domain-specific query methods
7. WHEN examining the example directory THEN the system SHALL include an error handling example showing proper exception handling patterns
8. WHEN reading documentation THEN the system SHALL provide best practices for connection lifecycle management and repository reuse
