# Design Document

## Overview

The `dddart_repository_mongodb` package provides MongoDB persistence for DDDart aggregate roots through code generation. It generates concrete repository implementations that leverage existing JSON serialization from `dddart_json` and the `mongo_dart` driver for MongoDB connectivity. The package targets AWS DocumentDB Serverless compatibility while maintaining broad MongoDB compatibility.

### Key Design Principles

1. **Leverage Existing Serialization**: Reuse `dddart_json` serializers to avoid duplicate serialization logic
2. **Code Generation Pattern**: Follow the same annotation-driven code generation pattern as `dddart_json`
3. **Extensibility**: Generated repositories can be used directly or extended with custom query methods
4. **Encapsulation**: Database connections are library-private but accessible to subclasses in the same library
5. **Standard MongoDB Driver**: Use `mongo_dart` for mature, well-tested MongoDB connectivity

## Architecture

### Package Structure

```
packages/dddart_repository_mongodb/
├── lib/
│   ├── dddart_repository_mongodb.dart          # Main library export
│   └── src/
│       ├── annotations/
│       │   └── generate_mongo_repository.dart  # @GenerateMongoRepository annotation
│       ├── generators/
│       │   └── mongo_repository_generator.dart # Code generator
│       ├── connection/
│       │   └── mongo_connection.dart           # Connection management
│       └── exceptions/
│           └── mongo_repository_exception.dart # MongoDB-specific exception mapping
├── test/
│   ├── generator_test.dart                     # Generator unit tests
│   ├── repository_test.dart                    # Generated repository tests
│   └── connection_test.dart                    # Connection management tests
├── example/
│   ├── lib/
│   │   └── domain/
│   │       ├── user.dart                       # Example aggregate
│   │       └── user.mongo_repository.g.dart    # Generated repository
│   ├── basic_crud.dart                         # Basic CRUD example
│   ├── custom_queries.dart                     # Extended repository example
│   ├── error_handling.dart                     # Error handling example
│   ├── with_config.dart                        # Using dddart_config example
│   ├── pubspec.yaml
│   └── README.md
├── build.yaml                                  # Build configuration
├── pubspec.yaml
└── README.md
```

### Dependencies

```yaml
dependencies:
  dddart: ^1.0.0
  dddart_serialization: ^1.0.0
  dddart_json: ^1.0.0
  mongo_dart: ^0.10.0
  
dev_dependencies:
  build: ^2.4.0
  source_gen: ^1.4.0
  build_runner: ^2.4.0
  test: ^1.24.0
  very_good_analysis: ^6.0.0
```

## Components and Interfaces

### 1. Annotation: `@GenerateMongoRepository()`

```dart
/// Annotation to mark aggregate roots for MongoDB repository generation.
///
/// Example without custom interface:
/// ```dart
/// @Serializable()
/// @GenerateMongoRepository(collectionName: 'users')
/// class User extends AggregateRoot {
///   final String firstName;
///   final String lastName;
///   
///   User({required this.firstName, required this.lastName});
/// }
/// // Generates: class UserMongoRepository implements Repository<User>
/// ```
///
/// Example with custom interface:
/// ```dart
/// abstract interface class UserRepository implements Repository<User> {
///   Future<User?> findByEmail(String email);
/// }
///
/// @Serializable()
/// @GenerateMongoRepository(
///   collectionName: 'users',
///   implements: UserRepository,
/// )
/// class User extends AggregateRoot {
///   final String firstName;
///   final String email;
///   
///   User({required this.firstName, required this.email});
/// }
/// // Generates: abstract class UserMongoRepositoryBase implements UserRepository
/// ```
class GenerateMongoRepository {
  /// Creates a GenerateMongoRepository annotation.
  ///
  /// [collectionName] - Optional custom collection name. If not provided,
  /// the aggregate class name will be converted to snake_case.
  /// 
  /// [implements] - Optional custom repository interface. If provided and
  /// the interface contains custom methods beyond Repository<T>, an abstract
  /// base class will be generated requiring the developer to implement
  /// custom methods.
  const GenerateMongoRepository({
    this.collectionName,
    this.implements,
  });
  
  /// The MongoDB collection name for this aggregate type.
  /// If null, defaults to snake_case of the class name.
  final String? collectionName;
  
  /// The custom repository interface to implement.
  /// If null, generates a concrete class implementing Repository<T>.
  /// If provided with custom methods, generates an abstract base class.
  final Type? implements;
}
```

### 2. Connection Management: `MongoConnection`

```dart
/// Manages MongoDB database connections.
///
/// Provides connection lifecycle management and database instance access.
/// Does not manage connection pooling (handled by mongo_dart internally).
class MongoConnection {
  /// Creates a connection from individual parameters.
  MongoConnection({
    required this.host,
    required this.port,
    required this.databaseName,
    this.username,
    this.password,
    this.authSource,
    this.tls = false,
    this.tlsAllowInvalidCertificates = false,
  });
  
  /// Creates a connection from a MongoDB connection string URI.
  ///
  /// Supports standard MongoDB URIs and AWS DocumentDB connection strings.
  factory MongoConnection.fromUri(String uri);
  
  final String host;
  final int port;
  final String databaseName;
  final String? username;
  final String? password;
  final String? authSource;
  final bool tls;
  final bool tlsAllowInvalidCertificates;
  
  Db? _db;
  
  /// Opens the connection to MongoDB.
  ///
  /// Must be called before accessing [database].
  /// Throws [MongoRepositoryException] if connection fails.
  Future<void> open() async {
    if (_db != null && _db!.isConnected) return;
    
    final connectionString = _buildConnectionString();
    _db = await Db.create(connectionString);
    await _db!.open();
  }
  
  /// Closes the connection to MongoDB.
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
  
  /// Gets the database instance.
  ///
  /// Throws [StateError] if connection is not open.
  Db get database {
    if (_db == null || !_db!.isConnected) {
      throw StateError('Connection not open. Call open() first.');
    }
    return _db!;
  }
  
  /// Checks if the connection is currently open.
  bool get isConnected => _db != null && _db!.isConnected;
  
  String _buildConnectionString() {
    // Build MongoDB connection string from parameters
    // Format: mongodb://[username:password@]host:port/database[?options]
  }
}
```

### 3. Generated Repository Classes

The generator creates different outputs based on whether a custom interface is specified:

#### Case 1: No Custom Interface (Concrete Class)

For an aggregate `User` without a custom interface:

```dart
// user.mongo_repository.g.dart
part of 'user.dart';

/// Generated MongoDB repository for [User] aggregate.
///
/// This class can be used directly for basic CRUD operations or extended
/// to add custom query methods.
class UserMongoRepository implements Repository<User> {
  /// Creates a repository instance.
  ///
  /// [database] - An open MongoDB database connection.
  UserMongoRepository(this._database);
  
  /// The MongoDB database instance (library-private).
  final Db _database;
  
  /// The collection name for User aggregates.
  String get collectionName => 'users';
  
  /// Gets the MongoDB collection for this aggregate type.
  DbCollection get _collection => _database.collection(collectionName);
  
  /// The JSON serializer for User aggregates.
  final _serializer = UserJsonSerializer();
  
  @override
  Future<User> getById(UuidValue id) async {
    try {
      final doc = await _collection.findOne(where.eq('_id', id.toString()));
      
      if (doc == null) {
        throw RepositoryException(
          'User with ID $id not found',
          type: RepositoryExceptionType.notFound,
        );
      }
      
      // Convert MongoDB _id back to id field for deserialization
      doc['id'] = doc['_id'];
      doc.remove('_id');
      
      return _serializer.fromJson(doc);
    } on RepositoryException {
      rethrow;
    } catch (e, stackTrace) {
      throw RepositoryException(
        'Failed to retrieve User with ID $id: $e',
        type: RepositoryExceptionType.unknown,
        cause: e,
        stackTrace: stackTrace,
      );
    }
  }
  
  @override
  Future<void> save(User aggregate) async {
    try {
      final doc = _serializer.toJson(aggregate);
      
      // Use aggregate's id as MongoDB _id
      doc['_id'] = doc['id'];
      doc.remove('id');
      
      // Upsert operation
      await _collection.replaceOne(
        where.eq('_id', aggregate.id.toString()),
        doc,
        upsert: true,
      );
    } on MongoDartError catch (e, stackTrace) {
      throw _mapMongoException(e, stackTrace, 'save');
    } catch (e, stackTrace) {
      throw RepositoryException(
        'Failed to save User: $e',
        type: RepositoryExceptionType.unknown,
        cause: e,
        stackTrace: stackTrace,
      );
    }
  }
  
  @override
  Future<void> deleteById(UuidValue id) async {
    try {
      final result = await _collection.deleteOne(where.eq('_id', id.toString()));
      
      if (result['n'] == 0) {
        throw RepositoryException(
          'User with ID $id not found',
          type: RepositoryExceptionType.notFound,
        );
      }
    } on RepositoryException {
      rethrow;
    } on MongoDartError catch (e, stackTrace) {
      throw _mapMongoException(e, stackTrace, 'deleteById');
    } catch (e, stackTrace) {
      throw RepositoryException(
        'Failed to delete User with ID $id: $e',
        type: RepositoryExceptionType.unknown,
        cause: e,
        stackTrace: stackTrace,
      );
    }
  }
  
  /// Maps MongoDB exceptions to RepositoryException types.
  RepositoryException _mapMongoException(
    MongoDartError error,
    StackTrace stackTrace,
    String operation,
  ) {
    // Map specific MongoDB error codes to RepositoryExceptionType
    if (error.message?.contains('duplicate key') ?? false) {
      return RepositoryException(
        'Duplicate key error during $operation: ${error.message}',
        type: RepositoryExceptionType.duplicate,
        cause: error,
        stackTrace: stackTrace,
      );
    }
    
    if (error.message?.contains('connection') ?? false) {
      return RepositoryException(
        'Connection error during $operation: ${error.message}',
        type: RepositoryExceptionType.connection,
        cause: error,
        stackTrace: stackTrace,
      );
    }
    
    if (error.message?.contains('timeout') ?? false) {
      return RepositoryException(
        'Timeout during $operation: ${error.message}',
        type: RepositoryExceptionType.timeout,
        cause: error,
        stackTrace: stackTrace,
      );
    }
    
    return RepositoryException(
      'MongoDB error during $operation: ${error.message}',
      type: RepositoryExceptionType.unknown,
      cause: error,
      stackTrace: stackTrace,
    );
  }
}
```

### 4. Code Generator: `MongoRepositoryGenerator`

```dart
/// Generator for MongoDB repository implementations.
class MongoRepositoryGenerator extends GeneratorForAnnotation<GenerateMongoRepository> {
  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    // 1. Validate element is a ClassElement
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
        'Only classes can be annotated with @GenerateMongoRepository.',
        element: element,
      );
    }
    
    // 2. Validate class extends AggregateRoot
    if (!_extendsAggregateRoot(element)) {
      throw InvalidGenerationSourceError(
        'Class ${element.name} must extend AggregateRoot to use @GenerateMongoRepository.',
        element: element,
      );
    }
    
    // 3. Validate class has @Serializable annotation
    if (!_hasSerializableAnnotation(element)) {
      throw InvalidGenerationSourceError(
        'Class ${element.name} must be annotated with @Serializable() to use @GenerateMongoRepository.',
        element: element,
      );
    }
    
    // 4. Extract configuration
    final className = element.name;
    final collectionName = _extractCollectionName(annotation, className);
    final customInterface = _extractImplementsInterface(annotation);
    
    // 5. Determine what to generate based on interface analysis
    if (customInterface == null) {
      // No custom interface - generate concrete class
      return _generateConcreteRepository(className, collectionName);
    }
    
    // 6. Analyze interface to determine if abstract base is needed
    final interfaceMethods = _getInterfaceMethods(customInterface);
    final baseRepositoryMethods = {'getById', 'save', 'deleteById'};
    final customMethods = interfaceMethods
        .where((m) => !baseRepositoryMethods.contains(m.name))
        .toList();
    
    if (customMethods.isEmpty) {
      // Interface only has base Repository methods - generate concrete class
      return _generateConcreteRepository(
        className,
        collectionName,
        implements: customInterface,
      );
    } else {
      // Interface has custom methods - generate abstract base class
      return _generateAbstractBaseRepository(
        className,
        collectionName,
        implements: customInterface,
        abstractMethods: customMethods,
      );
    }
  }
  
  bool _extendsAggregateRoot(ClassElement element) {
    // Walk inheritance hierarchy to find AggregateRoot
    ClassElement? current = element;
    while (current != null) {
      if (current.name == 'AggregateRoot') return true;
      final supertype = current.supertype;
      if (supertype == null) break;
      current = supertype.element as ClassElement?;
    }
    return false;
  }
  
  bool _hasSerializableAnnotation(ClassElement element) {
    // Check for @Serializable annotation
    return element.metadata.any((annotation) {
      final element = annotation.element;
      return element is ConstructorElement &&
          element.enclosingElement.name == 'Serializable';
    });
  }
  
  String _extractCollectionName(ConstantReader annotation, String className) {
    // Get collectionName from annotation or default to snake_case
    final collectionName = annotation.peek('collectionName')?.stringValue;
    return collectionName ?? _toSnakeCase(className);
  }
  
  InterfaceType? _extractImplementsInterface(ConstantReader annotation) {
    // Extract the Type from the 'implements' parameter
    final implementsField = annotation.peek('implements');
    if (implementsField == null || implementsField.isNull) return null;
    
    return implementsField.typeValue as InterfaceType?;
  }
  
  List<MethodElement> _getInterfaceMethods(InterfaceType interfaceType) {
    final methods = <MethodElement>[];
    
    // Get methods from the interface itself
    methods.addAll(interfaceType.methods);
    
    // Get methods from all superinterfaces (including Repository<T>)
    for (final supertype in interfaceType.allSupertypes) {
      methods.addAll(supertype.methods);
    }
    
    return methods;
  }
  
  String _generateConcreteRepository(
    String className,
    String collectionName, {
    InterfaceType? implements,
  }) {
    // Generate fully concrete repository class
    final interfaceClause = implements != null
        ? 'implements ${implements.element.name}'
        : 'implements Repository<$className>';
    
    return '''
class ${className}MongoRepository $interfaceClause {
  ${className}MongoRepository(this._database);
  
  final Db _database;
  String get collectionName => '$collectionName';
  // ... full implementation
}
''';
  }
  
  String _generateAbstractBaseRepository(
    String className,
    String collectionName, {
    required InterfaceType implements,
    required List<MethodElement> abstractMethods,
  }) {
    // Generate abstract base class with concrete CRUD and abstract custom methods
    final buffer = StringBuffer();
    
    buffer.writeln('abstract class ${className}MongoRepositoryBase implements ${implements.element.name} {');
    buffer.writeln('  ${className}MongoRepositoryBase(this._database);');
    buffer.writeln('  ');
    buffer.writeln('  final Db _database;');
    buffer.writeln('  String get collectionName => \'$collectionName\';');
    buffer.writeln('  // ... concrete CRUD implementation');
    buffer.writeln('  ');
    
    // Add abstract method declarations
    for (final method in abstractMethods) {
      buffer.writeln('  @override');
      buffer.writeln('  ${_generateMethodSignature(method)};');
      buffer.writeln('  ');
    }
    
    buffer.writeln('}');
    
    return buffer.toString();
  }
  
  String _generateMethodSignature(MethodElement method) {
    // Generate method signature from MethodElement
    final returnType = method.returnType.getDisplayString(withNullability: true);
    final params = method.parameters.map((p) {
      final type = p.type.getDisplayString(withNullability: true);
      return '$type ${p.name}';
    }).join(', ');
    
    return 'Future<$returnType> ${method.name}($params)';
  }
  
  String _toSnakeCase(String input) {
    return input.replaceAllMapped(
      RegExp('[A-Z]'),
      (match) => '_${match.group(0)!.toLowerCase()}',
    ).substring(1); // Remove leading underscore
  }
}
```

## Interface Introspection and Code Generation Strategy

### Decision Logic

The generator uses interface introspection to determine whether to generate a concrete class or an abstract base class:

```
┌─────────────────────────────────────┐
│ @GenerateMongoRepository()          │
└──────────────┬──────────────────────┘
               │
               ▼
       ┌───────────────┐
       │ Has custom    │
       │ interface?    │
       └───┬───────┬───┘
           │       │
          No      Yes
           │       │
           │       ▼
           │   ┌────────────────────┐
           │   │ Introspect         │
           │   │ interface methods  │
           │   └────────┬───────────┘
           │            │
           │            ▼
           │   ┌────────────────────┐
           │   │ Has methods beyond │
           │   │ Repository<T>?     │
           │   └───┬────────────┬───┘
           │       │            │
           │      No           Yes
           │       │            │
           ▼       ▼            ▼
    ┌──────────────────┐  ┌──────────────────────┐
    │ Generate         │  │ Generate             │
    │ Concrete Class   │  │ Abstract Base Class  │
    │                  │  │                      │
    │ UserMongoRepo    │  │ UserMongoRepoBase    │
    │ (fully impl)     │  │ (CRUD impl, custom   │
    │                  │  │  methods abstract)   │
    └──────────────────┘  └──────────────────────┘
```

### Method Classification

The generator classifies methods into two categories:

1. **Base Repository Methods** (can be generated):
   - `Future<T> getById(UuidValue id)`
   - `Future<void> save(T aggregate)`
   - `Future<void> deleteById(UuidValue id)`

2. **Custom Methods** (cannot be generated):
   - Any method not in the base set
   - Examples: `findByEmail`, `searchByName`, `getActiveUsers`

### Examples

#### Example 1: No Interface → Concrete Class

```dart
@GenerateMongoRepository()
class User extends AggregateRoot { ... }

// Generated:
class UserMongoRepository implements Repository<User> {
  // Fully implemented
}
```

#### Example 2: Interface with Only Base Methods → Concrete Class

```dart
abstract interface class UserRepository implements Repository<User> {
  // Only has: getById, save, deleteById (inherited)
}

@GenerateMongoRepository(implements: UserRepository)
class User extends AggregateRoot { ... }

// Generated:
class UserMongoRepository implements UserRepository {
  // Fully implemented (all methods are base methods)
}
```

#### Example 3: Interface with Custom Methods → Abstract Base Class

```dart
abstract interface class UserRepository implements Repository<User> {
  Future<User?> findByEmail(String email); // ← Custom method!
}

@GenerateMongoRepository(implements: UserRepository)
class User extends AggregateRoot { ... }

// Generated:
abstract class UserMongoRepositoryBase implements UserRepository {
  // Implemented: getById, save, deleteById
  // Abstract: findByEmail
}

// Developer must create:
class UserMongoRepository extends UserMongoRepositoryBase {
  @override
  Future<User?> findByEmail(String email) {
    // Implementation
  }
}
```

### Naming Convention

| Scenario | Generated Class Name | Type |
|----------|---------------------|------|
| No custom interface | `{ClassName}MongoRepository` | Concrete |
| Interface with only base methods | `{ClassName}MongoRepository` | Concrete |
| Interface with custom methods | `{ClassName}MongoRepositoryBase` | Abstract |

The `Base` suffix signals to developers that they must extend the class and implement abstract methods.

### Type Safety

The Dart type system enforces correct usage:

```dart
// ✅ Concrete class - can instantiate directly
final repo = UserMongoRepository(database);

// ❌ Abstract base class - compile error
final repo = UserMongoRepositoryBase(database);
// Error: Cannot instantiate abstract class

// ✅ Must extend and implement
class UserMongoRepository extends UserMongoRepositoryBase {
  // Must implement all abstract methods
}
```

## Data Models

### ID Mapping Strategy

MongoDB uses `_id` as the primary key field. We map DDDart's `id` field to MongoDB's `_id`:

**Saving:**
```dart
// Aggregate has: { id: "uuid-123", firstName: "John", ... }
// Serialize to: { id: "uuid-123", firstName: "John", ... }
// Transform to: { _id: "uuid-123", firstName: "John", ... }
// Store in MongoDB
```

**Loading:**
```dart
// Load from MongoDB: { _id: "uuid-123", firstName: "John", ... }
// Transform to: { id: "uuid-123", firstName: "John", ... }
// Deserialize to aggregate
```

### Collection Naming Convention

- **Default**: Class name converted to snake_case (e.g., `UserProfile` → `user_profiles`)
- **Custom**: Specified via annotation parameter `@GenerateMongoRepository(collectionName: 'custom_name')`

### Field Serialization

All field serialization is delegated to the existing `JsonSerializer` from `dddart_json`:
- Respects `SerializationConfig` (field renaming, null handling)
- Handles nested Value objects and collections
- Maintains consistency with REST API serialization

## Error Handling

### Exception Mapping

MongoDB errors are mapped to `RepositoryException` types:

| MongoDB Error | RepositoryExceptionType | Trigger |
|--------------|------------------------|---------|
| Duplicate key error (E11000) | `duplicate` | Unique constraint violation |
| Connection errors | `connection` | Network issues, auth failures |
| Timeout errors | `timeout` | Operation exceeds time limit |
| Not found (0 documents affected) | `notFound` | `getById` or `deleteById` with non-existent ID |
| Other errors | `unknown` | Unexpected MongoDB errors |

### Error Handling Pattern

```dart
try {
  // MongoDB operation
} on RepositoryException {
  rethrow; // Already a RepositoryException
} on MongoDartError catch (e, stackTrace) {
  throw _mapMongoException(e, stackTrace, operation);
} catch (e, stackTrace) {
  throw RepositoryException(
    'Unexpected error: $e',
    type: RepositoryExceptionType.unknown,
    cause: e,
    stackTrace: stackTrace,
  );
}
```

## Testing Strategy

### Unit Tests

1. **Generator Tests** (`generator_test.dart`)
   - Validate annotation processing
   - Test error cases (missing @Serializable, not extending AggregateRoot)
   - Verify collection name generation (default and custom)
   - Test code generation output structure

2. **Connection Tests** (`connection_test.dart`)
   - Test connection string building
   - Test URI parsing
   - Test connection lifecycle (open/close)
   - Test error handling for connection failures

### Integration Tests

3. **Repository Tests** (`repository_test.dart`)
   - Test CRUD operations against in-memory MongoDB (using `mongo_dart_query`)
   - Test ID mapping (_id ↔ id)
   - Test exception mapping
   - Test with different SerializationConfig options
   - Test extended repositories with custom queries

### Test Utilities

```dart
/// Test helper for in-memory MongoDB testing
class TestMongoConnection {
  static Future<Db> createInMemory() async {
    // Create in-memory or test MongoDB instance
  }
}

/// Test aggregate for repository testing
@Serializable()
@GenerateMongoRepository()
class TestUser extends AggregateRoot {
  final String name;
  final String email;
  
  TestUser({required this.name, required this.email});
}
```

#### Case 2: Custom Interface with Only Base Methods (Concrete Class)

```dart
// user_repository.dart
abstract interface class UserRepository implements Repository<User> {
  // Only inherits: getById, save, deleteById
}

// user.dart
@Serializable()
@GenerateMongoRepository(implements: UserRepository)
class User extends AggregateRoot {
  final String firstName;
  User({required this.firstName});
}

part 'user.mongo_repository.g.dart';

// user.mongo_repository.g.dart - GENERATED (concrete class)
class UserMongoRepository implements UserRepository {
  UserMongoRepository(this._database);
  
  final Db _database;
  String get collectionName => 'users';
  
  // All methods fully implemented
  @override
  Future<User> getById(UuidValue id) async { ... }
  
  @override
  Future<void> save(User aggregate) async { ... }
  
  @override
  Future<void> deleteById(UuidValue id) async { ... }
}
```

#### Case 3: Custom Interface with Custom Methods (Abstract Base Class)

```dart
// user_repository.dart - DEVELOPER writes this
abstract interface class UserRepository implements Repository<User> {
  Future<User?> findByEmail(String email);
  Future<List<User>> findByLastName(String lastName);
}

// user.dart
@Serializable()
@GenerateMongoRepository(implements: UserRepository)
class User extends AggregateRoot {
  final String firstName;
  final String email;
  User({required this.firstName, required this.email});
}

part 'user.mongo_repository.g.dart';

// user.mongo_repository.g.dart - GENERATED (abstract base class)
abstract class UserMongoRepositoryBase implements UserRepository {
  UserMongoRepositoryBase(this._database);
  
  final Db _database;
  String get collectionName => 'users';
  DbCollection get _collection => _database.collection(collectionName);
  final _serializer = UserJsonSerializer();
  
  // ✅ Implemented: Base Repository methods
  @override
  Future<User> getById(UuidValue id) async { ... }
  
  @override
  Future<void> save(User aggregate) async { ... }
  
  @override
  Future<void> deleteById(UuidValue id) async { ... }
  
  // ❌ Abstract: Custom methods (developer must implement)
  @override
  Future<User?> findByEmail(String email);
  
  @override
  Future<List<User>> findByLastName(String lastName);
}

// user_mongo_repository.dart - DEVELOPER completes implementation
class UserMongoRepository extends UserMongoRepositoryBase {
  UserMongoRepository(super.database);
  
  @override
  Future<User?> findByEmail(String email) async {
    final doc = await _collection.findOne(where.eq('email', email));
    if (doc == null) return null;
    
    doc['id'] = doc['_id'];
    doc.remove('_id');
    return _serializer.fromJson(doc);
  }
  
  @override
  Future<List<User>> findByLastName(String lastName) async {
    final docs = await _collection
        .find(where.eq('lastName', lastName))
        .toList();
    
    return docs.map((doc) {
      doc['id'] = doc['_id'];
      doc.remove('_id');
      return _serializer.fromJson(doc);
    }).toList();
  }
}
```

## Extensibility Pattern

### Pattern 1: Simple CRUD (No Custom Interface)

```dart
// user.dart
@Serializable()
@GenerateMongoRepository()
class User extends AggregateRoot {
  final String firstName;
  User({required this.firstName});
}

part 'user.mongo_repository.g.dart';

// Usage
final repo = UserMongoRepository(database);
await repo.save(user);
final retrieved = await repo.getById(user.id);
```

### Pattern 2: Multiple Implementations (Custom Interface)

```dart
// user_repository.dart - Domain layer
abstract interface class UserRepository implements Repository<User> {
  Future<User?> findByEmail(String email);
}

// user.dart
@Serializable()
@GenerateMongoRepository(implements: UserRepository)
class User extends AggregateRoot {
  final String email;
  User({required this.email});
}

part 'user.mongo_repository.g.dart';

// user_mongo_repository.dart - MongoDB implementation
class UserMongoRepository extends UserMongoRepositoryBase {
  UserMongoRepository(super.database);
  
  @override
  Future<User?> findByEmail(String email) async {
    // MongoDB-specific implementation
  }
}

// user_rest_repository.dart - REST implementation (future package)
class UserRestRepository implements UserRepository {
  final ApiClient _client;
  
  @override
  Future<User> getById(UuidValue id) async {
    // REST API call
  }
  
  @override
  Future<User?> findByEmail(String email) async {
    // REST API call
  }
}

// Usage - swappable implementations
UserRepository repo = UserMongoRepository(database); // Production
UserRepository repo = UserRestRepository(apiClient); // Client-side
UserRepository repo = InMemoryRepository<User>();    // Testing
```

## Integration with dddart_config

Example showing configuration integration:

```dart
import 'package:dddart_config/dddart_config.dart';
import 'package:dddart_repository_mongodb/dddart_repository_mongodb.dart';

Future<void> main() async {
  // Load configuration
  final config = await ConfigLoader.load();
  
  // Create connection from config
  final connection = MongoConnection(
    host: config.getString('mongodb.host'),
    port: config.getInt('mongodb.port'),
    databaseName: config.getString('mongodb.database'),
    username: config.getString('mongodb.username'),
    password: config.getString('mongodb.password'),
    tls: config.getBool('mongodb.tls', defaultValue: false),
  );
  
  await connection.open();
  
  // Create repository
  final userRepo = UserMongoRepository(connection.database);
  
  // Use repository
  final user = User(firstName: 'John', lastName: 'Doe');
  await userRepo.save(user);
  
  await connection.close();
}
```

## Build Configuration

### build.yaml

```yaml
targets:
  $default:
    builders:
      dddart_repository_mongodb|mongo_repository:
        enabled: true
        generate_for:
          - lib/**/*.dart
          - test/**/*.dart
        options:
          # Future: Add generator options here

builders:
  mongo_repository:
    import: "package:dddart_repository_mongodb/src/generators/mongo_repository_generator.dart"
    builder_factories: ["mongoRepositoryBuilder"]
    build_extensions: {".dart": [".mongo_repository.g.dart"]}
    auto_apply: dependents
    build_to: source
    runs_before:
      - json_serializable
```

## AWS DocumentDB Compatibility

### Connection String Format

AWS DocumentDB uses TLS and requires specific connection parameters:

```dart
final connection = MongoConnection(
  host: 'docdb-cluster.cluster-xxx.us-east-1.docdb.amazonaws.com',
  port: 27017,
  databaseName: 'myapp',
  username: 'myuser',
  password: 'mypassword',
  tls: true,
  tlsAllowInvalidCertificates: true, // For DocumentDB with self-signed certs
  authSource: 'admin',
);
```

Or using URI:

```dart
final connection = MongoConnection.fromUri(
  'mongodb://myuser:mypassword@docdb-cluster.cluster-xxx.us-east-1.docdb.amazonaws.com:27017/myapp?tls=true&tlsAllowInvalidCertificates=true&authSource=admin'
);
```

### Compatibility Notes

- AWS DocumentDB is API-compatible with MongoDB 4.0
- `mongo_dart` supports MongoDB 4.0+ features
- TLS is required for DocumentDB connections
- Certificate validation may need to be disabled for self-signed certs
- Connection pooling is handled by `mongo_dart` internally

## Performance Considerations

1. **Connection Pooling**: `mongo_dart` handles connection pooling internally; reuse `MongoConnection` instances
2. **Serialization Overhead**: Minimal - direct map conversion without string encoding
3. **Index Strategy**: Developers should create indexes on MongoDB collections for custom query fields
4. **Batch Operations**: Future enhancement - add bulk save/delete methods
5. **Query Optimization**: Custom queries should use MongoDB indexes and query optimization techniques

## Transaction Support Decision

**Transactions are explicitly NOT supported in v1** to maintain clean abstraction and implementation independence.

### Rationale

1. **DDD Philosophy**: Each aggregate root should be independently consistent. Transactions across multiple aggregates often indicate incorrect aggregate boundaries.

2. **Implementation Independence**: Transaction semantics vary significantly across implementations:
   - MongoDB: `ClientSession` with multi-document ACID transactions
   - REST APIs: No native transaction support (might use optimistic locking or batch operations)
   - In-memory: No transaction concept needed

3. **Leaky Abstraction**: Adding transaction support to the repository interface would leak implementation details and prevent true implementation swapping.

### Alternatives for Developers

When transactional operations are genuinely required:

1. **Reconsider Aggregate Boundaries** (Preferred):
   ```dart
   // Instead of two aggregates with transaction
   class Order extends AggregateRoot {
     final UuidValue userId; // Reference, not full User
     // Order is independently consistent
   }
   ```

2. **Use Domain Events for Eventual Consistency**:
   ```dart
   user.placeOrder(orderId);
   await userRepo.save(user); // Raises OrderPlacedEvent
   // Event handler creates order asynchronously
   ```

3. **Access Database Directly** (Escape Hatch):
   ```dart
   final session = await db.startSession();
   session.startTransaction();
   try {
     await db.collection('users').replaceOne(..., session: session);
     await db.collection('orders').replaceOne(..., session: session);
     await session.commitTransaction();
   } catch (e) {
     await session.abortTransaction();
   }
   ```

### Future Consideration

If transaction support becomes a common requirement, a **Unit of Work pattern** could be introduced in a future version as a separate abstraction that doesn't pollute the repository interface.

## Future Enhancements

1. **Query Builder**: Type-safe query builder for common query patterns
2. **Batch Operations**: `saveAll()`, `deleteAll()` methods
3. **Pagination Support**: Built-in pagination helpers
4. **Change Streams**: MongoDB change stream support for event sourcing
5. **Unit of Work Pattern**: Optional transaction support through separate abstraction
6. **Aggregation Pipeline**: Helper methods for aggregation queries
7. **Index Management**: Annotation-driven index creation
8. **Convention-Based Query Generation**: Automatic implementation of simple queries like `findByEmail` using annotations
