# dddart_repository_sql

Base SQL repository abstractions for DDDart - Domain-Driven Design for Dart.

## Overview

`dddart_repository_sql` provides the foundational abstractions and utilities for implementing SQL database repositories for DDDart aggregate roots. This package is designed to be extended by concrete implementations like `dddart_repository_sqlite`, `dddart_repository_postgres`, etc.

The package provides a complete ORM (Object-Relational Mapping) framework with:

- **Full Normalization**: Every class (aggregate roots, entities, value objects) gets its own table
- **Automatic Schema Generation**: CREATE TABLE statements generated from aggregate root definitions
- **Relationship Mapping**: Automatic foreign key generation and JOIN handling
- **Value Object Embedding**: Smart handling of value objects with prefixed columns
- **Transaction Support**: Multi-table operations wrapped in transactions
- **SQL Dialect Support**: Abstraction for database-specific SQL syntax

## Features

- **Schema Generation**: Automatically generate SQL DDL from aggregate root definitions
- **Object Graph Traversal**: Discover all referenced types in an aggregate
- **Relationship Analysis**: Detect one-to-one, one-to-many relationships
- **Type Mapping**: Convert between Dart types and SQL column types
- **Query Building**: Generate SELECT queries with JOINs for loading aggregates
- **Object Mapping**: Serialize/deserialize object graphs to/from SQL rows
- **SQL Dialect Abstraction**: Support multiple SQL databases through dialect interface
- **Foreign Key Management**: Automatic CASCADE DELETE for aggregate boundaries
- **Value Object Embedding**: Flatten value objects into parent tables with prefixed columns

## Architecture

This package provides the base abstractions that concrete implementations extend:

```
dddart_repository_sql (base abstractions)
    ├── SqlConnection (abstract)
    ├── SqlDialect (abstract)
    ├── SchemaGenerator
    ├── RelationshipAnalyzer
    ├── ObjectMapper
    └── JoinBuilder

dddart_repository_sqlite (concrete implementation)
    ├── SqliteConnection (implements SqlConnection)
    ├── SqliteDialect (implements SqlDialect)
    └── SqliteRepositoryGenerator (uses base utilities)
```

## Installation

This package is typically not used directly. Instead, use a concrete implementation:

```yaml
dependencies:
  dddart: ^0.9.0
  dddart_json: ^0.9.0
  dddart_repository_sqlite: ^0.9.0  # Or postgres, mysql, etc.
```

## Core Abstractions

### SqlConnection

Abstract interface for database connections:

```dart
abstract class SqlConnection {
  /// Opens the database connection
  Future<void> open();
  
  /// Closes the database connection
  Future<void> close();
  
  /// Executes a SQL statement without returning results
  Future<void> execute(String sql, [List<Object?>? parameters]);
  
  /// Executes a SQL query and returns results
  Future<List<Map<String, Object?>>> query(String sql, [List<Object?>? parameters]);
  
  /// Executes multiple statements in a transaction
  Future<T> transaction<T>(Future<T> Function() action);
  
  /// Whether the connection is currently open
  bool get isOpen;
}
```

### SqlDialect

Abstract interface for database-specific SQL syntax:

```dart
abstract class SqlDialect {
  /// SQL type for UUID columns (e.g., BLOB, UUID)
  String get uuidColumnType;
  
  /// SQL type for text columns (e.g., TEXT, VARCHAR)
  String get textColumnType;
  
  /// SQL type for integer columns (e.g., INTEGER, BIGINT)
  String get integerColumnType;
  
  /// SQL type for floating point columns (e.g., REAL, DOUBLE)
  String get realColumnType;
  
  /// SQL type for boolean columns (e.g., INTEGER, BOOLEAN)
  String get booleanColumnType;
  
  /// Encodes a UuidValue to database format
  Object? encodeUuid(UuidValue uuid);
  
  /// Decodes a database value to UuidValue
  UuidValue decodeUuid(Object? value);
  
  /// Encodes a DateTime to database format
  Object? encodeDateTime(DateTime dateTime);
  
  /// Decodes a database value to DateTime
  DateTime decodeDateTime(Object? value);
  
  /// Generates CREATE TABLE IF NOT EXISTS statement
  String createTableIfNotExists(TableDefinition table);
  
  /// Generates INSERT OR REPLACE statement
  String insertOrReplace(String tableName, List<String> columns);
  
  /// Generates SELECT with JOINs statement
  String selectWithJoins(TableDefinition rootTable, List<JoinClause> joins);
  
  /// Generates DELETE statement
  String delete(String tableName);
}
```

### TableDefinition

Represents a SQL table definition:

```dart
class TableDefinition {
  final String tableName;
  final String className;
  final List<ColumnDefinition> columns;
  final List<ForeignKeyDefinition> foreignKeys;
  final bool isAggregateRoot;
  
  /// Generates CREATE TABLE SQL statement
  String toCreateTableSql(SqlDialect dialect);
}

class ColumnDefinition {
  final String name;
  final String sqlType;
  final String dartType;
  final bool isNullable;
  final bool isPrimaryKey;
  final bool isForeignKey;
}

class ForeignKeyDefinition {
  final String columnName;
  final String referencedTable;
  final String referencedColumn;
  final CascadeAction onDelete;
}

enum CascadeAction {
  cascade,    // DELETE CASCADE for entities within aggregate
  setNull,    // SET NULL for optional references
  restrict,   // RESTRICT for references to other aggregates
}
```

### RelationshipAnalyzer

Analyzes aggregate roots to discover all referenced types:

```dart
class RelationshipAnalyzer {
  /// Discovers all types referenced by an aggregate root.
  /// Returns a dependency-ordered list of types.
  List<ClassElement> analyzeAggregate(ClassElement aggregateRoot);
  
  /// Determines the relationship type between two classes.
  RelationshipType getRelationshipType(FieldElement field);
  
  /// Checks if a type is a value object (no identity).
  bool isValueObject(ClassElement element);
  
  /// Checks if a type is an entity (has identity).
  bool isEntity(ClassElement element);
}
```

### ObjectMapper

Maps between domain objects and SQL rows:

```dart
class ObjectMapper {
  /// Serializes an object graph to SQL rows.
  /// Returns a map of table names to rows to insert/update.
  /// Value objects are flattened into parent rows with prefixed columns.
  Map<String, List<Map<String, Object?>>> serializeGraph(
    Object aggregateRoot,
    Map<Type, TableDefinition> schema,
  );
  
  /// Deserializes SQL rows to an object graph.
  /// Reconstructs value objects from prefixed columns.
  T deserializeGraph<T>(
    Map<String, List<Map<String, Object?>>> rows,
    Map<Type, TableDefinition> schema,
  );
  
  /// Flattens a value object into prefixed key-value pairs.
  Map<String, Object?> flattenValueObject(String prefix, Object valueObject);
  
  /// Reconstructs a value object from prefixed columns.
  T reconstructValueObject<T>(String prefix, Map<String, Object?> row);
}
```

### JoinBuilder

Builds SQL JOIN queries:

```dart
class JoinBuilder {
  /// Generates a SELECT query with JOINs for an aggregate root.
  String buildLoadQuery(
    TableDefinition rootTable,
    Map<Type, TableDefinition> schema,
    SqlDialect dialect,
  );
  
  /// Generates JOIN clauses for related tables.
  List<String> buildJoinClauses(
    TableDefinition table,
    Map<Type, TableDefinition> schema,
    SqlDialect dialect,
  );
}
```

## Schema Generation Strategy

### Table Generation

**For Each Class in Object Graph:**

1. **Aggregate Roots**: Get their own table with all primitive fields
2. **Entities**: Get their own table with foreign key to parent
3. **Value Objects**: **Embedded** into parent table with prefixed columns (no separate table)

### Value Object Embedding

Value objects are flattened into the parent table:

```dart
class Order {
  final Money totalAmount;  // Value object
}

class Money {
  final double amount;
  final String currency;
}
```

**Generated Schema:**
```sql
CREATE TABLE orders (
  id BLOB PRIMARY KEY,
  totalAmount_amount REAL NOT NULL,    -- Flattened from Money.amount
  totalAmount_currency TEXT NOT NULL   -- Flattened from Money.currency
);
```

**Benefits:**
- ✅ Simple schema - no extra tables
- ✅ No foreign keys needed
- ✅ No JOIN overhead
- ✅ Direct SQL queries possible
- ✅ Aligned with DDD - value objects have no identity

### Foreign Key Strategy

**Within Aggregate Boundary:**
- Entity → Aggregate Root: `ON DELETE CASCADE`
- Entity → Entity: `ON DELETE CASCADE`

**Across Aggregate Boundaries:**
- Aggregate → Aggregate: **NO FOREIGN KEY** (just store UUID)
- Rationale: Aggregates may be in different databases

**Value Objects:**
- **NO FOREIGN KEYS** - embedded as columns

## Type Mapping

| Dart Type | SQL Type | Notes |
|-----------|----------|-------|
| UuidValue | BLOB/UUID | Database-specific |
| String | TEXT | UTF-8 |
| int | INTEGER | 64-bit |
| double | REAL | 64-bit float |
| bool | INTEGER | 0 or 1 |
| DateTime | INTEGER | Milliseconds since epoch |
| Enum | TEXT | Enum name as string |
| Custom class | BLOB (FK) | Foreign key to class table |
| List<T> | N/A | Separate table with FK back |
| T? (nullable) | Same + NULL | Allow NULL values |

## Usage in Concrete Implementations

Concrete implementations (like `dddart_repository_sqlite`) use these utilities:

```dart
class SqliteRepositoryGenerator extends GeneratorForAnnotation<GenerateSqliteRepository> {
  @override
  String generateForAnnotatedElement(Element element, ...) {
    // 1. Use RelationshipAnalyzer to discover types
    final analyzer = RelationshipAnalyzer();
    final types = analyzer.analyzeAggregate(element as ClassElement);
    
    // 2. Generate TableDefinitions
    final tables = types.map((type) => generateTableDefinition(type)).toList();
    
    // 3. Use SchemaGenerator to create DDL
    final schemaGen = SchemaGenerator(SqliteDialect());
    final createStatements = tables.map((t) => schemaGen.generateCreateTable(t));
    
    // 4. Use JoinBuilder for SELECT queries
    final joinBuilder = JoinBuilder();
    final loadQuery = joinBuilder.buildLoadQuery(rootTable, schema, dialect);
    
    // 5. Use ObjectMapper for serialization
    final mapper = ObjectMapper();
    // ... generate code that uses mapper.serializeGraph() and deserializeGraph()
    
    return generatedCode;
  }
}
```

## Design Principles

1. **Full Normalization**: Every class gets a table (except value objects which are embedded)
2. **No JSON Blobs**: All data stored in proper SQL columns
3. **Aggregate Boundaries**: Respect DDD with CASCADE DELETE
4. **Type Safety**: Compile-time code generation
5. **Transaction Integrity**: Multi-table operations in transactions
6. **Dialect Abstraction**: Support multiple SQL databases

## Concrete Implementations

- **`dddart_repository_sqlite`**: SQLite implementation for local/mobile/web
- **`dddart_repository_postgres`**: PostgreSQL implementation (future)
- **`dddart_repository_mysql`**: MySQL implementation (future)

## Requirements

- **Dart SDK**: >=3.5.0 <4.0.0
- **Dependencies**:
  - `dddart`: Core DDD framework
  - `dddart_serialization`: Serialization abstractions
  - `analyzer`: Dart code analysis
  - `source_gen`: Code generation utilities
  - `build`: Build system

## Contributing

Contributions are welcome! Please see the main DDDart repository for contribution guidelines.

## License

MIT License - see LICENSE file for details.
