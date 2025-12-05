# Requirements Document

## Introduction

This specification defines comprehensive collection support for DDDart SQL repositories (SQLite and MySQL). Currently, SQL repositories only support `List<Entity>` collections. This feature will add support for all collection types (`List`, `Set`, `Map`) containing primitives, value objects, and entities.

The implementation will extend the existing code generation in `dddart_repository_sql`, `dddart_repository_sqlite`, and `dddart_repository_mysql` packages to automatically create junction tables for collections, maintain proper ordering for lists, enforce uniqueness for sets, and handle key-value mappings for maps.

Additionally, this specification includes general improvements to type mapping, specifically using native database types for DateTime and boolean values instead of generic INTEGER columns.

This brings DDDart's SQL repository capabilities in line with industry-leading ORMs like Hibernate's `@ElementCollection`, while maintaining proper normalization and DDD principles.

## Glossary

- **Collection**: A Dart collection type (`List`, `Set`, or `Map`) containing multiple values
- **Primitive Type**: Basic Dart types (`int`, `double`, `String`, `bool`, `DateTime`, `UuidValue`)
- **Value Object**: A DDD value object extending the `Value` base class with no identity
- **Entity**: A DDD entity extending the `Entity` base class with identity
- **Junction Table**: A separate SQL table storing collection items with foreign keys to the parent
- **Position Column**: An integer column in junction tables maintaining list ordering
- **Map Key Column**: A column in junction tables storing the key for map entries
- **Element Collection**: A collection of primitives or value objects (term from Hibernate)
- **Flattening**: The process of converting value object fields into prefixed table columns
- **Collection Repository**: Generated code that handles saving and loading collection items
- **ISO8601**: International standard for date/time string format (e.g., "2024-12-04T10:30:00.000Z")
- **UTC**: Coordinated Universal Time, the primary time standard used for datetime storage

## Requirements

### Requirement 1

**User Story:** As a developer, I want to store lists of primitive values in my aggregate roots, so that I can model simple collections like favorite numbers, tags, or scores without creating wrapper entities.

#### Acceptance Criteria

1. WHEN an aggregate root has a `List<int>` field THEN the system SHALL create a junction table with columns for entity_id, position, and value
2. WHEN an aggregate root has a `List<String>` field THEN the system SHALL create a junction table storing string values
3. WHEN an aggregate root has a `List<double>` field THEN the system SHALL create a junction table storing double values
4. WHEN an aggregate root has a `List<bool>` field THEN the system SHALL create a junction table storing boolean values as integers
5. WHEN an aggregate root has a `List<DateTime>` field THEN the system SHALL create a junction table storing timestamps
6. WHEN an aggregate root has a `List<UuidValue>` field THEN the system SHALL create a junction table storing UUIDs as blobs
7. WHEN saving an aggregate with a primitive list THEN the system SHALL maintain the order of items using position values starting at 0
8. WHEN loading an aggregate with a primitive list THEN the system SHALL reconstruct the list in the correct order based on position values
9. WHEN an aggregate is deleted THEN the system SHALL cascade delete all collection items via foreign key constraints

### Requirement 2

**User Story:** As a developer, I want to store sets of primitive values in my aggregate roots, so that I can model unique collections without duplicates or ordering concerns.

#### Acceptance Criteria

1. WHEN an aggregate root has a `Set<int>` field THEN the system SHALL create a junction table without a position column
2. WHEN an aggregate root has a `Set<String>` field THEN the system SHALL create a junction table with a unique constraint on (entity_id, value)
3. WHEN saving an aggregate with a primitive set THEN the system SHALL store each unique value once
4. WHEN loading an aggregate with a primitive set THEN the system SHALL reconstruct the set with all unique values
5. WHEN the set contains duplicate values THEN the system SHALL store only unique values in the database
6. WHEN an aggregate is deleted THEN the system SHALL cascade delete all set items via foreign key constraints

### Requirement 3

**User Story:** As a developer, I want to store maps with primitive keys and primitive values in my aggregate roots, so that I can model key-value relationships like scores by country or settings by name.

#### Acceptance Criteria

1. WHEN an aggregate root has a `Map<String, int>` field THEN the system SHALL create a junction table with columns for entity_id, map_key, and value
2. WHEN an aggregate root has a `Map<int, String>` field THEN the system SHALL create a junction table supporting integer keys
3. WHEN saving an aggregate with a map THEN the system SHALL store each key-value pair as a separate row
4. WHEN saving an aggregate with a map THEN the system SHALL enforce uniqueness on (entity_id, map_key) combination
5. WHEN loading an aggregate with a map THEN the system SHALL reconstruct the map with all key-value pairs
6. WHEN a map key is updated THEN the system SHALL delete the old entry and insert the new entry
7. WHEN an aggregate is deleted THEN the system SHALL cascade delete all map entries via foreign key constraints

### Requirement 4

**User Story:** As a developer, I want to store lists of value objects in my aggregate roots, so that I can model collections of domain concepts like addresses, money amounts, or colors without creating entities.

#### Acceptance Criteria

1. WHEN an aggregate root has a `List<ValueObject>` field THEN the system SHALL create a junction table with flattened value object fields
2. WHEN the value object has multiple fields THEN the system SHALL create separate columns for each field in the junction table
3. WHEN saving a list of value objects THEN the system SHALL flatten each value object into table columns
4. WHEN loading a list of value objects THEN the system SHALL reconstruct value objects from flattened columns
5. WHEN the value object field is nullable THEN the system SHALL handle null values appropriately in all columns
6. WHEN the list maintains order THEN the system SHALL use a position column to preserve ordering

### Requirement 5

**User Story:** As a developer, I want to store sets of value objects in my aggregate roots, so that I can model unique collections of domain concepts without duplicates.

#### Acceptance Criteria

1. WHEN an aggregate root has a `Set<ValueObject>` field THEN the system SHALL create a junction table with flattened value object fields
2. WHEN saving a set of value objects THEN the system SHALL enforce uniqueness based on all value object fields
3. WHEN loading a set of value objects THEN the system SHALL reconstruct unique value objects from table rows
4. WHEN the set contains duplicate value objects THEN the system SHALL store only unique combinations

### Requirement 6

**User Story:** As a developer, I want to store maps with primitive keys and value object values in my aggregate roots, so that I can model relationships like colors by name or addresses by type.

#### Acceptance Criteria

1. WHEN an aggregate root has a `Map<String, ValueObject>` field THEN the system SHALL create a junction table with map_key column and flattened value object fields
2. WHEN saving a map with value object values THEN the system SHALL flatten each value object into table columns
3. WHEN loading a map with value object values THEN the system SHALL reconstruct value objects from flattened columns
4. WHEN the map key is updated THEN the system SHALL delete the old entry and insert the new entry with flattened fields

### Requirement 7

**User Story:** As a developer, I want to store sets of entities in my aggregate roots, so that I can model unique entity collections without ordering concerns, complementing the existing `List<Entity>` support.

#### Acceptance Criteria

1. WHEN an aggregate root has a `Set<Entity>` field THEN the system SHALL create a table for the entity without a position column
2. WHEN saving a set of entities THEN the system SHALL store each entity with a foreign key to the parent aggregate
3. WHEN loading a set of entities THEN the system SHALL reconstruct the set with all entities
4. WHEN the set contains entities with duplicate IDs THEN the system SHALL store only unique entities
5. WHEN an aggregate is deleted THEN the system SHALL cascade delete all entity set items

### Requirement 8

**User Story:** As a developer, I want to store maps with primitive keys and entity values in my aggregate roots, so that I can model named or indexed entity relationships.

#### Acceptance Criteria

1. WHEN an aggregate root has a `Map<String, Entity>` field THEN the system SHALL create a table for the entity with a map_key column
2. WHEN saving a map with entity values THEN the system SHALL store each entity with its map key and foreign key to parent
3. WHEN loading a map with entity values THEN the system SHALL reconstruct the map with entities keyed appropriately
4. WHEN the map key is updated THEN the system SHALL update the map_key column for that entity
5. WHEN an aggregate is deleted THEN the system SHALL cascade delete all map entity items

### Requirement 9

**User Story:** As a developer, I want automatic schema generation for all collection types, so that junction tables are created with appropriate columns, constraints, and indexes.

#### Acceptance Criteria

1. WHEN generating schema for a primitive list THEN the system SHALL create a table with (entity_id, position, value) columns
2. WHEN generating schema for a primitive set THEN the system SHALL create a table with (entity_id, value) columns and UNIQUE constraint
3. WHEN generating schema for a primitive map THEN the system SHALL create a table with (entity_id, map_key, value) columns and UNIQUE constraint on (entity_id, map_key)
4. WHEN generating schema for a value object list THEN the system SHALL create a table with (entity_id, position, field1, field2, ...) columns
5. WHEN generating schema for a value object set THEN the system SHALL create a table with (entity_id, field1, field2, ...) columns and UNIQUE constraint on all fields
6. WHEN generating schema for a value object map THEN the system SHALL create a table with (entity_id, map_key, field1, field2, ...) columns
7. WHEN generating schema for an entity set THEN the system SHALL create an entity table without position column
8. WHEN generating schema for an entity map THEN the system SHALL create an entity table with map_key column
9. WHEN generating any collection table THEN the system SHALL add a foreign key constraint with CASCADE DELETE to the parent table
10. WHEN the collection field name is camelCase THEN the system SHALL convert it to snake_case for the table name

### Requirement 10

**User Story:** As a developer, I want collection save operations to be transactional and efficient, so that partial updates cannot occur and performance is acceptable.

#### Acceptance Criteria

1. WHEN saving an aggregate with collections THEN the system SHALL wrap all operations in a database transaction
2. WHEN saving an aggregate with modified collections THEN the system SHALL delete existing collection items before inserting new ones
3. WHEN saving an aggregate with empty collections THEN the system SHALL delete all existing collection items
4. WHEN saving an aggregate with null collection fields THEN the system SHALL treat them as empty collections
5. WHEN a save operation fails THEN the system SHALL roll back all collection changes
6. WHEN saving multiple collections in one aggregate THEN the system SHALL save them in dependency order

### Requirement 11

**User Story:** As a developer, I want collection load operations to efficiently reconstruct domain objects, so that retrieving aggregates with collections has acceptable performance.

#### Acceptance Criteria

1. WHEN loading an aggregate with collections THEN the system SHALL query all collection tables in parallel where possible
2. WHEN loading a list collection THEN the system SHALL order results by position column
3. WHEN loading a set collection THEN the system SHALL return results without ordering guarantees
4. WHEN loading a map collection THEN the system SHALL use map_key values as keys in the reconstructed map
5. WHEN loading value object collections THEN the system SHALL reconstruct value objects from flattened columns
6. WHEN a collection is empty THEN the system SHALL return an empty collection of the appropriate type
7. WHEN loading fails for any collection THEN the system SHALL throw a RepositoryException

### Requirement 12

**User Story:** As a developer, I want clear error messages when using unsupported collection patterns, so that I understand limitations and can adjust my domain model.

#### Acceptance Criteria

1. WHEN an aggregate has a nested collection like `List<List<int>>` THEN the system SHALL fail code generation with a clear error message
2. WHEN an aggregate has a `Map<ValueObject, T>` field THEN the system SHALL fail code generation explaining that value objects cannot be map keys
3. WHEN an aggregate has a collection of aggregate roots THEN the system SHALL fail code generation explaining aggregate boundary violations
4. WHEN an aggregate has a `List<dynamic>` field THEN the system SHALL fail code generation explaining that dynamic types cannot be stored in SQL
5. WHEN an aggregate has a `List<Object>` field THEN the system SHALL fail code generation explaining that Object types cannot be stored in SQL
6. WHEN an aggregate has a `Set<dynamic>` or `Map<dynamic, T>` field THEN the system SHALL fail code generation with appropriate error messages
7. WHEN code generation fails THEN the system SHALL provide the field name, type, and reason for failure
8. WHEN code generation fails THEN the system SHALL suggest alternatives like wrapping in value objects or entities

### Requirement 13

**User Story:** As a developer, I want collection support to work identically in both SQLite and MySQL repositories, so that I can switch databases without changing my domain model.

#### Acceptance Criteria

1. WHEN using SQLite THEN the system SHALL support all collection types with SQLite-specific SQL syntax
2. WHEN using MySQL THEN the system SHALL support all collection types with MySQL-specific SQL syntax
3. WHEN using SQLite THEN the system SHALL use BLOB type for UUIDs in collection tables
4. WHEN using MySQL THEN the system SHALL use BINARY(16) type for UUIDs in collection tables
5. WHEN using SQLite THEN the system SHALL use INTEGER for booleans in collection tables
6. WHEN using MySQL THEN the system SHALL use TINYINT for booleans in collection tables
7. WHEN switching between SQLite and MySQL THEN the system SHALL maintain the same domain model without code changes

### Requirement 14

**User Story:** As a developer, I want nullable collection fields to be handled correctly, so that optional collections work as expected in my domain model.

#### Acceptance Criteria

1. WHEN an aggregate has a nullable collection field like `List<int>?` THEN the system SHALL treat null as an empty collection
2. WHEN saving an aggregate with a null collection THEN the system SHALL delete all existing collection items
3. WHEN loading an aggregate with no collection items THEN the system SHALL return an empty collection, not null
4. WHEN a collection contains nullable elements like `List<int?>` THEN the system SHALL store null values appropriately in the value column

### Requirement 15

**User Story:** As a developer, I want collection table names to follow consistent naming conventions, so that generated schemas are predictable and readable.

#### Acceptance Criteria

1. WHEN generating a collection table THEN the system SHALL name it `{parent_table}_{field_name}_items`
2. WHEN the parent table is "users" and field is "favoriteNumbers" THEN the system SHALL create table "users_favoriteNumbers_items"
3. WHEN the field name contains underscores THEN the system SHALL preserve them in the table name
4. WHEN generating foreign key column names THEN the system SHALL use `{parent_table}_id` format
5. WHEN generating map key column names THEN the system SHALL use `map_key` as the column name

### Requirement 16

**User Story:** As a developer, I want DateTime fields to use native database datetime types, so that I can leverage database datetime functions and have human-readable values in database tools.

#### Acceptance Criteria

1. WHEN using SQLite THEN the system SHALL store DateTime fields as TEXT columns with ISO8601 format
2. WHEN using MySQL THEN the system SHALL store DateTime fields as DATETIME columns
3. WHEN encoding a DateTime for SQLite THEN the system SHALL convert it to ISO8601 string format
4. WHEN decoding a DateTime from SQLite THEN the system SHALL parse ISO8601 string format
5. WHEN encoding a DateTime for MySQL THEN the system SHALL convert it to MySQL DATETIME format in UTC
6. WHEN decoding a DateTime from MySQL THEN the system SHALL parse DATETIME values as UTC
7. WHEN a DateTime field is in a collection THEN the system SHALL use the appropriate native datetime type for that database
8. WHEN querying DateTime fields THEN the system SHALL support database-native datetime comparison and sorting
9. WHEN an entity has ANY DateTime field THEN the system SHALL encode and decode it correctly regardless of field name
10. WHEN an entity has a DateTime field named "birthday" THEN the system SHALL handle it the same as "createdAt" or "updatedAt"
11. WHEN encoding values for database storage THEN the system SHALL detect DateTime type by the field's Dart type, not by field name patterns

### Requirement 17

**User Story:** As a developer, I want boolean fields to use appropriate database-native types, so that schemas are idiomatic and storage is efficient.

#### Acceptance Criteria

1. WHEN using SQLite THEN the system SHALL store boolean fields as INTEGER columns with values 0 or 1
2. WHEN using MySQL THEN the system SHALL store boolean fields as TINYINT(1) columns
3. WHEN encoding a boolean for SQLite THEN the system SHALL convert true to 1 and false to 0
4. WHEN decoding a boolean from SQLite THEN the system SHALL convert 1 to true and 0 to false
5. WHEN encoding a boolean for MySQL THEN the system SHALL convert true to 1 and false to 0
6. WHEN decoding a boolean from MySQL THEN the system SHALL convert non-zero values to true and 0 to false
7. WHEN a boolean field is in a collection THEN the system SHALL use the appropriate boolean type for that database
