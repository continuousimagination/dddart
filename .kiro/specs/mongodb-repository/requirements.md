# Requirements Document

## Introduction

This document specifies the requirements for `dddart_repository_mongodb`, a MongoDB repository implementation for the DDDart framework. The package provides code-generated MongoDB repositories for aggregate roots, leveraging MongoDB's document-oriented storage model. The implementation targets AWS DocumentDB Serverless compatibility while using standard MongoDB drivers, ensuring broad compatibility with MongoDB-compatible databases.

## Glossary

- **Repository**: A collection-like interface for persisting and retrieving aggregate roots, abstracting data access details
- **AggregateRoot**: The entry point to an aggregate in DDD, extending Entity with domain event management
- **MongoDB**: A document-oriented NoSQL database that stores data in JSON-like documents
- **AWS DocumentDB**: Amazon's managed document database service that is API-compatible with MongoDB
- **Code Generation**: Automated creation of repository implementation code from annotated aggregate root classes
- **Build Runner**: Dart's code generation tool that executes generators during the build process
- **GenerateMongoRepository Annotation**: A class-level annotation marking aggregate roots for MongoDB repository generation
- **Connection Configuration**: Database connection parameters including host, port, credentials, and database name
- **BSON**: Binary JSON format used by MongoDB for document storage and data interchange
- **Collection**: A MongoDB grouping of documents, analogous to a table in relational databases
- **Document**: A record in MongoDB, stored as a BSON object

## Requirements

### Requirement 1

**User Story:** As a developer, I want to annotate my aggregate root classes with `@GenerateMongoRepository()` so that repository implementations are automatically generated for MongoDB persistence

#### Acceptance Criteria

1. WHEN a developer annotates an aggregate root class with `@GenerateMongoRepository()`, THE Code Generator SHALL generate a repository class implementing `Repository<T>`
2. WHEN the code generator processes the annotation, THE Code Generator SHALL validate that the annotated class extends `AggregateRoot`
3. IF a class annotated with `@GenerateMongoRepository()` does not extend `AggregateRoot`, THEN THE Code Generator SHALL throw an `InvalidGenerationSourceError` with a descriptive message
4. WHEN no custom interface is specified, THE Code Generator SHALL name the generated class `{ClassName}MongoRepository` and generate a concrete implementation
5. THE Generated Repository SHALL implement all methods from the `Repository<T>` interface: `getById`, `save`, and `deleteById`

### Requirement 2

**User Story:** As a developer, I want the generated repositories to use the existing JSON serialization from `dddart_json` so that I don't need to maintain separate serialization logic for database persistence

#### Acceptance Criteria

1. WHEN the generated repository saves an aggregate, THE Repository SHALL use the aggregate's `JsonSerializer` to convert the aggregate to a Map
2. WHEN the generated repository retrieves an aggregate, THE Repository SHALL use the aggregate's `JsonSerializer` to reconstruct the aggregate from a Map
3. THE Generated Repository SHALL require that the aggregate root is annotated with both `@Serializable()` and `@GenerateMongoRepository()`
4. IF an aggregate root is annotated with `@GenerateMongoRepository()` but not `@Serializable()`, THEN THE Code Generator SHALL throw an `InvalidGenerationSourceError`
5. THE Generated Repository SHALL leverage BSON's native support for JSON-like documents without additional conversion layers

### Requirement 3

**User Story:** As a developer, I want to configure MongoDB connection settings through constructor parameters so that I can use `dddart_config` or other configuration sources to provide database credentials

#### Acceptance Criteria

1. THE Generated Repository SHALL accept a `MongoDatabase` instance in its constructor
2. THE Package SHALL provide a `MongoDbConnection` class that manages database connections
3. WHEN creating a `MongoDbConnection`, THE Connection Class SHALL accept connection parameters including host, port, database name, username, and password
4. THE Connection Class SHALL provide a method to obtain a `MongoDatabase` instance for a specific database
5. THE Connection Class SHALL support connection string URIs for flexible configuration including AWS DocumentDB connection strings

### Requirement 4

**User Story:** As a developer, I want the `getById` method to retrieve aggregates by their UUID so that I can fetch specific aggregate instances from MongoDB

#### Acceptance Criteria

1. WHEN `getById` is called with a `UuidValue`, THE Repository SHALL query the MongoDB collection using the UUID as the document `_id` field
2. WHEN a document with the specified UUID exists, THE Repository SHALL deserialize the document and return the aggregate root instance
3. IF no document with the specified UUID exists, THEN THE Repository SHALL throw a `RepositoryException` with type `RepositoryExceptionType.notFound`
4. IF deserialization fails, THEN THE Repository SHALL throw a `RepositoryException` with type `RepositoryExceptionType.unknown` and include the underlying error details
5. THE Repository SHALL convert the aggregate's `UuidValue` to a string for storage in MongoDB's `_id` field

### Requirement 5

**User Story:** As a developer, I want the `save` method to persist aggregates to MongoDB so that I can store new aggregates and update existing ones with a single operation

#### Acceptance Criteria

1. WHEN `save` is called with an aggregate root, THE Repository SHALL serialize the aggregate to a BSON document using its `JsonSerializer`
2. THE Repository SHALL perform an upsert operation using the aggregate's UUID as the `_id` field
3. WHEN the aggregate does not exist in the collection, THE Repository SHALL insert a new document
4. WHEN the aggregate already exists in the collection, THE Repository SHALL replace the existing document with the new data
5. IF the save operation fails due to a MongoDB error, THEN THE Repository SHALL throw a `RepositoryException` with an appropriate type and error message

### Requirement 6

**User Story:** As a developer, I want the `deleteById` method to remove aggregates from MongoDB so that I can delete aggregate instances by their UUID

#### Acceptance Criteria

1. WHEN `deleteById` is called with a `UuidValue`, THE Repository SHALL delete the document with the matching `_id` from the MongoDB collection
2. WHEN a document with the specified UUID exists and is deleted, THE Repository SHALL complete successfully
3. IF no document with the specified UUID exists, THEN THE Repository SHALL throw a `RepositoryException` with type `RepositoryExceptionType.notFound`
4. IF the delete operation fails due to a MongoDB error, THEN THE Repository SHALL throw a `RepositoryException` with an appropriate type and error message
5. THE Repository SHALL verify the delete operation affected exactly one document

### Requirement 7

**User Story:** As a developer, I want the annotation to support custom collection names so that I can control how aggregate types map to MongoDB collections

#### Acceptance Criteria

1. THE `@GenerateMongoRepository()` annotation SHALL accept an optional `collectionName` parameter
2. WHEN `collectionName` is provided, THE Generated Repository SHALL use the specified collection name
3. WHEN `collectionName` is not provided, THE Generated Repository SHALL use the aggregate class name converted to snake_case as the collection name
4. THE Generated Repository SHALL store the collection name as a constant for reuse across methods
5. THE Collection Name SHALL be validated to ensure it follows MongoDB collection naming rules

### Requirement 8

**User Story:** As a developer, I want comprehensive error handling that maps MongoDB errors to `RepositoryException` types so that I can handle different failure scenarios appropriately

#### Acceptance Criteria

1. WHEN a MongoDB operation fails with a duplicate key error, THE Repository SHALL throw a `RepositoryException` with type `RepositoryExceptionType.duplicate`
2. WHEN a MongoDB operation fails with a connection error, THE Repository SHALL throw a `RepositoryException` with type `RepositoryExceptionType.connection`
3. WHEN a MongoDB operation times out, THE Repository SHALL throw a `RepositoryException` with type `RepositoryExceptionType.timeout`
4. WHEN a MongoDB operation fails for an unknown reason, THE Repository SHALL throw a `RepositoryException` with type `RepositoryExceptionType.unknown`
5. THE Repository SHALL include the original MongoDB error message and stack trace in the `RepositoryException`

### Requirement 9

**User Story:** As a developer, I want to use the standard `mongo_dart` package so that I can leverage a mature, well-tested MongoDB driver for Dart

#### Acceptance Criteria

1. THE Package SHALL depend on `mongo_dart` as the MongoDB driver
2. THE Package SHALL use `mongo_dart` version 0.10.0 or higher for modern MongoDB feature support
3. THE Generated Repository SHALL use `mongo_dart` APIs for all database operations
4. THE Package SHALL provide helper utilities for common `mongo_dart` operations specific to DDDart patterns
5. THE Package SHALL be compatible with AWS DocumentDB Serverless through `mongo_dart`'s MongoDB protocol support

### Requirement 10

**User Story:** As a developer, I want to define custom repository interfaces with domain-specific query methods so that I can have multiple implementations (MongoDB, REST, etc.) that conform to the same interface

#### Acceptance Criteria

1. THE `@GenerateMongoRepository()` annotation SHALL accept an optional `implements` parameter specifying a custom repository interface
2. WHEN a custom interface is specified, THE Code Generator SHALL introspect the interface to identify all required methods
3. WHEN the interface contains only methods from `Repository<T>`, THE Code Generator SHALL generate a concrete class named `{ClassName}MongoRepository` implementing the interface
4. WHEN the interface contains custom methods beyond `Repository<T>`, THE Code Generator SHALL generate an abstract base class named `{ClassName}MongoRepositoryBase` implementing the interface
5. THE Generated Abstract Base Class SHALL implement all `Repository<T>` methods and declare custom methods as abstract
6. THE Generated Repository SHALL store the `MongoDatabase` instance in a library-private field named `_database` accessible to subclasses
7. THE Generated Repository SHALL expose a protected getter `collectionName` returning the MongoDB collection name
8. THE Generated Repository SHALL be created as a `part` of the developer's aggregate root library using `part of` directive

### Requirement 11

**User Story:** As a developer, I want comprehensive examples demonstrating repository usage so that I can quickly understand how to integrate MongoDB repositories into my application

#### Acceptance Criteria

1. THE Package SHALL include an `example/` directory with runnable Dart files
2. THE Examples SHALL demonstrate basic CRUD operations using generated repositories without custom interfaces
3. THE Examples SHALL demonstrate defining a custom repository interface with domain-specific query methods
4. THE Examples SHALL demonstrate implementing custom query methods by extending a generated abstract base class
5. THE Examples SHALL show how to configure MongoDB connections using `dddart_config`
6. THE Examples SHALL demonstrate error handling for common failure scenarios
7. THE Examples SHALL demonstrate swapping repository implementations (e.g., MongoDB for production, in-memory for testing)
8. THE Examples SHALL include a README explaining how to run the examples and what each demonstrates

### Requirement 12

**User Story:** As a developer, I want the package to follow DDDart's standard structure and conventions so that it integrates seamlessly with other DDDart packages

#### Acceptance Criteria

1. THE Package SHALL be located at `packages/dddart_repository_mongodb/`
2. THE Package SHALL follow the standard Dart package structure with `lib/`, `test/`, and `example/` directories
3. THE Package SHALL include a `build.yaml` file configuring the code generator
4. THE Package SHALL depend on `dddart`, `dddart_serialization`, and `dddart_json` packages
5. THE Package SHALL include comprehensive documentation in README.md covering installation, usage, configuration, and extensibility patterns

### Requirement 13

**User Story:** As a developer, I want the generated repositories to handle MongoDB connection lifecycle so that I can manage database connections efficiently

#### Acceptance Criteria

1. THE Generated Repository SHALL not manage connection opening or closing
2. THE Generated Repository SHALL accept an already-opened `MongoDatabase` instance in its constructor
3. THE Developer SHALL be responsible for opening and closing MongoDB connections
4. THE Package SHALL provide examples demonstrating proper connection lifecycle management
5. THE Package SHALL document best practices for connection pooling and reuse
