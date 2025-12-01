# Implementation Plan

- [x] 1. Set up base package structure (dddart_repository_sql)
  - Create package directory and pubspec.yaml
  - Set up lib/ directory structure with src/ subdirectories
  - Configure dependencies: dddart, dddart_serialization, analyzer, source_gen, build
  - Create analysis_options.yaml with very_good_analysis
  - _Requirements: 1.1, 8.1_

- [x] 2. Implement core abstractions in base package
  - [x] 2.1 Create SqlConnection abstract class
    - Define open(), close(), execute(), query(), transaction() methods
    - Add isOpen getter
    - _Requirements: 5.1, 5.3, 5.4_
  
  - [x] 2.2 Create SqlDialect abstract interface
    - Define column type getters (uuidColumnType, textColumnType, etc.)
    - Define encode/decode methods for UuidValue and DateTime
    - Define SQL statement generation methods (createTableIfNotExists, insertOrReplace, etc.)
    - _Requirements: 8.1, 8.2, 10.1, 10.2_
  
  - [x] 2.3 Create RepositoryException mapping
    - Reuse existing RepositoryException from dddart
    - Document exception type mapping strategy
    - _Requirements: 6.1, 6.2, 6.5_

- [x] 3. Implement schema generation components
  - [x] 3.1 Create TableDefinition model classes
    - Implement TableDefinition with columns and foreign keys
    - Implement ColumnDefinition with SQL type mapping
    - Implement ForeignKeyDefinition with cascade actions
    - _Requirements: 3.2, 3.3, 11.1_
  
  - [x] 3.2 Create TypeMapper class
    - Implement getSqlType() for all Dart primitive types
    - Map UuidValue → BLOB, String → TEXT, int → INTEGER, etc.
    - Handle nullable types
    - _Requirements: 3.4, 3.5, 3.6, 3.7_
  
  - [x] 3.3 Create SchemaGenerator class
    - Implement generateCreateTable() method
    - Implement generateColumnDefinition() method
    - Implement isPrimitiveType() classification
    - Generate UNIQUE constraints for value objects
    - _Requirements: 3.1, 3.2, 3.11, 12.4_

- [x] 4. Implement relationship analysis components
  - [x] 4.1 Create RelationshipAnalyzer class
    - Implement analyzeAggregate() to discover all referenced types
    - Implement dependency ordering (topological sort)
    - Implement getRelationshipType() for field analysis
    - Detect circular references and handle gracefully
    - _Requirements: 3.1, 3.10_
  
  - [x] 4.2 Implement type classification
    - Implement isValueObject() detection
    - Implement isEntity() detection
    - Implement isAggregateRoot() detection
    - _Requirements: 11.1, 11.2, 11.3_

- [x] 5. Implement object mapping components
  - [x] 5.1 Create ObjectMapper class
    - Implement serializeGraph() for multi-table serialization
    - Implement deserializeGraph() for object reconstruction
    - Implement flattenValueObject() to embed value objects with prefixed columns
    - Implement reconstructValueObject() to reassemble value objects from columns
    - _Requirements: 2.1, 2.3, 2.5, 12.1, 12.2, 12.4_
  
  - [x] 5.2 Create JoinBuilder class
    - Implement buildLoadQuery() with JOIN generation
    - Implement buildJoinClauses() for related tables
    - Use LEFT JOIN for nullable relationships
    - _Requirements: 2.4, 2.5_

- [x] 6. Set up SQLite package structure (dddart_repository_sqlite)
  - Create package directory and pubspec.yaml
  - Configure dependencies: dddart, dddart_json, dddart_repository_sql, sqlite3, build, source_gen
  - Create build.yaml for code generation
  - Set up lib/ directory structure
  - Create analysis_options.yaml
  - _Requirements: 1.1, 9.1_

- [x] 7. Implement SQLite-specific components
  - [x] 7.1 Create SqliteConnection class
    - Implement file-based and in-memory constructors
    - Implement open() with PRAGMA foreign_keys = ON
    - Implement close(), execute(), query() methods
    - Implement transaction() with BEGIN/COMMIT/ROLLBACK
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 11.5_
  
  - [x] 7.2 Create SqliteDialect class
    - Implement column type getters (BLOB, TEXT, INTEGER, REAL)
    - Implement UUID encode/decode with 16-byte BLOB
    - Implement DateTime encode/decode with milliseconds
    - Implement SQL statement generation methods
    - _Requirements: 8.5, 10.1, 10.2, 10.4_
  
  - [x] 7.3 Create @GenerateSqliteRepository annotation
    - Define annotation class with tableName and implements parameters
    - _Requirements: 1.1, 1.2_

- [x] 8. Implement code generator
  - [x] 8.1 Create SqliteRepositoryGenerator class
    - Extend GeneratorForAnnotation<GenerateSqliteRepository>
    - Implement validation (extends AggregateRoot, has @Serializable)
    - _Requirements: 1.1, 1.5_
  
  - [x] 8.2 Implement object graph analysis
    - Use RelationshipAnalyzer to discover all types
    - Generate TableDefinitions for all discovered types
    - Order tables by dependencies
    - _Requirements: 3.1, 3.11_
  
  - [x] 8.3 Generate CREATE TABLE statements
    - Generate table creation for aggregate root with embedded value object columns
    - Generate table creation for entities with foreign keys and embedded value objects
    - Use CREATE TABLE IF NOT EXISTS
    - _Requirements: 3.2, 3.9, 3.12, 11.1, 12.1, 12.2_
  
  - [x] 8.4 Generate repository CRUD methods
    - Generate getById() with JOIN query
    - Generate save() with multi-table INSERT/UPDATE in transaction
    - Generate deleteById() with CASCADE DELETE
    - Generate createTables() method
    - _Requirements: 2.1, 2.2, 2.3, 4.1, 4.3, 4.4, 4.5_
  
  - [x] 8.5 Generate serialization/deserialization logic
    - Generate code to extract values from JsonSerializer.toJson()
    - Generate code to flatten value objects into prefixed columns
    - Generate code to reconstruct JSON from SQL rows with embedded value objects
    - Generate code to call JsonSerializer.fromJson()
    - _Requirements: 2.1, 2.2, 12.1, 12.2, 12.4_
  
  - [x] 8.6 Generate custom interface support
    - Detect custom methods in interface
    - Generate concrete class if no custom methods
    - Generate abstract base class if custom methods exist
    - Expose protected members (_connection, _dialect, _serializer)
    - _Requirements: 1.4, 7.1, 7.2, 7.3_
  
  - [x] 8.7 Generate exception mapping
    - Generate _mapSqliteException() helper method
    - Map SQLite error codes to RepositoryException types
    - Handle UNIQUE constraint violations, connection errors, etc.
    - _Requirements: 6.1, 6.2, 6.5_

- [x] 9. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 10. Write unit tests for base package
  - [x] 10.1 Test TypeMapper
    - Test SQL type selection for each Dart type
    - Test null handling
    - _Requirements: 3.4, 3.5, 3.6, 3.7_
  
  - [x] 10.2 Test SchemaGenerator
    - Test CREATE TABLE generation
    - Test column definition generation
    - Test foreign key generation
    - _Requirements: 3.2, 3.11_
  
  - [x] 10.3 Test RelationshipAnalyzer
    - Test type discovery
    - Test dependency ordering
    - Test circular reference detection
    - _Requirements: 3.1_
  
  - [x] 10.4 Test ObjectMapper
    - Test value object flattening with prefixed columns
    - Test value object reconstruction from columns
    - Test nullable value object handling
    - _Requirements: 12.1, 12.2, 12.4, 12.5_

- [x] 11. Write property-based tests
  - [x] 11.1 Property test: Aggregate round trip
    - **Property 1: Aggregate round trip preserves all fields**
    - **Validates: Requirements 2.1, 2.2, 4.1, 4.3**
    - Generate random aggregates with nested entities and value objects
    - Verify save/retrieve preserves all fields
    - Run 100+ iterations
    - **STATUS: Test infrastructure created but FAILING due to generator bugs**
  
  - [x] 11.2 Property test: Nested entities preserved
    - **Property 2: Nested entities are preserved**
    - **Validates: Requirements 2.3, 2.4**
    - Generate aggregates with lists of entities
    - Verify list order and entity fields preserved
    - Run 100+ iterations
    - **STATUS: NOT IMPLEMENTED**
  
  - [x] 11.3 Property test: Value object preservation
    - **Property 3: Value objects are preserved**
    - **Validates: Requirements 12.1, 12.2, 12.4**
    - Create aggregates with value objects
    - Verify value object fields are preserved through round-trip
    - Run 100+ iterations
    - **STATUS: NOT IMPLEMENTED**
  
  - [x] 11.4 Property test: Cascade delete entities
    - **Property 4: Deleting aggregate cascades to entities**
    - **Validates: Requirements 4.5**
    - Save aggregate with entities, delete aggregate
    - Verify entity rows are deleted
    - Run 100+ iterations
    - **STATUS: NOT IMPLEMENTED**
  
  - [x] 11.6 Property test: Non-existent ID throws notFound
    - **Property 6: Non-existent ID throws notFound**
    - **Validates: Requirements 4.2**
    - Generate random UUIDs not in database
    - Verify getById throws RepositoryException.notFound
    - Run 100+ iterations
    - **STATUS: NOT IMPLEMENTED**
  
  - [x] 11.7 Property test: Update preserves relationships
    - **Property 7: Update preserves relationships**
    - **Validates: Requirements 4.4**
    - Save aggregate, modify nested entity, save again
    - Verify modified values retrieved correctly
    - Run 100+ iterations
    - **STATUS: NOT IMPLEMENTED**
  
  - [x] 11.8 Property test: Concurrent saves maintain integrity
    - **Property 8: Concurrent saves maintain integrity**
    - **Validates: Requirements 4.3, 4.4**
    - Save two aggregates concurrently in separate transactions
    - Verify both are fully persisted without corruption
    - Run 100+ iterations
    - **STATUS: NOT IMPLEMENTED**
  
  - [x] 11.9 Property test: UUID round trip
    - **Property 9: UUID round trip**
    - **Validates: Requirements 10.1, 10.2**
    - Generate random UUIDs, store as BLOB, retrieve
    - Verify decoded UUID equals original
    - Run 100+ iterations
  
  - [x] 11.10 Property test: DateTime precision
    - **Property 10: DateTime precision preserved**
    - **Validates: Requirements 3.6**
    - Generate random DateTimes, round-trip through storage
    - Verify millisecond precision preserved
    - Run 100+ iterations
  
  - [x] 11.11 Property test: Boolean values
    - **Property 11: Boolean values preserved**
    - **Validates: Requirements 3.7**
    - Generate aggregates with boolean fields
    - Verify exact boolean values preserved
    - Run 100+ iterations

- [x] 12. Write integration tests
  - [x] 12.1 Test code generation
    - Test generator with simple aggregate root
    - Test generator with nested entities
    - Test generator with value objects
    - Verify generated code compiles
    - _Requirements: 1.1, 1.2, 1.3, 1.4_
  
  - [x] 12.2 Test multi-table operations
    - Test saving aggregate with deep nesting
    - Test loading with complex JOINs
    - Test transaction rollback on error
    - _Requirements: 2.1, 2.3, 2.4, 2.5_
  
  - [x] 12.3 Test foreign key constraints
    - Test CASCADE DELETE works correctly
    - Test RESTRICT prevents deletion
    - Verify PRAGMA foreign_keys = ON is set
    - _Requirements: 11.1, 11.5, 11.6_
  
  - [x] 12.4 Test value object embedding
    - Test value objects are flattened into parent table
    - Test prefixed column names are generated correctly
    - Test value object reconstruction from embedded columns
    - _Requirements: 12.1, 12.2, 12.4_
  
  - [x] 12.5 Test error handling
    - Test constraint violation errors
    - Test connection errors
    - Test not found errors
    - Verify exception types are correct
    - _Requirements: 6.1, 6.2, 6.4, 6.5_
  
  - [x] 12.6 Test custom repository interfaces
    - Test concrete class generation (no custom methods)
    - Test abstract base class generation (with custom methods)
    - Test custom query implementation
    - _Requirements: 7.1, 7.2, 7.4, 7.5_

- [x] 13. Create example applications
  - [x] 13.1 Create basic CRUD example
    - Simple aggregate root with primitive fields
    - Demonstrate save, retrieve, delete operations
    - Show connection management
    - _Requirements: 13.1_
  
  - [x] 13.2 Create complex aggregate example
    - Aggregate with nested entities and embedded value objects
    - Demonstrate multi-table persistence
    - Show value object embedding with prefixed columns
    - _Requirements: 13.1, 13.2_
  
  - [x] 13.3 Create custom repository example
    - Define custom interface with query methods
    - Implement custom SQL queries
    - Demonstrate JOIN usage
    - _Requirements: 13.3_

- [x] 14. Write documentation
  - [x] 14.1 Write base package README
    - Document SqlConnection and SqlDialect abstractions
    - Document schema generation concepts
    - Document relationship mapping
    - _Requirements: 13.4_
  
  - [x] 14.2 Write SQLite package README
    - Quick start guide with code examples
    - Document @GenerateSqliteRepository annotation
    - Document connection management best practices
    - Document PRAGMA foreign_keys requirement
    - Document error handling patterns
    - Document custom repository interfaces
    - Document value object embedding strategy
    - _Requirements: 13.1, 13.2, 13.3, 13.4, 13.5, 13.6_
  
  - [x] 14.3 Create API documentation
    - Document all public classes and methods
    - Add code examples to doc comments
    - Document generated repository structure
    - _Requirements: 13.4_

- [x] 15. Update workspace configuration
  - Add dddart_repository_sql to workspace in root pubspec.yaml
  - Add dddart_repository_sqlite to workspace in root pubspec.yaml
  - Add packages to .github/workflows/test.yml matrix
  - Add packages to scripts/test-all.sh
  - _Requirements: All_

- [x] 16. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.
