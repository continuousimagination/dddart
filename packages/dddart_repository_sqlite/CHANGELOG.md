# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

### Changed

- Breaking: generated Repository<T, I> lookup/deletion and collection parents
  use the concrete identity. Constructors accept shared identityCodecs.
- Native/scoped IDs and identity collections use exact canonical UTF-8 BLOBs,
  with typed field/JSON path metadata instead of UUID/name heuristics.
- UUID keys now preserve their exact text case; migrate/recreate 16-byte schemas.
- Preserve named/generic custom method signatures, include null identity fields
  in persistence updates, and reject malformed keys without persisted changes.
- Migrate the illustrative order item to the public serializable entity API.

## [0.9.0] - 2025-12-01

### Added

- Initial release of dddart_repository_sqlite
- SQLite repository code generation for DDDart aggregate roots
- Full normalization with multi-table persistence
- Value object embedding with prefixed columns
- Automatic schema generation from aggregate roots
- Foreign key relationships with cascade delete support
- Transaction support for atomic operations
- CRUD operations (getById, save, deleteById)
- Custom repository interface support
- SqliteConnection for database lifecycle management
- SqliteDialect for SQLite-specific SQL generation
- Support for iOS, Android, Windows, macOS, Linux, and Web platforms
