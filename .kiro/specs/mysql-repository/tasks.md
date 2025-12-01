# Implementation Plan

- [ ] 1. Set up package structure and dependencies
  - Create package directory structure (lib/src with subdirectories)
  - Create pubspec.yaml with dependencies (mysql1, dddart_repository_sql, etc.)
  - Create build.yaml for code generation configuration
  - Create analysis_options.yaml with very_good_analysis
  - Add package to workspace root pubspec.yaml
  - _Requirements: 1.1, 10.2_

- [ ] 2. Implement MysqlDialect
  - Create lib/src/dialect/mysql_dialect.dart
  - Implement SqlDialect interface with MySQL-specific type mappings
  - Implement UUID encoding/decoding (string to BINARY(16) and back)
  - Implement DateTime encoding/decoding (DateTime to TIMESTAMP and back)
  - Implement createTableIfNotExists with ENGINE=InnoDB and DEFAULT CHARSET=utf8mb4
  - Implement insertOrReplace with ON DUPLICATE KEY UPDATE syntax
  - Implement selectWithJoins for loading aggregates
  - Implement delete method
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7_

- [ ] 2.1 Write property test for UUID round-trip
  - **Property 5: UUID encoding round-trip**
  - **Validates: Requirements 3.1, 3.2**

- [ ] 2.2 Write property test for DateTime round-trip
  - **Property 6: DateTime encoding round-trip**
  - **Validates: Requirements 3.3, 3.4**

- [ ] 2.3 Write property test for SQL syntax validation
  - **Property 7: MySQL-specific SQL syntax**
  - **Property 8: MySQL INSERT syntax**
  - **Property 9: Type mapping correctness**
  - **Validates: Requirements 3.5, 3.6, 3.7**

- [ ] 3. Implement MysqlConnection
  - Create lib/src/connection/mysql_connection.dart
  - Implement SqlConnection interface
  - Implement connection pooling with configurable pool size
  - Implement open() method with connection establishment
  - Implement close() method with connection cleanup
  - Implement execute() method for non-query SQL
  - Implement query() method for SELECT statements
  - Implement transaction() method with nested transaction support
  - Implement isOpen getter
  - Implement MySQL exception mapping to RepositoryException
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 5.1, 5.2, 5.3, 5.4, 7.1, 7.2, 7.3, 7.4, 7.5_

- [ ] 3.1 Write property test for connection lifecycle
  - **Property 3: Connection lifecycle correctness**
  - **Validates: Requirements 2.2, 2.3, 2.4**

- [ ] 3.2 Write property test for connection error handling
  - **Property 4: Connection error handling**
  - **Validates: Requirements 2.5, 7.1**

- [ ] 3.3 Write property test for transaction atomicity
  - **Property 16: Transaction atomicity**
  - **Validates: Requirements 5.1, 5.2, 5.3**

- [ ] 3.4 Write property test for nested transactions
  - **Property 17: Nested transaction handling**
  - **Validates: Requirements 5.4**

- [ ] 3.5 Write property tests for error mapping
  - **Property 19: Duplicate key error mapping**
  - **Property 20: Not found error handling**
  - **Property 21: Timeout error mapping**
  - **Property 22: Unknown error mapping**
  - **Validates: Requirements 7.2, 7.3, 7.4, 7.5**

- [ ] 4. Implement @GenerateMysqlRepository annotation
  - Create lib/src/annotations/generate_mysql_repository.dart
  - Define GenerateMysqlRepository class with tableName and implements parameters
  - Add documentation explaining usage
  - _Requirements: 1.1, 10.2_

- [ ] 5. Implement MysqlRepositoryGenerator
  - Create lib/src/generators/mysql_repository_generator.dart
  - Implement GeneratorForAnnotation<GenerateMysqlRepository>
  - Implement generateForAnnotatedElement method
  - Validate element is ClassElement extending AggregateRoot with @Serializable
  - Extract configuration from annotation (tableName, custom interface)
  - Use RelationshipAnalyzer to discover object graph
  - Generate TableDefinitions for all types (excluding value objects)
  - Add parent foreign keys to entity tables
  - Generate concrete repository class or abstract base class based on custom interface
  - _Requirements: 1.1, 1.2, 1.3, 1.5, 8.1, 8.2, 10.3_

- [ ] 5.1 Implement repository code generation - CRUD methods
  - Generate createTables() method with CREATE TABLE statements
  - Generate getById() method with SELECT and entity loading
  - Generate save() method with INSERT/UPDATE and entity persistence
  - Generate deleteById() method with CASCADE handling
  - _Requirements: 1.2, 4.1, 4.2, 4.3, 4.4, 6.1, 6.2, 6.3_

- [ ] 5.2 Implement repository code generation - helper methods
  - Generate _saveEntity methods for each entity table
  - Generate _loadEntity methods for each entity table
  - Generate _flattenForTable for value object embedding
  - Generate _rowToJson for value object reconstruction
  - Generate _encodeValue for SQL encoding
  - Generate _decodeValue for SQL decoding
  - Generate _mapMysqlException for error mapping
  - _Requirements: 6.4, 6.5, 7.1, 7.2, 7.3, 7.4, 7.5, 8.5_

- [ ] 5.3 Write property test for repository generation
  - **Property 1: Repository generation completeness**
  - **Property 27: Multiple aggregate independence**
  - **Validates: Requirements 1.1, 1.2, 1.3, 1.5**

- [ ] 5.4 Write property test for schema generation
  - **Property 10: Schema generation completeness**
  - **Property 11: Schema creation idempotence**
  - **Property 12: Entity foreign key constraints**
  - **Property 13: Value object embedding**
  - **Property 14: Nullable value object handling**
  - **Property 15: Non-nullable value object handling**
  - **Validates: Requirements 4.1, 4.2, 4.3, 4.4, 6.1, 6.2, 6.3**

- [ ] 5.5 Write property test for code structure consistency
  - **Property 25: Repository interface consistency**
  - **Property 26: Code structure consistency**
  - **Validates: Requirements 10.1, 10.3, 10.4**

- [ ] 6. Create main library export file
  - Create lib/dddart_repository_mysql.dart
  - Export all public classes (MysqlConnection, MysqlDialect, GenerateMysqlRepository)
  - Add library documentation
  - _Requirements: 1.1_

- [ ] 7. Create build configuration
  - Create build.yaml with builder configuration
  - Configure mysql_repository builder with SharedPartBuilder
  - Set build_extensions to .mysql_repository.g.part
  - _Requirements: 1.1_

- [ ] 8. Implement Docker test infrastructure
  - Create test/test_helpers.dart with MysqlTestContainer class
  - Implement container start/stop methods
  - Implement MySQL readiness check with retry logic
  - Implement test connection factory
  - Create test/docker_test_setup.dart for shared test setup
  - _Requirements: All (enables testing)_

- [ ] 8.1 Write integration test for Docker container management
  - Test container start/stop lifecycle
  - Test MySQL readiness detection
  - Test connection creation
  - _Requirements: All (test infrastructure)_

- [ ] 9. Write integration tests with Docker
  - Create test/repository_integration_test.dart
  - Test basic CRUD operations (save, getById, deleteById)
  - Test complex object graphs with entities and value objects
  - Test value object embedding and reconstruction
  - Test foreign key CASCADE DELETE behavior
  - Test transaction rollback on errors
  - Test custom repository interfaces
  - Tag tests with @Tags(['requires-mysql', 'integration'])
  - _Requirements: 1.2, 1.4, 4.3, 5.1, 5.2, 5.5, 6.4, 6.5, 8.3, 8.4_

- [ ] 9.1 Write property test for object graph round-trip
  - **Property 2: Object graph persistence round-trip**
  - **Validates: Requirements 1.4, 6.4, 6.5**

- [ ] 9.2 Write property test for custom query transaction context
  - **Property 18: Custom query transaction context**
  - **Validates: Requirements 5.5, 8.4**

- [ ] 9.3 Write property test for abstract base class generation
  - **Property 23: Abstract base class generation**
  - **Property 24: Deserialization helper availability**
  - **Validates: Requirements 8.1, 8.2, 8.5**

- [ ] 10. Create comprehensive examples
  - Create example/lib/domain/ with sample domain models (Order, OrderItem, Money, Address)
  - Add @Serializable and @GenerateMysqlRepository annotations
  - Create example/basic_crud_example.dart demonstrating save/load/delete
  - Create example/custom_repository_example.dart demonstrating custom interfaces
  - Create example/error_handling_example.dart demonstrating exception handling
  - Create example/connection_management_example.dart demonstrating connection lifecycle
  - Create example/README.md explaining how to run examples
  - Add example/pubspec.yaml with dependencies
  - _Requirements: 9.1, 9.2, 9.3_

- [ ] 11. Create package documentation
  - Create README.md with overview, features, installation, quick start, and usage
  - Document MySQL-specific configuration (host, port, credentials, pool size)
  - Document value object embedding strategy
  - Document error handling patterns
  - Document custom repository interfaces
  - Document connection pooling and production best practices
  - Document migration from SQLite to MySQL
  - Create CHANGELOG.md with version 0.9.0 initial release
  - Create LICENSE file (MIT)
  - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5_

- [ ] 12. Update workspace configuration
  - Add dddart_repository_mysql to workspace list in root pubspec.yaml
  - Add dddart_repository_mysql to .github/workflows/test.yml matrix
  - Add dddart_repository_mysql to scripts/test-all.sh PACKAGES array
  - _Requirements: All (enables CI/CD)_

- [ ] 13. Checkpoint - Ensure all tests pass
  - Run dart pub get from workspace root
  - Run dart run build_runner build in package directory
  - Run dart analyze --fatal-infos
  - Run dart format --set-exit-if-changed .
  - Run dart test (excluding requires-mysql tests if Docker not available)
  - Run ./scripts/test-all.sh from workspace root
  - Ensure all tests pass, ask the user if questions arise.
  - _Requirements: All_
