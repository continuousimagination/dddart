# Testing Guide

## Running Tests

### All Tests

Run all tests (no external dependencies required):

```bash
dart test
```

SQLite tests use in-memory databases, so no external service is needed.

## Test Categories

### Unit Tests
- **generator_test.dart**: Tests code generation logic for repository classes
- **validation_error_test.dart**: Tests for validation error handling

### Integration Tests
- **integration_test.dart**: Tests generated repositories with in-memory SQLite
  - Tests CRUD operations, transactions, custom queries, etc.
- **collection_integration_test.dart**: Tests collection support with in-memory SQLite
  - Tests primitive collections (List, Set, Map)
  - Tests value object collections
  - Tests entity collections
  - Tests nullable collections
  - Tests CASCADE DELETE behavior

### Property-Based Tests
- **collection_property_test.dart**: Property-based tests for collection round-trip preservation
  - Tests all collection types with random data
  - Validates data integrity across save/load cycles
  - Tests transaction rollback behavior
  - Tests empty and null collection handling

## Collection Tests

Collection tests verify comprehensive support for Dart collections in aggregate roots:

- **Primitive Collections**: `List<int>`, `Set<String>`, `Map<String, int>`, etc.
- **Value Object Collections**: `List<Money>`, `Set<Address>`, `Map<String, Money>`, etc.
- **Entity Collections**: `Set<Entity>`, `Map<String, Entity>`
- **Nullable Collections**: `List<int>?`, nullable elements `List<int?>`

These tests ensure:
- Correct schema generation with junction tables
- Round-trip preservation of data
- Proper ordering for lists
- Uniqueness for sets
- CASCADE DELETE behavior
- Transaction safety

## Test Configuration

The `dart_test.yaml` file configures:
- **Concurrency**: Tests run serially (`concurrency: 1`) to avoid SQLite database conflicts
- **Timeouts**: Property-based tests get 2x timeout for thorough testing

## CI/CD

### GitHub Actions

The GitHub Actions workflow automatically:
- Runs **all tests** for `dddart_repository_sqlite`
- No external services needed (uses in-memory SQLite)
- Tests run on every push and pull request

### Local Pre-Push Hook

The pre-push hook runs:
```bash
dart test
```

All tests run locally since SQLite is embedded and requires no setup.

## Advantages of SQLite for Testing

SQLite is ideal for testing because:
- **No setup required**: No external database to install or configure
- **Fast**: In-memory databases are extremely fast
- **Isolated**: Each test gets a fresh database
- **Portable**: Works on all platforms (macOS, Linux, Windows)
- **Deterministic**: No network issues or connection pooling concerns

## Collection Test Coverage

The collection tests provide comprehensive coverage:

1. **Schema Generation**: Verifies junction tables are created correctly
2. **Save Operations**: Tests insert and update of collection items
3. **Load Operations**: Tests reconstruction of collections from database
4. **Delete Operations**: Tests CASCADE DELETE removes collection items
5. **Empty Collections**: Tests handling of empty lists, sets, and maps
6. **Null Collections**: Tests nullable collection fields
7. **Large Collections**: Tests performance with 100+ items
8. **Multiple Aggregates**: Tests isolation between different aggregates
9. **Value Object Flattening**: Tests value objects are properly flattened into columns
10. **Entity Relationships**: Tests foreign key relationships for entity collections

## Property-Based Testing

Property-based tests use random data generation to verify correctness properties:

- **Property 1-8**: Round-trip preservation for all collection types
- **Property 9**: CASCADE DELETE behavior
- **Property 10**: Empty collection handling
- **Property 11**: Null collection handling
- **Property 12**: DateTime round-trip preservation
- **Property 13**: Boolean round-trip preservation

Each property runs 100+ iterations with randomly generated data to catch edge cases.

## Troubleshooting

### Test Failures

If tests fail:
1. Run `dart pub get` to ensure dependencies are up to date
2. Run `dart run build_runner build` if using generated code
3. Check for file descriptor limits (see below)

### "Too many open files" Error

SQLite can hit file descriptor limits on some systems. The test script automatically increases the limit, but you can also do it manually:

```bash
# macOS/Linux
ulimit -n 4096

# Then run tests
dart test
```

### Skipped Tests

Some tests may be skipped with a reason:
- **Nullable element deserialization bug**: Known issue with nullable collection elements
  - These tests document expected behavior
  - Will be enabled once the bug is fixed

### Performance

Collection tests may take longer than simple unit tests because they:
- Create multiple junction tables
- Insert many rows for large collections
- Test CASCADE DELETE behavior
- Run property-based tests with 100+ iterations

This is expected and ensures thorough testing of collection support.

## Comparing with MySQL

SQLite and MySQL implementations should behave identically for domain logic:
- Same collection types supported
- Same round-trip guarantees
- Same CASCADE DELETE behavior
- Same transaction semantics

Differences are only in:
- SQL syntax (SQLite vs MySQL dialects)
- Type mappings (TEXT vs DATETIME for timestamps)
- Connection setup (in-memory vs network)

The property-based tests verify this consistency by testing the same properties on both implementations.
