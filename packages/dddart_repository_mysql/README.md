# dddart_repository_mysql

MySQL database repository implementation for DDDart aggregate roots with automatic code generation support.

## Features

- 🗄️ **Full Normalization**: Every class gets its own table with proper columns and foreign keys
- 🔄 **Automatic Schema Generation**: Tables created with InnoDB engine and utf8mb4 charset
- 💎 **Value Object Embedding**: Value objects flattened into parent tables with prefixed columns
- 🔗 **Relationship Mapping**: Automatic foreign key generation with CASCADE DELETE
- 🔒 **Transaction Support**: Multi-table operations with nested transaction handling
- 🔌 **Connection Pooling**: Configurable connection pool for concurrent operations
- 🎯 **Type Safety**: Compile-time code generation ensures type-safe operations
- 🚀 **Zero Boilerplate**: Annotate your aggregate roots and generate repositories
- 🔐 **Efficient UUID Storage**: UUIDs stored as BINARY(16) for optimal performance
- 🌐 **Production Ready**: Built for MySQL 5.7+ with best practices

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  dddart: ^0.9.0
  dddart_serialization: ^0.9.0
  dddart_repository_mysql: ^0.9.0

dev_dependencies:
  build_runner: ^2.4.0
  dddart_json: ^0.9.0
```

## Quick Start

### 1. Define Your Domain Model

```dart
import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_repository_mysql/dddart_repository_mysql.dart';

@Serializable()
@GenerateMysqlRepository(tableName: 'orders')
class Order extends AggregateRoot {
  Order({
    required UuidValue id,
    required this.customerId,
    required this.totalAmount,
    required this.items,
  }) : super(id);

  final UuidValue customerId;
  final Money totalAmount;  // Value object (embedded)
  final List<OrderItem> items;  // Entities (separate table)
}

@Serializable()
class OrderItem {
  OrderItem({
    required this.productId,
    required this.quantity,
    required this.price,
  });

  final UuidValue productId;
  final int quantity;
  final Money price;  // Value object (embedded)
}

@Serializable()
class Money {
  Money({required this.amount, required this.currency});
  final double amount;
  final String currency;
}
```

### 2. Generate Repository Code

```bash
dart run build_runner build
```

### 3. Use the Repository

```dart
void main() async {
  // Create connection
  final connection = MysqlConnection(
    host: 'localhost',
    port: 3306,
    database: 'myapp',
    user: 'myapp_user',
    password: 'secure_password',
    maxConnections: 10,  // Connection pool size
  );
  await connection.open();

  // Create repository
  final repository = OrderMysqlRepository(connection);

  // Create tables (idempotent - safe to call multiple times)
  await repository.createTables();

  // Save an order
  final order = Order(
    id: UuidValue.generate(),
    customerId: UuidValue.generate(),
    totalAmount: Money(amount: 99.99, currency: 'USD'),
    items: [
      OrderItem(
        productId: UuidValue.generate(),
        quantity: 2,
        price: Money(amount: 49.99, currency: 'USD'),
      ),
    ],
  );
  await repository.save(order);

  // Retrieve the order
  final retrieved = await repository.getById(order.id);
  print('Order total: ${retrieved.totalAmount.amount}');

  // Delete the order (cascades to items)
  await repository.deleteById(order.id);

  await connection.close();
}
```

## How It Works

### Schema Generation

The generator analyzes your aggregate root and creates normalized MySQL tables:

```sql
-- Value objects are embedded as columns with prefixes
CREATE TABLE IF NOT EXISTS orders (
  id BINARY(16) PRIMARY KEY NOT NULL,
  createdAt TIMESTAMP NOT NULL,
  updatedAt TIMESTAMP NOT NULL,
  customerId BINARY(16) NOT NULL,
  totalAmount_amount DOUBLE NOT NULL,      -- Embedded Money
  totalAmount_currency VARCHAR(255) NOT NULL     -- Embedded Money
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Entities get their own tables with foreign keys
CREATE TABLE IF NOT EXISTS order_items (
  id BINARY(16) PRIMARY KEY NOT NULL,
  order_id BINARY(16) NOT NULL,
  productId BINARY(16) NOT NULL,
  quantity BIGINT NOT NULL,
  price_amount DOUBLE NOT NULL,            -- Embedded Money
  price_currency VARCHAR(255) NOT NULL,          -- Embedded Money
  FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### MySQL-Specific Features

**InnoDB Engine:**
- ACID transactions
- Foreign key constraint enforcement
- Row-level locking for concurrency

**utf8mb4 Charset:**
- Full Unicode support (including emojis)
- 4-byte UTF-8 encoding
- International character support

**BINARY(16) for UUIDs:**
- 16 bytes vs 36 bytes for string representation
- Faster indexing and lookups
- Maintains sortability

**INSERT ... ON DUPLICATE KEY UPDATE:**
- Efficient upsert operations
- Single query for insert or update
- Reduces round trips

### Value Object Embedding Strategy

Value objects are **embedded directly** into parent tables with prefixed column names. This is a key design decision that simplifies the schema and improves performance.

**Example:**
```dart
class Order {
  final Money totalAmount;
  final Address shippingAddress;
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
  id BINARY(16) PRIMARY KEY,
  -- Money value object embedded with prefix
  totalAmount_amount DOUBLE NOT NULL,
  totalAmount_currency VARCHAR(255) NOT NULL,
  -- Address value object embedded with prefix
  shippingAddress_street VARCHAR(255) NOT NULL,
  shippingAddress_city VARCHAR(255) NOT NULL,
  shippingAddress_country VARCHAR(255) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

**Benefits:**
- ✅ No extra tables or JOINs needed
- ✅ Simple, flat schema
- ✅ Direct SQL queries: `WHERE totalAmount_amount > 100`
- ✅ Better query performance
- ✅ Aligned with DDD principles (value objects have no identity)
- ✅ No foreign key complexity

**Nullable Value Objects:**
```dart
class Order {
  final Address? billingAddress;  // Optional
}
```

All embedded columns become nullable:
```sql
CREATE TABLE orders (
  billingAddress_street VARCHAR(255),      -- Nullable
  billingAddress_city VARCHAR(255),        -- Nullable
  billingAddress_country VARCHAR(255)      -- Nullable
);
```

**Why Not Separate Tables?**

Value objects don't have identity in DDD, so they shouldn't have their own tables with primary keys. Embedding them:
- Reflects their nature as attributes, not entities
- Avoids unnecessary JOINs
- Simplifies queries and improves performance
- Prevents accidental sharing between aggregates

### Transaction Safety

All multi-table operations are wrapped in MySQL transactions:

```dart
await repository.save(order);  // Saves to multiple tables atomically
```

**Nested Transactions:**
```dart
await connection.transaction(() async {
  await repository.save(order1);
  
  await connection.transaction(() async {
    // Inner transaction - tracked but not committed separately
    await repository.save(order2);
  });
  
  // Only outer transaction commits
});
```

## MySQL Configuration

### Connection Parameters

```dart
final connection = MysqlConnection(
  host: 'localhost',           // MySQL server host
  port: 3306,                  // MySQL server port
  database: 'myapp',           // Database name
  user: 'myapp_user',          // MySQL user
  password: 'secure_password', // MySQL password
  maxConnections: 10,          // Connection pool size (default: 5)
  timeout: Duration(seconds: 30), // Connection timeout (default: 30s)
);
```

### Connection Pooling

The MySQL connection maintains a pool of reusable connections:

**Pool Size:**
- Default: 5 connections
- Increase for high-concurrency applications
- Monitor pool usage in production

**Benefits:**
- Reduced connection overhead
- Better resource utilization
- Improved throughput under load

**Example:**
```dart
// High-traffic application
final connection = MysqlConnection(
  host: 'db.example.com',
  port: 3306,
  database: 'production_db',
  user: 'app_user',
  password: env['DB_PASSWORD']!,
  maxConnections: 20,  // Larger pool for high concurrency
);
```

### SSL/TLS Connections

For secure connections to MySQL:

```dart
// Note: SSL support depends on mysql_client package configuration
final connection = MysqlConnection(
  host: 'secure-db.example.com',
  port: 3306,
  database: 'myapp',
  user: 'myapp_user',
  password: 'secure_password',
  // SSL configuration via mysql_client package
);
```

### Production Best Practices

**1. Use Environment Variables:**
```dart
final connection = MysqlConnection(
  host: Platform.environment['DB_HOST'] ?? 'localhost',
  port: int.parse(Platform.environment['DB_PORT'] ?? '3306'),
  database: Platform.environment['DB_NAME']!,
  user: Platform.environment['DB_USER']!,
  password: Platform.environment['DB_PASSWORD']!,
  maxConnections: int.parse(Platform.environment['DB_POOL_SIZE'] ?? '10'),
);
```

**2. Connection Lifecycle Management:**
```dart
final connection = MysqlConnection(/* ... */);
try {
  await connection.open();
  
  // Use connection for application lifetime
  final orderRepo = OrderMysqlRepository(connection);
  final customerRepo = CustomerMysqlRepository(connection);
  
  // Run application
  await runApplication(orderRepo, customerRepo);
} finally {
  await connection.close();
}
```

**3. Health Checks:**
```dart
Future<bool> isDatabaseHealthy(MysqlConnection connection) async {
  try {
    await connection.query('SELECT 1');
    return true;
  } catch (e) {
    return false;
  }
}
```

**4. Monitoring:**
- Monitor connection pool usage
- Track query performance
- Set up slow query logging in MySQL
- Monitor transaction rollback rates

**5. Indexing:**
```sql
-- Add indexes for frequently queried columns
CREATE INDEX idx_orders_customer ON orders(customerId);
CREATE INDEX idx_orders_created ON orders(createdAt);
```

## Custom Repository Interfaces

You can extend generated repositories with custom query methods for domain-specific operations.

### Define Custom Interface

```dart
abstract class OrderRepository implements Repository<Order> {
  Future<List<Order>> findByCustomerId(UuidValue customerId);
  Future<List<Order>> findByDateRange(DateTime start, DateTime end);
  Future<double> getTotalRevenue();
}

@Serializable()
@GenerateMysqlRepository(
  tableName: 'orders',
  implements: OrderRepository,
)
class Order extends AggregateRoot {
  Order({
    required UuidValue id,
    required this.customerId,
    required this.totalAmount,
    required this.createdAt,
  }) : super(id);

  final UuidValue customerId;
  final Money totalAmount;
  final DateTime createdAt;
}
```

### Implement Custom Methods

The generator creates an abstract base class when you specify a custom interface:

```dart
// Generated: OrderMysqlRepository (abstract base class)
// You implement: OrderMysqlRepositoryImpl

class OrderMysqlRepositoryImpl extends OrderMysqlRepository {
  OrderMysqlRepositoryImpl(super.connection);

  @override
  Future<List<Order>> findByCustomerId(UuidValue customerId) async {
    final rows = await connection.query(
      'SELECT * FROM orders WHERE customerId = ?',
      [dialect.encodeUuid(customerId)],
    );
    return rows.map((row) => deserializeOrder(row)).toList();
  }

  @override
  Future<List<Order>> findByDateRange(DateTime start, DateTime end) async {
    final rows = await connection.query(
      'SELECT * FROM orders WHERE createdAt BETWEEN ? AND ?',
      [dialect.encodeDateTime(start), dialect.encodeDateTime(end)],
    );
    return rows.map((row) => deserializeOrder(row)).toList();
  }

  @override
  Future<double> getTotalRevenue() async {
    final result = await connection.query(
      'SELECT SUM(totalAmount_amount) as total FROM orders',
    );
    return result.first['total'] as double? ?? 0.0;
  }
}
```

### Protected Members

The generated base class exposes protected members for custom implementations:

- `connection`: The `MysqlConnection` instance
- `dialect`: The `MysqlDialect` instance for encoding/decoding
- `serializer`: The JSON serializer for the aggregate
- `deserializeOrder()`: Helper to reconstruct aggregates from rows
- `serializeOrder()`: Helper to convert aggregates to rows

### Complex Queries with JOINs

```dart
@override
Future<List<Order>> findOrdersWithItems() async {
  final rows = await connection.query('''
    SELECT 
      o.*,
      oi.id as item_id,
      oi.productId,
      oi.quantity,
      oi.price_amount,
      oi.price_currency
    FROM orders o
    LEFT JOIN order_items oi ON oi.order_id = o.id
    ORDER BY o.id, oi.id
  ''');
  
  // Group rows by order and reconstruct object graph
  return reconstructOrdersWithItems(rows);
}
```

### Transaction Context

Custom queries participate in the same transaction context:

```dart
@override
Future<void> transferOrder(UuidValue orderId, UuidValue newCustomerId) async {
  await connection.transaction(() async {
    // Update order
    await connection.execute(
      'UPDATE orders SET customerId = ? WHERE id = ?',
      [dialect.encodeUuid(newCustomerId), dialect.encodeUuid(orderId)],
    );
    
    // Log transfer (hypothetical audit table)
    await connection.execute(
      'INSERT INTO order_transfers (orderId, newCustomerId, transferredAt) VALUES (?, ?, ?)',
      [dialect.encodeUuid(orderId), dialect.encodeUuid(newCustomerId), DateTime.now()],
    );
  });
}
```

## Error Handling

All MySQL errors are mapped to `RepositoryException` for consistent error handling:

### Exception Types

```dart
enum RepositoryExceptionType {
  notFound,      // Entity not found by ID
  duplicate,     // Unique constraint violation (error 1062)
  connection,    // Database connection error (errors 2003, 1045, 1049)
  timeout,       // Query timeout (errors 1205, 3024)
  unknown,       // Other database errors
}
```

### Basic Error Handling

```dart
try {
  final order = await repository.getById(orderId);
} on RepositoryException catch (e) {
  switch (e.type) {
    case RepositoryExceptionType.notFound:
      print('Order not found');
    case RepositoryExceptionType.duplicate:
      print('Duplicate order');
    case RepositoryExceptionType.connection:
      print('Database connection error');
    case RepositoryExceptionType.timeout:
      print('Query timeout');
    default:
      print('Unknown error: ${e.message}');
  }
}
```

### Handling Specific Errors

**Not Found:**
```dart
try {
  final order = await repository.getById(orderId);
  return order;
} on RepositoryException catch (e) {
  if (e.type == RepositoryExceptionType.notFound) {
    return null; // Or throw domain-specific exception
  }
  rethrow;
}
```

**Duplicate Key (MySQL Error 1062):**
```dart
try {
  await repository.save(order);
} on RepositoryException catch (e) {
  if (e.type == RepositoryExceptionType.duplicate) {
    throw DomainException('Order with this ID already exists');
  }
  rethrow;
}
```

**Connection Errors (MySQL Errors 2003, 1045, 1049):**
```dart
try {
  await connection.open();
} on RepositoryException catch (e) {
  if (e.type == RepositoryExceptionType.connection) {
    // Retry logic or fallback
    await Future.delayed(Duration(seconds: 1));
    await connection.open();
  }
}
```

**Timeout Errors (MySQL Errors 1205, 3024):**
```dart
try {
  final orders = await repository.getAll();
} on RepositoryException catch (e) {
  if (e.type == RepositoryExceptionType.timeout) {
    // Handle timeout - maybe return cached data
    return getCachedOrders();
  }
  rethrow;
}
```

### Transaction Rollback

Transactions automatically rollback on error:

```dart
try {
  await repository.save(order); // Multi-table operation in transaction
} on RepositoryException catch (e) {
  // Transaction was rolled back automatically
  // No partial writes in database
  print('Save failed, transaction rolled back: ${e.message}');
}
```

### Accessing Original Error

```dart
try {
  await repository.save(order);
} on RepositoryException catch (e) {
  print('Repository error: ${e.message}');
  print('Error type: ${e.type}');
  if (e.cause != null) {
    print('Original MySQL error: ${e.cause}');
  }
}
```

## Migration from SQLite to MySQL

Migrating from `dddart_repository_sqlite` to `dddart_repository_mysql` is straightforward:

### 1. Update Dependencies

```yaml
dependencies:
  # dddart_repository_sqlite: ^0.9.0  # Remove
  dddart_repository_mysql: ^0.9.0     # Add
```

### 2. Update Annotations

```dart
// Before
@GenerateSqliteRepository()
class Order extends AggregateRoot { /* ... */ }

// After
@GenerateMysqlRepository(tableName: 'orders')
class Order extends AggregateRoot { /* ... */ }
```

### 3. Update Connection Type

```dart
// Before
final connection = SqliteConnection.file('orders.db');

// After
final connection = MysqlConnection(
  host: 'localhost',
  port: 3306,
  database: 'myapp',
  user: 'myapp_user',
  password: 'secure_password',
);
```

### 4. Regenerate Code

```bash
dart run build_runner clean
dart run build_runner build
```

### 5. Update Repository Instantiation

```dart
// Before
final repository = OrderSqliteRepository(connection);

// After
final repository = OrderMysqlRepository(connection);
```

### 6. Data Migration (Optional)

If you need to migrate existing data:

```dart
// Export from SQLite
final sqliteConn = SqliteConnection.file('orders.db');
await sqliteConn.open();
final sqliteRepo = OrderSqliteRepository(sqliteConn);
final orders = await sqliteRepo.getAll();

// Import to MySQL
final mysqlConn = MysqlConnection(/* ... */);
await mysqlConn.open();
final mysqlRepo = OrderMysqlRepository(mysqlConn);
await mysqlRepo.createTables();

for (final order in orders) {
  await mysqlRepo.save(order);
}

await sqliteConn.close();
await mysqlConn.close();
```

### Key Differences

| Feature | SQLite | MySQL |
|---------|--------|-------|
| Connection | File or in-memory | Network (host, port, credentials) |
| UUID Storage | BLOB | BINARY(16) |
| DateTime Storage | INTEGER (Unix timestamp) | TIMESTAMP |
| Engine | N/A | InnoDB |
| Charset | N/A | utf8mb4 |
| Connection Pooling | No | Yes (configurable) |
| Upsert Syntax | INSERT OR REPLACE | INSERT ... ON DUPLICATE KEY UPDATE |

**No changes required to:**
- Domain models
- Business logic
- Value object embedding strategy
- Transaction handling
- Error handling patterns

## Requirements

- Dart SDK >=3.5.0
- **MySQL 5.7+ (MySQL 8.0+ recommended)**
  - Full support for MySQL 8.0+ default authentication (caching_sha2_password)
  - No legacy authentication plugins required
  - InnoDB storage engine
- Aggregate roots must extend `AggregateRoot`
- Aggregate roots must have `@Serializable()` annotation
- Run `build_runner` to generate repository code

## Version 2.0 Migration Guide

### What's New in 2.0

Version 2.0 migrates from the `mysql1` driver to `mysql_client`, providing:

- ✅ **Native MySQL 8.0+ Support**: Full support for `caching_sha2_password` authentication
- ✅ **Improved Stability**: Fixes connection issues and "packets out of order" errors
- ✅ **Better Error Handling**: Enhanced error messages with more context
- ✅ **No Workarounds Needed**: No need for `mysql_native_password` plugin

### Breaking Changes

**Driver Change:**
- The underlying MySQL driver has changed from `mysql1` to `mysql_client`
- This is a major version bump (2.0.0) to indicate the driver change

**Minimum MySQL Version:**
- MySQL 5.7+ is required (MySQL 8.0+ recommended)
- MySQL 8.0 with default authentication is fully supported

### Migration Steps

For most users, upgrading is simple:

**1. Update your `pubspec.yaml`:**
```yaml
dependencies:
  dddart_repository_mysql: ^2.0.0  # Update from ^1.x
```

**2. Run pub get:**
```bash
dart pub get
```

**3. Test your application:**
- Run your existing tests
- Verify database operations work correctly
- No code changes should be required

**4. Remove MySQL 8.0 workarounds (if any):**

If you were using MySQL 8.0 with the legacy authentication workaround, you can now remove it:

```sql
-- You can remove this workaround:
-- ALTER USER 'myapp_user'@'%' IDENTIFIED WITH mysql_native_password BY 'password';

-- MySQL 8.0 default authentication now works:
CREATE USER 'myapp_user'@'%' IDENTIFIED BY 'password';
```

### What Stays the Same

- ✅ All public APIs remain unchanged
- ✅ Generated repository code is compatible
- ✅ SQL generation produces identical output
- ✅ Transaction semantics are identical
- ✅ Error handling patterns are the same
- ✅ No regeneration of code required

### Custom Repository Implementations

If you have custom repository implementations that directly import or use `mysql1` types:

**1. Check for direct mysql1 imports:**
```dart
// If you have this:
import 'package:mysql1/mysql1.dart';

// You may need to update to:
import 'package:mysql_client/mysql_client.dart';
```

**2. Update mysql1-specific type references (if any)**

**3. Test thoroughly:**
- Run all custom repository tests
- Verify custom queries work correctly

### Troubleshooting

**Connection Issues:**
- Ensure MySQL 5.7+ or 8.0+ is running
- Verify connection parameters (host, port, user, password)
- Check that the database exists and user has proper permissions

**Authentication Issues:**
- MySQL 8.0 default authentication (caching_sha2_password) is now fully supported
- No need to use mysql_native_password plugin

**Test Failures:**
- Run `dart test` to verify all tests pass
- Check that MySQL server is accessible
- Verify test database configuration

**Need Help?**
- Check the [CHANGELOG](CHANGELOG.md) for detailed changes
- Review the [example code](./example) for updated patterns
- Open an issue on GitHub if you encounter problems

## Documentation

For more information, see:

- [DDDart Core Documentation](https://github.com/continuousimagination/dddart)
- [Base SQL Package](../dddart_repository_sql)
- [Example Applications](./example)

## License

MIT License - see [LICENSE](LICENSE) file for details.
