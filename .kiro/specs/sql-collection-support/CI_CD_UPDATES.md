# CI/CD Configuration Updates for Collection Support

This document summarizes the CI/CD configuration updates made to support collection testing in both SQLite and MySQL repositories.

## Changes Made

### 1. GitHub Actions Workflow (.github/workflows/test.yml)

#### MySQL Service Configuration
- **Already configured**: MySQL 8.0 service container on port 3307
- **Added comment**: Documented that MySQL is used for collection integration tests
- **Environment variables**: Added MySQL connection settings to test execution step
  - `MYSQL_HOST: 127.0.0.1`
  - `MYSQL_PORT: 3307`
  - `MYSQL_USER: root`
  - `MYSQL_PASSWORD: test_password`
  - `MYSQL_DATABASE: test_db`

#### Test Execution
- **Collection tests included**: MySQL collection integration tests (tagged with `requires-mysql`) run automatically in CI
- **SQLite tests included**: All SQLite tests run automatically (no external service needed)
- **Comment added**: Clarified that collection tests are included in CI test runs

### 2. Local Test Script (scripts/test-all.sh)

#### Header Documentation
- **Added usage notes**: Documented which tests are excluded locally
- **Added instructions**: How to run MySQL collection tests locally
  ```bash
  docker run -d -p 3307:3306 -e MYSQL_ROOT_PASSWORD=test_password -e MYSQL_DATABASE=test_db mysql:8.0
  cd packages/dddart_repository_mysql && dart test
  ```
- **Added instructions**: How to run SQLite collection tests locally
  ```bash
  cd packages/dddart_repository_sqlite && dart test
  ```

#### Test Exclusions
- **Updated comment**: Clarified that collection tests are included in the excluded tags
- **Behavior unchanged**: Still excludes `requires-mysql` tag for local runs

### 3. MySQL Test Helpers (packages/dddart_repository_mysql/test/test_helpers.dart)

#### Environment Variable Support
- **Added import**: `dart:io` for Platform.environment access
- **Updated constructor**: TestMysqlHelper now reads from environment variables
  - `MYSQL_HOST` (default: localhost)
  - `MYSQL_PORT` (default: 3307)
  - `MYSQL_DATABASE` (default: test_db)
  - `MYSQL_USER` (default: root)
  - `MYSQL_PASSWORD` (default: test_password)
- **Documentation**: Added doc comments explaining environment variable usage

### 4. Testing Documentation

#### Created: packages/dddart_repository_mysql/TESTING.md
Comprehensive testing guide including:
- How to run unit tests vs integration tests
- Collection test categories and coverage
- Environment variable configuration
- Docker setup instructions
- CI/CD configuration examples
- Troubleshooting guide

#### Created: packages/dddart_repository_sqlite/TESTING.md
Comprehensive testing guide including:
- How to run all tests (no external dependencies)
- Collection test categories and coverage
- Property-based testing explanation
- Advantages of SQLite for testing
- Comparison with MySQL implementation
- Troubleshooting guide

## Test Execution Matrix

### Local Development (scripts/test-all.sh)
| Package | Tests Run | External Service Required |
|---------|-----------|---------------------------|
| dddart_repository_sqlite | All tests (including collections) | No |
| dddart_repository_mysql | Unit tests only | No |
| Other packages | All tests | No (except MongoDB/DynamoDB) |

### CI/CD (GitHub Actions)
| Package | Tests Run | External Service |
|---------|-----------|------------------|
| dddart_repository_sqlite | All tests (including collections) | None |
| dddart_repository_mysql | All tests (including collections) | MySQL 8.0 container |
| Other packages | All tests | MongoDB/DynamoDB containers |

## Collection Test Coverage

Both SQLite and MySQL packages now have comprehensive collection test coverage:

### Integration Tests
- **Primitive collections**: List<int>, Set<String>, Map<String, int>
- **Value object collections**: List<Money>, Set<Address>, Map<String, Money>
- **Entity collections**: Set<Entity>, Map<String, Entity>
- **Nullable collections**: List<int>?, nullable elements
- **CASCADE DELETE**: Verifies foreign key constraints work correctly
- **Large collections**: Tests with 100+ items
- **Multiple aggregates**: Tests isolation between aggregates

### Property-Based Tests
- **Round-trip preservation**: All collection types (Properties 1-8)
- **CASCADE DELETE**: Property 9
- **Empty collections**: Property 10
- **Null collections**: Property 11
- **DateTime round-trip**: Property 12
- **Boolean round-trip**: Property 13
- **Dialect consistency**: Property 18 (MySQL vs SQLite)

## Running Collection Tests

### SQLite (No Setup Required)
```bash
cd packages/dddart_repository_sqlite
dart test
```

### MySQL (Requires Docker)
```bash
# Start MySQL
docker run -d -p 3307:3306 \
  -e MYSQL_ROOT_PASSWORD=test_password \
  -e MYSQL_DATABASE=test_db \
  mysql:8.0

# Run tests
cd packages/dddart_repository_mysql
dart test
```

### CI/CD (Automatic)
- Push to GitHub
- GitHub Actions automatically starts MySQL container
- All tests run including collection integration tests

## Benefits

1. **Comprehensive Testing**: Collection support is thoroughly tested in CI
2. **Fast Local Development**: Developers can run unit tests quickly without MySQL
3. **Flexible**: Developers can optionally run integration tests locally with Docker
4. **Documented**: Clear instructions for running all test types
5. **Consistent**: Same test coverage in both SQLite and MySQL implementations
6. **Automated**: CI catches integration issues before merge

## Future Improvements

Potential enhancements for collection testing:

1. **Test Containers**: Use Testcontainers for Dart to automatically manage MySQL in tests
2. **Performance Benchmarks**: Add benchmarks for large collection operations
3. **Stress Tests**: Test with very large collections (1000+ items)
4. **Concurrent Tests**: Test concurrent access to collections
5. **Migration Tests**: Test schema migrations when adding/removing collections
