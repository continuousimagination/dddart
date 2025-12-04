# Design Document

## Overview

This design extends DDDart's SQL repository code generation to support comprehensive collection types (`List`, `Set`, `Map`) containing primitives, value objects, and entities. The implementation builds upon the existing code generation infrastructure in `dddart_repository_sql`, `dddart_repository_sqlite`, and `dddart_repository_mysql`.

The core approach uses junction tables for all collection types, with variations in schema based on collection semantics:
- **Lists**: Include position column for ordering
- **Sets**: No position column, enforce uniqueness
- **Maps**: Include map_key column for key-value relationships

Additionally, this design improves type mapping to use native database types for DateTime and boolean values instead of generic INTEGER columns.

## Architecture

### Package Structure

The implementation spans three packages with clear separation of concerns:

**dddart_repository_sql (Base Package)**
- `RelationshipAnalyzer`: Extended to detect collection types (List, Set, Map)
- `TypeMapper`: Enhanced to return dialect-specific types for DateTime and boolean
- `CollectionAnalyzer`: New component to analyze collection element types
- `SchemaGenerator`: Extended to generate junction table schemas

**dddart_repository_sqlite (SQLite Implementation)**
- `SqliteRepositoryGenerator`: Extended to generate collection save/load code
- `SqliteDialect`: Updated with TEXT for DateTime, INTEGER for boolean

**dddart_repository_mysql (MySQL Implementation)**
- `MysqlRepositoryGenerator`: Extended to generate collection save/load code
- `MysqlDialect`: Updated with DATETIME for DateTime, TINYINT(1) for boolean

### Code Generation Flow

```
Aggregate Root Class
       ↓
RelationshipAnalyzer.analyzeAggregate()
       ↓
Discovers: Entities, Values, Collections
       ↓
CollectionAnalyzer.analyzeCollection()
       ↓
Determines: Element type, Collection type
       ↓
SchemaGenerator.generateJunctionTable()
       ↓
Creates: Junction table definition
       ↓
RepositoryGenerator.generate()
       ↓
Produces: Save/Load methods for collections
```

## Components and Interfaces

### CollectionAnalyzer

New component for analyzing collection fields:

```dart
class CollectionAnalyzer {
  /// Analyzes a collection field to determine element type and collection semantics.
  CollectionInfo analyzeCollection(FieldElement field);
  
  /// Checks if a type is a supported primitive type.
  bool isPrimitiveType(DartType type);
  
  /// Checks if a type is a value object.
  bool isValueObject(ClassElement element);
  
  /// Checks if a type is an entity.
  bool isEntity(ClassElement element);
  
  /// Validates that a collection type is supported.
  void validateCollectionType(DartType collectionType);
}

class CollectionInfo {
  final CollectionKind kind; // list, set, map
  final ElementKind elementKind; // primitive, value, entity
  final DartType elementType;
  final DartType? keyType; // For maps
  final String tableName;
  final List<ColumnDefinition> columns;
}

enum CollectionKind { list, set, map }
enum ElementKind { primitive, value, entity }
```


### Extended RelationshipAnalyzer

Enhanced to detect and handle collection types:

```dart
class RelationshipAnalyzer {
  // Existing methods...
  
  /// Determines if a field is a collection type.
  bool isCollection(FieldElement field) {
    final type = field.type;
    return type.isDartCoreList || type.isDartCoreSet || type.isDartCoreMap;
  }
  
  /// Gets the collection kind (List, Set, Map).
  CollectionKind getCollectionKind(DartType type);
  
  /// Extracts element type from List<T> or Set<T>.
  DartType? getElementType(DartType collectionType);
  
  /// Extracts key and value types from Map<K, V>.
  (DartType?, DartType?) getMapTypes(DartType mapType);
}
```

### Enhanced TypeMapper

Updated to use dialect-specific types:

```dart
class TypeMapper {
  /// Gets SQL type using dialect for database-specific types.
  String? getSqlType(String dartType, SqlDialect dialect) {
    switch (dartType) {
      case 'String':
        return dialect.textColumnType;
      case 'int':
        return dialect.integerColumnType;
      case 'double':
        return dialect.realColumnType;
      case 'bool':
        return dialect.booleanColumnType;
      case 'DateTime':
        return dialect.dateTimeColumnType; // NEW
      case 'UuidValue':
        return dialect.uuidColumnType;
      default:
        return null;
    }
  }
}
```

### Updated SqlDialect Interface

Extended with DateTime column type:

```dart
abstract class SqlDialect {
  // Existing getters...
  
  /// SQL type for DateTime columns (e.g., TEXT, DATETIME).
  String get dateTimeColumnType;
  
  // Existing methods remain unchanged
}
```

## Data Models

### Junction Table Schemas

**List of Primitives:**
```sql
CREATE TABLE {parent_table}_{field_name}_items (
  {parent_table}_id BLOB NOT NULL,
  position INTEGER NOT NULL,
  value {SQL_TYPE} NOT NULL,
  FOREIGN KEY ({parent_table}_id) REFERENCES {parent_table}(id) ON DELETE CASCADE,
  UNIQUE ({parent_table}_id, position)
);
```

**Set of Primitives:**
```sql
CREATE TABLE {parent_table}_{field_name}_items (
  {parent_table}_id BLOB NOT NULL,
  value {SQL_TYPE} NOT NULL,
  FOREIGN KEY ({parent_table}_id) REFERENCES {parent_table}(id) ON DELETE CASCADE,
  UNIQUE ({parent_table}_id, value)
);
```

**Map of Primitives:**
```sql
CREATE TABLE {parent_table}_{field_name}_items (
  {parent_table}_id BLOB NOT NULL,
  map_key {KEY_SQL_TYPE} NOT NULL,
  value {VALUE_SQL_TYPE} NOT NULL,
  FOREIGN KEY ({parent_table}_id) REFERENCES {parent_table}(id) ON DELETE CASCADE,
  UNIQUE ({parent_table}_id, map_key)
);
```

**List of Value Objects:**
```sql
CREATE TABLE {parent_table}_{field_name}_items (
  {parent_table}_id BLOB NOT NULL,
  position INTEGER NOT NULL,
  {value_field1} {SQL_TYPE1} NOT NULL,
  {value_field2} {SQL_TYPE2} NOT NULL,
  ...
  FOREIGN KEY ({parent_table}_id) REFERENCES {parent_table}(id) ON DELETE CASCADE,
  UNIQUE ({parent_table}_id, position)
);
```

**Set of Entities:**
```sql
CREATE TABLE {entity_table} (
  id BLOB PRIMARY KEY NOT NULL,
  {parent_table}_id BLOB NOT NULL,
  {entity_fields}...,
  FOREIGN KEY ({parent_table}_id) REFERENCES {parent_table}(id) ON DELETE CASCADE
);
-- No position column, no UNIQUE constraint on id (already PK)
```

**Map of Entities:**
```sql
CREATE TABLE {entity_table} (
  id BLOB PRIMARY KEY NOT NULL,
  {parent_table}_id BLOB NOT NULL,
  map_key {KEY_SQL_TYPE} NOT NULL,
  {entity_fields}...,
  FOREIGN KEY ({parent_table}_id) REFERENCES {parent_table}(id) ON DELETE CASCADE,
  UNIQUE ({parent_table}_id, map_key)
);
```


### Type Mapping Examples

**SQLite:**
- `int` → `INTEGER`
- `double` → `REAL`
- `String` → `TEXT`
- `bool` → `INTEGER` (0/1)
- `DateTime` → `TEXT` (ISO8601)
- `UuidValue` → `BLOB` (16 bytes)

**MySQL:**
- `int` → `BIGINT`
- `double` → `DOUBLE`
- `String` → `VARCHAR(255)`
- `bool` → `TINYINT(1)`
- `DateTime` → `DATETIME` (UTC)
- `UuidValue` → `BINARY(16)`

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Primitive list round-trip preservation

*For any* aggregate root with a `List<primitive>` field, saving and then loading the aggregate should reconstruct the list with the same values in the same order.

**Validates: Requirements 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8**

### Property 2: Primitive set round-trip preservation

*For any* aggregate root with a `Set<primitive>` field, saving and then loading the aggregate should reconstruct the set with the same unique values (order not guaranteed).

**Validates: Requirements 2.1, 2.2, 2.3, 2.4**

### Property 3: Primitive map round-trip preservation

*For any* aggregate root with a `Map<primitive, primitive>` field, saving and then loading the aggregate should reconstruct the map with the same key-value pairs.

**Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5**

### Property 4: Value object list round-trip preservation

*For any* aggregate root with a `List<ValueObject>` field, saving and then loading the aggregate should reconstruct the list with equivalent value objects in the same order.

**Validates: Requirements 4.1, 4.2, 4.3, 4.4, 4.6**

### Property 5: Value object set round-trip preservation

*For any* aggregate root with a `Set<ValueObject>` field, saving and then loading the aggregate should reconstruct the set with equivalent unique value objects.

**Validates: Requirements 5.1, 5.2, 5.3, 5.4**

### Property 6: Value object map round-trip preservation

*For any* aggregate root with a `Map<primitive, ValueObject>` field, saving and then loading the aggregate should reconstruct the map with equivalent value objects for each key.

**Validates: Requirements 6.1, 6.2, 6.3, 6.4**

### Property 7: Entity set round-trip preservation

*For any* aggregate root with a `Set<Entity>` field, saving and then loading the aggregate should reconstruct the set with the same entities (by ID).

**Validates: Requirements 7.1, 7.2, 7.3, 7.4**

### Property 8: Entity map round-trip preservation

*For any* aggregate root with a `Map<primitive, Entity>` field, saving and then loading the aggregate should reconstruct the map with the same entities for each key.

**Validates: Requirements 8.1, 8.2, 8.3, 8.4**

### Property 9: Collection cascade delete

*For any* aggregate root with collection fields, deleting the aggregate should cascade delete all collection items from their junction tables.

**Validates: Requirements 1.9, 2.6, 7.5, 8.5**

### Property 10: Empty collection handling

*For any* aggregate root with empty collection fields, saving and then loading should reconstruct empty collections of the correct type.

**Validates: Requirements 10.3, 11.6**

### Property 11: Null collection handling

*For any* aggregate root with nullable collection fields set to null, saving and then loading should return empty collections (not null).

**Validates: Requirements 14.1, 14.2, 14.3**

### Property 12: DateTime round-trip preservation

*For any* aggregate root with DateTime fields (regardless of field name), saving and then loading should reconstruct the DateTime with the same instant in time.

**Validates: Requirements 16.1, 16.2, 16.3, 16.4, 16.5, 16.6, 16.9, 16.10, 16.11**

### Property 13: Boolean round-trip preservation

*For any* aggregate root with boolean fields, saving and then loading should reconstruct the boolean with the same value.

**Validates: Requirements 17.1, 17.2, 17.3, 17.4, 17.5, 17.6**

### Property 14: Schema generation for primitive lists

*For any* aggregate root with a `List<primitive>` field, the generated schema should include a junction table with entity_id, position, and value columns.

**Validates: Requirements 9.1**

### Property 15: Schema generation for primitive sets

*For any* aggregate root with a `Set<primitive>` field, the generated schema should include a junction table with entity_id and value columns, and a UNIQUE constraint.

**Validates: Requirements 9.2**

### Property 16: Schema generation for primitive maps

*For any* aggregate root with a `Map<primitive, primitive>` field, the generated schema should include a junction table with entity_id, map_key, and value columns, and a UNIQUE constraint on (entity_id, map_key).

**Validates: Requirements 9.3**

### Property 17: Transaction rollback on failure

*For any* aggregate root with collections, if saving fails partway through, all changes should be rolled back and the database should remain in its previous state.

**Validates: Requirements 10.1, 10.5**

### Property 18: Dialect consistency

*For any* aggregate root with collections, the same domain model should work identically in both SQLite and MySQL without code changes.

**Validates: Requirements 13.1, 13.2, 13.3, 13.4, 13.5, 13.6, 13.7**


## Error Handling

### Unsupported Collection Types

The code generator will validate collection types during analysis and fail with clear error messages for:

**Nested Collections:**
```
Error: Nested collections are not supported.
Field: User.matrix
Type: List<List<int>>
Suggestion: Wrap the inner collection in a Value object or Entity.
```

**Dynamic Collections:**
```
Error: Collections with dynamic or Object types are not supported.
Field: User.stuff
Type: List<dynamic>
Suggestion: Use a specific type like List<int> or List<String>.
```

**Value Objects as Map Keys:**
```
Error: Value objects cannot be used as map keys.
Field: Order.itemsByProduct
Type: Map<Product, int>
Suggestion: Use a primitive type as the key, or use the entity's ID.
```

**Aggregate Root Collections:**
```
Error: Collections of aggregate roots violate aggregate boundaries.
Field: User.orders
Type: List<Order>
Suggestion: Store aggregate IDs instead: List<UuidValue>.
```

### Runtime Errors

**Transaction Failures:**
- Wrap all collection operations in database transactions
- On failure, roll back all changes
- Throw `RepositoryException` with appropriate type

**Type Conversion Errors:**
- Validate types during encoding/decoding
- Throw `RepositoryException` with details about the field and expected type

**Constraint Violations:**
- UNIQUE constraint violations indicate duplicate keys in maps or sets
- Foreign key violations indicate orphaned collection items
- Throw `RepositoryException` with constraint details

## Testing Strategy

### Unit Tests

**Schema Generation Tests:**
- Test that each collection type generates correct SQL schema
- Verify column names, types, and constraints
- Test table naming conventions

**Type Mapping Tests:**
- Test TypeMapper returns correct SQL types for each dialect
- Test DateTime encoding/decoding for both SQLite and MySQL
- Test boolean encoding/decoding for both dialects

**Collection Analysis Tests:**
- Test CollectionAnalyzer correctly identifies collection kinds
- Test element type extraction for List, Set, Map
- Test validation rejects unsupported types

### Property-Based Tests

All correctness properties will be implemented as property-based tests using the `test` package with custom generators:

**Generators Needed:**
- `arbitraryPrimitiveList()` - Generates List<int>, List<String>, etc.
- `arbitraryPrimitiveSet()` - Generates Set<int>, Set<String>, etc.
- `arbitraryPrimitiveMap()` - Generates Map<String, int>, etc.
- `arbitraryValueObjectList()` - Generates List<Money>, List<Address>, etc.
- `arbitraryEntitySet()` - Generates Set<OrderItem>, etc.
- `arbitraryDateTime()` - Generates DateTime values
- `arbitraryAggregate()` - Generates complete aggregates with collections

**Test Configuration:**
- Run each property test with minimum 100 iterations
- Use both SQLite (in-memory) and MySQL (test container) for dialect tests
- Tag tests appropriately for CI/CD filtering

**Example Property Test:**
```dart
/// Feature: sql-collection-support, Property 1: Primitive list round-trip preservation
test('List<int> round-trip preserves order and values', () {
  final generator = arbitraryAggregateWithIntList();
  
  for (var i = 0; i < 100; i++) {
    final original = generator.generate();
    final repository = TestAggregateRepository(connection);
    
    await repository.save(original);
    final loaded = await repository.getById(original.id);
    
    expect(loaded.favoriteNumbers, equals(original.favoriteNumbers));
  }
});
```

### Integration Tests

**End-to-End Tests:**
- Create aggregates with all collection types
- Save, load, update, delete operations
- Verify CASCADE DELETE behavior
- Test with both SQLite and MySQL

**Performance Tests:**
- Measure save/load times for large collections
- Verify query performance with indexes
- Test transaction overhead


## Implementation Details

### Collection Save Algorithm

```dart
Future<void> _saveCollection(
  UuidValue aggregateId,
  String fieldName,
  dynamic collectionValue,
  CollectionInfo info,
) async {
  // 1. Delete existing items
  await _connection.execute(
    'DELETE FROM ${info.tableName} WHERE ${parentTable}_id = ?',
    [_dialect.encodeUuid(aggregateId)],
  );
  
  // 2. Handle empty/null collections
  if (collectionValue == null || collectionValue.isEmpty) {
    return;
  }
  
  // 3. Insert new items based on collection kind
  switch (info.kind) {
    case CollectionKind.list:
      await _saveListItems(aggregateId, collectionValue, info);
    case CollectionKind.set:
      await _saveSetItems(aggregateId, collectionValue, info);
    case CollectionKind.map:
      await _saveMapItems(aggregateId, collectionValue, info);
  }
}
```

### Collection Load Algorithm

```dart
Future<dynamic> _loadCollection(
  UuidValue aggregateId,
  CollectionInfo info,
) async {
  // 1. Query collection items
  final rows = await _connection.query(
    'SELECT * FROM ${info.tableName} WHERE ${parentTable}_id = ? ${_getOrderClause(info)}',
    [_dialect.encodeUuid(aggregateId)],
  );
  
  // 2. Handle empty result
  if (rows.isEmpty) {
    return _emptyCollection(info.kind);
  }
  
  // 3. Reconstruct collection based on kind
  switch (info.kind) {
    case CollectionKind.list:
      return _reconstructList(rows, info);
    case CollectionKind.set:
      return _reconstructSet(rows, info);
    case CollectionKind.map:
      return _reconstructMap(rows, info);
  }
}

String _getOrderClause(CollectionInfo info) {
  return info.kind == CollectionKind.list ? 'ORDER BY position' : '';
}
```

### DateTime Encoding/Decoding

**SQLite Implementation:**
```dart
class SqliteDialect implements SqlDialect {
  @override
  String get dateTimeColumnType => 'TEXT';
  
  @override
  Object? encodeDateTime(DateTime dateTime) {
    return dateTime.toUtc().toIso8601String();
  }
  
  @override
  DateTime decodeDateTime(Object? value) {
    if (value is! String) {
      throw ArgumentError('Expected String for DateTime, got ${value.runtimeType}');
    }
    return DateTime.parse(value).toUtc();
  }
}
```

**MySQL Implementation:**
```dart
class MysqlDialect implements SqlDialect {
  @override
  String get dateTimeColumnType => 'DATETIME';
  
  @override
  Object? encodeDateTime(DateTime dateTime) {
    // MySQL DATETIME expects format: 'YYYY-MM-DD HH:MM:SS'
    final utc = dateTime.toUtc();
    return '${utc.year.toString().padLeft(4, '0')}-'
           '${utc.month.toString().padLeft(2, '0')}-'
           '${utc.day.toString().padLeft(2, '0')} '
           '${utc.hour.toString().padLeft(2, '0')}:'
           '${utc.minute.toString().padLeft(2, '0')}:'
           '${utc.second.toString().padLeft(2, '0')}';
  }
  
  @override
  DateTime decodeDateTime(Object? value) {
    if (value is DateTime) {
      return value.toUtc();
    }
    if (value is String) {
      return DateTime.parse(value).toUtc();
    }
    throw ArgumentError('Expected DateTime or String, got ${value.runtimeType}');
  }
}
```

### Value Object Flattening in Collections

When a collection contains value objects, each field is flattened into the junction table:

```dart
List<ColumnDefinition> _flattenValueObjectForCollection(
  ClassElement valueObjectClass,
  TypeMapper typeMapper,
  SqlDialect dialect,
) {
  final columns = <ColumnDefinition>[];
  
  for (final field in valueObjectClass.fields) {
    if (field.isStatic) continue;
    
    final dartType = field.type.getDisplayString(withNullability: false);
    final sqlType = typeMapper.getSqlType(dartType, dialect);
    
    if (sqlType != null) {
      columns.add(ColumnDefinition(
        name: field.name, // No prefix needed in junction table
        sqlType: sqlType,
        dartType: dartType,
        isNullable: field.type.nullabilitySuffix.toString().contains('question'),
        isPrimaryKey: false,
        isForeignKey: false,
      ));
    }
  }
  
  return columns;
}
```

### Generated Code Structure

For each collection field, the generator produces:

**Save Method:**
```dart
Future<void> _saveFavoriteNumbers(
  UuidValue aggregateId,
  List<int> favoriteNumbers,
) async {
  // Delete existing
  await _connection.execute(
    'DELETE FROM users_favoriteNumbers_items WHERE users_id = ?',
    [_dialect.encodeUuid(aggregateId)],
  );
  
  // Insert new items
  for (var i = 0; i < favoriteNumbers.length; i++) {
    await _connection.execute(
      'INSERT INTO users_favoriteNumbers_items (users_id, position, value) VALUES (?, ?, ?)',
      [_dialect.encodeUuid(aggregateId), i, favoriteNumbers[i]],
    );
  }
}
```

**Load Method:**
```dart
Future<List<int>> _loadFavoriteNumbers(UuidValue aggregateId) async {
  final rows = await _connection.query(
    'SELECT value FROM users_favoriteNumbers_items WHERE users_id = ? ORDER BY position',
    [_dialect.encodeUuid(aggregateId)],
  );
  
  return rows.map((row) => row['value'] as int).toList();
}
```

## Migration Strategy

### Backward Compatibility

This feature is **additive** and maintains backward compatibility:

1. Existing aggregates without collections continue to work unchanged
2. Existing `List<Entity>` support remains unchanged
3. New collection types are opt-in by adding fields to aggregates

### Database Migration

For existing databases, adding collection fields requires:

1. Generate new junction tables via `createTables()`
2. Existing data is unaffected
3. New collection fields start empty

### Deprecation Path

The old INTEGER-based DateTime storage is replaced but existing data can be migrated:

```dart
// Migration helper (optional, for existing databases)
Future<void> migrateDateTimeColumns() async {
  // SQLite: Convert INTEGER to TEXT
  await _connection.execute('''
    UPDATE users SET 
      birthday = datetime(birthday / 1000, 'unixepoch')
    WHERE typeof(birthday) = 'integer'
  ''');
  
  // MySQL: Convert BIGINT to DATETIME
  await _connection.execute('''
    UPDATE users SET 
      birthday = FROM_UNIXTIME(birthday / 1000)
    WHERE birthday > 1000000000000
  ''');
}
```

## Performance Considerations

### Query Optimization

**Indexes:**
- Foreign key columns are automatically indexed
- Position columns in lists should be indexed for ordering
- Map key columns should be indexed for lookups

**Batch Operations:**
- Use prepared statements for bulk inserts
- Consider batch size limits (SQLite: 999 parameters, MySQL: configurable)

**Load Strategies:**
- Load collections in parallel where possible
- Use single query with JOINs for small collections
- Use separate queries for large collections

### Memory Management

**Large Collections:**
- Stream results for very large collections
- Consider pagination for UI display
- Warn users about performance implications of large collections

**Transaction Size:**
- Keep transactions focused on single aggregate
- Avoid long-running transactions
- Use connection pooling for concurrent operations

## Security Considerations

### SQL Injection Prevention

- All queries use parameterized statements
- No string concatenation for user input
- Dialect handles proper escaping

### Data Validation

- Validate collection element types at code generation time
- Runtime type checking during encoding/decoding
- Constraint enforcement via database schema

## Documentation and Examples

### README Updates

Each repository package README will be updated with collection examples:

**dddart_repository_sqlite/README.md:**
- Add "Collection Support" section
- Show examples of List, Set, Map with primitives
- Show examples with value objects
- Show examples with entities
- Include schema diagrams

**dddart_repository_mysql/README.md:**
- Mirror SQLite examples
- Highlight MySQL-specific types (DATETIME, TINYINT)
- Show connection setup

### Example Code

Add comprehensive examples to `example/` directories:

**collection_examples.dart:**
```dart
// List of primitives
class User extends AggregateRoot {
  final List<int> favoriteNumbers;
  final Set<String> tags;
  final Map<String, int> scoresByGame;
}

// List of value objects
class Order extends AggregateRoot {
  final List<Money> payments;
  final Set<Address> deliveryLocations;
}

// Set/Map of entities
class ShoppingCart extends AggregateRoot {
  final Set<CartItem> items;
  final Map<String, Discount> discountsByCode;
}
```

### API Documentation

Update API reference docs with:
- Collection field annotations
- Junction table naming conventions
- Performance considerations
- Migration guides

## CI/CD Integration

### GitHub Actions Workflow

Update `.github/workflows/test.yml` to include:

**SQLite Tests:**
```yaml
- name: Run SQLite collection tests
  run: dart test
  working-directory: packages/dddart_repository_sqlite
```

**MySQL Tests:**
```yaml
- name: Start MySQL container
  run: |
    docker run -d \
      --name mysql-test \
      -e MYSQL_ROOT_PASSWORD=test \
      -e MYSQL_DATABASE=testdb \
      -p 3306:3306 \
      mysql:8.0

- name: Wait for MySQL
  run: |
    until docker exec mysql-test mysqladmin ping -h localhost --silent; do
      sleep 1
    done

- name: Run MySQL collection tests
  run: dart test
  working-directory: packages/dddart_repository_mysql
  env:
    MYSQL_HOST: localhost
    MYSQL_PORT: 3306
    MYSQL_USER: root
    MYSQL_PASSWORD: test
    MYSQL_DATABASE: testdb
```

### Test Script Updates

Update `scripts/test-all.sh` to run collection-specific tests:

```bash
# Test SQLite collections
echo "Testing SQLite collections..."
cd packages/dddart_repository_sqlite
dart test --tags=collections

# Test MySQL collections (if MySQL available)
if command -v mysql &> /dev/null; then
  echo "Testing MySQL collections..."
  cd ../dddart_repository_mysql
  dart test --tags=collections
fi
```

## Future Enhancements

### Potential Additions

1. **Lazy Loading**: Load collections on-demand rather than eagerly
2. **Partial Updates**: Update only changed collection items
3. **Indexing Hints**: Allow developers to specify indexes on collection columns
4. **Custom Serialization**: Support custom serializers for complex types
5. **Nested Collections**: Support one level of nesting (e.g., `Map<String, List<int>>`)

### Not Planned

1. **Arbitrary Nesting**: Deep nesting (e.g., `List<List<List<int>>>`) - too complex
2. **Polymorphic Collections**: Collections with mixed types - violates type safety
3. **Circular References**: Collections that reference parent - violates DDD principles
