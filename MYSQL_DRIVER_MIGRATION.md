# MySQL Driver Migration Guide

## Current Status

The `dddart_repository_mysql` package currently uses `mysql1: ^0.20.0`, which has known limitations and compatibility issues with modern MySQL versions.

## Known Issues with mysql1

### 1. MySQL 8.0 Authentication Problems

**Issue:** The `mysql1` package has poor support for MySQL 8.0's default `caching_sha2_password` authentication plugin.

**Symptoms:**
- `SocketException: Socket has been closed` immediately after connection
- Connection succeeds but queries fail
- Intermittent connection drops

**Current Workaround:**
```bash
# Start MySQL with legacy authentication
docker run -d --name mysql-test \
  -p 3307:3306 \
  -e MYSQL_ROOT_PASSWORD=test_password \
  -e MYSQL_DATABASE=test_db \
  mysql:8.0 --default-authentication-plugin=mysql_native_password
```

### 2. Integration Test Failures

**Current Test Results:**
- ✅ All 71 non-integration tests pass (code generation, schema generation, etc.)
- ✅ Basic connection and table creation works
- ❌ 27 of 55 integration tests fail with data loading issues

**Failing Test Categories:**
- Collection data deserialization (Set vs List type mismatches)
- Entity relationship loading
- Complex object graph persistence

**Example Error:**
```
RepositoryException: MySQL error during getById: DeserializationException: 
Failed to deserialize TestPrimitiveCollections: type '_Set<dynamic>' is not 
a subtype of type 'List<dynamic>' in type cast
```

### 3. Connection Stability

**Issues:**
- Connection pool exhaustion under concurrent load
- "Got packets out of order" errors
- Socket closure during query execution

### 4. Limited Maintenance

The `mysql1` package:
- Last significant update: 2021
- Known issues with MySQL 8.0+ remain unresolved
- Limited async/await support
- No prepared statement pooling

## Recommended Alternative: mysql_client

### Why mysql_client?

**Package:** `mysql_client: ^0.0.27` (or latest)
**Repository:** https://pub.dev/packages/mysql_client

**Advantages:**
1. ✅ Full MySQL 8.0+ support (including `caching_sha2_password`)
2. ✅ Better connection pooling and stability
3. ✅ Modern async/await API
4. ✅ Actively maintained
5. ✅ Better prepared statement support
6. ✅ Improved error handling

**Disadvantages:**
1. ⚠️ Different API (requires code changes)
2. ⚠️ Less mature than mysql1 (but more actively developed)

## Migration Plan

### Phase 1: Assessment (Current)

**Status:** ✅ Complete

- [x] Document current mysql1 issues
- [x] Identify failing tests
- [x] Research alternative drivers
- [x] Create migration guide

### Phase 2: API Compatibility Layer

**Goal:** Minimize breaking changes for users

**Tasks:**
1. Create abstraction layer for MySQL operations
2. Implement adapter pattern for driver switching
3. Maintain backward compatibility where possible

**Files to Update:**
- `lib/src/connection/mysql_connection.dart` - Main connection class
- `lib/src/dialect/mysql_dialect.dart` - SQL dialect (minimal changes)
- `lib/src/generators/mysql_repository_generator.dart` - Code generator (no changes needed)

### Phase 3: Driver Implementation

**Key Changes Required:**

#### 1. Connection Management

**Current (mysql1):**
```dart
import 'package:mysql1/mysql1.dart';

final settings = ConnectionSettings(
  host: host,
  port: port,
  user: user,
  password: password,
  db: database,
);
final pool = await MySqlConnection.connect(settings);
```

**New (mysql_client):**
```dart
import 'package:mysql_client/mysql_client.dart';

final conn = await MySQLConnection.createConnection(
  host: host,
  port: port,
  userName: user,
  password: password,
  databaseName: database,
);
await conn.connect();
```

#### 2. Query Execution

**Current (mysql1):**
```dart
final results = await pool.query(sql, parameters);
for (final row in results) {
  // row is indexed by position
  final value = row[0];
}
```

**New (mysql_client):**
```dart
final result = await conn.execute(sql, parameters);
for (final row in result.rows) {
  // row has named column access
  final value = row.colByName('column_name');
}
```

#### 3. Transaction Handling

**Current (mysql1):**
```dart
await pool.transaction((ctx) async {
  await ctx.query('INSERT ...');
  await ctx.query('UPDATE ...');
});
```

**New (mysql_client):**
```dart
await conn.transactional((txn) async {
  await txn.execute('INSERT ...');
  await txn.execute('UPDATE ...');
});
```

### Phase 4: Testing

**Test Strategy:**

1. **Unit Tests:** Should pass without changes (no driver dependency)
2. **Integration Tests:** Require MySQL instance
   - Run against MySQL 8.0 with default authentication
   - Test connection pooling under load
   - Verify collection support works correctly
   - Test transaction rollback behavior

3. **Compatibility Tests:** Run both drivers in parallel
   - Ensure same SQL generation
   - Verify identical behavior
   - Compare performance

### Phase 5: Migration Path for Users

**Breaking Changes:**
- Minimum MySQL version: 5.7+ (8.0+ recommended)
- Connection configuration may need updates
- Custom repository implementations may need adjustments

**Migration Steps for Users:**

1. Update `pubspec.yaml`:
```yaml
dependencies:
  dddart_repository_mysql: ^2.0.0  # New major version
```

2. Update connection code (if using custom connection):
```dart
// Old
final connection = MysqlConnection(
  host: 'localhost',
  port: 3306,
  database: 'mydb',
  user: 'root',
  password: 'password',
);

// New - same API, different implementation
final connection = MysqlConnection(
  host: 'localhost',
  port: 3306,
  database: 'mydb',
  user: 'root',
  password: 'password',
);
```

3. Test thoroughly - most code should work unchanged

## Implementation Checklist

### Core Changes

- [ ] Update `pubspec.yaml` to use `mysql_client`
- [ ] Refactor `MysqlConnection` class
  - [ ] Update `open()` method
  - [ ] Update `close()` method
  - [ ] Update `query()` method
  - [ ] Update `execute()` method
  - [ ] Update `transaction()` method
- [ ] Update result set handling
  - [ ] Convert row access from indexed to named
  - [ ] Handle field metadata differences
  - [ ] Update type conversions
- [ ] Update error handling
  - [ ] Map new exception types
  - [ ] Preserve error messages
  - [ ] Maintain RepositoryException types

### Testing Updates

- [ ] Update test helpers for new driver
- [ ] Remove `mysql_native_password` workaround from docs
- [ ] Update Docker commands in TESTING.md
- [ ] Verify all 71 non-integration tests still pass
- [ ] Fix and verify all 55 integration tests pass
- [ ] Add connection pool stress tests
- [ ] Add MySQL 8.0 authentication tests

### Documentation Updates

- [ ] Update README.md with new requirements
- [ ] Update TESTING.md with new setup instructions
- [ ] Update CHANGELOG.md with breaking changes
- [ ] Add migration guide for users
- [ ] Update example code

## Expected Outcomes

After migration:

1. ✅ All 126 tests passing (71 unit + 55 integration)
2. ✅ MySQL 8.0+ support without workarounds
3. ✅ Stable connection handling under load
4. ✅ Better error messages and debugging
5. ✅ Collection support fully functional
6. ✅ Improved performance (better connection pooling)

## Timeline Estimate

- **Phase 2 (API Layer):** 2-4 hours
- **Phase 3 (Implementation):** 4-6 hours
- **Phase 4 (Testing):** 2-4 hours
- **Phase 5 (Documentation):** 1-2 hours

**Total:** 9-16 hours of development time

## References

- mysql1 package: https://pub.dev/packages/mysql1
- mysql_client package: https://pub.dev/packages/mysql_client
- MySQL 8.0 authentication: https://dev.mysql.com/doc/refman/8.0/en/caching-sha2-pluggable-authentication.html
- Current test failures: See test output in CI/CD logs

## Notes

- The SQL generation code (generators) requires **no changes** - only the runtime connection layer
- The dialect implementation requires **minimal changes** - mostly type conversions
- Generated repository code remains **100% compatible** - users don't need to regenerate
- This is a **runtime dependency change only** - no breaking changes to the public API

## Getting Started

To begin the migration:

```bash
# Create a new branch
git checkout -b feature/mysql-client-migration

# Update the dependency
cd packages/dddart_repository_mysql
# Edit pubspec.yaml: replace mysql1 with mysql_client

# Start with the connection layer
# Edit lib/src/connection/mysql_connection.dart
```

Follow the implementation checklist above, testing incrementally as you go.
