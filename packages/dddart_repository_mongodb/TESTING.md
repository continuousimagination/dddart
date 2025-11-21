# Testing Guide

## Running Tests

### All Unit Tests (Recommended)

Run all tests excluding MongoDB integration tests:

```bash
dart test --exclude-tags=requires-mongo
```

### Generator Tests Only

The generator tests use `build_test` which can hit system file descriptor limits when run in parallel. Run with limited concurrency:

```bash
dart test test/generator_test.dart --concurrency=1
```

Or run all non-integration tests with limited concurrency:

```bash
dart test --exclude-tags=requires-mongo --concurrency=1
```

### Integration Tests (Requires MongoDB)

Integration tests require a MongoDB instance running on `localhost:27017`.

To run integration tests only:

```bash
dart test --tags=requires-mongo
```

To run all tests including integration tests:

```bash
dart test --concurrency=1
```

## Test Categories

### Unit Tests
- **connection_test.dart**: Tests MongoConnection configuration and URI parsing
- **generator_test.dart**: Tests code generation logic for repository classes

### Integration Tests  
- **repository_integration_test.dart**: Tests generated repositories against real MongoDB
  - Tagged with `requires-mongo`
  - Automatically skipped when MongoDB is not available
  - Tests CRUD operations, ID mapping, custom collections, error handling, etc.

## Troubleshooting

### "Too many open files" Error

If you encounter file descriptor limit errors when running generator tests:

1. Run with `--concurrency=1` to limit parallel execution
2. On macOS/Linux, you can increase the limit:
   ```bash
   ulimit -n 4096
   ```

### MongoDB Connection Errors

Integration tests will fail if MongoDB is not running. This is expected behavior. The tests are tagged and can be excluded as shown above.

To start MongoDB locally:
```bash
# Using Docker
docker run -d -p 27017:27017 mongo:latest

# Or using Homebrew (macOS)
brew services start mongodb-community
```

## CI/CD

### GitHub Actions

The GitHub Actions workflow automatically:
- Starts a MongoDB service container for all test jobs
- Runs **all tests** (including integration tests) for `dddart_repository_mongodb`
- Excludes MongoDB tests for other packages

This ensures integration tests run in CI without requiring developers to have MongoDB installed locally.

### Local Pre-Push Hook

The pre-push hook runs:
```bash
dart test --exclude-tags=requires-mongo
```

This allows fast local validation without requiring MongoDB. Integration tests are verified in CI.

### Manual CI/CD Setup

For other CI systems, use a MongoDB service container:

```yaml
# Example for GitHub Actions
services:
  mongodb:
    image: mongo:latest
    ports:
      - 27017:27017
```

Then run:
```bash
# Run unit tests only (fast, no external dependencies)
dart test --exclude-tags=requires-mongo --concurrency=1

# Run integration tests separately with MongoDB service
dart test --tags=requires-mongo
```
