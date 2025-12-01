# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.9.0] - 2025-01-XX

### Added

- Initial release of base SQL repository abstractions
- `SqlConnection` abstract interface for database connections
- `SqlDialect` abstract interface for database-specific SQL syntax
- `TableDefinition` model for SQL table schemas
- `RelationshipAnalyzer` for discovering aggregate object graphs
- `SchemaGenerator` for generating CREATE TABLE statements
- `TypeMapper` for Dart to SQL type conversion
- `ObjectMapper` for object-relational mapping
- `JoinBuilder` for generating SELECT queries with JOINs
- Support for full normalization with one table per class
- Value object embedding with prefixed columns
- Foreign key generation with CASCADE DELETE for aggregate boundaries
- Transaction support abstractions
