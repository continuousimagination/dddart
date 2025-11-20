# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.9.0] - 2025-01-XX

### Added

#### Core Features

- Initial release of `dddart_repository_mongodb` - MongoDB persistence for DDDart aggregate roots
- Code generation pattern following `dddart_json` conventions for zero-boilerplate repository implementations
- Full integration with existing `dddart_json` serialization - no duplicate serialization logic required
- Support for MongoDB 4.0+ and AWS DocumentDB Serverless

#### Annotations

- `@GenerateMongoRepository()` annotation for marking aggregate roots for repository generation
  - `collectionName` parameter for custom collection names (defaults to snake_case of class name)
  - `implements` parameter for custom repository interfaces

#### Code Generation

- Intelligent code generator that analyzes interfaces and generates appropriate implementations:
  - Concrete classes (`{ClassName}MongoRepository`) for simple CRUD scenarios
  - Abstract base classes (`{ClassName}MongoRepositoryBase`) when custom methods are present
- Automatic validation of annotated classes (must extend `AggregateRoot` and have `@Serializable()`)
- Generated repositories implement all `Repository<T>` methods: `getById`, `save`, `deleteById`
- Exposes protected members (`_database`, `_collection`, `_serializer`, `collectionName`) for extensibility

#### Connection Management

- `MongoConnection` class for managing MongoDB database connections
- Constructor-based configuration with parameters: host, port, database, credentials, TLS options
- `MongoConnection.fromUri()` factory for connection string URIs
- Connection lifecycle methods: `open()`, `close()`, `isConnected`
- Connection pooling handled automatically by `mongo_dart`
- Support for AWS DocumentDB with TLS configuration

#### Repository Operations

- **`getById(UuidValue id)`**: Retrieve aggregate by ID with automatic ID field mapping
- **`save(T aggregate)`**: Upsert operation (insert or update) using MongoDB's `replaceOne` with `upsert: true`
- **`deleteById(UuidValue id)`**: Delete aggregate by ID with verification of affected documents
- Automatic ID field mapping between DDDart's `id` field and MongoDB's `_id` field
- BSON document serialization using existing `JsonSerializer` from `dddart_json`

#### Error Handling

- Comprehensive MongoDB exception mapping to `RepositoryException` types:
  - `notFound`: Document doesn't exist (0 documents affected)
  - `duplicate`: Duplicate key errors (E11000)
  - `connection`: Network or authentication failures
  - `timeout`: Operation timeout errors
  - `unknown`: Unexpected errors with full error details
- All exceptions include original error message and stack trace for debugging

#### Extensibility

- Custom repository interface pattern for domain-specific query methods
- Generated abstract base classes when custom methods are detected
- Access to MongoDB internals (`_database`, `_collection`) for custom queries
- Support for multiple repository implementations (MongoDB, REST, in-memory) via interfaces
- Repository swapping pattern for testing and different environments

#### Documentation & Examples

- Comprehensive README with installation, quick start, and advanced patterns
- Connection lifecycle best practices documentation
- Error handling patterns and examples
- AWS DocumentDB configuration guide
- Example directory with runnable demonstrations:
  - Basic CRUD operations
  - Custom repository interfaces
  - Error handling patterns
  - Integration with `dddart_config`
  - Repository swapping for testing

#### Testing

- Connection management tests
- Generator validation tests
- Integration tests for repository operations

### Dependencies

- `dddart`: ^0.9.0 - Core DDD framework
- `dddart_serialization`: ^0.9.0 - Serialization framework
- `dddart_json`: ^0.9.0 - JSON serialization implementation
- `mongo_dart`: ^0.10.0 - MongoDB driver for Dart
- `build`: ^2.4.0 - Build system
- `source_gen`: ^1.4.0 - Code generation utilities
- `analyzer`: ^6.0.0 - Dart code analysis
