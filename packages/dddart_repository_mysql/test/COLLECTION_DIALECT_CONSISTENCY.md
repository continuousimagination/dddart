# Collection Dialect Consistency Testing

**Feature: sql-collection-support, Property 18: Dialect consistency**  
**Validates: Requirements 13.1-13.7**

## Overview

This document describes how dialect consistency is validated for collection support between SQLite and MySQL repositories.

## Property Statement

*For any* aggregate root with collection fields, the same domain model should work identically in both SQLite and MySQL without code changes.

## Validation Approach

Dialect consistency is validated through:

1. **Parallel Test Suites**: Both `dddart_repository_sqlite` and `dddart_repository_mysql` have equivalent property-based tests for collections
2. **Identical Test Models**: The same test aggregates with collections are used in both packages
3. **Equivalent Test Logic**: The same test scenarios are run against both dialects
4. **Manual Verification**: Results from both test suites are compared to ensure identical behavior

## Test Coverage

The following collection types are tested in both dialects:

### Primitive Collections
- `List<int>` - ordered list of integers
- `Set<String>` - unique set of strings  
- `Map<String, int>` - key-value map with string keys and integer values

### Value Object Collections
- `List<Money>` - ordered list of value objects
- `Set<Address>` - unique set of value objects
- `Map<String, Money>` - map with value object values

### Entity Collections
- `Set<CartItem>` - unique set of entities
- `Map<String, CartItem>` - map with entity values

### Special Cases
- Empty collections
- DateTime field handling
- Boolean field handling
- Null collection handling

## Requirements Validated

### 13.1: SQLite Collection Support
All collection types work with SQLite-specific SQL syntax.

### 13.2: MySQL Collection Support
All collection types work with MySQL-specific SQL syntax.

### 13.3: SQLite UUID Type
SQLite uses BLOB type for UUIDs in collection tables.

### 13.4: MySQL UUID Type
MySQL uses BINARY(16) type for UUIDs in collection tables.

### 13.5: SQLite Boolean Type
SQLite uses INTEGER for booleans in collection tables.

### 13.6: MySQL Boolean Type
MySQL uses TINYINT for booleans in collection tables.

### 13.7: Domain Model Portability
The same domain model works without code changes when switching between SQLite and MySQL.

## Running Tests

### SQLite Tests
```bash
cd packages/dddart_repository_sqlite
dart test test/collection_property_test.dart
```

### MySQL Tests
```bash
cd packages/dddart_repository_mysql
dart test test/repository_integration_test.dart --tags=collections
```

## Verification Checklist

- [ ] All SQLite collection tests pass
- [ ] All MySQL collection tests pass
- [ ] Test models are identical in both packages
- [ ] Test scenarios cover the same cases
- [ ] Generated code structure is consistent
- [ ] Schema generation produces equivalent tables
- [ ] Save operations work identically
- [ ] Load operations work identically
- [ ] Delete operations cascade correctly
- [ ] Empty collections handled identically
- [ ] DateTime encoding/decoding matches
- [ ] Boolean encoding/decoding matches

## Implementation Notes

### Code Generation
Both generators produce equivalent code structure:
- `_saveCollection` methods for each collection field
- `_loadCollection` methods for each collection field
- Junction table creation in `createTables()`
- Collection loading in `getById()`
- Collection saving in `save()`

### Type Mapping
Both dialects use appropriate native types:
- DateTime: TEXT (SQLite) vs DATETIME (MySQL)
- Boolean: INTEGER (SQLite) vs TINYINT(1) (MySQL)
- UUID: BLOB (SQLite) vs BINARY(16) (MySQL)

### SQL Syntax
Dialect-specific SQL is handled by the dialect classes:
- SQLite: `INSERT OR REPLACE`
- MySQL: `INSERT ... ON DUPLICATE KEY UPDATE`

## Conclusion

Dialect consistency is achieved through:
1. Shared base package (`dddart_repository_sql`) with common logic
2. Dialect-specific implementations in generator classes
3. Comprehensive parallel test suites
4. Consistent code generation patterns

This ensures that developers can switch between SQLite and MySQL without modifying their domain models or repository interfaces.
