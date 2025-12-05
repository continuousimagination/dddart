# Future Enhancements for Distributed Events

## Automatic Time-Range Query Generation for Repositories

### Overview

Currently, developers must manually implement `findSince()` and `deleteOlderThan()` methods when using StoredEvent with database repositories. This document describes a future enhancement to automatically generate these methods in all `dddart_repository_*` packages.

### Current State

**What developers do now:**

```dart
// 1. Extend StoredEvent for their database
@GenerateMongoRepository()
class StoredEventMongo extends StoredEvent {
  StoredEventMongo({
    required super.id,
    required super.createdAt,
    required super.aggregateId,
    required super.eventType,
    required super.eventJson,
    required super.context,
  });
}

// 2. Run code generation
// dart run build_runner build

// 3. Manually add time-range queries via extension
extension StoredEventMongoRepositoryExtension on StoredEventMongoRepository {
  Future<List<StoredEventMongo>> findSince(DateTime timestamp) async {
    return collection
        .find({'createdAt': {'\$gte': timestamp.toIso8601String()}})
        .toList();
  }

  Future<void> deleteOlderThan(DateTime timestamp) async {
    await collection.deleteMany({
      'createdAt': {'\$lt': timestamp.toIso8601String()}
    });
  }
}
```

### Desired Future State

**What developers should be able to do:**

```dart
// 1. Extend StoredEvent for their database
@GenerateMongoRepository()
class StoredEventMongo extends StoredEvent {
  StoredEventMongo({
    required super.id,
    required super.createdAt,
    required super.aggregateId,
    required super.eventType,
    required super.eventJson,
    required super.context,
  });
}

// 2. Run code generation
// dart run build_runner build

// 3. Use generated time-range methods automatically!
final events = await repository.findSince(DateTime.now().subtract(Duration(hours: 1)));
await repository.deleteOlderThan(DateTime.now().subtract(Duration(days: 7)));
```

### Implementation Strategy

#### Phase 1: Define EventRepository Interface

In `dddart_events_distributed`, define an abstract class that repository generators can implement:

```dart
/// Extended repository interface for time-based event queries
abstract class EventRepository<T extends StoredEvent> implements Repository<T> {
  /// Finds all events with createdAt >= timestamp
  Future<List<T>> findSince(DateTime timestamp);
  
  /// Deletes all events with createdAt < timestamp
  Future<void> deleteOlderThan(DateTime timestamp);
}
```

#### Phase 2: Update Repository Code Generators

Update each `dddart_repository_*` package's code generator to:

1. **Detect StoredEvent subclasses**: Check if the class being generated extends `StoredEvent`
2. **Implement EventRepository**: Generate repository class that implements `EventRepository<T>` instead of just `Repository<T>`
3. **Generate time-range methods**: Add database-specific implementations of `findSince` and `deleteOlderThan`

**Example for MongoDB:**

```dart
// Generated code in stored_event_mongo.repository.g.dart
class StoredEventMongoRepository extends EventRepository<StoredEventMongo> {
  // ... existing generated methods (save, findById, delete, etc.)
  
  @override
  Future<List<StoredEventMongo>> findSince(DateTime timestamp) async {
    final results = await collection.find({
      'createdAt': {'\$gte': timestamp.toIso8601String()}
    }).toList();
    
    return results.map((doc) => StoredEventMongo.fromJson(doc)).toList();
  }
  
  @override
  Future<void> deleteOlderThan(DateTime timestamp) async {
    await collection.deleteMany({
      'createdAt': {'\$lt': timestamp.toIso8601String()}
    });
  }
}
```

**Example for DynamoDB:**

```dart
// Generated code in stored_event_dynamo.repository.g.dart
class StoredEventDynamoRepository extends EventRepository<StoredEventDynamo> {
  // ... existing generated methods
  
  @override
  Future<List<StoredEventDynamo>> findSince(DateTime timestamp) async {
    final response = await dynamodb.query(
      tableName: tableName,
      indexName: 'createdAt-index', // Assumes GSI on createdAt
      keyConditionExpression: 'createdAt >= :timestamp',
      expressionAttributeValues: {
        ':timestamp': {'S': timestamp.toIso8601String()},
      },
    );
    
    return response.items.map((item) => StoredEventDynamo.fromJson(item)).toList();
  }
  
  @override
  Future<void> deleteOlderThan(DateTime timestamp) async {
    // DynamoDB doesn't support bulk delete by condition
    // Need to query first, then batch delete
    final oldEvents = await query(
      keyConditionExpression: 'createdAt < :timestamp',
      expressionAttributeValues: {
        ':timestamp': {'S': timestamp.toIso8601String()},
      },
    );
    
    // Batch delete in chunks of 25 (DynamoDB limit)
    for (var i = 0; i < oldEvents.length; i += 25) {
      final batch = oldEvents.skip(i).take(25).toList();
      await dynamodb.batchWriteItem(
        requestItems: {
          tableName: batch.map((event) => {
            'DeleteRequest': {'Key': {'id': {'S': event.id.toString()}}}
          }).toList(),
        },
      );
    }
  }
}
```

**Example for MySQL:**

```dart
// Generated code in stored_event_mysql.repository.g.dart
class StoredEventMysqlRepository extends EventRepository<StoredEventMysql> {
  // ... existing generated methods
  
  @override
  Future<List<StoredEventMysql>> findSince(DateTime timestamp) async {
    final results = await connection.query(
      'SELECT * FROM stored_events WHERE createdAt >= ? ORDER BY createdAt ASC',
      [timestamp.toIso8601String()],
    );
    
    return results.map((row) => StoredEventMysql.fromJson(row.fields)).toList();
  }
  
  @override
  Future<void> deleteOlderThan(DateTime timestamp) async {
    await connection.query(
      'DELETE FROM stored_events WHERE createdAt < ?',
      [timestamp.toIso8601String()],
    );
  }
}
```

#### Phase 3: Generalize Beyond StoredEvent

Once the pattern is proven with StoredEvent, consider generalizing to any aggregate with a `createdAt` field:

```dart
// Code generator detects any class with createdAt field
@GenerateMongoRepository()
class AuditLog extends AggregateRoot {
  AuditLog({
    required super.id,
    required super.createdAt,
    required this.action,
    required this.userId,
  });
  
  final String action;
  final String userId;
}

// Generated repository automatically includes time-range queries
final recentLogs = await auditLogRepo.findSince(DateTime.now().subtract(Duration(days: 1)));
```

### Benefits

1. **Zero boilerplate**: Developers don't write any query code
2. **Consistent API**: Same methods across all databases
3. **Database-optimized**: Each implementation uses database-specific best practices
4. **Type-safe**: Generated code is fully type-checked
5. **Maintainable**: Changes to query logic happen in one place (the generator)

### Migration Path

1. **Phase 1**: Ship distributed events with manual implementation (current plan)
2. **Phase 2**: Update one repository package (e.g., `dddart_repository_mongodb`) as proof of concept
3. **Phase 3**: Roll out to all repository packages
4. **Phase 4**: Deprecate manual extensions, update documentation

### Packages to Update

- `dddart_repository_mongodb`
- `dddart_repository_mysql`
- `dddart_repository_sqlite`
- `dddart_repository_dynamodb`
- `dddart_repository_sql` (base SQL implementation)
- Any future repository packages

### Technical Considerations

#### Index Requirements

Time-range queries require database indexes on `createdAt`:

- **MongoDB**: Automatically create index in generated repository constructor
- **MySQL/PostgreSQL**: Include index creation in migration scripts or repository setup
- **DynamoDB**: Require GSI (Global Secondary Index) on `createdAt` - document in README

#### Timestamp Format

Ensure consistent timestamp storage across databases:
- Store as ISO 8601 strings for consistency
- Or use database-native timestamp types where appropriate
- Document the format in generated code comments

#### Performance

- `findSince`: Should use index on `createdAt` for efficient queries
- `deleteOlderThan`: May need batching for large deletions (especially DynamoDB)
- Consider adding `limit` parameter for pagination in future

### Documentation Updates

When implemented, update:
1. `dddart_events_distributed` README - remove manual implementation instructions
2. Each `dddart_repository_*` README - document automatic time-range query generation
3. Migration guide for existing users with manual extensions

### Related Future Enhancements

- **Pagination support**: Add `findSince(timestamp, {int? limit, String? cursor})`
- **Event type filtering**: Add `findSince(timestamp, {List<String>? eventTypes})`
- **Aggregate filtering**: Add `findSince(timestamp, {UuidValue? aggregateId})`
- **Count queries**: Add `countSince(timestamp)` for metrics

### Priority

**Medium-High**: This enhancement significantly improves developer experience and should be prioritized after the initial distributed events implementation is stable.

### Estimated Effort

- Phase 1 (Define interface): 1-2 hours
- Phase 2 (Update one repository generator): 4-8 hours
- Phase 3 (Roll out to all repositories): 2-4 hours per repository
- Phase 4 (Documentation and migration): 4-6 hours

**Total**: ~20-40 hours depending on number of repository packages


## JSON/Map Field Support in SQL Repository Generators

### Overview

Currently, SQL repository generators (MySQL, PostgreSQL, SQLite) do not support `Map<String, dynamic>` or `List<T>` fields on aggregate roots. This limitation affects StoredEvent's `context` field, which is a `Map<String, dynamic>` used for authorization filtering.

### Current Limitation

**What doesn't work:**

```dart
@GenerateMysqlRepository()
class StoredEventMysql extends StoredEvent {
  StoredEventMysql({
    required super.id,
    required super.createdAt,
    required super.aggregateId,
    required super.eventType,
    required super.eventJson,
    required super.context, // Map<String, dynamic> - NOT SUPPORTED
  });
}
```

The generated repository will fail to properly store/retrieve the `context` field because:
- `_encodeValue()` doesn't handle Map or List types
- `_flattenForTable()` doesn't serialize complex types to JSON
- `_rowToJson()` doesn't deserialize JSON columns back to Map/List

### Desired Future State

**What should work:**

```dart
@GenerateMysqlRepository()
class StoredEventMysql extends StoredEvent {
  StoredEventMysql({
    required super.id,
    required super.createdAt,
    required super.aggregateId,
    required super.eventType,
    required super.eventJson,
    required super.context, // Automatically stored as JSON column
  });
}

// Generated repository handles JSON serialization automatically
final event = StoredEventMysql(
  id: eventId,
  createdAt: DateTime.now(),
  aggregateId: userId,
  eventType: 'UserCreatedEvent',
  eventJson: '{"email":"user@example.com"}',
  context: {'userId': 'user-123', 'tenantId': 'tenant-1'},
);

await repository.save(event);
// context is stored as: '{"userId":"user-123","tenantId":"tenant-1"}'

final loaded = await repository.findById(eventId);
print(loaded.context['userId']); // 'user-123'
```

### Implementation Strategy

#### Phase 1: Detect JSON Fields

Update code generators to detect fields that need JSON serialization:
- `Map<String, dynamic>`
- `Map<String, T>` where T is serializable
- `List<T>` where T is a primitive or serializable type
- Custom types annotated with `@JsonField()`

#### Phase 2: Update _encodeValue Method

```dart
Object? _encodeValue(dynamic value) {
  if (value == null) return null;
  
  // Handle UUID strings
  if (value is String && value.contains('-') && value.length == 36) {
    try {
      return _dialect.encodeUuid(UuidValue.fromString(value));
    } catch (_) {
      return value;
    }
  }
  
  // Handle DateTime strings
  if (value is String) {
    final dateTime = DateTime.tryParse(value);
    if (dateTime != null) {
      return _dialect.encodeDateTime(dateTime);
    }
  }
  
  // Handle booleans
  if (value is bool) {
    return value ? 1 : 0;
  }
  
  // NEW: Handle Map and List - serialize to JSON
  if (value is Map || value is List) {
    return jsonEncode(value);
  }
  
  return value;
}
```

#### Phase 3: Update _decodeValue Method

```dart
dynamic _decodeValue(Object? value, String fieldName, Type fieldType) {
  if (value == null) return null;
  
  // Existing decoding logic...
  
  // NEW: Decode JSON fields based on type
  if (fieldType == Map<String, dynamic> || 
      fieldType.toString().startsWith('Map<') ||
      fieldType.toString().startsWith('List<')) {
    if (value is String) {
      try {
        return jsonDecode(value);
      } catch (e) {
        _logger.warning('Failed to decode JSON field $fieldName: $e');
        return null;
      }
    }
  }
  
  return value;
}
```

#### Phase 4: Schema Generation

Update schema generation to use appropriate JSON column types:

**MySQL:**
```sql
CREATE TABLE stored_events (
  id BINARY(16) PRIMARY KEY,
  created_at BIGINT NOT NULL,
  aggregate_id BINARY(16) NOT NULL,
  event_type VARCHAR(255) NOT NULL,
  event_json TEXT NOT NULL,
  context JSON,  -- Use JSON column type
  INDEX idx_created_at (created_at),
  INDEX idx_aggregate_id (aggregate_id)
);
```

**PostgreSQL:**
```sql
CREATE TABLE stored_events (
  id UUID PRIMARY KEY,
  created_at TIMESTAMP NOT NULL,
  aggregate_id UUID NOT NULL,
  event_type VARCHAR(255) NOT NULL,
  event_json TEXT NOT NULL,
  context JSONB,  -- Use JSONB for better performance
  INDEX idx_created_at (created_at),
  INDEX idx_aggregate_id (aggregate_id)
);
```

**SQLite:**
```sql
CREATE TABLE stored_events (
  id TEXT PRIMARY KEY,
  created_at INTEGER NOT NULL,
  aggregate_id TEXT NOT NULL,
  event_type TEXT NOT NULL,
  event_json TEXT NOT NULL,
  context TEXT,  -- Store as TEXT (SQLite has no JSON type)
  INDEX idx_created_at (created_at),
  INDEX idx_aggregate_id (aggregate_id)
);
```

#### Phase 5: Query Support

Enable querying on JSON fields (where database supports it):

**MySQL:**
```dart
// Query events by context field
final events = await repository.query(
  where: "JSON_EXTRACT(context, '\$.userId') = ?",
  whereArgs: ['user-123'],
);
```

**PostgreSQL:**
```dart
// Query events by context field
final events = await repository.query(
  where: "context->>'userId' = ?",
  whereArgs: ['user-123'],
);
```

### Type Metadata Requirements

To properly decode JSON fields, the generator needs type information. Options:

**Option A: Reflection (not available in Dart)**
- Can't use reflection to get field types at runtime

**Option B: Code Generation with Type Metadata**
```dart
// Generated code includes type metadata
final _fieldTypes = <String, Type>{
  'context': Map<String, dynamic>,
  'eventJson': String,
  'aggregateId': UuidValue,
};

dynamic _decodeValue(Object? value, String fieldName) {
  final fieldType = _fieldTypes[fieldName];
  // Use fieldType for decoding logic
}
```

**Option C: Annotation-Based**
```dart
class StoredEvent extends AggregateRoot {
  @JsonField()  // Explicitly mark JSON fields
  final Map<String, dynamic> context;
}
```

### Workaround for Initial Implementation

Until JSON field support is added, developers can manually handle JSON fields:

```dart
@GenerateMysqlRepository()
class StoredEventMysql extends StoredEvent {
  StoredEventMysql({
    required super.id,
    required super.createdAt,
    required super.aggregateId,
    required super.eventType,
    required super.eventJson,
    Map<String, dynamic>? context,
  }) : _contextJson = context != null ? jsonEncode(context) : null,
       super(context: context ?? {});
  
  // Store context as JSON string
  final String? _contextJson;
  
  // Override toJson to use _contextJson
  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json['context'] = _contextJson;
    return json;
  }
  
  // Override fromJson to parse _contextJson
  factory StoredEventMysql.fromJson(Map<String, dynamic> json) {
    final contextJson = json['context'] as String?;
    final context = contextJson != null 
        ? jsonDecode(contextJson) as Map<String, dynamic>
        : <String, dynamic>{};
    
    return StoredEventMysql(
      id: UuidValue.fromString(json['id']),
      createdAt: DateTime.parse(json['createdAt']),
      aggregateId: UuidValue.fromString(json['aggregateId']),
      eventType: json['eventType'],
      eventJson: json['eventJson'],
      context: context,
    );
  }
}
```

### Benefits

1. **Simplified development**: No manual JSON serialization for Map/List fields
2. **Type safety**: Proper typing maintained throughout
3. **Query support**: Can filter on JSON field contents (where database supports it)
4. **Consistent API**: Same approach across all SQL databases
5. **Better performance**: Native JSON types in PostgreSQL/MySQL

### Packages to Update

- `dddart_repository_mysql`
- `dddart_repository_sqlite`
- `dddart_repository_sql` (base SQL implementation)
- Future PostgreSQL package

### Priority

**High**: This limitation affects StoredEvent usability with SQL databases. Should be prioritized alongside or shortly after the initial distributed events implementation.

### Estimated Effort

- Phase 1-2 (Detection and encoding): 4-6 hours
- Phase 3 (Decoding with type metadata): 6-8 hours
- Phase 4 (Schema generation): 4-6 hours
- Phase 5 (Query support): 4-6 hours
- Testing and documentation: 6-8 hours

**Total**: ~24-34 hours
