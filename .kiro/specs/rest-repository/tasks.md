# Implementation Plan

- [ ] 1. Set up project structure and core interfaces
  - Create package directory structure (lib/src/annotations, lib/src/connection, lib/src/generators)
  - Create main library export file (lib/dddart_repository_rest.dart)
  - Set up pubspec.yaml with dependencies
  - Create build.yaml for code generation configuration
  - Set up analysis_options.yaml with very_good_analysis
  - _Requirements: 1.1, 8.1, 8.2, 8.3_

- [ ] 2. Implement RestConnection class
  - Create RestConnection class with baseUrl, authProvider, and RestClient
  - Implement constructor that initializes RestClient
  - Implement client getter
  - Implement dispose() method
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_

- [ ] 2.1 Write unit tests for RestConnection
  - Test connection stores base URL correctly
  - Test connection with auth provider
  - Test connection without auth provider
  - Test dispose() closes HTTP client
  - Test multiple repositories share connection
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_

- [ ] 3. Implement GenerateRestRepository annotation
  - Create annotation class with resourcePath and implements parameters
  - Add documentation for annotation parameters
  - _Requirements: 1.2, 1.3, 1.4, 1.5_

- [ ] 4. Implement RestRepositoryGenerator
  - Create generator class extending GeneratorForAnnotation
  - Implement element validation (ClassElement, extends AggregateRoot, has @Serializable)
  - Implement annotation parameter extraction (resourcePath, implements)
  - Implement resource path generation from class name
  - Implement interface analysis to determine concrete vs abstract base class
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 8.1, 8.2, 8.3_

- [ ] 4.1 Write unit tests for generator validation
  - Test non-class element fails with clear error
  - Test class not extending AggregateRoot fails with clear error
  - Test class without @Serializable fails with clear error
  - Test valid class passes validation
  - _Requirements: 8.1, 8.2, 8.3_

- [ ] 4.2 Write property test for code generation
  - **Property 1: Code generation produces valid Dart code**
  - **Validates: Requirements 1.1**

- [ ] 4.3 Write property test for resource path configuration
  - **Property 2: Resource path configuration is respected**
  - **Validates: Requirements 1.2**

- [ ] 4.4 Write property test for resource path generation
  - **Property 3: Resource path generation follows naming convention**
  - **Validates: Requirements 1.3**

- [ ] 4.5 Write property test for custom interface handling
  - **Property 4: Custom interface determines class type**
  - **Validates: Requirements 1.4, 1.5**

- [ ] 5. Generate concrete repository class
  - Generate class declaration implementing Repository<T>
  - Generate constructor accepting RestConnection
  - Generate fields: _connection, _serializer, _resourcePath getter
  - Generate getById() method with HTTP GET request
  - Generate save() method with HTTP PUT request
  - Generate deleteById() method with HTTP DELETE request
  - Generate _mapHttpException() helper method
  - _Requirements: 2.1, 2.2, 2.3, 2.5, 4.1, 4.2, 4.3, 4.4, 4.5_

- [ ] 5.1 Write unit tests for error mapping
  - Test 404 maps to notFound
  - Test 409 maps to duplicate
  - Test 408/504 map to timeout
  - Test 5xx maps to connection
  - Test network errors map to connection
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5_

- [ ] 5.2 Write property test for HTTP status code mapping
  - **Property 8: HTTP status codes map to correct exception types**
  - **Validates: Requirements 4.1, 4.2, 4.3, 4.4**

- [ ] 6. Generate abstract base repository class
  - Generate abstract class declaration implementing custom interface
  - Generate constructor accepting RestConnection
  - Generate fields: _connection, _serializer, _resourcePath getter
  - Generate concrete implementations of getById(), save(), deleteById()
  - Generate _mapHttpException() helper method
  - Generate abstract method declarations for custom interface methods
  - _Requirements: 6.1, 6.2, 6.3, 6.5_

- [ ] 6.1 Write property test for custom interface methods
  - **Property 12: Custom interface methods are abstract**
  - **Validates: Requirements 6.1**

- [ ] 6.2 Write unit test for protected members
  - **Property 13: Protected members are accessible in subclasses**
  - **Validates: Requirements 6.3, 6.5**

- [ ] 7. Create test models and helpers
  - Create User aggregate with @Serializable and @GenerateRestRepository
  - Run build_runner to generate serializers and repositories
  - Create test helper functions for random data generation
  - Create test server factory function
  - _Requirements: 11.1, 11.2, 12.1_

- [ ] 8. Implement integration test infrastructure
  - Create test server using dddart_rest with in-memory repository
  - Set up server start/stop in setUp/tearDown
  - Create RestConnection pointing to test server
  - Create repository instance using test connection
  - _Requirements: 11.1, 11.2, 11.4_

- [ ] 9. Write integration tests for CRUD operations
  - Test save() stores aggregate on server
  - Test getById() retrieves aggregate from server
  - Test deleteById() removes aggregate from server
  - Test getById() on non-existent ID throws notFound
  - _Requirements: 2.1, 2.2, 2.3, 2.5, 11.2, 11.3_

- [ ] 9.1 Write property test for CRUD round-trip
  - **Property 5: CRUD operations round-trip correctly**
  - **Validates: Requirements 2.1, 2.2**

- [ ] 9.2 Write property test for delete operation
  - **Property 6: Delete removes aggregates**
  - **Validates: Requirements 2.3**

- [ ] 9.3 Write property test for serialization
  - **Property 7: Serialization uses dddart_json serializers**
  - **Validates: Requirements 3.1, 3.2, 3.3**

- [ ] 9.4 Write property test for connection configuration
  - **Property 9: Connection configuration is used consistently**
  - **Validates: Requirements 5.1**

- [ ] 9.5 Write property test for authentication
  - **Property 10: Authentication is applied when configured**
  - **Validates: Requirements 5.2, 7.2**

- [ ] 9.6 Write property test for connection sharing
  - **Property 11: Multiple repositories share connection state**
  - **Validates: Requirements 5.5**

- [ ] 9.7 Write property test for integration round-trip
  - **Property 14: Integration test round-trip preserves data**
  - **Validates: Requirements 11.3**

- [ ] 10. Write integration tests with authentication
  - Set up test server with JWT authentication
  - Create mock AuthProvider for testing
  - Test authenticated requests succeed
  - Test unauthenticated requests fail
  - Test token refresh scenario
  - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 11.5_

- [ ] 11. Write integration tests for custom repositories
  - Create custom repository interface with query methods
  - Implement custom repository extending generated base
  - Test custom query methods work end-to-end
  - Verify protected members are accessible
  - _Requirements: 6.1, 6.3, 6.4, 6.5_

- [ ] 12. Create comprehensive examples
  - Create basic_crud_example.dart with simple CRUD operations
  - Create authentication_example.dart with auth provider setup
  - Create custom_repository_example.dart with custom query methods
  - Create error_handling_example.dart with error handling patterns
  - Add README.md to example directory explaining how to run examples
  - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5, 13.4, 13.5, 13.6, 13.7_

- [ ] 13. Write comprehensive README documentation
  - Write overview and features section
  - Write installation instructions
  - Write quick start guide with annotation, generation, and usage
  - Document RestConnection configuration with and without authentication
  - Document annotation parameters (resourcePath, implements)
  - Document custom repository interface pattern
  - Document error handling patterns and exception types
  - Document best practices for connection lifecycle
  - Add API reference section
  - Add troubleshooting section
  - _Requirements: 9.1, 9.2, 9.3, 9.4, 13.1, 13.2, 13.3, 13.8_

- [ ] 14. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 15. Update workspace configuration
  - Add dddart_repository_rest to root pubspec.yaml workspace list
  - Add dddart_repository_rest to .github/workflows/test.yml matrix
  - Add dddart_repository_rest to scripts/test-all.sh PACKAGES array
  - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5_

- [ ] 16. Create CHANGELOG and LICENSE
  - Create CHANGELOG.md with initial 0.1.0 release notes
  - Copy LICENSE file (MIT) from other packages
  - _Requirements: 13.1_

- [ ] 17. Final verification
  - Run dart pub get from workspace root
  - Run dart analyze on package
  - Run dart format on package
  - Run all tests with dart test
  - Run ./scripts/test-all.sh to verify CI/CD compatibility
  - Verify examples run successfully
  - _Requirements: All_
