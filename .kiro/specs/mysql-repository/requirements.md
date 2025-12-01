# Requirements Document

## Introduction

This document specifies the requirements for `dddart_repository_mysql`, a MySQL database repository implementation for DDDart aggregate roots. The package will follow the established pattern used by `dddart_repository_sqlite`, extending the base `dddart_repository_sql` abstractions to provide MySQL-specific implementations with automatic code generation support.

The MySQL repository will enable developers to persist DDDart aggregate roots to MySQL databases with full normalization, automatic schema generation, value object embedding, relationship mapping, and transaction support - all with zero boilerplate through code generation.

## Glossary

- **Aggregate Root**: A DDD pattern representing a cluster of domain objects that can be treated as a single unit, with the root entity controlling access to the cluster
- **Value Object**: An immutable object defined by its attributes rather than identity, embedded directly into parent tables with prefixed columns
- **Entity**: A domain object with a unique identity that persists over time
- **Repository**: A DDD pattern that mediates between the domain and data mapping layers, acting like an in-memory collection of aggregate roots
- **Code Generation**: Compile-time generation of repository implementation code from annotated domain models
- **Schema Generation**: Automatic creation of database tables and relationships from domain model definitions
- **SqlConnection**: Abstract interface for database connection management
- **SqlDialect**: Abstract interface for database-specific SQL syntax and type mappings
- **DDL**: Data Definition Language - SQL statements for creating/modifying database schema (CREATE TABLE, ALTER TABLE, etc.)
- **DML**: Data Manipulation Language - SQL statements for querying/modifying data (SELECT, INSERT, UPDATE, DELETE)
- **Foreign Key Constraint**: Database constraint ensuring referential integrity between tables
- **Transaction**: A unit of work that either completes entirely or rolls back entirely, ensuring data consistency
- **ORM**: Object-Relational Mapping - technique for converting between incompatible type systems (objects and relational tables)
- **Build Runner**: Dart's code generation tool that executes generators during the build process
- **MySQL**: Open-source relational database management system
- **mysql1**: Dart package providing MySQL client connectivity

## Requirements

### Requirement 1

**User Story:** As a developer using DDDart, I want to persist aggregate roots to MySQL databases, so that I can use MySQL as my data store with the same patterns as SQLite.

#### Acceptance Criteria

1. WHEN a developer annotates an aggregate root with `@GenerateMysqlRepository()` THEN the system SHALL generate a MySQL repository implementation
2. WHEN the generated repository is instantiated with a MySQL connection THEN the system SHALL provide save, getById, getAll, and deleteById operations
3. WHEN repository operations are executed THEN the system SHALL use the MySQL-specific connection and dialect implementations
4. WHERE the aggregate root contains entities and value objects THEN the system SHALL persist the complete object graph to normalized MySQL tables
5. WHEN multiple aggregate roots are defined THEN the system SHALL generate independent repository implementations for each

### Requirement 2

**User Story:** As a developer, I want MySQL-specific connection management, so that I can connect to MySQL databases with proper lifecycle handling.

#### Acceptance Criteria

1. WHEN a developer creates a `MysqlConnection` with host, port, database, username, and password THEN the system SHALL establish a connection to the MySQL server
2. WHEN the `open()` method is called THEN the system SHALL connect to MySQL and verify the connection is ready
3. WHEN the `close()` method is called THEN the system SHALL properly close the MySQL connection and release resources
4. WHEN the connection is not open and an operation is attempted THEN the system SHALL throw a StateError with a clear message
5. WHEN connection parameters are invalid THEN the system SHALL throw a RepositoryException with type connection

### Requirement 3

**User Story:** As a developer, I want MySQL-specific SQL dialect support, so that the generated code uses correct MySQL syntax and data types.

#### Acceptance Criteria

1. WHEN encoding a UuidValue THEN the system SHALL convert it to a BINARY(16) format for efficient storage
2. WHEN decoding a UUID from MySQL THEN the system SHALL convert BINARY(16) back to UuidValue
3. WHEN encoding a DateTime THEN the system SHALL convert it to MySQL TIMESTAMP format
4. WHEN decoding a DateTime from MySQL THEN the system SHALL convert TIMESTAMP to Dart DateTime
5. WHEN generating CREATE TABLE statements THEN the system SHALL use MySQL-specific syntax including `ENGINE=InnoDB` and `DEFAULT CHARSET=utf8mb4`
6. WHEN generating INSERT statements THEN the system SHALL use MySQL's `INSERT ... ON DUPLICATE KEY UPDATE` syntax
7. WHEN specifying column types THEN the system SHALL use MySQL types: BINARY(16) for UUIDs, VARCHAR(255) for text, BIGINT for integers, DOUBLE for reals, TINYINT(1) for booleans

### Requirement 4

**User Story:** As a developer, I want automatic schema generation for MySQL, so that database tables are created from my domain models without manual SQL.

#### Acceptance Criteria

1. WHEN `createTables()` is called on a repository THEN the system SHALL generate and execute CREATE TABLE statements for all tables in the aggregate
2. WHEN creating tables THEN the system SHALL use `CREATE TABLE IF NOT EXISTS` to allow idempotent schema creation
3. WHEN an aggregate contains entities THEN the system SHALL create separate tables with foreign key constraints using `ON DELETE CASCADE`
4. WHEN an aggregate contains value objects THEN the system SHALL embed value object fields as prefixed columns in the parent table
5. WHEN creating tables THEN the system SHALL specify `ENGINE=InnoDB` for transaction support and foreign key enforcement
6. WHEN creating tables THEN the system SHALL specify `DEFAULT CHARSET=utf8mb4` for full Unicode support

### Requirement 5

**User Story:** As a developer, I want transaction support in MySQL repositories, so that multi-table operations are atomic and consistent.

#### Acceptance Criteria

1. WHEN saving an aggregate root THEN the system SHALL wrap all INSERT/UPDATE operations in a MySQL transaction
2. WHEN a save operation fails THEN the system SHALL rollback the transaction and leave the database unchanged
3. WHEN a save operation succeeds THEN the system SHALL commit the transaction
4. WHEN nested transactions are attempted THEN the system SHALL track transaction depth and only commit/rollback the outermost transaction
5. WHEN executing custom queries within a transaction THEN the system SHALL support the transaction context

### Requirement 6

**User Story:** As a developer, I want value objects embedded in MySQL tables, so that I get simple schemas without unnecessary joins.

#### Acceptance Criteria

1. WHEN an aggregate contains a value object field THEN the system SHALL flatten the value object properties into the parent table with prefixed column names
2. WHEN a value object is nullable THEN the system SHALL make all embedded columns nullable
3. WHEN a value object is non-nullable THEN the system SHALL make all embedded columns non-nullable
4. WHEN saving an aggregate THEN the system SHALL serialize value objects into the prefixed columns
5. WHEN loading an aggregate THEN the system SHALL reconstruct value objects from the prefixed columns

### Requirement 7

**User Story:** As a developer, I want proper error handling with MySQL-specific errors, so that I can handle database failures appropriately.

#### Acceptance Criteria

1. WHEN a MySQL connection error occurs THEN the system SHALL throw RepositoryException with type connection
2. WHEN a duplicate key violation occurs THEN the system SHALL throw RepositoryException with type duplicate
3. WHEN an entity is not found by ID THEN the system SHALL throw RepositoryException with type notFound
4. WHEN a query timeout occurs THEN the system SHALL throw RepositoryException with type timeout
5. WHEN an unknown MySQL error occurs THEN the system SHALL throw RepositoryException with type unknown and include the original error details

### Requirement 8

**User Story:** As a developer, I want to extend generated repositories with custom query methods, so that I can implement domain-specific queries.

#### Acceptance Criteria

1. WHERE a custom repository interface is specified in the annotation THEN the system SHALL generate an abstract base class implementing the standard repository methods
2. WHEN the abstract base class is generated THEN the system SHALL expose protected members for connection, dialect, and serialization utilities
3. WHEN a developer extends the abstract base class THEN the system SHALL allow implementation of custom query methods using the protected members
4. WHEN custom queries are executed THEN the system SHALL use the same connection and transaction context as standard operations
5. WHEN custom queries return aggregate roots THEN the system SHALL provide deserialization helpers to reconstruct objects from query results

### Requirement 9

**User Story:** As a developer, I want comprehensive examples and documentation, so that I can quickly learn how to use MySQL repositories.

#### Acceptance Criteria

1. WHEN the package is published THEN the system SHALL include a README with quick start guide, features, and usage examples
2. WHEN the package is published THEN the system SHALL include an example directory with runnable code samples
3. WHEN the package is published THEN the system SHALL include examples for basic CRUD operations, custom repositories, error handling, and connection management
4. WHEN the package is published THEN the system SHALL document MySQL-specific configuration requirements
5. WHEN the package is published THEN the system SHALL include guidance on connection pooling and production deployment

### Requirement 10

**User Story:** As a developer, I want the MySQL repository to follow the same patterns as SQLite, so that I can easily switch between database implementations.

#### Acceptance Criteria

1. WHEN using the MySQL repository THEN the system SHALL provide the same Repository interface as SQLite
2. WHEN annotating domain models THEN the system SHALL use the same pattern as `@GenerateSqliteRepository()` but with `@GenerateMysqlRepository()`
3. WHEN generating code THEN the system SHALL follow the same structure and naming conventions as the SQLite implementation
4. WHEN handling errors THEN the system SHALL use the same RepositoryException types as other repository implementations
5. WHEN the developer switches from SQLite to MySQL THEN the system SHALL require only changing the annotation and connection type
