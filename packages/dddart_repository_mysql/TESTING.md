# Testing Guide

## Running Tests

### All Unit Tests (Recommended)

Run all tests excluding MySQL integration tests:

```bash
dart test --exclude-tags=requires-mysql
```

### Integration Tests (Requires MySQL)

Integration tests (including collection support tests) require a MySQL instance running on `localhost:3307`.

To run integration tests only:

```bash
dart test --tags=requires-mysql
```

To run all tests including integration tests:

```bash
dart test
```

## Test Categories

### Unit Tests
- **connection_property_test.dart**: Property-based tests for MySQL connection
- **generator_property_test.dart**: Property-based tests for code generation
- **dialect_property_test.dart**: Tests for MySQL-specific SQL dialect
- **schema_generation_property_test.dart**: Tests for schema generation
- **validation_error_test.dart**: Tests for validation error handling

### Integration Tests
- **repository_integration_test.dart**: Tests generated repositories against real MySQL
  - Tagged with `requires-mysql`
  - Automatically skipped when MySQL is not available
  - Tests CRUD operations, transactions, custom queries, etc.
- **collection_integration_test.dart**: Tests collection support against real MySQL
  - Tagged with `requires-mysql` and `integration`
  - Tests primitive collections (List, Set, Map)
  - Tests value object collections
  - Tests entity collections
  - Tests nullable collections
  - Tests CASCADE DELETE behavior

### Property-Based Tests
- **collection_property_test.dart**: Property-based tests for collection round-trip preservation
  - Tests all collection types with random data
  - Validates dialect consistency between SQLite and MySQL
  - Tests transaction rollback behavior

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

## Environment Variables

MySQL connection settings can be configured via environment variables:

- `MYSQL_HOST` (default: localhost)
- `MYSQL_PORT` (default: 3307)
- `MYSQL_USER` (default: root)
- `MYSQL_PASSWORD` (default: test_password)
- `MYSQL_DATABASE` (default: test_db)

Example:
```bash
MYSQL_PORT=3306 dart test --tags=requires-mysql
```

## Starting MySQL for Testing

### Using Docker (Recommended)

```bash
docker run -d \
  --name mysql-test \
  -p 3307:3306 \
  -e MYSQL_ROOT_PASSWORD=test_password \
  -e MYSQL_DATABASE=test_db \
  mysql:8.0
```

To stop and remove:
```bash
docker stop mysql-test
docker rm mysql-test
```

### Using Homebrew (macOS)

```bash
brew install mysql
brew services start mysql

# Create test database
mysql -u root -e "CREATE DATABASE test_db;"
```

## CI/CD

### GitHub Actions

The GitHub Actions workflow automatically:
- Starts a MySQL service container on port 3307
- Sets environment variables for MySQL connection
- Runs **all tests** (including integration and collection tests) for `dddart_repository_mysql`
- Excludes MySQL tests for other packages

This ensures integration tests run in CI without requiring developers to have MySQL installed locally.

### Local Pre-Push Hook

The pre-push hook runs:
```bash
dart test --exclude-tags=requires-mysql
```

This allows fast local validation without requiring MySQL. Integration tests are verified in CI.

### Manual CI/CD Setup

For other CI systems, use a MySQL service container:

```yaml
# Example for GitHub Actions
services:
  mysql:
    image: mysql:8.0
    ports:
      - 3307:3306
    env:
      MYSQL_ROOT_PASSWORD: test_password
      MYSQL_DATABASE: test_db
    options: >-
      --health-cmd "mysqladmin ping -h localhost -ptest_password"
      --health-interval 10s
      --health-timeout 5s
      --health-retries 10
```

Then run:
```bash
# Run unit tests only (fast, no external dependencies)
dart test --exclude-tags=requires-mysql

# Run integration tests separately with MySQL service
dart test --tags=requires-mysql
```

## Troubleshooting

### MySQL Connection Errors

Integration tests will fail if MySQL is not running. This is expected behavior. The tests are tagged and can be excluded as shown above.

Common connection issues:
- **Port conflict**: Make sure port 3307 is not in use
- **Wrong credentials**: Verify MYSQL_PASSWORD matches your setup
- **Database not created**: Ensure test_db database exists

### Collection Test Failures

If collection tests fail:
1. Verify MySQL is running and accessible
2. Check that the test database is empty (tests create their own tables)
3. Ensure foreign key constraints are enabled (default in MySQL 8.0)
4. Check MySQL logs for constraint violations

### Performance Issues

Collection tests may be slower than unit tests because they:
- Create multiple junction tables
- Insert many rows for large collections
- Test CASCADE DELETE behavior

This is expected. Run with `--concurrency=1` if needed:
```bash
dart test --tags=requires-mysql --concurrency=1
```
