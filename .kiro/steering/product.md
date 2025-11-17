# DDDart Product Overview

DDDart is a lightweight Domain-Driven Design (DDD) framework for Dart that provides base classes and utilities for implementing DDD principles across all Dart platforms (server, web, mobile, desktop).

## Core Packages

- **dddart**: Core DDD framework with Entity, AggregateRoot, Value, DomainEvent, EventBus, and Repository abstractions
- **dddart_serialization**: Framework package providing serialization annotations and configuration
- **dddart_json**: JSON serialization code generation for aggregate roots and value objects
- **dddart_rest**: RESTful CRUD API framework providing REST endpoints with minimal boilerplate

## Key Features

- Event-driven architecture with local publish/subscribe
- Automatic GUID generation for entity IDs and event IDs
- Automatic timestamp management (createdAt, updatedAt, occurredAt)
- Type-safe event distribution system
- Repository pattern with in-memory implementation
- Code generation for JSON serialization (no reflection)
- RESTful CRUD endpoints with content negotiation
- RFC 7807 error responses

## Design Philosophy

- Keep domain objects as Plain Old Dart Objects (PODOs)
- Enforce proper DDD patterns (only AggregateRoots and Values are directly serializable)
- No reflection or runtime type discovery
- Platform-independent using only Dart core libraries
- Minimal boilerplate through code generation
