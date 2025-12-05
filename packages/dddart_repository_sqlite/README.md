# dddart_repository_sqlite

SQLite repository implementation for DDDart aggregate roots with automatic code generation.

## Features

- 🗄️ **Full Normalization**: Every class gets its own table with proper columns and foreign keys
- 🔄 **Automatic Schema Generation**: Tables created from aggregate root definitions
- 💎 **Value Object Embedding**: Value objects flattened into parent tables with prefixed columns
- 🔗 **Relationship Mapping**: Automatic foreign key generation and JOIN handling
- 📦 **Collection Support**: Full support for List, Set, and Map collections with primitives, value objects, and entities
- 🔒 **Transaction Support**: Multi-table operations wrapped in transactions
- 🎯 **Type Safety**: Compile-time code generation ensures type-safe operations
- 📱 **Cross-Platform**: Works on iOS, Android, Windows, macOS, Linux, and Web
- 🚀 **Zero Boilerplate**: Annotate your aggregate roots and generate repositories
- 📅 **Native DateTime**: DateTime fields stored as TEXT in ISO8601 format for human readability

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

## Collection Support

DDDart SQLite repositories provide comprehensive support for collections in your aggregate roots. Collections are automatically persisted to junction tables with proper ordering, uniqueness constraints, and cascade delete behavior.

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
@GenerateSqliteRepository()
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
CREATE TABLE users_favoriteNumbers_items (
  users_id BLOB NOT NULL,
  position INTEGER NOT NULL,
  value INTEGER NOT NULL,
  FOREIGN KEY (users_id) REFERENCES users(id) ON DELETE CASCADE,
  UNIQUE (users_id, position)
);

-- Set enforces uniqueness
CREATE TABLE users_tags_items (
  users_id BLOB NOT NULL,
  value TEXT NOT NULL,
  FOREIGN KEY (users_id) REFERENCES users(id) ON DELETE CASCADE,
  UNIQUE (users_id, value)
);

-- Map stores key-value pairs
CREATE TABLE users_scoresByGame_items (
  users_id BLOB NOT NULL,
  map_key TEXT NOT NULL,
  value INTEGER NOT NULL,
  FOREIGN KEY (users_id) REFERENCES users(id) ON DELETE CASCADE,
  UNIQUE (users_id, map_key)
);
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
@GenerateSqliteRepository()
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
CREATE TABLE orders_payments_items (
  orders_id BLOB NOT NULL,
  position INTEGER NOT NULL,
  amount REAL NOT NULL,
  currency TEXT NOT NULL,
  FOREIGN KEY (orders_id) REFERENCES orders(id) ON DELETE CASCADE,
  UNIQUE (orders_id, position)
);

CREATE TABLE orders_deliveryLocations_items (
  orders_id BLOB NOT NULL,
  street TEXT NOT NULL,
  city TEXT NOT NULL,
  country TEXT NOT NULL,
  FOREIGN KEY (orders_id) REFERENCES orders(id) ON DELETE CASCADE,
  UNIQUE (orders_id, street, city, country)
);

CREATE TABLE orders_discountsByCode_items (
  orders_id BLOB NOT NULL,
  map_key TEXT NOT NULL,
  amount REAL NOT NULL,
  currency TEXT NOT NULL,
  FOREIGN KEY (orders_id) REFERENCES orders(id) ON DELETE CASCADE,
  UNIQUE (orders_id, map_key)
);
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
@GenerateSqliteRepository()
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
CREATE TABLE cart_items (
  id BLOB PRIMARY KEY NOT NULL,
  shopping_cart_id BLOB NOT NULL,
  position INTEGER,  -- Only for List<Entity>
  productId BLOB NOT NULL,
  quantity INTEGER NOT NULL,
  FOREIGN KEY (shopping_cart_id) REFERENCES shopping_carts(id) ON DELETE CASCADE
);

CREATE TABLE discounts (
  id BLOB PRIMARY KEY NOT NULL,
  shopping_cart_id BLOB NOT NULL,
  code TEXT NOT NULL,
  percentage REAL NOT NULL,
  FOREIGN KEY (shopping_cart_id) REFERENCES shopping_carts(id) ON DELETE CASCADE
);

CREATE TABLE saved_cart_items (
  id BLOB PRIMARY KEY NOT NULL,
  shopping_cart_id BLOB NOT NULL,
  map_key TEXT NOT NULL,
  productId BLOB NOT NULL,
  quantity INTEGER NOT NULL,
  FOREIGN KEY (shopping_cart_id) REFERENCES shopping_carts(id) ON DELETE CASCADE,
  UNIQUE (shopping_cart_id, map_key)
);
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
- No orphaned collection items remain in the database

**Null Handling:**
- Nullable collection fields (`List<int>?`) are treated as empty collections
- Saving null deletes all existing collection items
- Loading returns empty collections, never null
- Nullable elements (`List<int?>`) are supported

### DateTime and Boolean Type Improvements

**DateTime Storage:**
- DateTime fields are stored as TEXT in ISO8601 format
- Example: `2024-12-04T10:30:00.000Z`
- Human-readable in database tools
- Supports all DateTime fields, not just those ending in "At"
- Automatic UTC conversion for consistency

```dart
@Serializable()
@GenerateSqliteRepository()
class Event extends AggregateRoot {
  Event({
    required UuidValue id,
    required this.scheduledFor,
    required this.birthday,
    required this.timestamps,
  }) : super(id);

  final DateTime scheduledFor;  // Stored as TEXT (ISO8601)
  final DateTime birthday;      // Stored as TEXT (ISO8601)
  final List<DateTime> timestamps;  // Each stored as TEXT (ISO8601)
}
```

**Boolean Storage:**
- Boolean fields are stored as INTEGER (0 or 1)
- `true` → 1, `false` → 0
- Efficient storage and indexing
- Works in collections and embedded value objects

```dart
@Serializable()
@GenerateSqliteRepository()
class Task extends AggregateRoot {
  Task({
    required UuidValue id,
    required this.completed,
    required this.flags,
  }) : super(id);

  final bool completed;        // Stored as INTEGER (0/1)
  final List<bool> flags;      // Each stored as INTEGER (0/1)
}
```

### Migration Guide

If you have existing databases using the old INTEGER-based DateTime storage, you can migrate to the new TEXT-based format:

```dart
Future<void> migrateDateTimeColumns(SqliteConnection connection) async {
  // Migrate DateTime columns from INTEGER (Unix timestamp) to TEXT (ISO8601)
  await connection.execute('''
    UPDATE users SET 
      birthday = datetime(birthday / 1000, 'unixepoch')
    WHERE typeof(birthday) = 'integer'
  ''');
  
  await connection.execute('''
    UPDATE events SET 
      scheduledFor = datetime(scheduledFor / 1000, 'unixepoch')
    WHERE typeof(scheduledFor) = 'integer'
  ''');
  
  // Repeat for other tables with DateTime columns
}

// Run migration once
final connection = SqliteConnection.file('app.db');
await connection.open();
await migrateDateTimeColumns(connection);
await connection.close();
```

**Migration Steps:**
1. Backup your database before migration
2. Run the migration script to convert INTEGER to TEXT
3. Regenerate repository code with `dart run build_runner build`
4. Test thoroughly with your application
5. Deploy the updated application

**Note:** The new format is more human-readable and works better with SQLite's datetime functions.

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
