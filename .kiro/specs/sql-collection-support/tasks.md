# Implementation Plan

- [x] 1. Extend base SQL package with collection support infrastructure
  - Create CollectionAnalyzer class for analyzing collection fields
  - Add collection detection methods to RelationshipAnalyzer
  - Update TypeMapper to accept SqlDialect parameter for database-specific types
  - Add dateTimeColumnType getter to SqlDialect interface
  - _Requirements: 1.1-1.9, 9.1-9.10_

- [x] 2. Implement DateTime and boolean type improvements
  - Update SqliteDialect with TEXT for DateTime (ISO8601 encoding/decoding)
  - Update MysqlDialect with DATETIME for DateTime (UTC encoding/decoding)
  - Verify boolean types are correct (INTEGER for SQLite, TINYINT(1) for MySQL)
  - Fix DateTime encoding/decoding to work for ALL DateTime fields, not just fields ending in "At"
  - _Requirements: 16.1-16.11, 17.1-17.7_

- [x] 2.1 Write property test for DateTime round-trip
  - **Property 12: DateTime round-trip preservation**
  - **Validates: Requirements 16.1-16.11**

- [x] 2.2 Write property test for boolean round-trip
  - **Property 13: Boolean round-trip preservation**
  - **Validates: Requirements 17.1-17.7**

- [x] 3. Implement primitive collection schema generation
  - Add List<primitive> junction table generation with position column
  - Add Set<primitive> junction table generation with UNIQUE constraint
  - Add Map<primitive, primitive> junction table generation with map_key column
  - Implement table naming convention: {parent_table}_{field_name}_items
  - _Requirements: 1.1-1.6, 2.1-2.2, 3.1-3.2, 9.1-9.3, 15.1-15.5_

- [x] 3.1 Write property test for primitive list schema generation
  - **Property 14: Schema generation for primitive lists**
  - **Validates: Requirements 9.1**

- [x] 3.2 Write property test for primitive set schema generation
  - **Property 15: Schema generation for primitive sets**
  - **Validates: Requirements 9.2**

- [x] 3.3 Write property test for primitive map schema generation
  - **Property 16: Schema generation for primitive maps**
  - **Validates: Requirements 9.3**

- [x] 4. Implement value object collection schema generation
  - Add List<Value> junction table generation with flattened value fields
  - Add Set<Value> junction table generation with flattened value fields and UNIQUE constraint
  - Add Map<primitive, Value> junction table generation with map_key and flattened value fields
  - Implement value object field flattening for junction tables
  - _Requirements: 4.1-4.6, 5.1-5.4, 6.1-6.4, 9.4-9.6_

- [x] 5. Implement entity collection schema generation
  - Add Set<Entity> table generation (entity table without position column)
  - Add Map<primitive, Entity> table generation (entity table with map_key column)
  - Ensure CASCADE DELETE foreign keys for all entity collections
  - _Requirements: 7.1-7.5, 8.1-8.5, 9.7-9.9_

- [x] 6. Implement SQLite collection save operations
  - Generate _saveCollection methods for List<primitive>
  - Generate _saveCollection methods for Set<primitive>
  - Generate _saveCollection methods for Map<primitive, primitive>
  - Generate _saveCollection methods for List<Value>
  - Generate _saveCollection methods for Set<Value>
  - Generate _saveCollection methods for Map<primitive, Value>
  - Generate _saveCollection methods for Set<Entity>
  - Generate _saveCollection methods for Map<primitive, Entity>
  - Wrap all operations in transactions
  - Implement delete-then-insert strategy for updates
  - _Requirements: 1.7, 10.1-10.6_

- [x] 7. Implement SQLite collection load operations
  - Generate _loadCollection methods for List<primitive> with ORDER BY position
  - Generate _loadCollection methods for Set<primitive>
  - Generate _loadCollection methods for Map<primitive, primitive>
  - Generate _loadCollection methods for List<Value> with value object reconstruction
  - Generate _loadCollection methods for Set<Value> with value object reconstruction
  - Generate _loadCollection methods for Map<primitive, Value> with value object reconstruction
  - Generate _loadCollection methods for Set<Entity>
  - Generate _loadCollection methods for Map<primitive, Entity>
  - Handle empty collections correctly
  - _Requirements: 1.8, 11.1-11.7_

- [x] 7.1 Write property test for primitive list round-trip
  - **Property 1: Primitive list round-trip preservation**
  - **Validates: Requirements 1.1-1.8**

- [x] 7.2 Write property test for primitive set round-trip
  - **Property 2: Primitive set round-trip preservation**
  - **Validates: Requirements 2.1-2.4**

- [x] 7.3 Write property test for primitive map round-trip
  - **Property 3: Primitive map round-trip preservation**
  - **Validates: Requirements 3.1-3.5**

- [x] 7.4 Write property test for value object list round-trip
  - **Property 4: Value object list round-trip preservation**
  - **Validates: Requirements 4.1-4.6**

- [x] 7.5 Write property test for value object set round-trip
  - **Property 5: Value object set round-trip preservation**
  - **Validates: Requirements 5.1-5.4**

- [x] 7.6 Write property test for value object map round-trip
  - **Property 6: Value object map round-trip preservation**
  - **Validates: Requirements 6.1-6.4**

- [x] 7.7 Write property test for entity set round-trip
  - **Property 7: Entity set round-trip preservation**
  - **Validates: Requirements 7.1-7.4**

- [x] 7.8 Write property test for entity map round-trip
  - **Property 8: Entity map round-trip preservation**
  - **Validates: Requirements 8.1-8.4**

- [x] 8. Implement MySQL collection save operations
  - Mirror SQLite save operations with MySQL-specific SQL syntax
  - Use MySQL dialect for type encoding
  - Ensure transaction handling works with MySQL
  - _Requirements: 10.1-10.6, 13.1-13.7_

- [x] 9. Implement MySQL collection load operations
  - Mirror SQLite load operations with MySQL-specific SQL syntax
  - Use MySQL dialect for type decoding
  - Handle MySQL-specific datetime and boolean decoding
  - _Requirements: 11.1-11.7, 13.1-13.7_

- [x] 9.1 Write property test for dialect consistency
  - **Property 18: Dialect consistency**
  - **Validates: Requirements 13.1-13.7**

- [x] 10. Implement error handling and validation
  - Add validation to reject List<dynamic> and List<Object>
  - Add validation to reject nested collections (List<List<T>>)
  - Add validation to reject Map<Value, T> (value objects as keys)
  - Add validation to reject collections of aggregate roots
  - Generate clear error messages with field name, type, and suggestions
  - _Requirements: 12.1-12.8_

- [x] 11. Implement nullable collection handling
  - Treat null collections as empty collections during save
  - Return empty collections (not null) during load
  - Handle nullable collection elements (List<int?>)
  - _Requirements: 14.1-14.4_

- [x] 11.1 Write property test for empty collection handling
  - **Property 10: Empty collection handling**
  - **Validates: Requirements 10.3, 11.6**

- [x] 11.2 Write property test for null collection handling
  - **Property 11: Null collection handling**
  - **Validates: Requirements 14.1-14.3**

- [x] 12. Implement CASCADE DELETE testing
  - Verify foreign key constraints are generated correctly
  - Test that deleting aggregate deletes all collection items
  - Test with all collection types
  - _Requirements: 1.9, 2.6, 7.5, 8.5_

- [x] 12.1 Write property test for collection cascade delete
  - **Property 9: Collection cascade delete**
  - **Validates: Requirements 1.9, 2.6, 7.5, 8.5**

- [x] 13. Implement transaction rollback testing
  - Test that failed saves roll back all changes
  - Test with multiple collections in one aggregate
  - Verify database state remains consistent after rollback
  - _Requirements: 10.1, 10.5_

- [x] 13.1 Write property test for transaction rollback
  - **Property 17: Transaction rollback on failure**
  - **Validates: Requirements 10.1, 10.5**

- [x] 14. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 15. Create comprehensive test models
  - Create test aggregates with all collection types
  - Create test value objects for collection testing
  - Create test entities for collection testing
  - Add to both SQLite and MySQL test suites
  - _Requirements: All_

- [x] 15.1 Write integration tests for SQLite
  - Test all collection types end-to-end
  - Test with in-memory database
  - Test schema creation, save, load, delete operations

- [x] 15.2 Write integration tests for MySQL
  - Test all collection types end-to-end
  - Test with MySQL test container
  - Test schema creation, save, load, delete operations

- [x] 16. Update documentation
  - Update dddart_repository_sqlite/README.md with collection examples
  - Update dddart_repository_mysql/README.md with collection examples
  - Add collection_examples.dart to example directories
  - Document DateTime and boolean type improvements
  - Add migration guide for existing databases
  - _Requirements: All_

- [x] 17. Update CI/CD configuration
  - Update .github/workflows/test.yml to include MySQL container
  - Add collection-specific test execution
  - Update scripts/test-all.sh with collection tests
  - Ensure both SQLite and MySQL tests run in CI
  - _Requirements: All_

- [x] 18. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.
