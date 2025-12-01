# Requirements Document

## Introduction

This specification defines the implementation of SQL database repository support for DDDart aggregate roots. The implementation will consist of two packages: a base package (`dddart_repository_sql`) providing common SQL functionality and abstractions, and a concrete SQLite implementation (`dddart_repository_sqlite`) for local and mobile database persistence.

The implementation follows the established patterns from `dddart_repository_mongodb` and `dddart_repository_dynamodb`, providing code-generated repositories that leverage existing JSON serialization from `dddart_json`. This ensures consistency across the DDDart ecosystem while enabling SQL database persistence for server, desktop, mobile, and web applications.

## Glossary

- **SQL Repository**: A repository implementation that persists aggregate roots to SQL databases
- **Base Package**: The `dddart_repository_sql` package containing shared SQL functionality
- **SQLite Package**: The `dddart_repository_sqlite` package providing SQLite-specific implementation
- **SQL Dialect**: Database-specific SQL syntax and behavior variations
- **Schema Generator**: Component that creates SQL DDL statements from aggregate root definitions
- **Type Mapper**: Component that converts between JSON types and SQL column types
- **Connection**: A database connection instance managing the lifecycle of database access
- **Table**: A SQL database table storing serialized aggregate roots
- **Migration**: The process of creating or updating database schema
- **Aggregate Root**: A DDD entity that serves as the root of an aggregate boundary
- **Code Generation**: Automatic creation of repository implementation code from annotations
- **CRUD Operations**: Create, Read, Update, Delete operations on aggregate roots

## Requirements

### Requirement 1

**User Story:** As a developer, I want to annotate my aggregate roots with SQL repository annotations, so that repository implementations are automatically generated following the same patterns as MongoDB and DynamoDB repositories.

#### Acceptance Criteria

1. WHEN a developer annotates an aggregate root with @GenerateSqliteRepository THEN the system SHALL generate a repository implementation with CRUD methods
2. WHEN the annotation includes a custom tableName parameter THEN the system SHALL use that name for the SQL table
3. WHEN the annotation omits the tableName parameter THEN the system SHALL convert the class name to snake_case for the table name
4. WHEN the annotation includes a custom repository interface THEN the system SHALL generate an abstract base class requiring custom method implementation
5. WHEN the aggregate root lacks @Serializable annotation THEN the system SHALL fail code generation with a clear error message

### Requirement 2

**User Story:** As a developer, I want the SQL repository to map domain objects to normalized SQL tables, so that I can query and join data using standard SQL while maintaining object-oriented domain models.

#### Acceptance Criteria

1. WHEN saving an aggregate root THEN the system SHALL save data to multiple tables representing the aggregate root, its entities, and its value objects
2. WHEN saving an aggregate root THEN the system SHALL wrap all table operations in a transaction to ensure atomicity
3. WHEN saving an aggregate root THEN the system SHALL save value objects first, then entities, then the aggregate root to satisfy foreign key constraints
4. WHEN retrieving an aggregate root THEN the system SHALL use SQL JOINs to load data from all related tables
5. WHEN retrieving an aggregate root THEN the system SHALL reconstruct the complete object graph including nested entities and value objects
6. WHEN the aggregate contains nested objects THEN the system SHALL store them in separate tables with foreign key relationships
7. WHEN the aggregate contains lists of entities THEN the system SHALL store them in separate tables with foreign keys back to the parent
8. WHEN fields contain null values THEN the system SHALL store them as SQL NULL values in the appropriate columns

### Requirement 3

**User Story:** As a developer, I want automatic SQL schema generation with full normalization from my aggregate roots, so that all classes get proper tables with columns and foreign key relationships.

#### Acceptance Criteria

1. WHEN generating a repository THEN the system SHALL analyze the entire object graph to discover all referenced types
2. WHEN generating a repository THEN the system SHALL create a table for the aggregate root, all entities within the aggregate, and all value objects
3. WHEN generating tables THEN the system SHALL create columns for all primitive fields with appropriate SQL types
4. WHEN the aggregate root has a UuidValue id field THEN the system SHALL map it to BLOB column storing 16 bytes
5. WHEN any class has String fields THEN the system SHALL map them to TEXT columns
6. WHEN any class has numeric fields THEN the system SHALL map them to appropriate numeric SQL types
7. WHEN any class has DateTime fields THEN the system SHALL map them to INTEGER columns storing Unix timestamps
8. WHEN any class has boolean fields THEN the system SHALL map them to INTEGER columns storing 0 or 1
9. WHEN a class references another class THEN the system SHALL create a foreign key column
10. WHEN a class contains a List of entities THEN the system SHALL create a separate table for those entities with a foreign key back to the parent
11. WHEN generating tables THEN the system SHALL order table creation by dependencies to satisfy foreign key constraints
12. WHEN calling createTables THEN the system SHALL execute SQL CREATE TABLE statements for all discovered types
13. WHEN tables already exist THEN the system SHALL handle the error gracefully using CREATE TABLE IF NOT EXISTS

### Requirement 4

**User Story:** As a developer, I want to perform CRUD operations on aggregate roots through generated repositories, so that I can persist and retrieve domain objects without writing SQL queries.

#### Acceptance Criteria

1. WHEN calling getById with a valid ID THEN the system SHALL return the aggregate root
2. WHEN calling getById with a non-existent ID THEN the system SHALL throw RepositoryException with type notFound
3. WHEN calling save with a new aggregate THEN the system SHALL insert it into the database
4. WHEN calling save with an existing aggregate THEN the system SHALL update it in the database
5. WHEN calling deleteById with a valid ID THEN the system SHALL remove the aggregate from the database
6. WHEN calling deleteById with a non-existent ID THEN the system SHALL throw RepositoryException with type notFound

### Requirement 5

**User Story:** As a developer, I want to manage SQLite database connections with proper lifecycle management, so that I can efficiently use database resources and avoid connection leaks.

#### Acceptance Criteria

1. WHEN creating a SqliteConnection with a file path THEN the system SHALL open a connection to that database file
2. WHEN creating a SqliteConnection with :memory: THEN the system SHALL open an in-memory database
3. WHEN calling open on a connection THEN the system SHALL establish the database connection
4. WHEN calling close on a connection THEN the system SHALL release all database resources
5. WHEN accessing the database before calling open THEN the system SHALL throw an appropriate error
6. WHEN the connection is closed THEN the system SHALL prevent further database operations

### Requirement 6

**User Story:** As a developer, I want consistent error handling across SQL repositories, so that I can handle database errors uniformly regardless of the underlying SQL database.

#### Acceptance Criteria

1. WHEN a SQL constraint violation occurs THEN the system SHALL throw RepositoryException with type duplicate
2. WHEN a database connection fails THEN the system SHALL throw RepositoryException with type connection
3. WHEN a query times out THEN the system SHALL throw RepositoryException with type timeout
4. WHEN an aggregate is not found THEN the system SHALL throw RepositoryException with type notFound
5. WHEN an unexpected SQL error occurs THEN the system SHALL throw RepositoryException with type unknown and include the original error

### Requirement 7

**User Story:** As a developer, I want to define custom repository interfaces with domain-specific query methods, so that I can extend generated repositories with business logic while maintaining type safety.

#### Acceptance Criteria

1. WHEN a custom interface contains only base Repository methods THEN the system SHALL generate a concrete repository class
2. WHEN a custom interface contains additional methods THEN the system SHALL generate an abstract base repository class
3. WHEN extending the abstract base class THEN the developer SHALL have access to protected connection and serializer members
4. WHEN implementing custom query methods THEN the developer SHALL be able to execute raw SQL queries
5. WHEN implementing custom query methods THEN the developer SHALL be able to map results using the serializer

### Requirement 8

**User Story:** As a developer, I want the SQL repository implementation to support multiple SQL dialects through a common abstraction, so that I can add support for MySQL, PostgreSQL, and other databases in the future without breaking existing code.

#### Acceptance Criteria

1. WHEN the base package defines SQL operations THEN the system SHALL use a SqlDialect abstraction for database-specific syntax
2. WHEN generating CREATE TABLE statements THEN the system SHALL delegate to the dialect for column type syntax
3. WHEN generating INSERT statements THEN the system SHALL delegate to the dialect for parameter binding syntax
4. WHEN generating UPDATE statements THEN the system SHALL delegate to the dialect for syntax variations
5. WHEN implementing SqliteDialect THEN the system SHALL provide SQLite-specific SQL syntax

### Requirement 9

**User Story:** As a developer, I want to use SQLite repositories in Flutter mobile applications, so that I can persist aggregate roots locally on iOS and Android devices.

#### Acceptance Criteria

1. WHEN using the sqlite3 package THEN the system SHALL work on iOS, Android, Windows, macOS, Linux, and Web
2. WHEN creating an in-memory database THEN the system SHALL support fast testing without file I/O
3. WHEN using file-based databases THEN the system SHALL persist data across application restarts
4. WHEN running on mobile platforms THEN the system SHALL use platform-appropriate file paths
5. WHEN running on web platforms THEN the system SHALL use WASM-based SQLite

### Requirement 10

**User Story:** As a developer, I want efficient GUID storage in SQL databases, so that primary key operations and joins perform well without sacrificing the benefits of using GUIDs as identifiers.

#### Acceptance Criteria

1. WHEN storing a UuidValue in SQLite THEN the system SHALL convert it to a 16-byte BLOB for efficient storage
2. WHEN retrieving a UuidValue from SQLite THEN the system SHALL convert the BLOB back to a UuidValue
3. WHEN querying by ID THEN the system SHALL use the binary BLOB format for optimal index performance
4. WHEN creating foreign key columns THEN the system SHALL use BLOB type for UUID references
5. WHEN joining tables on UUID foreign keys THEN the system SHALL use efficient binary comparison

### Requirement 11

**User Story:** As a developer, I want automatic foreign key generation with proper cascade rules, so that relationships between tables maintain referential integrity and respect DDD aggregate boundaries.

#### Acceptance Criteria

1. WHEN an entity within an aggregate references the aggregate root THEN the system SHALL create a foreign key with ON DELETE CASCADE
2. WHEN an aggregate root references a value object THEN the system SHALL create a foreign key with ON DELETE RESTRICT
3. WHEN an entity references a value object THEN the system SHALL create a foreign key with ON DELETE RESTRICT
4. WHEN an aggregate root references another aggregate root THEN the system SHALL NOT create a foreign key constraint
5. WHEN deleting an aggregate root THEN the system SHALL automatically delete all entities within the aggregate via CASCADE
6. WHEN deleting an aggregate root THEN the system SHALL NOT delete value objects that may be referenced by other aggregates

### Requirement 12

**User Story:** As a developer, I want value objects to be embedded directly in their parent tables, so that the schema is simple and queries are efficient without unnecessary JOINs.

#### Acceptance Criteria

1. WHEN a class contains a value object field THEN the system SHALL flatten the value object's fields into the parent table with prefixed column names
2. WHEN a value object has multiple fields THEN the system SHALL create a column for each field using the pattern `{fieldName}_{valueObjectField}`
3. WHEN generating SQL queries THEN the system SHALL directly access embedded value object columns without JOINs
4. WHEN reconstructing objects THEN the system SHALL reassemble value objects from their embedded columns
5. WHEN a value object is nullable THEN the system SHALL make all its embedded columns nullable

### Requirement 13

**User Story:** As a developer, I want comprehensive examples and documentation, so that I can quickly understand how to use SQL repositories with normalized schemas in my applications.

#### Acceptance Criteria

1. WHEN reading the package README THEN the developer SHALL find quick start examples showing aggregate roots with nested entities
2. WHEN reading the package README THEN the developer SHALL find examples of value object deduplication
3. WHEN reading the package README THEN the developer SHALL find custom repository interface examples with SQL queries
4. WHEN reading the package README THEN the developer SHALL find connection management best practices
5. WHEN reading the package README THEN the developer SHALL find error handling patterns
6. WHEN exploring the example directory THEN the developer SHALL find runnable code demonstrating complex object graphs
