# DDDart SQLite Repository Examples

This directory contains examples demonstrating the use of `dddart_repository_sqlite` for persisting aggregate roots to SQLite databases.

## Running the Examples

First, generate the repository code:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Then run any example:

```bash
dart run basic_crud_example.dart
dart run complex_aggregate_example.dart
dart run custom_repository_example.dart
```

## Examples

### 1. Basic CRUD Example (`basic_crud_example.dart`)

Demonstrates basic Create, Read, Update, Delete operations with a simple aggregate root.

**Features:**
- Simple aggregate with primitive fields
- In-memory database connection
- Save, retrieve, update, and delete operations
- Error handling for not found cases
- Proper connection lifecycle management

**Domain Model:**
- `SimpleUser`: Aggregate root with name, email, age, and isActive fields

### 2. Complex Aggregate Example (`complex_aggregate_example.dart`)

**Note:** This example demonstrates the intended design but currently has limitations due to incomplete multi-table persistence in the generator.

**Intended Features:**
- Aggregate with nested entities (OrderItem)
- Multiple embedded value objects (Money, Address)
- Value object embedding with prefixed columns
- Multi-table persistence with foreign keys
- Cascade delete behavior

**Domain Model:**
- `Order`: Aggregate root with customer info, addresses, and items
- `OrderItem`: Entity within the order aggregate
- `Money`: Value object for monetary amounts
- `Address`: Value object for addresses

**Current Limitation:** The generator does not yet fully implement multi-table persistence for nested entities. This is tracked as a known issue.

### 3. Custom Repository Example (`custom_repository_example.dart`)

Demonstrates how to extend generated repositories with custom query methods.

**Features:**
- Custom repository interface with domain-specific methods
- Custom SQL queries
- JOIN operations
- Access to protected connection and serializer members

## Domain Models

All domain models are located in the `lib/` directory:

- `lib/simple_user.dart` - Simple aggregate for basic CRUD
- `lib/complex_order.dart` - Complex aggregate with nested entities and value objects
- `lib/custom_user.dart` - User aggregate with custom repository interface

## Generated Code

The build runner generates:
- `*.g.dart` files containing JSON serializers
- Repository implementations with CRUD methods
- CREATE TABLE statements
- SQL query builders

## Database Schema

### Simple User

```sql
CREATE TABLE users (
  id BLOB PRIMARY KEY NOT NULL,
  createdAt INTEGER NOT NULL,
  updatedAt INTEGER NOT NULL,
  name TEXT NOT NULL,
  email TEXT NOT NULL,
  age INTEGER NOT NULL,
  isActive INTEGER NOT NULL
);
```

### Complex Order (Intended Design)

```sql
CREATE TABLE orders (
  id BLOB PRIMARY KEY NOT NULL,
  createdAt INTEGER NOT NULL,
  updatedAt INTEGER NOT NULL,
  customerId BLOB NOT NULL,
  customerName TEXT NOT NULL,
  totalAmount_amount REAL NOT NULL,
  totalAmount_currency TEXT NOT NULL,
  shippingAddress_street TEXT NOT NULL,
  shippingAddress_city TEXT NOT NULL,
  shippingAddress_country TEXT NOT NULL,
  billingAddress_street TEXT NOT NULL,
  billingAddress_city TEXT NOT NULL,
  billingAddress_country TEXT NOT NULL,
  status TEXT NOT NULL
);

CREATE TABLE order_items (
  id BLOB PRIMARY KEY NOT NULL,
  order_id BLOB NOT NULL,
  productId BLOB NOT NULL,
  productName TEXT NOT NULL,
  quantity INTEGER NOT NULL,
  unitPrice_amount REAL NOT NULL,
  unitPrice_currency TEXT NOT NULL,
  FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE
);
```

Note how value objects (Money, Address) are embedded as prefixed columns in their parent tables, while entities (OrderItem) get their own tables with foreign keys.

## Connection Management

### In-Memory Database

```dart
final connection = SqliteConnection.memory();
await connection.open();
// Use connection
await connection.close();
```

### File-Based Database

```dart
final connection = SqliteConnection.file('path/to/database.db');
await connection.open();
// Use connection
await connection.close();
```

## Error Handling

The repository throws `RepositoryException` with specific types:

- `RepositoryExceptionType.notFound` - Entity not found
- `RepositoryExceptionType.duplicate` - Unique constraint violation
- `RepositoryExceptionType.connection` - Database connection error
- `RepositoryExceptionType.unknown` - Other errors

Example:

```dart
try {
  final user = await repository.getById(id);
} on RepositoryException catch (e) {
  if (e.type == RepositoryExceptionType.notFound) {
    print('User not found');
  } else {
    print('Error: ${e.message}');
  }
}
```

## Value Object Embedding

Value objects are automatically embedded as prefixed columns:

```dart
class Order {
  final Money totalAmount;  // Value object
}

class Money {
  final double amount;
  final String currency;
}
```

Becomes:

```sql
CREATE TABLE orders (
  ...
  totalAmount_amount REAL NOT NULL,
  totalAmount_currency TEXT NOT NULL,
  ...
);
```

This provides:
- Simple schema without extra tables
- No JOIN overhead
- Direct SQL queries possible
- Aligned with DDD principles (value objects have no identity)
