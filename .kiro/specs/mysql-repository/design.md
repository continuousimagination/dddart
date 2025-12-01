# Design Document: MySQL Repository Implementation

## Overview

The `dddart_repository_mysql` package provides a MySQL database repository implementation for DDDart aggregate roots, following the established pattern used by `dddart_repository_sqlite`. The package extends the base `dddart_repository_sql` abstractions to provide MySQL-specific implementations with automatic code generation support.

The implementation consists of three main components:
1. **MysqlConnection**: MySQL-specific connection management
2. **MysqlDialect**: MySQL-specific SQL syntax and type mappings
3. **MysqlRepositoryGenerator**: Code generator for MySQL repository implementations

The design leverages the existing ORM framework from `dddart_repository_sql`, which provides schema generation, relationship analysis, object mapping, and query building utilities. The MySQL implementation only needs to provide database-specific connection handling and SQL dialect support.

## Architecture

### Package Structure

```
dddart_repository_mysql/
├── lib/
│   ├── dddart_repository_mysql.dart          # Main export file
│   └── src/
│       ├── annotations/
│       │   └── generate_mysql_repository.dart # @GenerateMysqlRepository annotation
│       ├── connection/
│       │   └── mysql_connection.dart          # MySQL connection implementation
│       ├── dialect/
│       │   └── mysql_dialect.dart             # MySQL SQL dialect
│       └── generators/
│           └── mysql_repository_generator.dart # Code generator
├── build.yaml                                 # Build configuration
├── pubspec.yaml                               # Package dependencies
├── example/                                   # Usage examples
└── test/                                      # Test suite
```

### Dependencies

The package depends on:
- `dddart`: Core DDD framework (workspace)
- `dddart_serialization`: Serialization abstractions (workspace)
- `dddart_repository_sql`: Base SQL abstractions (workspace)
- `mysql1`: MySQL client library for Dart
- `analyzer`: Dart code analysis for code generation
- `source_gen`: Code generation utilities
- `build`: Build system

### Relationship to Base Package

```
┌─────────────────────────────────────┐
│   dddart_repository_sql (base)      │
│   - SqlConnection (abstract)        │
│   - SqlDialect (abstract)           │
│   - SchemaGenerator                 │
│   - RelationshipAnalyzer            │
│   - ObjectMapper                    │
│   - JoinBuilder                     │
│   - TableDefinition                 │
└─────────────────────────────────────┘
                  ▲
                  │ extends
                  │
┌─────────────────────────────────────┐
│   dddart_repository_mysql           │
│   - MysqlConnection                 │
│   - MysqlDialect                    │
│   - MysqlRepositoryGenerator        │
└─────────────────────────────────────┘
```

## Components and Interfaces

### 1. MysqlConnection

Implements the `SqlConnection` interface for MySQL database connectivity.

**Class Definition:**
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
  
  @override
  Future<void> open();
  
  @override
  Future<void> close();
  
  @override
  Future<void> execute(String sql, [List<Object?>? parameters]);
  
  @override
  Future<List<Map<String, Object?>>> query(String sql, [List<Object?>? parameters]);
  
  @override
  Future<T> transaction<T>(Future<T> Function() action);
  
  @override
  bool get isOpen;
}
```

**Implementation Details:**
- Uses `mysql1` package for MySQL connectivity
- Maintains a connection pool for concurrent operations
- Tracks transaction depth for nested transaction support
- Maps MySQL exceptions to `RepositoryException` types
- Validates connection state before operations

**Connection Pooling:**
- Default pool size: 5 connections
- Configurable via constructor parameter
- Connections are reused across operations
- Pool is closed when `close()` is called

**Transaction Management:**
- Supports nested transactions via depth tracking
- Only outermost transaction commits/rollbacks
- Inner transactions are no-ops
- Automatic rollback on exceptions

### 2. MysqlDialect

Implements the `SqlDialect` interface for MySQL-specific SQL syntax.

**Class Definition:**
```dart
class MysqlDialect implements SqlDialect {
  const MysqlDialect();
  
  @override
  String get uuidColumnType => 'BINARY(16)';
  
  @override
  String get textColumnType => 'VARCHAR(255)';
  
  @override
  String get integerColumnType => 'BIGINT';
  
  @override
  String get realColumnType => 'DOUBLE';
  
  @override
  String get booleanColumnType => 'TINYINT(1)';
  
  @override
  Object? encodeUuid(UuidValue uuid);
  
  @override
  UuidValue decodeUuid(Object? value);
  
  @override
  Object? encodeDateTime(DateTime dateTime);
  
  @override
  DateTime decodeDateTime(Object? value);
  
  @override
  String createTableIfNotExists(TableDefinition table);
  
  @override
  String insertOrReplace(String tableName, List<String> columns);
  
  @override
  String selectWithJoins(TableDefinition rootTable, List<JoinClause> joins);
  
  @override
  String delete(String tableName);
}
```

**Type Mappings:**

| Dart Type | MySQL Type | Encoding | Decoding |
|-----------|------------|----------|----------|
| UuidValue | BINARY(16) | UUID string → 16 bytes | 16 bytes → UUID string |
| String | VARCHAR(255) | Direct | Direct |
| int | BIGINT | Direct | Direct |
| double | DOUBLE | Direct | Direct |
| bool | TINYINT(1) | true=1, false=0 | 0=false, other=true |
| DateTime | TIMESTAMP | ISO 8601 string | String → DateTime |

**UUID Encoding:**
- Converts UUID string (36 chars with hyphens) to 16-byte binary
- Removes hyphens and converts hex pairs to bytes
- Efficient storage: 16 bytes vs 36 bytes for string
- Maintains sortability and indexing performance

**DateTime Encoding:**
- Uses MySQL TIMESTAMP type for timezone-aware storage
- Encodes as ISO 8601 string for compatibility
- Decodes back to Dart DateTime with timezone preservation
- Range: 1970-01-01 00:00:01 UTC to 2038-01-19 03:14:07 UTC

**SQL Generation:**

**CREATE TABLE:**
```sql
CREATE TABLE IF NOT EXISTS table_name (
  id BINARY(16) PRIMARY KEY NOT NULL,
  field1 VARCHAR(255) NOT NULL,
  field2 BIGINT,
  FOREIGN KEY (parent_id) REFERENCES parent(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

**INSERT OR REPLACE:**
```sql
INSERT INTO table_name (col1, col2, col3)
VALUES (?, ?, ?)
ON DUPLICATE KEY UPDATE
  col1 = VALUES(col1),
  col2 = VALUES(col2),
  col3 = VALUES(col3);
```

**SELECT WITH JOINS:**
```sql
SELECT t1.*, t2.*, t3.*
FROM table1 t1
LEFT JOIN table2 t2 ON t2.parent_id = t1.id
LEFT JOIN table3 t3 ON t3.parent_id = t1.id
WHERE t1.id = ?;
```

### 3. MysqlRepositoryGenerator

Generates MySQL repository implementations from annotated aggregate roots.

**Class Definition:**
```dart
class MysqlRepositoryGenerator extends GeneratorForAnnotation<GenerateMysqlRepository> {
  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  );
}
```

**Generation Process:**

1. **Validation:**
   - Verify element is a ClassElement
   - Verify class extends AggregateRoot
   - Verify class has @Serializable annotation

2. **Configuration Extraction:**
   - Extract table name (or generate from class name)
   - Extract custom interface (if specified)

3. **Object Graph Analysis:**
   - Use RelationshipAnalyzer to discover all types
   - Generate TableDefinitions for each type
   - Add parent foreign keys to entity tables

4. **Code Generation:**
   - Generate concrete class (if no custom interface)
   - Generate abstract base class (if custom interface with custom methods)
   - Generate CRUD methods (getById, save, deleteById)
   - Generate helper methods for multi-table persistence
   - Generate exception mapping

**Generated Repository Structure:**

```dart
class OrderMysqlRepository implements Repository<Order> {
  OrderMysqlRepository(this._connection);
  
  final MysqlConnection _connection;
  final _dialect = MysqlDialect();
  final _serializer = OrderJsonSerializer();
  
  String get tableName => 'orders';
  
  Future<void> createTables() async { /* ... */ }
  Future<Order> getById(UuidValue id) async { /* ... */ }
  Future<void> save(Order aggregate) async { /* ... */ }
  Future<void> deleteById(UuidValue id) async { /* ... */ }
  
  // Helper methods for multi-table persistence
  Future<void> _saveOrderItems(Order aggregate, Map<String, dynamic> json) async { /* ... */ }
  Future<List<Map<String, dynamic>>> _loadOrderItems(UuidValue aggregateId) async { /* ... */ }
  
  // Utility methods
  Map<String, dynamic> _flattenForTable(Map<String, dynamic> json, List<String> excludeKeys) { /* ... */ }
  Map<String, dynamic> _rowToJson(Map<String, Object?> row) { /* ... */ }
  Object? _encodeValue(dynamic value) { /* ... */ }
  dynamic _decodeValue(Object? value, String fieldName) { /* ... */ }
  RepositoryException _mapMysqlException(Object error, String operation) { /* ... */ }
}
```

## Data Models

### TableDefinition

Represents a MySQL table schema (inherited from base package):

```dart
class TableDefinition {
  final String tableName;
  final String className;
  final List<ColumnDefinition> columns;
  final List<ForeignKeyDefinition> foreignKeys;
  final bool isAggregateRoot;
}
```

### ColumnDefinition

Represents a table column (inherited from base package):

```dart
class ColumnDefinition {
  final String name;
  final String sqlType;
  final String dartType;
  final bool isNullable;
  final bool isPrimaryKey;
  final bool isForeignKey;
}
```

### ForeignKeyDefinition

Represents a foreign key constraint (inherited from base package):

```dart
class ForeignKeyDefinition {
  final String columnName;
  final String referencedTable;
  final String referencedColumn;
  final CascadeAction onDelete;
}
```

### Value Object Embedding

Value objects are embedded directly into parent tables with prefixed columns:

**Domain Model:**
```dart
class Order extends AggregateRoot {
  final Money totalAmount;  // Value object
  final Address shippingAddress;  // Value object
}

class Money {
  final double amount;
  final String currency;
}

class Address {
  final String street;
  final String city;
  final String country;
}
```

**Generated Schema:**
```sql
CREATE TABLE orders (
  id BINARY(16) PRIMARY KEY NOT NULL,
  createdAt TIMESTAMP NOT NULL,
  updatedAt TIMESTAMP NOT NULL,
  totalAmount_amount DOUBLE NOT NULL,
  totalAmount_currency VARCHAR(255) NOT NULL,
  shippingAddress_street VARCHAR(255) NOT NULL,
  shippingAddress_city VARCHAR(255) NOT NULL,
  shippingAddress_country VARCHAR(255) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

**Nullable Value Objects:**
```dart
class Order {
  final Address? billingAddress;  // Optional
}
```

All embedded columns become nullable:
```sql
billingAddress_street VARCHAR(255),
billingAddress_city VARCHAR(255),
billingAddress_country VARCHAR(255)
```

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Repository generation completeness
*For any* aggregate root annotated with `@GenerateMysqlRepository()`, the generator should produce valid Dart code that compiles without errors and implements the Repository interface.
**Validates: Requirements 1.1, 1.2, 1.3**

### Property 2: Object graph persistence round-trip
*For any* aggregate root with entities and value objects, saving the aggregate then loading it by ID should return an equivalent object (same field values, same nested entities, same value objects).
**Validates: Requirements 1.4, 6.4, 6.5**

### Property 3: Connection lifecycle correctness
*For any* MySQL connection, after calling `open()` the connection should be usable, and after calling `close()` the connection should throw StateError on operations.
**Validates: Requirements 2.2, 2.3, 2.4**

### Property 4: Connection error handling
*For any* invalid connection parameters (bad host, wrong credentials, etc.), attempting to open the connection should throw RepositoryException with type connection.
**Validates: Requirements 2.5, 7.1**

### Property 5: UUID encoding round-trip
*For any* UuidValue, encoding it to BINARY(16) then decoding should return an equivalent UuidValue.
**Validates: Requirements 3.1, 3.2**

### Property 6: DateTime encoding round-trip
*For any* DateTime, encoding it to TIMESTAMP then decoding should return an equivalent DateTime (within millisecond precision).
**Validates: Requirements 3.3, 3.4**

### Property 7: MySQL-specific SQL syntax
*For any* generated CREATE TABLE statement, it should contain `ENGINE=InnoDB` and `DEFAULT CHARSET=utf8mb4`.
**Validates: Requirements 3.5, 4.5, 4.6**

### Property 8: MySQL INSERT syntax
*For any* generated INSERT statement, it should use `INSERT ... ON DUPLICATE KEY UPDATE` syntax.
**Validates: Requirements 3.6**

### Property 9: Type mapping correctness
*For any* Dart type (UuidValue, String, int, double, bool, DateTime), the dialect should map it to the correct MySQL type (BINARY(16), VARCHAR(255), BIGINT, DOUBLE, TINYINT(1), TIMESTAMP).
**Validates: Requirements 3.7**

### Property 10: Schema generation completeness
*For any* aggregate root, calling `createTables()` should create all required tables (aggregate root table plus entity tables, but not value object tables).
**Validates: Requirements 4.1**

### Property 11: Schema creation idempotence
*For any* repository, calling `createTables()` multiple times should have the same effect as calling it once (no errors, same schema).
**Validates: Requirements 4.2**

### Property 12: Entity foreign key constraints
*For any* aggregate containing entities, the generated schema should include foreign key constraints with `ON DELETE CASCADE` from entity tables to the aggregate root table.
**Validates: Requirements 4.3**

### Property 13: Value object embedding
*For any* aggregate containing value objects, the generated schema should embed value object fields as prefixed columns in the parent table (not separate tables).
**Validates: Requirements 4.4, 6.1**

### Property 14: Nullable value object handling
*For any* nullable value object field, all embedded columns should be nullable in the schema.
**Validates: Requirements 6.2**

### Property 15: Non-nullable value object handling
*For any* non-nullable value object field, all embedded columns should be non-nullable in the schema.
**Validates: Requirements 6.3**

### Property 16: Transaction atomicity
*For any* aggregate save operation, either all tables are updated or none are (no partial writes on failure).
**Validates: Requirements 5.1, 5.2, 5.3**

### Property 17: Nested transaction handling
*For any* nested transaction sequence, only the outermost transaction should commit or rollback, and inner transactions should be no-ops.
**Validates: Requirements 5.4**

### Property 18: Custom query transaction context
*For any* custom query executed within a transaction, it should participate in the same transaction (commit/rollback together).
**Validates: Requirements 5.5, 8.4**

### Property 19: Duplicate key error mapping
*For any* duplicate key violation, the system should throw RepositoryException with type duplicate.
**Validates: Requirements 7.2**

### Property 20: Not found error handling
*For any* query for a non-existent ID, the system should throw RepositoryException with type notFound.
**Validates: Requirements 7.3**

### Property 21: Timeout error mapping
*For any* query timeout, the system should throw RepositoryException with type timeout.
**Validates: Requirements 7.4**

### Property 22: Unknown error mapping
*For any* unknown MySQL error, the system should throw RepositoryException with type unknown and include the original error details.
**Validates: Requirements 7.5**

### Property 23: Abstract base class generation
*For any* aggregate with a custom repository interface containing custom methods, the generator should produce an abstract base class with protected members exposed.
**Validates: Requirements 8.1, 8.2**

### Property 24: Deserialization helper availability
*For any* generated repository, deserialization helper methods should be available for reconstructing aggregates from query results.
**Validates: Requirements 8.5**

### Property 25: Repository interface consistency
*For any* generated MySQL repository, it should implement the same Repository<T> interface as SQLite repositories.
**Validates: Requirements 10.1, 10.4**

### Property 26: Code structure consistency
*For any* generated MySQL repository, it should follow the same structure and naming conventions as SQLite repositories (same method names, same helper method patterns).
**Validates: Requirements 10.3**

### Property 27: Multiple aggregate independence
*For any* set of multiple aggregate roots, each should generate an independent repository implementation that doesn't interfere with others.
**Validates: Requirements 1.5**

## Error Handling

### Exception Mapping

All MySQL errors are mapped to `RepositoryException` with appropriate types:

```dart
enum RepositoryExceptionType {
  notFound,      // Entity not found by ID
  duplicate,     // Unique constraint violation
  connection,    // Database connection error
  timeout,       // Query timeout
  unknown,       // Other database errors
}
```

### MySQL Error Patterns

| MySQL Error | RepositoryExceptionType | Detection Pattern |
|-------------|------------------------|-------------------|
| Duplicate entry | duplicate | Error code 1062 |
| Connection refused | connection | Error code 2003 |
| Access denied | connection | Error code 1045 |
| Unknown database | connection | Error code 1049 |
| Lock wait timeout | timeout | Error code 1205 |
| Query timeout | timeout | Error code 3024 |
| Other errors | unknown | Default fallback |

### Error Handling Strategy

```dart
RepositoryException _mapMysqlException(Object error, String operation) {
  if (error is MySqlException) {
    switch (error.errorNumber) {
      case 1062: // Duplicate entry
        return RepositoryException(
          'Duplicate key error during $operation',
          type: RepositoryExceptionType.duplicate,
          cause: error,
        );
      case 2003: // Connection refused
      case 1045: // Access denied
      case 1049: // Unknown database
        return RepositoryException(
          'Connection error during $operation: ${error.message}',
          type: RepositoryExceptionType.connection,
          cause: error,
        );
      case 1205: // Lock wait timeout
      case 3024: // Query timeout
        return RepositoryException(
          'Timeout during $operation',
          type: RepositoryExceptionType.timeout,
          cause: error,
        );
      default:
        return RepositoryException(
          'MySQL error during $operation: ${error.message}',
          type: RepositoryExceptionType.unknown,
          cause: error,
        );
    }
  }
  
  return RepositoryException(
    'Unknown error during $operation: $error',
    type: RepositoryExceptionType.unknown,
    cause: error,
  );
}
```

## Testing Strategy

### Unit Tests

Unit tests will cover:
- **MysqlConnection**: Connection lifecycle, transaction management, error handling
- **MysqlDialect**: Type encoding/decoding, SQL generation
- **MysqlRepositoryGenerator**: Code generation validation, annotation processing

### Property-Based Tests

Property-based tests will use the `test` package with custom generators to verify universal properties across many inputs. The testing framework will be Dart's built-in `test` package with custom property testing utilities.

**Property Test Configuration:**
- Minimum 100 iterations per property test
- Random seed for reproducibility
- Shrinking support for minimal failing examples

**Key Property Tests:**

1. **UUID Round-Trip (Property 5)**
   - Generate random UUIDs
   - Encode then decode
   - Verify equivalence

2. **DateTime Round-Trip (Property 6)**
   - Generate random DateTimes
   - Encode then decode
   - Verify equivalence (within precision)

3. **Object Graph Round-Trip (Property 2)**
   - Generate random aggregate roots with entities and value objects
   - Save then load
   - Verify equivalence

4. **Schema Generation Idempotence (Property 11)**
   - Generate random aggregate definitions
   - Call createTables() multiple times
   - Verify same result

5. **Transaction Atomicity (Property 16)**
   - Generate random aggregates
   - Force failures during save
   - Verify no partial writes

**Test Tagging:**
- Property tests tagged with `@Tags(['property-test'])`
- Tests requiring MySQL tagged with `@Tags(['requires-mysql'])`
- Integration tests tagged with `@Tags(['integration'])`

### Integration Tests

Integration tests will require a running MySQL instance:
- **Use Docker container for local development and CI/CD**
- Test against MySQL 8.0 (latest stable)
- Test full CRUD operations
- Test complex object graphs
- Test error scenarios
- Test custom repository interfaces

**Docker Test Infrastructure:**

The test suite will automatically start a MySQL Docker container if one is not already running. This ensures tests can run in any environment without manual setup.

```dart
// Test helper to manage MySQL Docker container
class MysqlTestContainer {
  static const String containerName = 'dddart_mysql_test';
  static const int port = 3307; // Use non-standard port to avoid conflicts
  
  /// Starts MySQL container if not already running
  static Future<void> start() async {
    // Check if container exists and is running
    final checkResult = await Process.run('docker', [
      'ps',
      '-a',
      '--filter',
      'name=$containerName',
      '--format',
      '{{.Status}}',
    ]);
    
    if (checkResult.stdout.toString().contains('Up')) {
      print('MySQL container already running');
      return;
    }
    
    // Remove old container if exists
    await Process.run('docker', ['rm', '-f', containerName]);
    
    // Start new container
    print('Starting MySQL test container...');
    await Process.run('docker', [
      'run',
      '--name', containerName,
      '-e', 'MYSQL_ROOT_PASSWORD=test_password',
      '-e', 'MYSQL_DATABASE=test_db',
      '-p', '$port:3306',
      '-d',
      'mysql:8.0',
      '--default-authentication-plugin=mysql_native_password',
    ]);
    
    // Wait for MySQL to be ready
    await _waitForMysql();
  }
  
  /// Waits for MySQL to be ready to accept connections
  static Future<void> _waitForMysql() async {
    print('Waiting for MySQL to be ready...');
    for (var i = 0; i < 30; i++) {
      try {
        final connection = MysqlConnection(
          host: 'localhost',
          port: port,
          database: 'test_db',
          user: 'root',
          password: 'test_password',
        );
        await connection.open();
        await connection.close();
        print('MySQL is ready!');
        return;
      } catch (e) {
        await Future.delayed(Duration(seconds: 1));
      }
    }
    throw Exception('MySQL failed to start within 30 seconds');
  }
  
  /// Stops and removes the MySQL container
  static Future<void> stop() async {
    await Process.run('docker', ['stop', containerName]);
    await Process.run('docker', ['rm', containerName]);
  }
  
  /// Creates a test connection to the MySQL container
  static MysqlConnection createConnection() {
    return MysqlConnection(
      host: 'localhost',
      port: port,
      database: 'test_db',
      user: 'root',
      password: 'test_password',
    );
  }
}
```

**Test Setup:**

```dart
void main() {
  setUpAll(() async {
    // Start MySQL container before all tests
    await MysqlTestContainer.start();
  });
  
  tearDownAll(() async {
    // Stop MySQL container after all tests
    await MysqlTestContainer.stop();
  });
  
  group('MySQL Repository Integration Tests', () {
    late MysqlConnection connection;
    
    setUp(() async {
      connection = MysqlTestContainer.createConnection();
      await connection.open();
    });
    
    tearDown(() async {
      // Clean up test data
      await connection.execute('DROP DATABASE IF EXISTS test_db');
      await connection.execute('CREATE DATABASE test_db');
      await connection.execute('USE test_db');
      await connection.close();
    });
    
    test('should save and retrieve aggregate', () async {
      // Test implementation
    });
  });
}
```

**CI/CD Integration:**

The GitHub Actions workflow will use the same Docker-based approach:

```yaml
- name: Start MySQL container
  run: |
    docker run --name dddart_mysql_test \
      -e MYSQL_ROOT_PASSWORD=test_password \
      -e MYSQL_DATABASE=test_db \
      -p 3307:3306 \
      -d mysql:8.0 \
      --default-authentication-plugin=mysql_native_password
    
    # Wait for MySQL to be ready
    for i in {1..30}; do
      if docker exec dddart_mysql_test mysqladmin ping -h localhost -u root -ptest_password &> /dev/null; then
        echo "MySQL is ready!"
        break
      fi
      echo "Waiting for MySQL..."
      sleep 1
    done

- name: Run tests
  run: dart test

- name: Stop MySQL container
  if: always()
  run: docker stop dddart_mysql_test && docker rm dddart_mysql_test
```

This approach ensures:
- Tests can run locally without manual MySQL setup
- Tests run in CI/CD with consistent environment
- No conflicts with existing MySQL installations
- Clean state for each test run
- Automatic cleanup after tests

### Test Utilities

```dart
// Generator for random aggregate roots
AggregateRoot generateRandomAggregate();

// Generator for random UUIDs
UuidValue generateRandomUuid();

// Generator for random DateTimes
DateTime generateRandomDateTime();

// MySQL test container management
Future<MysqlConnection> createTestConnection();
Future<void> cleanupTestDatabase(MysqlConnection connection);
```

## Performance Considerations

### Connection Pooling

- Default pool size: 5 connections
- Configurable via constructor
- Connections reused across operations
- Automatic connection recycling

### Query Optimization

- Use prepared statements for all queries
- Minimize round-trips with batch operations
- Use transactions to group related operations
- Index on UUID columns for fast lookups

### Value Object Embedding Benefits

- No JOINs required for value objects
- Reduced query complexity
- Better query performance
- Simpler schema

### Potential Bottlenecks

- Network latency to MySQL server
- Large object graphs with many entities
- Concurrent writes to same aggregate
- Connection pool exhaustion

## Security Considerations

### SQL Injection Prevention

- All queries use prepared statements with parameterized values
- No string concatenation for SQL generation
- User input never directly embedded in SQL

### Connection Security

- Support for SSL/TLS connections
- Encrypted credentials in connection string
- Connection timeout to prevent hanging connections

### Access Control

- Repository operations respect MySQL user permissions
- No privilege escalation
- Audit logging via MySQL's built-in logging

## Deployment Considerations

### MySQL Version Requirements

- Minimum: MySQL 5.7
- Recommended: MySQL 8.0
- InnoDB engine required for foreign key support
- utf8mb4 charset required for full Unicode support

### Configuration

```dart
final connection = MysqlConnection(
  host: 'localhost',
  port: 3306,
  database: 'myapp',
  user: 'myapp_user',
  password: 'secure_password',
  maxConnections: 10,  // Adjust based on load
  timeout: Duration(seconds: 30),
);
```

### Production Best Practices

- Use connection pooling (default: 5, increase for high load)
- Set appropriate timeouts
- Monitor connection pool usage
- Use read replicas for read-heavy workloads
- Regular backups of MySQL database
- Monitor slow query log
- Use indexes on frequently queried columns

### Migration from SQLite

To migrate from SQLite to MySQL:

1. Change annotation: `@GenerateSqliteRepository()` → `@GenerateMysqlRepository()`
2. Change connection type: `SqliteConnection` → `MysqlConnection`
3. Run code generation: `dart run build_runner build`
4. Update connection configuration (add host, port, credentials)
5. Export data from SQLite and import to MySQL (schema is compatible)

No changes to domain models or business logic required.
