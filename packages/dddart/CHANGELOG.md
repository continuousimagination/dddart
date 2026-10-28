# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.9.0] - Unreleased

### Changed

- **BREAKING:** `Entity<I>`, `AggregateRoot<I>`, repositories and event aggregate
  references carry the concrete `I extends Identity`. General entity creation
  requires its actual identity; repository lookup/deletion reject unrelated IDs.
- `UuidValue` is the stock Identity implementation. `UuidEntity` and
  `UuidAggregateRoot` preserve optional UUID generation without coercing custom IDs.
- **BREAKING:** Removed `QueryableRepository<T>`. `Repository<T, I>` remains a
  CRUD-only contract; applications should define domain-specific read methods
  when they need collection access.
- `InMemoryRepository<T, I>.getAll()` and `getAllSync()` remain concrete,
  unmodifiable conveniences for tests and prototypes.

### Added
- Initial project structure
- Entity base class with automatic ID and timestamp generation
- AggregateRoot base class extending Entity
- Value base class for immutable value objects
- Comprehensive unit tests for all base classes

## [0.1.0] - 2024-11-01

### Added
- Initial release of DDDart
- Basic project structure and configuration
