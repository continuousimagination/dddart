# MySQL Repository Tests

This directory contains comprehensive tests for the `dddart_repository_mysql` package.

## Test Categories

The test suite is organized into three main categories:

### 1. Unit Tests

Unit tests validate components in isolation without requiring a database connection.

**Files:**
- `generator_property_test.dart` - Code generator validation
- `schema_generation_property_test.dart` - Schema generation validation
- `sql_generation_property_test.dart` - SQL syntax generation validation
- `dialect_property_test.dart` - MySQL dialect validation
- `type_conversion_property_test.dart` - Type conversion validation
- `code_structure_property_test.dart` - Generated code structure validation
- `abstract_base_class_property_test.dart` - Custom repository base class validation

**Running unit tests:**
```bash
# Run all unit tests (no database required)
dart test --exclude-tags=integration

# Run specific unit test
dart test test/generator_property_test.dart
```

### 2. Integration Tests

Integration tests validate end-to-end functionality with a real MySQL database.

**Files:**
- `repository_integration_test.dart` - Full CRUD operations
- `collection_roundtrip_property_test.dart` - Set/List serialization
- `datatype_roundtrip_property_test.dart` - Data type preservation
- `object_graph_property_test.dart` - Relationship loading
- `connection_property_test.dart` - Connection lifecycle
- `transaction_commit_property_test.dart` - Transaction commit behavior
- `transaction_rollback_property_test.dart` - Transaction rollback behavior
- `nested_transaction_property_test.dart` - Nested transaction handling
- `custom_query_transaction_property_test.dart` - Custom queries in transactions

**Running integration tests:**
```bash
# Run all integration tests (requires MySQL)
dart test --tags=integration

# Run specific integration test
dart test test/repository_integration_test.dart
```


### 3. Property-Based Tests

Property-based tests validate universal properties across many generated inputs.

**Files:**
- All files ending in `_property_test.dart`
- Each test runs 100+ iterations with random data
- Tests validate correctness properties from the design document

**Running property tests:**
```bash
# Run all property tests
dart test --tags=property-test

# Run specific property test
dart test test/collection_roundtrip_property_test.dart
```

## Prerequisites

### MySQL Server

Integration tests require a running MySQL instance:

**Requirements:**
- MySQL 5.7+ (MySQL 8.0+ recommended)
- Database: `test_db`
- User: `test_user` with password `test_password`
- Host: `localhost`
- Port: `3307` (to avoid conflicts with local MySQL on 3306)

### Quick Setup with Docker

The easiest way to run tests is using Docker:

```bash
# Start MySQL 8.0 container for testing
docker run --name mysql-test \
  -e MYSQL_ROOT_PASSWORD=test_password \
  -e MYSQL_DATABASE=test_db \
  -e MYSQL_USER=test_user \
  -e MYSQL_PASSWORD=test_password \
  -p 3307:3306 \
  -d mysql:8.0

# Wait for MySQL to be ready (about 30 seconds)
docker logs -f mysql-test

# When you see "ready for connections", press Ctrl+C

# Run tests
dart test

# Stop and remove container when done
docker stop mysql-test
docker rm mysql-test
```

### Alternative: Local MySQL

If you have MySQL installed locally:

```sql
-- Create test database and user
CREATE DATABASE test_db;
CREATE USER 'test_user'@'localhost' IDENTIFIED BY 'test_password';
GRANT ALL PRIVILEGES ON test_db.* TO 'test_user'@'localhost';
FLUSH PRIVILEGES;
```

**Note:** You may need to update `test_helpers.dart` to use port 3306 instead of 3307.


## Running Tests

### Run All Tests

```bash
# From package directory
cd packages/dddart_repository_mysql
dart test

# From workspace root
cd packages/dddart_repository_mysql && dart test
```

### Run Specific Test Categories

```bash
# Unit tests only (no database required)
dart test --exclude-tags=integration

# Integration tests only (requires MySQL)
dart test --tags=integration

# Property tests only
dart test --tags=property-test
```

### Run Specific Test Files

```bash
# Single test file
dart test test/repository_integration_test.dart

# Multiple test files
dart test test/collection_roundtrip_property_test.dart test/datatype_roundtrip_property_test.dart
```

### Run with Coverage

```bash
# Generate coverage report
dart test --coverage=coverage

# Convert to LCOV format
dart pub global activate coverage
dart pub global run coverage:format_coverage \
  --lcov \
  --in=coverage \
  --out=coverage/lcov.info \
  --packages=.dart_tool/package_config.json \
  --report-on=lib

# View coverage (requires lcov tools)
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

## Test Configuration

### Test Tags

Tests are tagged for selective execution:

- `integration` - Requires MySQL database
- `property-test` - Property-based tests
- No tag - Unit tests (no database required)

### Test Helpers

The `test_helpers.dart` file provides utilities for integration tests:

**Key functions:**
- `createTestConnection()` - Creates a connection to test database
- `cleanupTestData()` - Cleans up test data after tests
- `withTestConnection()` - Runs a test with automatic cleanup

**Example usage:**
```dart
test('should save and retrieve order', () async {
  await withTestConnection((connection) async {
    final repo = OrderMysqlRepository(connection);
    await repo.createTables();
    
    final order = Order(/* ... */);
    await repo.save(order);
    
    final retrieved = await repo.getById(order.id);
    expect(retrieved.id, equals(order.id));
  });
});
```


## Test Models

The test suite uses domain models defined in `test/integration_test_models.dart`:

**Aggregate Roots:**
- `TestOrder` - Order with items and addresses
- `TestProduct` - Product with categories

**Entities:**
- `TestOrderItem` - Line item in an order
- `TestCategory` - Product category

**Value Objects:**
- `TestMoney` - Monetary amount with currency
- `TestAddress` - Physical address

These models are annotated with `@Serializable()` and `@GenerateMysqlRepository()` to generate test repositories.

## Troubleshooting

### Connection Refused

**Problem:** Tests fail with "Connection refused" error.

**Solutions:**
1. Verify MySQL is running:
   ```bash
   docker ps | grep mysql-test
   ```

2. Check MySQL logs:
   ```bash
   docker logs mysql-test
   ```

3. Verify port 3307 is available:
   ```bash
   lsof -i :3307
   ```

4. Restart MySQL container:
   ```bash
   docker restart mysql-test
   ```

### Authentication Failed

**Problem:** Tests fail with "Access denied" error.

**Solutions:**
1. Verify credentials in `test_helpers.dart` match your MySQL setup

2. For MySQL 8.0, ensure user is created correctly:
   ```sql
   CREATE USER 'test_user'@'%' IDENTIFIED BY 'test_password';
   GRANT ALL PRIVILEGES ON test_db.* TO 'test_user'@'%';
   FLUSH PRIVILEGES;
   ```

3. No need for `mysql_native_password` workaround - version 2.0 supports MySQL 8.0 default authentication

### Packets Out of Order

**Problem:** Tests fail with "packets out of order" error.

**Solutions:**
1. This was a known issue with mysql1 driver - should be fixed in version 2.0 with mysql_client

2. If you still see this error:
   - Verify you're using version 2.0+
   - Check that MySQL server is not overloaded
   - Try reducing concurrent test execution

### Table Already Exists

**Problem:** Tests fail with "table already exists" error.

**Solutions:**
1. Tests use `CREATE TABLE IF NOT EXISTS`, so this shouldn't happen

2. If it does, clean up the test database:
   ```sql
   DROP DATABASE test_db;
   CREATE DATABASE test_db;
   ```

3. Or use Docker to start fresh:
   ```bash
   docker stop mysql-test
   docker rm mysql-test
   # Then start a new container
   ```


### Type Cast Errors

**Problem:** Tests fail with type cast errors (e.g., `List<dynamic>` to `Set<String>`).

**Solutions:**
1. This was a known issue with collection deserialization - should be fixed in version 2.0

2. If you still see this error:
   - Verify you're using version 2.0+
   - Check that generated code is up to date: `dart run build_runner build`
   - Review the specific test failure for details

### Slow Tests

**Problem:** Tests take a long time to run.

**Solutions:**
1. Run only unit tests (fast, no database):
   ```bash
   dart test --exclude-tags=integration
   ```

2. Run specific test files instead of the entire suite

3. Use a local MySQL instance instead of Docker for faster I/O

4. Increase MySQL connection pool size in test helpers

### Code Generation Errors

**Problem:** Tests fail with "part of" or missing generated code errors.

**Solutions:**
1. Clean and regenerate code:
   ```bash
   dart run build_runner clean
   dart run build_runner build --delete-conflicting-outputs
   ```

2. Verify all test models have required annotations:
   - `@Serializable()` for JSON serialization
   - `@GenerateMysqlRepository()` for repository generation

3. Check for syntax errors in test model files

## Continuous Integration

### GitHub Actions

The package includes a GitHub Actions workflow (`.github/workflows/test.yml`) that:

1. Starts a MySQL 8.0 service container
2. Runs all tests (unit + integration + property)
3. Verifies code formatting and analysis
4. Runs on every pull request and push to main

### Local Pre-Push Hook

A pre-push git hook automatically runs tests before pushing:

**Setup:**
```bash
# From workspace root
./scripts/setup-hooks.sh
```

**What it checks:**
- Code formatting (`dart format --set-exit-if-changed`)
- Static analysis (`dart analyze --fatal-infos`)
- All tests (excluding `requires-mongo` tag)

**Skip if needed:**
```bash
git push --no-verify
```


## Test Metrics

### Current Test Count

As of version 2.0.0:

- **Unit Tests:** 71 tests
- **Integration Tests:** 55 tests
- **Property Tests:** Included in above counts (100+ iterations each)
- **Total:** 126+ tests

### Expected Test Results

All tests should pass with MySQL 8.0:

```
✓ All 126+ tests passed
✓ No SocketException errors
✓ No "packets out of order" errors
✓ No type cast errors
✓ No authentication errors
```

### Test Coverage

The test suite provides comprehensive coverage:

- ✅ CRUD operations (create, read, update, delete)
- ✅ Collection serialization (Set, List)
- ✅ Data type preservation (String, int, double, bool, DateTime, UUID)
- ✅ Object graph loading (relationships, foreign keys)
- ✅ Transaction handling (commit, rollback, nested)
- ✅ Error handling (not found, connection, timeout, duplicate)
- ✅ Connection lifecycle (open, close, state)
- ✅ Concurrent operations
- ✅ Schema generation
- ✅ SQL generation
- ✅ Type conversion

## Contributing

When adding new tests:

1. **Follow naming conventions:**
   - Unit tests: `*_test.dart`
   - Property tests: `*_property_test.dart`
   - Integration tests: Tag with `@Tags(['integration'])`

2. **Use appropriate tags:**
   ```dart
   @Tags(['integration'])
   void main() {
     // Integration test
   }
   ```

3. **Clean up after tests:**
   ```dart
   tearDown(() async {
     await cleanupTestData(connection);
   });
   ```

4. **Document test purpose:**
   ```dart
   test('should preserve Set collections in round-trip', () async {
     // Test implementation
   });
   ```

5. **Reference design properties:**
   ```dart
   // Feature: mysql-driver-migration, Property 1: Collection round-trip preservation
   test('should preserve collections', () async {
     // Test implementation
   });
   ```

## Additional Resources

- [Package README](../README.md) - Main documentation
- [Design Document](../.kiro/specs/mysql-driver-migration/design.md) - Architecture and design decisions
- [CHANGELOG](../CHANGELOG.md) - Version history and migration guides
- [Examples](../example/README.md) - Usage examples

## Support

For test-related issues:

1. Check this README for troubleshooting steps
2. Review test output for specific error messages
3. Check MySQL logs: `docker logs mysql-test`
4. Verify MySQL version: `SELECT VERSION();`
5. Open an issue on GitHub with test output and environment details
