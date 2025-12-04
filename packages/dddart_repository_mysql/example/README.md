# MySQL Repository Examples

This directory contains comprehensive examples demonstrating the usage of `dddart_repository_mysql`.

## Prerequisites

Before running these examples, you need:

1. **MySQL Server** running on `localhost:3306`
2. **Database created**: `dddart_example`
3. **User credentials**: `root` / `password` (or update connection parameters in examples)

### Quick MySQL Setup with Docker

```bash
# Start MySQL container
docker run --name mysql-examples \
  -e MYSQL_ROOT_PASSWORD=password \
  -e MYSQL_DATABASE=dddart_example \
  -p 3306:3306 \
  -d mysql:8.0

# Wait for MySQL to be ready (about 30 seconds)
docker logs -f mysql-examples

# Stop when done
docker stop mysql-examples
docker rm mysql-examples
```

### Alternative: Local MySQL Installation

If you have MySQL installed locally:

```sql
CREATE DATABASE dddart_example;
```

## Running the Examples

### 1. Generate Code

First, generate the repository code from the annotated domain models:

```bash
cd packages/dddart_repository_mysql/example
dart run build_runner build --delete-conflicting-outputs
```

This will generate:
- `lib/domain/*.g.dart` - JSON serializers
- `lib/domain/*_repository.g.part` - Repository implementations

### 2. Run Examples

Each example can be run independently:

```bash
# Basic CRUD operations
dart run basic_crud_example.dart

# Custom repository with domain-specific queries
dart run custom_repository_example.dart

# Error handling patterns
dart run error_handling_example.dart

# Connection lifecycle management
dart run connection_management_example.dart

# Collection support (List, Set, Map)
dart run collection_examples.dart
```

## Examples Overview

### basic_crud_example.dart

Demonstrates fundamental repository operations:
- Creating a MySQL connection
- Creating database tables
- Saving aggregates with entities and value objects
- Retrieving aggregates by ID
- Updating aggregates
- Deleting aggregates (with CASCADE for entities)
- Proper connection cleanup

**Key concepts:**
- Value object embedding (Money, Address)
- Entity relationships (Order → OrderItems)
- Automatic foreign key constraints
- Transaction wrapping for save operations

### custom_repository_example.dart

Shows how to extend generated repositories with custom query methods:
- Defining a custom repository interface
- Implementing domain-specific query methods
- Using both generated CRUD and custom queries
- Accessing protected members (connection, dialect, serializer)

**Key concepts:**
- Abstract base class generation
- Custom SQL queries
- Manual entity loading
- Domain-specific repository methods

### error_handling_example.dart

Demonstrates proper exception handling:
- Handling `RepositoryException.notFound`
- Handling connection errors
- Error type checking and recovery patterns
- Graceful degradation strategies

**Key concepts:**
- Exception types (notFound, connection, timeout, etc.)
- Try-catch patterns
- Error recovery
- Logging and continuing

### connection_management_example.dart

Covers connection lifecycle and advanced features:
- Connection creation with custom parameters
- Opening and closing connections
- Connection state checking
- Connection pooling configuration
- Transaction management (commit/rollback)
- Concurrent operations

**Key concepts:**
- Connection pooling
- Transaction boundaries
- Concurrent access
- Resource cleanup

### collection_examples.dart

Comprehensive demonstration of collection support in MySQL repositories:
- Primitive collections (List, Set, Map with int, String, DateTime, etc.)
- Value object collections (List, Set, Map with embedded value objects)
- Entity collections (List, Set, Map with entities)
- Nullable collections and empty collections
- Cascade delete behavior
- Order preservation for lists
- Uniqueness enforcement for sets
- Key-value mappings for maps

**Key concepts:**
- Junction table generation for collections
- Position columns for ordered lists
- UNIQUE constraints for sets and map keys
- Value object flattening in junction tables
- CASCADE DELETE for collection items
- DateTime storage as DATETIME (UTC)
- Boolean storage as TINYINT(1)

**Domain Models:**
- `User`: Aggregate with primitive collections (favoriteNumbers, tags, scoresByGame)
- `Order`: Aggregate with value object collections (payments, deliveryLocations, discountsByCode)
- `ShoppingCart`: Aggregate with entity collections (items, appliedDiscounts, savedItems)
- `Product`: Aggregate demonstrating nullable collections

**Collection Types Demonstrated:**
- `List<int>`, `Set<String>`, `Map<String, int>` - Primitive collections
- `List<Money>`, `Set<Address>`, `Map<String, Money>` - Value object collections
- `List<CartItem>`, `Set<Discount>`, `Map<String, CartItem>` - Entity collections
- `List<DateTime>` - DateTime collections with DATETIME storage
- `List<int?>` - Nullable element collections
- `Set<String>?` - Nullable collection fields

## Domain Models

The examples use a simple e-commerce domain:

### Aggregate Root
- **Order**: Customer order with items and addresses

### Entities
- **OrderItem**: Line item in an order (quantity, product, price)

### Value Objects
- **Money**: Monetary amount with currency
- **Address**: Physical address with street, city, state, postal code, country

### Schema Generated

```sql
-- Aggregate root table
CREATE TABLE orders (
  id BINARY(16) PRIMARY KEY NOT NULL,
  createdAt TIMESTAMP NOT NULL,
  updatedAt TIMESTAMP NOT NULL,
  customerName VARCHAR(255) NOT NULL,
  -- Embedded value object: shippingAddress
  shippingAddress_street VARCHAR(255) NOT NULL,
  shippingAddress_city VARCHAR(255) NOT NULL,
  shippingAddress_state VARCHAR(255) NOT NULL,
  shippingAddress_postalCode VARCHAR(255) NOT NULL,
  shippingAddress_country VARCHAR(255) NOT NULL,
  -- Embedded nullable value object: billingAddress
  billingAddress_street VARCHAR(255),
  billingAddress_city VARCHAR(255),
  billingAddress_state VARCHAR(255),
  billingAddress_postalCode VARCHAR(255),
  billingAddress_country VARCHAR(255)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Entity table with foreign key
CREATE TABLE order_items (
  id BINARY(16) PRIMARY KEY NOT NULL,
  order_id BINARY(16) NOT NULL,
  productName VARCHAR(255) NOT NULL,
  quantity BIGINT NOT NULL,
  -- Embedded value object: unitPrice
  unitPrice_amount DOUBLE NOT NULL,
  unitPrice_currency VARCHAR(255) NOT NULL,
  FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

## Customizing Connection Parameters

All examples use these default connection parameters:

```dart
final connection = MysqlConnection(
  host: 'localhost',
  port: 3306,
  database: 'dddart_example',
  user: 'root',
  password: 'password',
);
```

To use different parameters, edit the connection creation in each example file.

## Troubleshooting

### Connection Refused

If you see "Connection refused" errors:
1. Verify MySQL is running: `docker ps` or `mysql -u root -p`
2. Check the port: MySQL default is 3306
3. Verify the database exists: `SHOW DATABASES;`

### Authentication Failed

If you see "Access denied" errors:
1. Check username and password
2. Verify user has permissions: `GRANT ALL ON dddart_example.* TO 'root'@'%';`

### Code Generation Errors

If you see "part of" errors:
1. Run `dart run build_runner clean`
2. Run `dart run build_runner build --delete-conflicting-outputs`
3. Check that all domain models have `@Serializable()` annotation

### Table Already Exists

The examples call `createTables()` which uses `CREATE TABLE IF NOT EXISTS`, so running examples multiple times is safe. To start fresh:

```sql
DROP DATABASE dddart_example;
CREATE DATABASE dddart_example;
```

## Next Steps

After exploring these examples:

1. Review the [main package README](../README.md) for detailed documentation
2. Check the [test suite](../test/) for more usage patterns
3. Explore the [generated code](lib/domain/*.g.dart) to understand the implementation
4. Try creating your own domain models and repositories

## Support

For issues or questions:
- Check the [package documentation](../README.md)
- Review the [design document](../.kiro/specs/mysql-repository/design.md)
- Open an issue on GitHub
