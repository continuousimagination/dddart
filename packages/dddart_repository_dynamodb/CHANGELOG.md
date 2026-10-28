# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - Unreleased

### Changed
- **Breaking identity API:** generated repositories implement `Repository<T, I>`
  and accept an optional named `identityCodecs` registry shared with JSON.
- Native/scoped keys use explicit canonical codecs, validated as 1–2048 UTF-8
  bytes before I/O. Add `fromItem` to restore structural identity in custom reads.
- UUID consumers migrate to `UuidAggregateRoot`; existing UUID key text remains.
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
