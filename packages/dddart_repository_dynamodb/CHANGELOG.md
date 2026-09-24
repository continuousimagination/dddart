# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - Unreleased

### Changed
- **Breaking:** Generated default DynamoDB repositories now implement
  `Repository<T>` and no longer expose an implicit `getAll()` backed by a
  full-table `Scan`.
- Explicit application read methods such as `getAll()` and `scanPage()` are
  emitted exactly once as abstract custom methods for the application to
  implement.

### Added
- Initial release
- Code generation for DynamoDB repositories
- `@GenerateDynamoRepository` annotation
- `DynamoConnection` for client lifecycle management
- AttributeValue conversion utilities
- Support for custom repository interfaces
- Table creation utilities (programmatic, CLI, CloudFormation)
- DynamoDB Local support
- Exception mapping to standard RepositoryException types
- Comprehensive documentation and examples
