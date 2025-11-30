# Implementation Plan

- [x] 1. Set up project structure and dependencies
  - Create package directory structure (lib/src/, test/, example/)
  - Configure pubspec.yaml with dependencies (dddart, dddart_json, dddart_serialization, aws_dynamodb_api, build, source_gen, analyzer)
  - Configure build.yaml for code generation
  - Create analysis_options.yaml with very_good_analysis
  - Create initial README.md structure
  - _Requirements: 7.1, 9.1, 9.2_

- [x] 2. Implement AttributeValue conversion utilities
  - Create AttributeValueConverter class with jsonToAttributeValue method
  - Implement attributeValueToJson method
  - Implement jsonMapToAttributeMap helper method
  - Implement attributeMapToJsonMap helper method
  - Handle all JSON types (null, bool, string, number, list, map)
  - _Requirements: 3.3, 3.4_

- [x] 2.1 Write property test for AttributeValue round-trip conversion
  - **Property 4: AttributeValue conversion round-trip**
  - **Validates: Requirements 3.3, 3.4**

- [x] 3. Implement DynamoConnection class
  - Create DynamoConnection class with constructor accepting region, credentials, and endpoint
  - Implement factory constructor for DynamoDB Local (DynamoConnection.local)
  - Implement lazy client getter that initializes DynamoDB client
  - Implement dispose method for resource cleanup
  - Add validation to throw StateError if client accessed before initialization
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_

- [x] 3.1 Write unit tests for DynamoConnection
  - Test client initialization with various configurations
  - Test custom endpoint configuration
  - Test StateError when accessing uninitialized client
  - Test local factory constructor
  - _Requirements: 5.1, 5.2, 5.4_

- [x] 4. Create annotation class
  - Create GenerateDynamoRepository annotation class
  - Add tableName parameter (String?)
  - Add implements parameter (Type?)
  - Add comprehensive doc comments explaining usage patterns
  - _Requirements: 1.1, 1.4, 1.5, 9.1_

- [x] 5. Implement code generator validation logic
  - Create DynamoRepositoryGenerator class extending GeneratorForAnnotation
  - Implement validation to check class extends AggregateRoot
  - Implement validation to check class has @Serializable annotation
  - Throw InvalidGenerationSourceError with descriptive messages for validation failures
  - Implement table name extraction with snake_case conversion fallback
  - Implement custom interface extraction from annotation
  - _Requirements: 1.2, 1.3, 1.4, 1.5, 4.1_

- [x] 5.1 Write unit tests for generator validation
  - Test error for class not extending AggregateRoot
  - Test error for class missing @Serializable
  - Test custom table name extraction
  - Test interface extraction
  - _Requirements: 1.2, 1.3, 1.4, 4.1_

- [x] 5.2 Write property test for snake_case conversion
  - **Property 5: Table name snake_case conversion**
  - **Validates: Requirements 1.5**

- [x] 6. Implement concrete repository generation
  - Implement method to generate concrete repository class
  - Generate constructor accepting DynamoConnection
  - Generate tableName getter
  - Generate _serializer field initialization
  - Generate getById method implementation using DynamoDB GetItem
  - Generate save method implementation using DynamoDB PutItem
  - Generate deleteById method implementation using DynamoDB DeleteItem
  - Generate exception mapping helper method
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 3.1, 3.2, 4.2_

- [x] 7. Implement abstract base repository generation
  - Implement method to analyze custom interface for additional methods
  - Generate abstract base class when custom methods detected
  - Generate concrete implementations of base CRUD methods
  - Generate abstract method declarations for custom methods
  - Expose protected members (_connection, tableName, _serializer)
  - _Requirements: 4.3, 4.4, 4.5_

- [x] 7.1 Write unit tests for generator output
  - Test concrete class generation structure
  - Test abstract base class generation structure
  - Test method signature generation
  - Test protected member exposure
  - _Requirements: 4.2, 4.3, 4.4, 4.5_

- [x] 8. Implement exception mapping logic
  - Map ResourceNotFoundException to RepositoryException.notFound
  - Map ConditionalCheckFailedException to RepositoryException.duplicate
  - Map network/connectivity errors to RepositoryException.connection
  - Map timeout errors to RepositoryException.timeout
  - Map unknown errors to RepositoryException.unknown with cause preservation
  - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 5.6_

- [x] 8.1 Write property test for exception mapping
  - **Property 6: DynamoDB exception mapping**
  - **Property 7: Unknown exception handling**
  - **Validates: Requirements 6.1, 6.5**

- [x] 9. Implement table creation utilities
  - Generate createTableDefinition static method returning CreateTableInput
  - Generate createTable instance method executing table creation
  - Generate getCreateTableCommand static method returning AWS CLI command string
  - Generate getCloudFormationTemplate static method returning CloudFormation YAML
  - Configure table with id as partition key (String type)
  - Use PAY_PER_REQUEST billing mode in generated definitions
  - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5_

- [x] 9.1 Write unit tests for table creation utilities
  - Test CreateTableInput structure
  - Test AWS CLI command format
  - Test CloudFormation template format
  - Test partition key configuration
  - _Requirements: 8.1, 8.3, 8.4, 8.5_

- [x] 10. Create test models and helpers
  - Create test aggregate classes (User, Product, Order)
  - Annotate with @Serializable and @GenerateDynamoRepository
  - Create custom repository interfaces for testing
  - Create test helper utilities for DynamoDB Local setup
  - Create test helper for table creation and cleanup
  - _Requirements: All testing requirements_

- [x] 11. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 12. Write property-based tests for repository operations
  - Create custom property test utilities and generators
  - Generate random aggregate instances for testing
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6_

- [x] 12.1 Write property test for round-trip persistence
  - **Property 1: Repository round-trip persistence**
  - **Validates: Requirements 2.1, 2.3**

- [x] 12.2 Write property test for upsert behavior
  - **Property 2: Repository upsert behavior**
  - **Validates: Requirements 2.4**

- [x] 12.3 Write property test for deletion
  - **Property 3: Repository deletion removes items**
  - **Validates: Requirements 2.5, 2.2, 2.6**

- [x] 13. Write integration tests with DynamoDB Local
  - Set up integration test with DynamoDB Local connection
  - Test complete CRUD workflow
  - Test custom repository interface implementation
  - Test table creation utilities
  - Test error handling with real DynamoDB errors
  - Tag tests with @Tags(['requires-dynamodb-local'])
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 4.3, 8.2_

- [x] 14. Create comprehensive examples
  - Create basic_crud_example.dart demonstrating simple CRUD operations
  - Create custom_interface_example.dart showing custom repository methods
  - Create local_development_example.dart showing DynamoDB Local setup
  - Create table_creation_example.dart demonstrating table creation utilities
  - Create error_handling_example.dart showing exception handling patterns
  - Add README.md to example directory explaining how to run examples
  - _Requirements: 7.2, 7.3, 7.4_

- [x] 15. Write comprehensive documentation
  - Complete README.md with overview, features, installation, quick start
  - Add API documentation section to README
  - Add troubleshooting section to README
  - Add AWS DocumentDB compatibility notes (if applicable)
  - Add connection lifecycle best practices
  - Add error handling patterns documentation
  - Add extensibility patterns documentation
  - Write doc comments for all public classes and methods
  - _Requirements: 7.1, 7.5_

- [x] 16. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 17. Update workspace configuration
  - Add dddart_repository_dynamodb to root pubspec.yaml workspace list
  - Add dddart_repository_dynamodb to .github/workflows/test.yml matrix
  - Add dddart_repository_dynamodb to scripts/test-all.sh PACKAGES array
  - _Requirements: 9.1, 9.2_
