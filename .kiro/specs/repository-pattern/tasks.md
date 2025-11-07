# Implementation Plan

- [x] 1. Create repository exception types
  - Create `packages/dddart/lib/src/repository_exception.dart` file
  - Define `RepositoryException` class with message, type, and optional cause fields
  - Define `RepositoryExceptionType` enum with values: notFound, duplicate, constraint, connection, timeout, unknown
  - Implement toString method for clear error messages
  - _Requirements: 6.1, 6.2, 6.3, 6.4_

- [x] 2. Create base Repository interface
  - Create `packages/dddart/lib/src/repository.dart` file
  - Define `Repository<T extends AggregateRoot>` as abstract interface class
  - Implement getById method signature that accepts UuidValue and returns Future<T>
  - Implement save method signature that accepts T and returns Future<void>
  - Implement deleteById method signature that accepts UuidValue and returns Future<void>
  - Add comprehensive documentation with examples and exception specifications
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 5.1, 5.2, 5.3, 5.4, 7.1, 7.2, 7.3, 7.4_

- [x] 3. Implement InMemoryRepository
  - Create `packages/dddart/lib/src/in_memory_repository.dart` file
  - Define `InMemoryRepository<T extends AggregateRoot>` class implementing Repository<T>
  - Add private `Map<UuidValue, T>` storage field
  - Implement getById to retrieve from map and throw RepositoryException if not found
  - Implement save to insert or update in map
  - Implement deleteById to remove from map and throw RepositoryException if not found
  - Add clear() utility method for test cleanup
  - Add getAll() utility method returning unmodifiable list
  - Add comprehensive documentation
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 5.5, 6.5_

- [x] 4. Update library exports
  - Update `packages/dddart/lib/dddart.dart` to export repository.dart
  - Update `packages/dddart/lib/dddart.dart` to export in_memory_repository.dart
  - Update `packages/dddart/lib/dddart.dart` to export repository_exception.dart
  - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5_

- [x] 5. Write repository tests
- [x] 5.1 Write tests for RepositoryException
  - Create `packages/dddart/test/repository_exception_test.dart` file
  - Test exception message formatting
  - Test exception with cause wrapping
  - Test toString output for different exception types
  - _Requirements: 6.1, 6.2, 6.3_

- [x] 5.2 Write tests for InMemoryRepository
  - Create `packages/dddart/test/in_memory_repository_test.dart` file
  - Create test aggregate class extending AggregateRoot
  - Test getById throws RepositoryException for non-existent ID
  - Test getById returns correct aggregate after save
  - Test save inserts new aggregate
  - Test save updates existing aggregate (upsert behavior)
  - Test deleteById removes aggregate successfully
  - Test deleteById throws RepositoryException for non-existent ID
  - Test clear removes all aggregates
  - Test getAll returns all stored aggregates
  - Test storage isolation between repository instances
  - Test type safety with multiple aggregate types
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 4.1, 4.2, 4.3, 4.4, 4.5, 5.5, 6.4, 6.5_

- [x] 6. Create usage documentation
  - Create example showing basic CRUD operations with InMemoryRepository
  - Create example showing custom repository interface definition
  - Create example showing custom repository implementation pattern
  - Create example showing error handling with try-catch
  - Create example showing integration with domain events
  - Add examples to API_REFERENCE.md or create REPOSITORY_GUIDE.md
  - _Requirements: 2.4_
