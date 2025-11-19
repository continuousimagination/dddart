# Implementation Plan

- [-] 1. Set up package structure and dependencies
  - Create `packages/dddart_repository_mongodb/` directory structure
  - Create `pubspec.yaml` with dependencies on `dddart`, `dddart_serialization`, `dddart_json`, and `mongo_dart`
  - Create `build.yaml` for code generator configuration
  - Create `analysis_options.yaml` with `very_good_analysis`
  - Create initial `README.md`, `CHANGELOG.md`, and `LICENSE` files
  - _Requirements: 12.1, 12.2, 12.3_

- [ ] 2. Implement annotation classes
  - [ ] 2.1 Create `GenerateMongoRepository` annotation class
    - Implement annotation with `collectionName` and `implements` parameters
    - Add comprehensive documentation with examples
    - _Requirements: 1.1, 7.1, 7.2, 10.1_
  
  - [ ] 2.2 Create main library export file
    - Export annotation and public classes
    - _Requirements: 12.2_

- [ ] 3. Implement connection management
  - [ ] 3.1 Create `MongoConnection` class
    - Implement constructor with connection parameters (host, port, database, credentials, TLS options)
    - Implement `fromUri` factory constructor for connection string URIs
    - Implement `open()` method for establishing connection
    - Implement `close()` method for closing connection
    - Implement `database` getter with connection state validation
    - Implement `isConnected` getter
    - _Requirements: 3.2, 3.3, 3.4, 3.5, 13.1, 13.2, 13.3_
  
  - [ ] 3.2 Implement connection string builder
    - Build MongoDB connection string from parameters
    - Support AWS DocumentDB connection string format with TLS options
    - _Requirements: 3.5, 9.5_

- [ ] 4. Implement code generator infrastructure
  - [ ] 4.1 Create `MongoRepositoryGenerator` class extending `GeneratorForAnnotation`
    - Implement `generateForAnnotatedElement` method
    - Validate annotated element is a `ClassElement`
    - _Requirements: 1.1, 1.2_
  
  - [ ] 4.2 Implement validation logic
    - Validate class extends `AggregateRoot`
    - Validate class has `@Serializable()` annotation
    - Throw `InvalidGenerationSourceError` for validation failures
    - _Requirements: 1.2, 1.3, 2.3, 2.4_
  
  - [ ] 4.3 Implement configuration extraction
    - Extract `collectionName` from annotation or generate from class name
    - Extract `implements` interface type from annotation
    - Implement snake_case conversion for default collection names
    - _Requirements: 7.1, 7.2, 7.3, 7.5_
  
  - [ ] 4.4 Implement interface introspection logic
    - Extract methods from custom interface using analyzer
    - Classify methods as base Repository methods or custom methods
    - Determine whether to generate concrete class or abstract base class
    - _Requirements: 10.2, 10.3, 10.4, 10.5_

- [ ] 5. Implement concrete repository generation
  - [ ] 5.1 Generate repository class structure
    - Generate class declaration with appropriate implements clause
    - Generate constructor accepting `Db` parameter
    - Generate library-private `_database` field
    - Generate `collectionName` getter
    - Generate `_collection` helper getter
    - Generate `_serializer` field
    - _Requirements: 1.4, 1.5, 3.1, 10.6, 10.7_
  
  - [ ] 5.2 Implement `getById` method generation
    - Generate MongoDB query using `_id` field
    - Generate document-to-aggregate deserialization using `JsonSerializer`
    - Generate ID field mapping (`_id` → `id`)
    - Generate `RepositoryException.notFound` for missing documents
    - Generate error handling with exception mapping
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 2.1, 2.2_
  
  - [ ] 5.3 Implement `save` method generation
    - Generate aggregate-to-document serialization using `JsonSerializer`
    - Generate ID field mapping (`id` → `_id`)
    - Generate upsert operation using `replaceOne` with `upsert: true`
    - Generate error handling with MongoDB exception mapping
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 2.1, 2.2_
  
  - [ ] 5.4 Implement `deleteById` method generation
    - Generate MongoDB delete operation using `_id` field
    - Generate result verification for affected document count
    - Generate `RepositoryException.notFound` for zero affected documents
    - Generate error handling with exception mapping
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5_
  
  - [ ] 5.5 Implement MongoDB exception mapping helper
    - Generate `_mapMongoException` method
    - Map duplicate key errors to `RepositoryExceptionType.duplicate`
    - Map connection errors to `RepositoryExceptionType.connection`
    - Map timeout errors to `RepositoryExceptionType.timeout`
    - Map unknown errors to `RepositoryExceptionType.unknown`
    - Include original error message and stack trace
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5_

- [ ] 6. Implement abstract base repository generation
  - [ ] 6.1 Generate abstract base class structure
    - Generate abstract class declaration with `Base` suffix
    - Generate constructor and fields same as concrete class
    - Generate concrete implementations of base Repository methods
    - _Requirements: 10.4, 10.5_
  
  - [ ] 6.2 Generate abstract method declarations
    - Identify custom methods from interface introspection
    - Generate abstract method signatures with proper return types and parameters
    - Add `@override` annotations
    - _Requirements: 10.5_

- [ ] 7. Implement builder configuration
  - [ ] 7.1 Create `build.yaml` configuration
    - Configure `mongo_repository` builder
    - Set build extensions to `.mongo_repository.g.dart`
    - Configure auto-apply to dependents
    - Set build target to source
    - _Requirements: 12.3_
  
  - [ ] 7.2 Create builder factory function
    - Implement `mongoRepositoryBuilder` function
    - Return `SharedPartBuilder` with `MongoRepositoryGenerator`
    - _Requirements: 12.3_

- [ ] 8. Create comprehensive examples
  - [ ] 8.1 Create example domain models
    - Create `User` aggregate with `@Serializable` and `@GenerateMongoRepository`
    - Create `Product` aggregate for additional examples
    - Generate serializers and repositories using build_runner
    - _Requirements: 11.1, 11.2_
  
  - [ ] 8.2 Create basic CRUD example
    - Demonstrate connection setup and opening
    - Demonstrate creating and saving aggregates
    - Demonstrate retrieving aggregates by ID
    - Demonstrate deleting aggregates
    - Demonstrate connection closing
    - _Requirements: 11.2, 13.4_
  
  - [ ] 8.3 Create custom interface example
    - Define custom repository interface with domain-specific methods
    - Annotate aggregate with `implements` parameter
    - Extend generated abstract base class
    - Implement custom query methods using `_database` and `_collection`
    - Demonstrate usage of both generated and custom methods
    - _Requirements: 11.3, 11.4_
  
  - [ ] 8.4 Create error handling example
    - Demonstrate handling `RepositoryException.notFound`
    - Demonstrate handling `RepositoryException.duplicate`
    - Demonstrate handling connection errors
    - Demonstrate proper try-catch patterns
    - _Requirements: 11.6_
  
  - [ ] 8.5 Create dddart_config integration example
    - Demonstrate loading MongoDB configuration from config file
    - Demonstrate creating connection from config values
    - Show configuration file structure
    - _Requirements: 11.5_
  
  - [ ] 8.6 Create repository swapping example
    - Define custom repository interface
    - Show MongoDB implementation for production
    - Show InMemoryRepository for testing
    - Demonstrate swapping implementations
    - _Requirements: 11.7_
  
  - [ ] 8.7 Create example README
    - Document how to run each example
    - Explain what each example demonstrates
    - Include prerequisites and setup instructions
    - _Requirements: 11.8_

- [ ] 9. Write comprehensive documentation
  - [ ] 9.1 Create package README
    - Write overview and features section
    - Write installation instructions
    - Write quick start guide with basic usage
    - Document annotation parameters and options
    - Document custom interface pattern
    - Document extensibility patterns
    - Document AWS DocumentDB compatibility
    - Document error handling patterns
    - Include API reference links
    - _Requirements: 12.5_
  
  - [ ] 9.2 Document connection lifecycle best practices
    - Document connection pooling (handled by mongo_dart)
    - Document connection reuse patterns
    - Document proper connection closing
    - _Requirements: 13.5_
  
  - [ ] 9.3 Create CHANGELOG
    - Document initial release features
    - _Requirements: 12.2_

- [ ] 10. Implement comprehensive tests
  - [ ] 10.1 Create generator unit tests
    - Test annotation processing and validation
    - Test error cases (missing @Serializable, not extending AggregateRoot)
    - Test collection name generation (default snake_case and custom)
    - Test interface introspection logic
    - Test concrete class generation decision
    - Test abstract base class generation decision
    - Test code generation output structure
    - _Requirements: 1.2, 1.3, 2.4, 7.2, 7.3, 7.5, 10.2, 10.3, 10.4_
  
  - [ ] 10.2 Create connection management tests
    - Test connection string building from parameters
    - Test URI parsing with `fromUri` factory
    - Test connection lifecycle (open/close)
    - Test connection state validation
    - Test error handling for connection failures
    - Test AWS DocumentDB connection string format
    - _Requirements: 3.2, 3.3, 3.4, 3.5, 9.5_
  
  - [ ] 10.3 Create repository integration tests
    - Set up test MongoDB instance or use in-memory alternative
    - Test CRUD operations (save, getById, deleteById)
    - Test ID mapping (_id ↔ id)
    - Test exception mapping for various MongoDB errors
    - Test with different SerializationConfig options
    - Test concrete repository usage
    - Test abstract base repository extension
    - Test custom query methods in extended repositories
    - _Requirements: 4.1, 4.2, 4.3, 4.5, 5.1, 5.2, 5.3, 5.4, 6.1, 6.2, 6.3, 6.5, 8.1, 8.2, 8.3, 8.4_
  
  - [ ] 10.4 Create test utilities
    - Create helper for setting up test MongoDB connections
    - Create test aggregate models with various configurations
    - Create test repository interfaces
    - _Requirements: Testing infrastructure_

- [ ] 11. Final integration and polish
  - [ ] 11.1 Run code formatter
    - Format all Dart files with `dart format`
    - _Requirements: Code quality_
  
  - [ ] 11.2 Run static analysis
    - Run `dart analyze` and fix all issues
    - Ensure compliance with `very_good_analysis` rules
    - _Requirements: Code quality_
  
  - [ ] 11.3 Verify all tests pass
    - Run `dart test` and ensure 100% pass rate
    - _Requirements: Code quality_
  
  - [ ] 11.4 Verify examples run successfully
    - Run each example and verify output
    - _Requirements: 11.8_
  
  - [ ] 11.5 Review documentation completeness
    - Verify README covers all features
    - Verify examples are well-documented
    - Verify API documentation is complete
    - _Requirements: 12.5_
