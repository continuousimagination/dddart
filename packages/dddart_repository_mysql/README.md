# dddart_repository_mysql

MySQL database repository implementation for DDDart aggregate roots with automatic code generation support.

## Features

- 🗄️ **Full Normalization**: Every class gets its own table with proper columns and foreign keys
- 🔄 **Automatic Schema Generation**: Tables created with InnoDB engine and utf8mb4 charset
- 💎 **Value Object Embedding**: Value objects flattened into parent tables with prefixed columns
- 🔗 **Relationship Mapping**: Automatic foreign key generation with CASCADE DELETE
- 📦 **Collection Support**: Full support for List, Set, and Map collections with primitives, value objects, and entities
- 🔒 **Transaction Support**: Multi-table operations with nested transaction handling
- 🔌 **Connection Pooling**: Configurable connection pool for concurrent operations
- 🎯 **Type Safety**: Compile-time code generation ensures type-safe operations
- 🚀 **Zero Boilerplate**: Annotate your aggregate roots and generate repositories
- 🔐 **Efficient UUID Storage**: UUIDs stored as BINARY(16) for optimal performance
- 📅 **Native DateTime**: DateTime fields stored as DATETIME in UTC for database-native operations
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
// Note: SSL support depends on mysql1 package configuration
final connection = MysqlConnection(
  host: 'secure-db.example.com',
  port: 3306,
  database: 'myapp',
  user: 'myapp_user',
  password: 'secure_password',
  // SSL configuration via mysql1 package
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

## Collection Support

DDDart MySQL repositories provide comprehensive support for collections in your aggregate roots. Collections are automatically persisted to junction tables with proper ordering, uniqueness constraints, and cascade delete behavior.

### Supported Collection Types

**Primitives:**
- `List<int>`, `List<String>`, `List<double>`, `List<bool>`, `List<DateTime>`, `List<UuidValue>`
- `Set<int>`, `Set<String>`, `Set<double>`, `Set<bool>`, `Set<DateTime>`, `Set<UuidValue>`
- `Map<String, int>`, `Map<int, String>`, and other primitive key-value combinations

**Value Objects:**
- `List<ValueObject>` - Ordered collections of value objects
- `Set<ValueObject>` - Unique collections of value objects
- `Map<primitive, ValueObject>` - Key-value mappings with value object values

**Entities:**
- `List<Entity>` - Ordered collections of entities (existing support)
- `Set<Entity>` - Unique collections of entities
- `Map<primitive, Entity>` - Key-value mappings with entity values

### Collection Examples

#### Primitive Collections

```dart
@Serializable()
@GenerateMysqlRepository(tableName: 'users')
class User extends AggregateRoot {
  User({
    required UuidValue id,
    required this.name,
    required this.favoriteNumbers,
    required this.tags,
    required this.scoresByGame,
  }) : super(id);

  final String name;
  final List<int> favoriteNumbers;      // Ordered list
  final Set<String> tags;               // Unique set
  final Map<String, int> scoresByGame;  // Key-value map
}

// Usage
final user = User(
  id: UuidValue.generate(),
  name: 'Alice',
  favoriteNumbers: [7, 13, 42],
  tags: {'developer', 'dart', 'ddd'},
  scoresByGame: {'chess': 1200, 'go': 1500},
);

await repository.save(user);
final loaded = await repository.getById(user.id);
print(loaded.favoriteNumbers); // [7, 13, 42] - order preserved
print(loaded.tags);            // {developer, dart, ddd} - unique values
print(loaded.scoresByGame);    // {chess: 1200, go: 1500}
```

**Generated Schema:**
```sql
-- List maintains order with position column
CREATE TABLE IF NOT EXISTS users_favoriteNumbers_items (
  users_id BINARY(16) NOT NULL,
  position BIGINT NOT NULL,
  value BIGINT NOT NULL,
  FOREIGN KEY (users_id) REFERENCES users(id) ON DELETE CASCADE,
  UNIQUE (users_id, position)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Set enforces uniqueness
CREATE TABLE IF NOT EXISTS users_tags_items (
  users_id BINARY(16) NOT NULL,
  value VARCHAR(255) NOT NULL,
  FOREIGN KEY (users_id) REFERENCES users(id) ON DELETE CASCADE,
  UNIQUE (users_id, value)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Map stores key-value pairs
CREATE TABLE IF NOT EXISTS users_scoresByGame_items (
  users_id BINARY(16) NOT NULL,
  map_key VARCHAR(255) NOT NULL,
  value BIGINT NOT NULL,
  FOREIGN KEY (users_id) REFERENCES users(id) ON DELETE CASCADE,
  UNIQUE (users_id, map_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

#### Value Object Collections

```dart
@Serializable()
class Money {
  Money({required this.amount, required this.currency});
  final double amount;
  final String currency;
}

@Serializable()
class Address {
  Address({required this.street, required this.city, required this.country});
  final String street;
  final String city;
  final String country;
}

@Serializable()
@GenerateMysqlRepository(tableName: 'orders')
class Order extends AggregateRoot {
  Order({
    required UuidValue id,
    required this.payments,
    required this.deliveryLocations,
    required this.discountsByCode,
  }) : super(id);

  final List<Money> payments;                    // Ordered payments
  final Set<Address> deliveryLocations;          // Unique addresses
  final Map<String, Money> discountsByCode;      // Discounts by code
}

// Usage
final order = Order(
  id: UuidValue.generate(),
  payments: [
    Money(amount: 50.0, currency: 'USD'),
    Money(amount: 49.99, currency: 'USD'),
  ],
  deliveryLocations: {
    Address(street: '123 Main St', city: 'NYC', country: 'USA'),
    Address(street: '456 Oak Ave', city: 'LA', country: 'USA'),
  },
  discountsByCode: {
    'SAVE10': Money(amount: 10.0, currency: 'USD'),
    'SAVE20': Money(amount: 20.0, currency: 'USD'),
  },
);

await repository.save(order);
```

**Generated Schema:**
```sql
-- Value objects are flattened into junction table columns
CREATE TABLE IF NOT EXISTS orders_payments_items (
  orders_id BINARY(16) NOT NULL,
  position BIGINT NOT NULL,
  amount DOUBLE NOT NULL,
  currency VARCHAR(255) NOT NULL,
  FOREIGN KEY (orders_id) REFERENCES orders(id) ON DELETE CASCADE,
  UNIQUE (orders_id, position)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS orders_deliveryLocations_items (
  orders_id BINARY(16) NOT NULL,
  street VARCHAR(255) NOT NULL,
  city VARCHAR(255) NOT NULL,
  country VARCHAR(255) NOT NULL,
  FOREIGN KEY (orders_id) REFERENCES orders(id) ON DELETE CASCADE,
  UNIQUE (orders_id, street, city, country)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS orders_discountsByCode_items (
  orders_id BINARY(16) NOT NULL,
  map_key VARCHAR(255) NOT NULL,
  amount DOUBLE NOT NULL,
  currency VARCHAR(255) NOT NULL,
  FOREIGN KEY (orders_id) REFERENCES orders(id) ON DELETE CASCADE,
  UNIQUE (orders_id, map_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

#### Entity Collections

```dart
@Serializable()
class CartItem extends Entity {
  CartItem({
    required UuidValue id,
    required this.productId,
    required this.quantity,
  }) : super(id);

  final UuidValue productId;
  final int quantity;
}

@Serializable()
class Discount extends Entity {
  Discount({
    required UuidValue id,
    required this.code,
    required this.percentage,
  }) : super(id);

  final String code;
  final double percentage;
}

@Serializable()
@GenerateMysqlRepository(tableName: 'shopping_carts')
class ShoppingCart extends AggregateRoot {
  ShoppingCart({
    required UuidValue id,
    required this.items,
    required this.appliedDiscounts,
    required this.savedItems,
  }) : super(id);

  final List<CartItem> items;                    // Ordered items (existing support)
  final Set<Discount> appliedDiscounts;          // Unique discounts
  final Map<String, CartItem> savedItems;        // Named saved items
}

// Usage
final cart = ShoppingCart(
  id: UuidValue.generate(),
  items: [
    CartItem(id: UuidValue.generate(), productId: UuidValue.generate(), quantity: 2),
    CartItem(id: UuidValue.generate(), productId: UuidValue.generate(), quantity: 1),
  ],
  appliedDiscounts: {
    Discount(id: UuidValue.generate(), code: 'SAVE10', percentage: 10.0),
  },
  savedItems: {
    'wishlist': CartItem(id: UuidValue.generate(), productId: UuidValue.generate(), quantity: 1),
  },
);

await repository.save(cart);
```

**Generated Schema:**
```sql
-- Entities get their own tables with foreign keys
CREATE TABLE IF NOT EXISTS cart_items (
  id BINARY(16) PRIMARY KEY NOT NULL,
  shopping_cart_id BINARY(16) NOT NULL,
  position BIGINT,  -- Only for List<Entity>
  productId BINARY(16) NOT NULL,
  quantity BIGINT NOT NULL,
  FOREIGN KEY (shopping_cart_id) REFERENCES shopping_carts(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS discounts (
  id BINARY(16) PRIMARY KEY NOT NULL,
  shopping_cart_id BINARY(16) NOT NULL,
  code VARCHAR(255) NOT NULL,
  percentage DOUBLE NOT NULL,
  FOREIGN KEY (shopping_cart_id) REFERENCES shopping_carts(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS saved_cart_items (
  id BINARY(16) PRIMARY KEY NOT NULL,
  shopping_cart_id BINARY(16) NOT NULL,
  map_key VARCHAR(255) NOT NULL,
  productId BINARY(16) NOT NULL,
  quantity BIGINT NOT NULL,
  FOREIGN KEY (shopping_cart_id) REFERENCES shopping_carts(id) ON DELETE CASCADE,
  UNIQUE (shopping_cart_id, map_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### Collection Behavior

**Order Preservation:**
- `List<T>` collections maintain insertion order using a `position` column
- Position values start at 0 and increment by 1
- Order is preserved across save/load cycles

**Uniqueness:**
- `Set<T>` collections enforce uniqueness via UNIQUE constraints
- Duplicate values are automatically filtered during save
- For value objects, uniqueness is based on all fields

**Map Keys:**
- Map keys are stored in a `map_key` column
- Keys must be primitive types (String, int, etc.)
- UNIQUE constraint on (parent_id, map_key) prevents duplicate keys

**Cascade Delete:**
- All collection items are automatically deleted when the parent aggregate is deleted
- Implemented via `ON DELETE CASCADE` foreign key constraints
- InnoDB engine enforces referential integrity
- No orphaned collection items remain in the database

**Null Handling:**
- Nullable collection fields (`List<int>?`) are treated as empty collections
- Saving null deletes all existing collection items
- Loading returns empty collections, never null
- Nullable elements (`List<int?>`) are supported

### DateTime and Boolean Type Improvements

**DateTime Storage:**
- DateTime fields are stored as DATETIME in UTC
- Example: `2024-12-04 10:30:00`
- Supports MySQL datetime functions (DATE_ADD, DATE_SUB, etc.)
- Supports all DateTime fields, not just those ending in "At"
- Automatic UTC conversion for consistency

```dart
@Serializable()
@GenerateMysqlRepository(tableName: 'events')
class Event extends AggregateRoot {
  Event({
    required UuidValue id,
    required this.scheduledFor,
    required this.birthday,
    required this.timestamps,
  }) : super(id);

  final DateTime scheduledFor;  // Stored as DATETIME (UTC)
  final DateTime birthday;      // Stored as DATETIME (UTC)
  final List<DateTime> timestamps;  // Each stored as DATETIME (UTC)
}

// Query with MySQL datetime functions
final rows = await connection.query('''
  SELECT * FROM events 
  WHERE scheduledFor > DATE_ADD(NOW(), INTERVAL 1 DAY)
''');
```

**Boolean Storage:**
- Boolean fields are stored as TINYINT(1)
- `true` → 1, `false` → 0
- Efficient storage and indexing
- Works in collections and embedded value objects

```dart
@Serializable()
@GenerateMysqlRepository(tableName: 'tasks')
class Task extends AggregateRoot {
  Task({
    required UuidValue id,
    required this.completed,
    required this.flags,
  }) : super(id);

  final bool completed;        // Stored as TINYINT(1)
  final List<bool> flags;      // Each stored as TINYINT(1)
}
```

### Migration Guide

If you have existing databases using the old BIGINT-based DateTime storage, you can migrate to the new DATETIME format:

```dart
Future<void> migrateDateTimeColumns(MysqlConnection connection) async {
  // Migrate DateTime columns from BIGINT (Unix timestamp) to DATETIME
  await connection.execute('''
    UPDATE users SET 
      birthday = FROM_UNIXTIME(birthday / 1000)
    WHERE birthday > 1000000000000
  ''');
  
  await connection.execute('''
    UPDATE events SET 
      scheduledFor = FROM_UNIXTIME(scheduledFor / 1000)
    WHERE scheduledFor > 1000000000000
  ''');
  
  // Repeat for other tables with DateTime columns
  
  // Optionally, alter column types (requires table lock)
  await connection.execute('''
    ALTER TABLE users 
    MODIFY COLUMN birthday DATETIME NOT NULL
  ''');
  
  await connection.execute('''
    ALTER TABLE events 
    MODIFY COLUMN scheduledFor DATETIME NOT NULL
  ''');
}

// Run migration once
final connection = MysqlConnection(
  host: 'localhost',
  port: 3306,
  database: 'myapp',
  user: 'migration_user',
  password: 'secure_password',
);
await connection.open();
await migrateDateTimeColumns(connection);
await connection.close();
```

**Migration Steps:**
1. Backup your database before migration
2. Run the migration script to convert BIGINT to DATETIME
3. Optionally alter column types (requires table lock - plan for downtime)
4. Regenerate repository code with `dart run build_runner build`
5. Test thoroughly with your application
6. Deploy the updated application

**Note:** The new format enables MySQL's powerful datetime functions and improves query performance.

### Dialect Consistency

Collection support works identically in both SQLite and MySQL repositories:

**Same Domain Model:**
```dart
// Works with both @GenerateSqliteRepository() and @GenerateMysqlRepository()
@Serializable()
class Order extends AggregateRoot {
  final List<int> itemIds;
  final Set<String> tags;
  final Map<String, double> prices;
}
```

**Database-Specific SQL:**
- SQLite: `BLOB` for UUIDs, `TEXT` for DateTime, `INTEGER` for booleans
- MySQL: `BINARY(16)` for UUIDs, `DATETIME` for DateTime, `TINYINT(1)` for booleans
- Junction table structure is identical
- Save/load behavior is identical
- No code changes needed when switching databases

## Requirements

- Dart SDK >=3.5.0
- MySQL 5.7+ (MySQL 8.0+ recommended)
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
