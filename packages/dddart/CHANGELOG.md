# Changelog

> Historical record; it may describe retired APIs. For current usage, start at
> [the documentation index](../../docs/README.md).

## Unreleased

- Export the portable conditional repository capability with concrete aggregate
  identity types, atomic mutation requests, revision tokens and durable receipts.


All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.9.0] - Unreleased

### Changed

- **BREAKING:** `Entity<I>`, `AggregateRoot<I>`, repositories and event aggregate
  references carry the concrete `I extends Identity`. General entity creation
  requires its actual identity; repository lookup/deletion reject unrelated IDs.
- `UuidValue` is the stock Identity implementation. UUID models use
  `Entity<UuidValue>` and `AggregateRoot<UuidValue>` with an explicit ID, just
  like other identity types. Domain constructors can call `UuidValue.generate()`.
- **BREAKING:** Removed the UUID-specific entity and aggregate convenience bases.
- **BREAKING:** Removed `QueryableRepository<T>`. `Repository<T, I>` remains a
  CRUD-only contract; applications should define domain-specific read methods
  when they need collection access.
- `InMemoryRepository<T, I>.getAll()` and `getAllSync()` remain concrete,
  unmodifiable conveniences for tests and prototypes.

### Added
- Captured pending-event batches with selective acknowledgment that preserves
  events raised during asynchronous saves.
- Optional repository event publication through `EventPublisher`,
  `saveWithEvents`, `EventPublishingRepository` and the InMemory publisher hook.
- `EventBus.deliver` and `onPublished` distinguish remote receipt from local
  origination; the bus exposes an injectable named logger.
- Initial project structure
- Entity base class with explicit identity and automatic timestamp generation
- AggregateRoot base class extending Entity
- Value base class for immutable value objects
- Comprehensive unit tests for all base classes

## [0.1.0] - 2024-11-01

### Added
- Initial release of DDDart
- Basic project structure and configuration
