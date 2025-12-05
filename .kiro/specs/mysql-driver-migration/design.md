# Design Document

## Overview

This design outlines the migration from mysql1 to mysql_client driver in the dddart_repository_mysql package. The migration addresses critical MySQL 8.0+ compatibility issues, fixes 27 failing integration tests, and improves connection stability while maintaining backward compatibility for users.

The key design principle is to isolate driver-specific code within the MysqlConnection class, leaving the SQL generation, dialect, and code generator components unchanged. This minimizes risk and ensures existing generated repositories continue to work without regeneration.

## Architecture

### Current Architecture

```
┌─────────────────────────────────────────────────────────┐
│ Generated Repository (e.g., OrderMysqlRepository)       │
│ - CRUD operations                                        │
│ - Uses SqlConnection interface                          │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│ MysqlConnection (implements SqlConnection)              │
│ - Wraps mysql1 driver                                   │
│ - Connection pooling                                    │
│ - Transaction management                                │
│ - Error mapping                                         │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│ mysql1 Package                                          │
│ - Low-level MySQL protocol                             │
│ - Connection management                                 │
│ - Query execution                                       │
└─────────────────────────────────────────────────────────┘
```

### New Architecture

The architecture remains identical, only the driver package changes:

```
┌─────────────────────────────────────────────────────────┐
│ Generated Repository (e.g., OrderMysqlRepository)       │
│ - CRUD operations (UNCHANGED)                           │
│ - Uses SqlConnection interface (UNCHANGED)              │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│ MysqlConnection (implements SqlConnection)              │
│ - Wraps mysql_client driver (CHANGED)                  │
│ - Connection pooling (IMPROVED)                         │
│ - Transaction management (UPDATED API)                  │
│ - Error mapping (UPDATED EXCEPTIONS)                    │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│ mysql_client Package                                    │
│ - Low-level MySQL protocol                             │
│ - MySQL 8.0+ authentication support                    │
│ - Improved connection stability                         │
└─────────────────────────────────────────────────────────┘
```

### Unchanged Components

These components require NO changes:
- **MysqlRepositoryGenerator**: Code generation logic remains identical
- **MysqlDialect**: SQL generation remains identical
- **GenerateMysqlRepository**: Annotation remains identical
- **Generated Repositories**: All generated code remains compatible

## Components and Interfaces

### SqlConnection Interface (Unchanged)

The SqlConnection interface from dddart_repository_sql defines the contract:

```dart
abstract class SqlConnection {
  Future<void> open();
  Future<void> close();
  bool get isOpen;
  Future<void> execute(String sql, [List<Object?>? parameters]);
  Future<List<Map<String, Object?>>> query(String sql, [List<Object?>? parameters]);
  Future<T> transaction<T>(Future<T> Function() action);
}
```

### MysqlConnection Class (Updated)

The MysqlConnection class will be refactored to use mysql_client while maintaining the same public API:

**Public API (Unchanged):**
```dart
class MysqlConnection implements SqlConnection {
  MysqlConnection({
    required String host,
    required int port,
    required String database,
    required String user,
    required String password,
    int maxConnections = 5,
    Duration timeout = const Duration(seconds: 30),
  });
  
  // SqlConnection interface methods (signatures unchanged)
  Future<void> open();
  Future<void> close();
  bool get isOpen;
  Future<void> execute(String sql, [List<Object?>? parameters]);
  Future<List<Map<String, Object?>>> query(String sql, [List<Object?>? parameters]);
  Future<T> transaction<T>(Future<T> Function() action);
}
```

**Internal Implementation (Changed):**
- Replace `MySqlConnection` (mysql1) with `MySQLConnection` (mysql_client)
- Update connection initialization to use `MySQLConnection.createConnection()` and `connect()`
- Update query execution to use `execute()` method and handle `IResultSet` return type
- Update result row access from indexed (`row[i]`) to named (`row.colByName()`)
- Update transaction handling to use `transactional()` method
- Update error mapping to handle mysql_client exception types

### Connection Lifecycle

**mysql1 (Current):**
```dart
final settings = ConnectionSettings(
  host: host,
  port: port,
  user: user,
  password: password,
  db: database,
  timeout: timeout,
);
_pool = await MySqlConnection.connect(settings);
```

**mysql_client (New):**
```dart
_connection = await MySQLConnection.createConnection(
  host: host,
  port: port,
  userName: user,
  password: password,
  databaseName: database,
);
await _connection!.connect(timeoutMs: timeout.inMilliseconds);
```

### Query Execution

**mysql1 (Current):**
```dart
final Results results = await _pool!.query(sql, parameters);
for (final row in results) {
  final value = row[i]; // Indexed access
}
```

**mysql_client (New):**
```dart
final IResultSet result = await _connection!.execute(sql, parameters);
for (final row in result.rows) {
  final value = row.colByName('column_name'); // Named access
}
```

### Transaction Handling

**mysql1 (Current):**
```dart
await _pool!.query('START TRANSACTION');
try {
  final result = await action();
  await _pool!.query('COMMIT');
  return result;
} catch (e) {
  await _pool!.query('ROLLBACK');
  rethrow;
}
```

**mysql_client (New):**
```dart
return await _connection!.transactional((txn) async {
  // action() executes within transaction context
  return await action();
});
```

## Data Models

### Result Set Mapping

The key data transformation is converting mysql_client result sets to the expected `List<Map<String, Object?>>` format:

**Input (mysql_client):**
```dart
IResultSet {
  rows: Iterable<ResultSetRow>
  columns: List<ColumnDefinition>
}

ResultSetRow {
  colByName(String name): dynamic
  colAt(int index): dynamic
}
```

**Output (SqlConnection interface):**
```dart
List<Map<String, Object?>>
```

**Mapping Logic:**
```dart
final resultList = <Map<String, Object?>>[];
for (final row in result.rows) {
  final rowMap = <String, Object?>{};
  for (final column in result.columns) {
    rowMap[column.name] = row.colByName(column.name);
  }
  resultList.add(rowMap);
}
return resultList;
```

### Error Type Mapping

Map mysql_client exceptions to RepositoryException types:

| mysql_client Error | RepositoryExceptionType | Condition |
|-------------------|------------------------|-----------|
| MySQLException with error code 1062 | duplicate | Duplicate key violation |
| MySQLException with error code 2003, 1045, 1049 | connection | Connection/auth errors |
| MySQLException with error code 1205, 3024 | timeout | Lock wait or query timeout |
| SocketException | connection | Network errors |
| TimeoutException | timeout | Connection timeout |
| Other exceptions | (default) | Generic error |


## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Collection round-trip preservation

*For any* entity containing Set or List collections, persisting and then retrieving the entity should return collections with the same elements and correct types (Set remains Set, List remains List).
**Validates: Requirements 1.3**

### Property 2: Object graph round-trip preservation

*For any* entity with relationships to other entities, persisting the complete object graph and then loading it back should preserve all relationships and referenced entities.
**Validates: Requirements 1.4**

### Property 3: Data type round-trip preservation

*For any* entity containing all supported data types (String, int, double, bool, DateTime, etc.), persisting and retrieving the entity should return identical values for all fields.
**Validates: Requirements 1.5**

### Property 4: Connection stability under query load

*For any* sequence of valid queries executed after connection, the connection should remain open and functional without SocketException or connection drop errors.
**Validates: Requirements 2.3, 2.4**

### Property 5: Concurrent query execution stability

*For any* set of valid queries executed concurrently, all queries should complete successfully without "packets out of order" errors or connection failures.
**Validates: Requirements 3.1**

### Property 6: Long-running transaction stability

*For any* transaction containing operations with delays, the connection should remain open throughout the transaction without premature socket closure.
**Validates: Requirements 3.3**

### Property 7: SQL generation consistency

*For any* entity model, the SQL generated for CRUD operations should match the expected SQL patterns and syntax used in the previous version.
**Validates: Requirements 4.3, 8.3**

### Property 8: Error type mapping consistency

*For any* database error condition (duplicate key, connection failure, timeout, constraint violation), the system should map it to the appropriate RepositoryException type with equivalent error information.
**Validates: Requirements 4.4, 7.4**

### Property 9: Transaction commit atomicity

*For any* set of operations executed within a transaction, if the transaction succeeds, all operations should be committed and visible in subsequent queries.
**Validates: Requirements 6.1**

### Property 10: Transaction rollback atomicity

*For any* set of operations executed within a transaction that encounters an error, all operations should be rolled back and the database should return to its pre-transaction state.
**Validates: Requirements 6.2**

### Property 11: Nested transaction correctness

*For any* nested transaction structure, operations should execute correctly with proper commit/rollback behavior at each nesting level.
**Validates: Requirements 6.3**

### Property 12: Connection error message completeness

*For any* connection failure, the error message should contain the host, port, database name, and failure reason.
**Validates: Requirements 7.1**

### Property 13: Query error message completeness

*For any* query failure, the error message should contain the SQL statement and the database error details.
**Validates: Requirements 7.2**

### Property 14: Deserialization error message completeness

*For any* deserialization failure, the error message should contain the entity type name and the field name that caused the failure.
**Validates: Requirements 7.3**

### Property 15: Type conversion consistency

*For any* Dart value of a supported type, converting to MySQL and back should preserve the value and type correctly.
**Validates: Requirements 8.4**

## Error Handling

### Exception Hierarchy

All database errors are mapped to `RepositoryException` from the dddart package:

```dart
class RepositoryException implements Exception {
  RepositoryException(
    this.message, {
    this.type = RepositoryExceptionType.unknown,
    this.cause,
  });
  
  final String message;
  final RepositoryExceptionType type;
  final Object? cause;
}

enum RepositoryExceptionType {
  unknown,
  notFound,
  duplicate,
  connection,
  timeout,
  validation,
}
```

### Error Mapping Strategy

The `_mapMysqlException` method in MysqlConnection will be updated to handle mysql_client exceptions:

**mysql_client Exception Types:**
- `MySQLException`: Database-level errors with error codes
- `SocketException`: Network connectivity errors
- `TimeoutException`: Connection or query timeouts
- `StateError`: Invalid connection state

**Mapping Rules:**

1. **Duplicate Key (Error 1062)**
   - Map to: `RepositoryExceptionType.duplicate`
   - Message: Include table and key information

2. **Connection Errors (Errors 2003, 1045, 1049)**
   - Map to: `RepositoryExceptionType.connection`
   - Message: Include connection parameters (host, port, database)

3. **Timeout Errors (Errors 1205, 3024)**
   - Map to: `RepositoryExceptionType.timeout`
   - Message: Include operation type and timeout duration

4. **Network Errors (SocketException)**
   - Map to: `RepositoryExceptionType.connection`
   - Message: Include network error details

5. **Other Errors**
   - Map to: `RepositoryExceptionType.unknown`
   - Message: Include original error message and SQL if available

### Error Context Preservation

All mapped exceptions must preserve:
- Original exception as `cause` field
- SQL statement (for query errors)
- Connection parameters (for connection errors)
- Entity type and field name (for deserialization errors)

## Testing Strategy

### Unit Tests

Unit tests validate components in isolation without requiring a database:

**Test Categories:**
1. **Code Generation Tests** (existing, should pass unchanged)
   - Verify generated repository code structure
   - Verify annotation processing
   - Verify file generation

2. **Schema Generation Tests** (existing, should pass unchanged)
   - Verify CREATE TABLE statements
   - Verify column definitions
   - Verify index creation

3. **SQL Dialect Tests** (existing, should pass unchanged)
   - Verify SQL syntax generation
   - Verify parameter binding
   - Verify type conversions

4. **Connection State Tests** (new)
   - Verify connection lifecycle (open/close)
   - Verify isOpen state tracking
   - Verify error handling for operations on closed connections

**Expected Results:**
- All 71 existing unit tests must pass without modification
- New connection state tests validate proper lifecycle management

### Property-Based Tests

Property-based tests validate universal properties across many generated inputs:

**Test Framework:** Use `package:test` with custom property test helpers

**Test Categories:**

1. **Round-Trip Properties**
   - Property 1: Collection preservation (Sets, Lists)
   - Property 2: Object graph preservation (relationships)
   - Property 3: Data type preservation (all supported types)
   - Property 15: Type conversion consistency

2. **Stability Properties**
   - Property 4: Connection stability under query load
   - Property 5: Concurrent query stability
   - Property 6: Long-running transaction stability

3. **Consistency Properties**
   - Property 7: SQL generation consistency
   - Property 8: Error type mapping consistency

4. **Transaction Properties**
   - Property 9: Transaction commit atomicity
   - Property 10: Transaction rollback atomicity
   - Property 11: Nested transaction correctness

5. **Error Message Properties**
   - Property 12: Connection error completeness
   - Property 13: Query error completeness
   - Property 14: Deserialization error completeness

**Test Configuration:**
- Minimum 100 iterations per property test
- Use random data generators for entities, collections, and queries
- Tag property tests with `@Tags(['property-test'])`
- Each property test must reference its design document property number

### Integration Tests

Integration tests validate end-to-end functionality with a real MySQL instance:

**Test Environment:**
- MySQL 8.0+ with default authentication (caching_sha2_password)
- Docker container for consistent test environment
- Test database created/destroyed per test run

**Test Categories:**

1. **Connection Tests**
   - MySQL 8.0 default authentication (validates Requirement 2.1)
   - Connection without legacy auth plugin (validates Requirement 2.2)
   - Multiple connection/disconnection cycles

2. **CRUD Operations**
   - Create, read, update, delete for all entity types
   - Batch operations
   - Query with filters and sorting

3. **Collection Operations**
   - Persist and retrieve entities with Set fields
   - Persist and retrieve entities with List fields
   - Verify no type cast errors (validates Requirement 1.3)

4. **Relationship Operations**
   - Persist and retrieve entities with references
   - Load complex object graphs
   - Verify relationship integrity (validates Requirement 1.4)

5. **Transaction Tests**
   - Commit successful transactions
   - Rollback failed transactions
   - Nested transaction handling
   - Concurrent transaction execution

6. **Error Handling Tests**
   - Duplicate key violations
   - Connection failures
   - Query syntax errors
   - Constraint violations

**Expected Results:**
- All 55 integration tests must pass (currently 27 failing)
- No SocketException errors
- No type cast errors
- No "packets out of order" errors

### Test Execution

**Local Testing:**
```bash
# Start MySQL 8.0 with default authentication
docker run -d --name mysql-test \
  -p 3307:3306 \
  -e MYSQL_ROOT_PASSWORD=test_password \
  -e MYSQL_DATABASE=test_db \
  mysql:8.0

# Run all tests
cd packages/dddart_repository_mysql
dart test

# Run only unit tests (no database required)
dart test --exclude-tags=integration

# Run only integration tests
dart test --tags=integration

# Run only property tests
dart test --tags=property-test
```

**CI/CD Testing:**
- GitHub Actions workflow with MySQL 8.0 service container
- Run all tests on every pull request
- Verify test count (71 unit + 55 integration = 126 total)
- Fail build if any test fails

### Test Migration Strategy

**Phase 1: Verify Baseline**
1. Run existing tests with mysql1 driver
2. Document which tests pass (71 unit tests)
3. Document which tests fail (27 integration tests)

**Phase 2: Implement Driver Change**
1. Update MysqlConnection to use mysql_client
2. Run unit tests after each change
3. Fix any unit test failures immediately

**Phase 3: Fix Integration Tests**
1. Run integration tests with mysql_client
2. Fix collection serialization issues
3. Fix relationship loading issues
4. Verify all 55 integration tests pass

**Phase 4: Add Property Tests**
1. Implement property-based tests for each correctness property
2. Run with 100+ iterations
3. Fix any issues discovered by property tests

**Phase 5: Validation**
1. Run complete test suite (unit + integration + property)
2. Verify all 126+ tests pass
3. Run stress tests for connection stability
4. Verify no regressions

## Implementation Notes

### Dependency Update

**pubspec.yaml changes:**
```yaml
dependencies:
  # Remove mysql1
  # mysql1: ^0.20.0
  
  # Add mysql_client
  mysql_client: ^0.0.27
```

### Import Changes

**Before:**
```dart
import 'package:mysql1/mysql1.dart';
```

**After:**
```dart
import 'package:mysql_client/mysql_client.dart';
```

### Connection Pool vs Single Connection

**mysql1** uses a connection pool by default (MySqlConnection.connect returns a pool).

**mysql_client** uses single connections (MySQLConnection.createConnection returns one connection).

**Design Decision:** For the initial migration, use a single connection to minimize complexity. Connection pooling can be added in a future enhancement if needed. The maxConnections parameter will be retained in the constructor for backward compatibility but will not be used initially.

### Transaction Context

**mysql1** requires manual transaction management with START TRANSACTION, COMMIT, ROLLBACK.

**mysql_client** provides a `transactional()` method that handles this automatically.

**Design Decision:** Use mysql_client's transactional() method for cleaner code and automatic rollback on exceptions. The nested transaction tracking (_transactionDepth) may need adjustment since mysql_client handles transaction context differently.

### Result Set Column Access

**mysql1** provides indexed access to columns, requiring field metadata to map to names.

**mysql_client** provides both indexed and named access, simplifying result mapping.

**Design Decision:** Use named column access (`row.colByName()`) for clarity and to avoid index-based errors. This requires iterating over column definitions to build the result map.

### Backward Compatibility Guarantee

The public API of MysqlConnection will remain unchanged:
- Constructor parameters: same names and types
- Method signatures: same names, parameters, and return types
- Exception types: same RepositoryException types

Users upgrading from mysql1-based version to mysql_client-based version should only need to:
1. Update their pubspec.yaml dependency version
2. Run `dart pub get`
3. Restart their application

No code changes should be required for standard usage.

### Breaking Changes

**Major Version Bump:** This migration will be released as version 2.0.0 to indicate the driver change, even though the public API remains compatible.

**Potential Breaking Changes:**
1. Minimum MySQL version: 5.7+ (8.0+ recommended)
2. Connection behavior: Single connection instead of pool (initially)
3. Error messages: May differ slightly due to different driver error formats
4. Performance characteristics: May differ due to different driver implementation

**Non-Breaking Changes:**
- Generated repository code: No changes required
- SQL syntax: Identical output
- Type conversions: Identical behavior
- Transaction semantics: Identical behavior

## Migration Path for Users

### For Standard Users

Users who use the package without customization:

**Step 1:** Update dependency
```yaml
dependencies:
  dddart_repository_mysql: ^2.0.0
```

**Step 2:** Update MySQL server (if needed)
- Ensure MySQL 5.7+ or 8.0+
- No need to disable caching_sha2_password

**Step 3:** Test application
- Run existing tests
- Verify database operations work correctly

### For Custom Repository Users

Users who have custom repository implementations:

**Step 1:** Review custom code
- Check if custom code directly imports mysql1
- Check if custom code uses mysql1-specific types

**Step 2:** Update imports (if needed)
- Replace mysql1 imports with mysql_client (if any)
- Update type references (if any)

**Step 3:** Test thoroughly
- Run all custom repository tests
- Verify custom queries work correctly

### For Contributors

Developers working on the package:

**Step 1:** Update development environment
```bash
cd packages/dddart_repository_mysql
dart pub get
```

**Step 2:** Run tests
```bash
# Start MySQL 8.0
docker run -d --name mysql-test \
  -p 3307:3306 \
  -e MYSQL_ROOT_PASSWORD=test_password \
  -e MYSQL_DATABASE=test_db \
  mysql:8.0

# Run all tests
dart test
```

**Step 3:** Verify all tests pass
- 71 unit tests
- 55 integration tests
- All property tests

## Documentation Updates

### README.md

**Updates Required:**
1. Update "Requirements" section with MySQL version requirements
2. Update "Installation" section with new version number
3. Add "Migration from 1.x" section with upgrade guide
4. Update example code (if any mysql1-specific code exists)
5. Remove any references to mysql_native_password workaround

### CHANGELOG.md

**New Entry:**
```markdown
## 2.0.0 - 2024-XX-XX

### Changed
- **BREAKING**: Migrated from mysql1 to mysql_client driver
- **BREAKING**: Minimum MySQL version is now 5.7+ (8.0+ recommended)
- Improved MySQL 8.0+ authentication support (caching_sha2_password)
- Improved connection stability and error handling

### Fixed
- Fixed 27 integration test failures related to collection deserialization
- Fixed SocketException errors with MySQL 8.0
- Fixed "packets out of order" errors under concurrent load
- Fixed type cast errors with Set and List collections

### Migration Guide
See README.md for migration instructions from 1.x to 2.0.0.
Most users can upgrade by simply updating the version number.
```

### Example Code

**Files to Update:**
- `example/basic_crud_example.dart`
- `example/connection_management_example.dart`
- `example/custom_repository_example.dart`
- `example/error_handling_example.dart`

**Changes Required:**
- Verify examples work with new driver
- Update any mysql1-specific code
- Update comments referencing mysql1

### Test Documentation

**New File:** `test/README.md`

**Content:**
- How to run tests locally
- MySQL Docker setup instructions
- Test categories and tags
- Troubleshooting common test issues

## Performance Considerations

### Connection Overhead

**mysql1:** Connection pool reduces overhead for multiple operations.

**mysql_client:** Single connection may have higher overhead for concurrent operations.

**Mitigation:** Initial implementation uses single connection for simplicity. Future enhancement can add connection pooling if performance testing shows it's needed.

### Query Execution

**mysql1:** Uses binary protocol for prepared statements.

**mysql_client:** Also uses binary protocol with improved implementation.

**Expected Impact:** Similar or better performance for query execution.

### Result Set Processing

**mysql1:** Indexed access is fast but requires field metadata lookup.

**mysql_client:** Named access may have slight overhead but is more maintainable.

**Expected Impact:** Negligible performance difference for typical result set sizes.

### Transaction Overhead

**mysql1:** Manual transaction management with explicit SQL commands.

**mysql_client:** Transactional method may have slight overhead for context management.

**Expected Impact:** Negligible performance difference for typical transaction sizes.

## Security Considerations

### Authentication

**mysql1:** Poor support for caching_sha2_password forces use of legacy authentication.

**mysql_client:** Full support for modern authentication plugins.

**Security Improvement:** Using modern authentication is more secure and follows MySQL best practices.

### Connection Security

Both drivers support SSL/TLS connections. The MysqlConnection class should be enhanced in a future version to expose SSL configuration options.

### SQL Injection

Both drivers use parameterized queries, preventing SQL injection. The migration does not change this security posture.

## Future Enhancements

### Connection Pooling

Add proper connection pooling support using mysql_client's connection management:

```dart
class MysqlConnectionPool {
  final List<MySQLConnection> _connections = [];
  final int maxConnections;
  
  Future<MySQLConnection> acquire() async { /* ... */ }
  Future<void> release(MySQLConnection conn) async { /* ... */ }
}
```

### SSL/TLS Support

Expose SSL configuration in MysqlConnection constructor:

```dart
MysqlConnection({
  // ... existing parameters
  bool useSSL = false,
  String? sslCert,
  String? sslKey,
  String? sslCA,
});
```

### Prepared Statement Caching

Leverage mysql_client's prepared statement support for frequently executed queries.

### Monitoring and Metrics

Add connection metrics and query performance tracking:

```dart
class ConnectionMetrics {
  int queriesExecuted = 0;
  Duration totalQueryTime = Duration.zero;
  int activeConnections = 0;
}
```
