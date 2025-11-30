# Requirements Document

## Introduction

This document specifies the requirements for `dddart_repository_dynamodb`, a DynamoDB repository implementation for DDDart aggregate roots. The package will provide code-generated DynamoDB repositories that leverage existing JSON serialization from `dddart_json` and the AWS SDK for Dart (`aws_dynamodb_api`) for DynamoDB connectivity. The implementation will mirror the architecture and patterns established by `dddart_repository_mongodb`, adapted for DynamoDB's key-value document model.

## Glossary

- **DynamoDB**: Amazon's fully managed NoSQL database service that provides fast and predictable performance with seamless scalability. Tables must be pre-created via AWS Console, CLI, Infrastructure as Code, or programmatically before use.
- **Aggregate Root**: A DDD pattern representing a cluster of domain objects that can be treated as a single unit, extending the `AggregateRoot` base class from dddart
- **Repository**: An abstraction that encapsulates data access logic, implementing the `Repository<T>` interface from dddart
- **Code Generation**: The process of automatically creating Dart source code from annotated classes using the build_runner package
- **Table Name**: The DynamoDB table identifier where aggregate instances are stored
- **Partition Key**: The primary key attribute in DynamoDB that determines data distribution across partitions (will use aggregate ID)
- **AWS SDK**: The official AWS SDK for Dart that provides DynamoDB client functionality
- **JSON Serialization**: The process of converting aggregate objects to/from JSON format using dddart_json serializers
- **DynamoDB Client**: The AWS SDK client instance that communicates with DynamoDB service
- **Annotation**: A Dart metadata marker (e.g., `@GenerateDynamoRepository`) that triggers code generation
- **Custom Repository Interface**: A user-defined interface extending `Repository<T>` with domain-specific query methods
- **Concrete Repository**: A fully implemented repository class that can be instantiated directly
- **Abstract Base Repository**: A partially implemented repository class requiring extension to implement custom methods
- **DynamoDB Connection**: A configuration object managing DynamoDB client instances and AWS credentials

## Requirements

### Requirement 1

**User Story:** As a developer, I want to annotate my aggregate roots with `@GenerateDynamoRepository`, so that DynamoDB repository implementations are automatically generated for me.

#### Acceptance Criteria

1. WHEN a class extends AggregateRoot and is annotated with `@Serializable()` and `@GenerateDynamoRepository()`, THEN the build system SHALL generate a DynamoDB repository implementation
2. WHEN a class annotated with `@GenerateDynamoRepository()` does not extend AggregateRoot, THEN the code generator SHALL throw an InvalidGenerationSourceError with a descriptive message
3. WHEN a class annotated with `@GenerateDynamoRepository()` is not annotated with `@Serializable()`, THEN the code generator SHALL throw an InvalidGenerationSourceError with a descriptive message
4. WHEN the `@GenerateDynamoRepository()` annotation specifies a tableName parameter, THEN the generated repository SHALL use that table name
5. WHEN the `@GenerateDynamoRepository()` annotation does not specify a tableName parameter, THEN the generated repository SHALL use the class name converted to snake_case as the table name

### Requirement 2

**User Story:** As a developer, I want the generated repository to implement basic CRUD operations, so that I can persist and retrieve aggregate roots without writing boilerplate code.

#### Acceptance Criteria

1. WHEN the generated repository's getById method is called with a valid UuidValue, THEN the system SHALL retrieve the aggregate from DynamoDB using the ID as the partition key
2. WHEN the generated repository's getById method is called with an ID that does not exist, THEN the system SHALL throw a RepositoryException with type notFound
3. WHEN the generated repository's save method is called with an aggregate, THEN the system SHALL serialize the aggregate to JSON and store it in DynamoDB using the aggregate's ID as the partition key
4. WHEN the generated repository's save method is called with an aggregate that already exists, THEN the system SHALL replace the existing item in DynamoDB
5. WHEN the generated repository's deleteById method is called with a valid UuidValue, THEN the system SHALL delete the item from DynamoDB
6. WHEN the generated repository's deleteById method is called with an ID that does not exist, THEN the system SHALL throw a RepositoryException with type notFound

### Requirement 3

**User Story:** As a developer, I want to use existing JSON serializers from dddart_json, so that I don't have to maintain duplicate serialization logic for DynamoDB persistence.

#### Acceptance Criteria

1. WHEN the generated repository serializes an aggregate for storage, THEN the system SHALL use the aggregate's JsonSerializer generated by dddart_json
2. WHEN the generated repository deserializes an aggregate from DynamoDB, THEN the system SHALL use the aggregate's JsonSerializer generated by dddart_json
3. WHEN serialization produces a JSON object, THEN the system SHALL convert it to DynamoDB's AttributeValue format for storage
4. WHEN deserialization receives DynamoDB AttributeValue data, THEN the system SHALL convert it to JSON format before passing to the JsonSerializer

### Requirement 4

**User Story:** As a developer, I want to define custom repository interfaces with domain-specific query methods, so that I can extend the generated repository with custom queries while maintaining type safety.

#### Acceptance Criteria

1. WHEN the `@GenerateDynamoRepository()` annotation specifies an implements parameter with a custom interface, THEN the generated repository SHALL implement that interface
2. WHEN the custom interface contains only methods from the base Repository interface, THEN the code generator SHALL produce a concrete repository class
3. WHEN the custom interface contains methods beyond the base Repository interface, THEN the code generator SHALL produce an abstract base repository class with abstract declarations for custom methods
4. WHEN an abstract base repository is generated, THEN the system SHALL implement the base CRUD methods (getById, save, deleteById) as concrete methods
5. WHEN an abstract base repository is generated, THEN the system SHALL expose protected members (_client, _tableName, _serializer) for use in custom method implementations

### Requirement 5

**User Story:** As a developer, I want to configure DynamoDB connections with AWS credentials and region settings, so that I can connect to DynamoDB in different environments (local, development, production).

#### Acceptance Criteria

1. WHEN a DynamoConnection is created with region and credentials parameters, THEN the system SHALL create a DynamoDB client configured with those parameters
2. WHEN a DynamoConnection is created with endpoint parameter, THEN the system SHALL configure the client to use that custom endpoint (for DynamoDB Local or LocalStack)
3. WHEN a DynamoConnection is created without explicit credentials, THEN the system SHALL use the AWS SDK's default credential provider chain
4. WHEN a DynamoConnection's client property is accessed before initialization, THEN the system SHALL throw a StateError
5. WHEN a DynamoConnection's dispose method is called, THEN the system SHALL clean up the DynamoDB client resources
6. WHEN repository operations are performed on a non-existent table, THEN the system SHALL throw a RepositoryException with type unknown and include the ResourceNotFoundException as the cause

### Requirement 6

**User Story:** As a developer, I want DynamoDB errors to be mapped to standard RepositoryException types, so that I can handle errors consistently across different repository implementations.

#### Acceptance Criteria

1. WHEN a DynamoDB operation fails due to a ResourceNotFoundException, THEN the system SHALL throw a RepositoryException with type notFound
2. WHEN a DynamoDB operation fails due to a ConditionalCheckFailedException, THEN the system SHALL throw a RepositoryException with type duplicate
3. WHEN a DynamoDB operation fails due to network or connectivity issues, THEN the system SHALL throw a RepositoryException with type connection
4. WHEN a DynamoDB operation fails due to a timeout, THEN the system SHALL throw a RepositoryException with type timeout
5. WHEN a DynamoDB operation fails with an unrecognized error, THEN the system SHALL throw a RepositoryException with type unknown and include the original error as the cause

### Requirement 7

**User Story:** As a developer, I want comprehensive documentation and examples, so that I can quickly understand how to use the package and integrate it into my applications.

#### Acceptance Criteria

1. WHEN the package is published, THEN the system SHALL include a README.md with overview, features, installation instructions, and quick start guide
2. WHEN the package is published, THEN the system SHALL include an example directory with runnable examples demonstrating basic CRUD operations
3. WHEN the package is published, THEN the system SHALL include an example demonstrating custom repository interfaces with domain-specific queries
4. WHEN the package is published, THEN the system SHALL include an example demonstrating DynamoDB Local configuration for local development
5. WHEN the package is published, THEN the system SHALL include API documentation with doc comments for all public classes and methods

### Requirement 8

**User Story:** As a developer, I want helper utilities for DynamoDB table creation, so that I can easily set up the required tables for my aggregates in development and testing environments.

#### Acceptance Criteria

1. WHEN a generated repository class provides a createTableDefinition static method, THEN the system SHALL return a DynamoDB CreateTableInput object with the correct table name and key schema
2. WHEN a generated repository class provides a createTable method, THEN the system SHALL execute the table creation operation using the DynamoDB client
3. WHEN a generated repository class provides a getCreateTableCommand static method, THEN the system SHALL return an AWS CLI command string that can be executed to create the table
4. WHEN a generated repository class provides a getCloudFormationTemplate static method, THEN the system SHALL return a CloudFormation YAML snippet for the table definition
5. WHEN table creation utilities are called, THEN the system SHALL configure the table with the aggregate ID as the partition key (hash key) with attribute type String

### Requirement 9

**User Story:** As a developer, I want the package to follow the same patterns as dddart_repository_mongodb, so that I can easily switch between MongoDB and DynamoDB implementations with minimal code changes.

#### Acceptance Criteria

1. WHEN comparing the annotation API, THEN the GenerateDynamoRepository annotation SHALL have the same structure as GenerateMongoRepository (tableName instead of collectionName, implements parameter)
2. WHEN comparing the connection API, THEN the DynamoConnection class SHALL provide similar lifecycle methods as MongoConnection (initialization and disposal)
3. WHEN comparing the generated repository API, THEN the generated DynamoDB repositories SHALL implement the same Repository interface as MongoDB repositories
4. WHEN comparing error handling, THEN both implementations SHALL use the same RepositoryException types from dddart
5. WHEN comparing extensibility patterns, THEN both implementations SHALL support custom interfaces with the same concrete/abstract base class generation logic
