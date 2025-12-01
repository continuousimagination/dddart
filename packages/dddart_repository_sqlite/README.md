# dddart_repository_sqlite

SQLite repository implementation for DDDart aggregate roots with automatic code generation.

## Features

- 🗄️ **Full Normalization**: Every class gets its own table with proper columns and foreign keys
- 🔄 **Automatic Schema Generation**: Tables created from aggregate root definitions
- 💎 **Value Object Embedding**: Value objects flattened into parent tables with prefixed columns
- 🔗 **Relationship Mapping**: Automatic foreign key generation and JOIN handling
- 🔒 **Transaction Support**: Multi-table operations wrapped in transactions
- 🎯 **Type Safety**: Compile-time code generation ensures type-safe operations
- 📱 **Cross-Platform**: Works on iOS, Android, Windows, macOS, Linux, and Web
- 🚀 **Zero Boilerplate**: Annotate your aggregate roots and generate repositories

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  dddart: ^0.9.0
  dddart_json: ^0.9.0
  dddart_repository_sqlite: ^0.9.0

dev_dependencies:
  build_runner: ^2.4.0
```

## Quick Start

### 1. Define Your Domain Model

```dart
import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_repository_sqlite/dddart_repository_sqlite.dart';

@Serializable()
@GenerateSqliteRepository()
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
  final connection = SqliteConnection.file('orders.db');
  await connection.open();

  // Create repository
  final repository = OrderSqliteRepository(connection);

  // Create tables
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

  // Delete the order
  await repository.deleteById(order.id);

  await connection.close();
}
```

## How It Works

### Schema Generation

The generator analyzes your aggregate root and creates normalized tables:

```sql
-- Value objects are embedded as columns with prefixes
CREATE TABLE orders (
  id BLOB PRIMARY KEY NOT NULL,
  createdAt INTEGER NOT NULL,
  updatedAt INTEGER NOT NULL,
  customerId BLOB NOT NULL,
  totalAmount_amount REAL NOT NULL,      -- Embedded Money
  totalAmount_currency TEXT NOT NULL     -- Embedded Money
);

-- Entities get their own tables with foreign keys
CREATE TABLE order_items (
  id BLOB PRIMARY KEY NOT NULL,
  order_id BLOB NOT NULL,
  productId BLOB NOT NULL,
  quantity INTEGER NOT NULL,
  price_amount REAL NOT NULL,            -- Embedded Money
  price_currency TEXT NOT NULL,          -- Embedded Money
  FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE
);
```

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
  id BLOB PRIMARY KEY,
  -- Money value object embedded with prefix
  totalAmount_amount REAL NOT NULL,
  totalAmount_currency TEXT NOT NULL,
  -- Address value object embedded with prefix
  shippingAddress_street TEXT NOT NULL,
  shippingAddress_city TEXT NOT NULL,
  shippingAddress_country TEXT NOT NULL
);
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
  billingAddress_street TEXT,      -- Nullable
  billingAddress_city TEXT,        -- Nullable
  billingAddress_country TEXT      -- Nullable
);
```

**Why Not Separate Tables?**

Value objects don't have identity in DDD, so they shouldn't have their own tables with primary keys. Embedding them:
- Reflects their nature as attributes, not entities
- Avoids unnecessary JOINs
- Simplifies queries and improves performance
- Prevents accidental sharing between aggregates

### Transaction Safety

All multi-table operations are wrapped in transactions:

```dart
await repository.save(order);  // Saves to multiple tables atomically
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
@GenerateSqliteRepository(implements: OrderRepository)
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
// Generated: OrderSqliteRepository (abstract base class)
// You implement: OrderSqliteRepositoryImpl

class OrderSqliteRepositoryImpl extends OrderSqliteRepository {
  OrderSqliteRepositoryImpl(super.connection);

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

- `connection`: The `SqliteConnection` instance
- `dialect`: The `SqliteDialect` instance for encoding/decoding
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

## Platform Support

Works on all platforms via the `sqlite3` package:

- 📱 iOS and Android (mobile apps)
- 💻 Windows, macOS, Linux (desktop apps)
- 🌐 Web (WASM-based SQLite)
- 🧪 In-memory databases for testing

## Connection Management

### File-based Database

```dart
final connection = SqliteConnection.file('path/to/database.db');
await connection.open();
// Use connection
await connection.close();
```

### In-memory Database

```dart
final connection = SqliteConnection.memory();
await connection.open();
// Use connection (data lost when closed)
await connection.close();
```

### Best Practices

**Always close connections:**
```dart
final connection = SqliteConnection.file('app.db');
try {
  await connection.open();
  final repository = OrderSqliteRepository(connection);
  // Use repository
} finally {
  await connection.close();
}
```

**Reuse connections:**
```dart
// Good: One connection shared across repositories
final connection = SqliteConnection.file('app.db');
await connection.open();

final orderRepo = OrderSqliteRepository(connection);
final customerRepo = CustomerSqliteRepository(connection);

// Use both repositories with same connection
```

**Use in-memory for tests:**
```dart
test('order repository saves and retrieves', () async {
  final connection = SqliteConnection.memory();
  await connection.open();
  
  final repository = OrderSqliteRepository(connection);
  await repository.createTables();
  
  // Test repository operations
  
  await connection.close();
});
```

### PRAGMA foreign_keys Requirement

**CRITICAL**: SQLite has foreign key constraints **disabled by default**. The `SqliteConnection` automatically enables them when opening:

```dart
// This is done automatically by SqliteConnection.open()
PRAGMA foreign_keys = ON;
```

**Why this matters:**
- Without this, CASCADE DELETE will not work
- Orphaned rows will remain in child tables
- Referential integrity is not enforced

**Verification:**
```dart
final result = await connection.query('PRAGMA foreign_keys');
print(result); // Should return [{foreign_keys: 1}]
```

If you're using a custom connection implementation, you **must** enable foreign keys or cascade deletes won't work.

## Error Handling

All database errors are mapped to `RepositoryException` for consistent error handling:

### Exception Types

```dart
enum RepositoryExceptionType {
  notFound,      // Entity not found by ID
  duplicate,     // Unique constraint violation
  connection,    // Database connection error
  timeout,       // Query timeout
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

**Duplicate Key:**
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

**Connection Errors:**
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
  print('Original error: ${e.originalError}');
  print('Stack trace: ${e.stackTrace}');
}
```

## Requirements

- Dart SDK >=3.5.0
- Aggregate roots must extend `AggregateRoot`
- Aggregate roots must have `@Serializable()` annotation
- Run `build_runner` to generate repository code

## Documentation

For more information, see:

- [DDDart Core Documentation](https://github.com/continuousimagination/dddart)
- [Base SQL Package](../dddart_repository_sql)
- [Example Applications](./example)

## License

MIT License - see [LICENSE](LICENSE) file for details.
