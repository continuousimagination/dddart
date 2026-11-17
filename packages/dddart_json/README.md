# DDDart JSON

[Supported platforms and capability boundaries](../../docs/CAPABILITIES.md) ·
[Supported imports and extension APIs](../../docs/PUBLIC_API.md)


For complete setup, named source files, expected output and cleanup, follow the
[canonical quickstart](../../docs/quickstarts/json/README.md). Other inline Dart snippets below are
**illustrative fragments** that assume application-specific models and surrounding
setup; they are not standalone programs. See the [quickstart inventory](../../docs/QUICKSTARTS.md)
for runnable, browser, service and credential-dependent coverage.


See the [serialization configuration and error contract](../../docs/SERIALIZATION.md)
for typed options, precedence, identity codecs, and failure behavior.


Concrete `DomainEvent<I>` classes are also supported. Expose named `aggregateId`,
`eventId`, `occurredAt` and `context` constructor parameters (normally through
`super` parameters). Event serializers retain the concrete identity codec and
UUID occurrence ID; they do not add entity timestamps. Private ancestor state
from another Dart library is not a public serialization field. Distributed event
registrations are documented in `dddart_events_distributed`.


JSON serialization code generation for DDDart aggregate roots, entities, and
value objects.

## Features

- **PODO Preservation**: Keep your domain objects as Plain Old Dart Objects
- **Service Class Generation**: Creates dedicated serializer classes - no mixins required
- **DDD Types**: Generates serializers for AggregateRoots, Entities, and Values
- **Cross-Platform**: Works on Dart server, Flutter mobile, and Flutter web
- **Nested Serialization**: Handles complex object graphs with embedded values and entities
- **Flexible Configuration**: Constructor-level defaults with method-level overrides
- **Type Safety**: Full compile-time type checking with generic interfaces

## Installation

DDDart is currently Git-only. Use the [Git installation guide](../../docs/GIT_INSTALLATION.md)
and the complete dependency setup in the [canonical quickstart](../../docs/quickstarts/json/README.md).
Pin all DDDart dependencies and overrides to the same full commit.

## Quick Start

Follow the [complete json generation and round trip workflow](../../docs/quickstarts/json/README.md).
It includes an outside-workspace pubspec, every import/model/part, clean generation
where required, execution, expected output and cleanup.

## Configuration

### Identity generation

Use `AggregateRoot<UuidValue>`/`Entity<UuidValue>` for UUID identities, supplying
an ID or generating one explicitly in the domain constructor. Externally
identified aggregates extend `AggregateRoot<IssueId>` and supply their native
ID. Define a concrete application `Identity` and register its `IdentityCodec`
with `IdentityCodecRegistry` from `dddart_serialization`.

```dart
final codecs = IdentityCodecRegistry()
  ..register<IssueId>('github.issue.v1', IssueIdCodec());
final serializer = IssueJsonSerializer.withIdentityCodecs(codecs);
final json = serializer.toJson(issue);
final restored = serializer.fromJson(json);
```

The generated `identityCodecs` getter exposes the shared registry for composition.
Nested generated serializers receive the same registry, including identities in
nullable fields, lists, sets, map values and identity map keys. JSON map keys are
strings or concrete identities; identity keys use the canonical key codec.
Stock UUIDs retain their string JSON representation. Application identity kinds
are recognized by type, so a class's name cannot accidentally select UUID
encoding.

`IssueJsonSerializer.withIdentityCodecs(codecs, config)` accepts constructor
configuration. Static helpers accept the registry after configuration:
`IssueJsonSerializer.encode(issue, config, codecs)` and
`IssueJsonSerializer.decode(json, config, codecs)`. Existing UUID serializers
can still use their default constructor.

An annotated class must have concrete identity and field types. A concrete class
can inherit from an unannotated generic base; inherited fields are resolved with
its type arguments. Annotated open generic classes, erased `Identity` roots and
unsupported map key types fail generation with a diagnostic. Regenerate every
owning library after migrating its base classes, then analyze and test the
combined generated part with its handwritten owner.

See [codec contracts](../dddart_serialization/README.md#identity-codecs) for the
tagged envelope and key validation rules. Repository adapter migration is
tracked separately from serializer support.

### Field Naming Strategies

Configure how field names are transformed in JSON:

```dart
import 'package:dddart_serialization/dddart_serialization.dart';

// Annotation-level configuration is the generated default.
@Serializable(
  fieldRename: FieldRename.kebab,
  includeNullFields: false,
)
class ApiValue extends Value {
  // ...
}

// Constructor-level configuration (default for all operations)
final snakeSerializer = UserJsonSerializer(
  SerializationConfig(fieldRename: FieldRename.snake)
);

// Method-level override (for specific operations)
final camelConfig = SerializationConfig(fieldRename: FieldRename.none);
final json = snakeSerializer.toJson(user, camelConfig);  // Override to camelCase
```

Configuration is selected as a complete value in this order: operation,
serializer constructor, annotation on the concrete type, then framework
defaults. Settings from annotations on ancestor types are not merged.

Available field naming strategies:
- `FieldRename.none` - Keep original field names (camelCase)
- `FieldRename.snake` - Convert to snake_case
- `FieldRename.kebab` - Convert to kebab-case

### Example Output

```dart
final user = User(firstName: 'John', lastName: 'Doe');

// Default (camelCase)
final defaultJson = serializer.toJson(user);
// {"firstName": "John", "lastName": "Doe", ...}

// Snake case
final snakeConfig = SerializationConfig(fieldRename: FieldRename.snake);
final snakeJson = serializer.toJson(user, snakeConfig);
// {"first_name": "John", "last_name": "Doe", ...}

// Kebab case  
final kebabConfig = SerializationConfig(fieldRename: FieldRename.kebab);
final kebabJson = serializer.toJson(user, kebabConfig);
// {"first-name": "John", "last-name": "Doe", ...}
```

## Advanced Usage

### Complex Object Graphs

The serializer handles nested entities and values automatically:

```dart
@Serializable()
class Company extends AggregateRoot<UuidValue> {
  Company({
    required this.name,
    required this.address,
    required this.employees,
    UuidValue? id,
    super.createdAt,
    super.updatedAt,
  }) : super(id: id ?? UuidValue.generate());
  
  final String name;
  final Address address;           // Nested value
  final List<Employee> employees;  // Collection of entities
}

@Serializable()
class Employee extends Entity<UuidValue> {
  Employee({
    required this.name,
    required this.position,
    UuidValue? id,
    super.createdAt,
    super.updatedAt,
  }) : super(id: id ?? UuidValue.generate());
  
  final String name;
  final String position;
}

// Serialization works recursively
final company = Company(
  name: 'Acme Corp',
  address: Address(
    street: '123 Main St',
    city: 'Anytown',
    zipCode: '12345',
  ),
  employees: [
    Employee(name: 'John', position: 'Developer'),
    Employee(name: 'Jane', position: 'Designer'),
  ],
);

final serializer = CompanyJsonSerializer();
final json = serializer.toJson(company);  // Serializes entire object graph
final restored = serializer.fromJson(json);  // Reconstructs complete structure
```

### Dependency Injection

Perfect for DI containers with constructor configuration:

```dart
// Configure serializers for different contexts
class ApiModule {
  UserJsonSerializer get userSerializer => UserJsonSerializer(
    SerializationConfig(fieldRename: FieldRename.snake)  // API uses snake_case
  );
}

class DatabaseModule {
  UserJsonSerializer get userSerializer => UserJsonSerializer(
    SerializationConfig(fieldRename: FieldRename.none)   // DB uses camelCase
  );
}

// Use in services
class UserService {
  UserService(this._serializer);
  final UserJsonSerializer _serializer;
  
  Future<void> saveToApi(User user) async {
    final json = _serializer.toJson(user);  // Uses constructor config (snake_case)
    await apiClient.post('/users', json);
  }
  
  Future<void> saveToCache(User user) async {
    // Override for specific operation
    final cacheConfig = SerializationConfig(fieldRename: FieldRename.kebab);
    final json = _serializer.toJson(user, cacheConfig);
    await cache.set('user:${user.id}', json);
  }
}
```

## JSON Structure

### AggregateRoot Serialization

AggregateRoots include Entity base fields plus custom fields:

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "createdAt": "2024-01-01T12:00:00.000Z",
  "updatedAt": "2024-01-01T12:30:00.000Z",
  "name": "John Doe",
  "email": "john@example.com"
}
```

### Entity Serialization

Entities include `id`, `createdAt`, and `updatedAt` plus their application
fields, using the same representation rules as aggregate roots.

### Value Object Serialization

Values serialize their application fields:

```json
{
  "street": "123 Main St",
  "city": "Anytown", 
  "zipCode": "12345"
}
```

### Nested Structures

Complex object graphs maintain proper nesting:

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "createdAt": "2024-01-01T12:00:00.000Z",
  "updatedAt": "2024-01-01T12:30:00.000Z",
  "name": "Acme Corp",
  "address": {
    "street": "123 Main St",
    "city": "Anytown",
    "zipCode": "12345"
  },
  "employees": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440001",
      "createdAt": "2024-01-01T12:00:00.000Z",
      "updatedAt": "2024-01-01T12:00:00.000Z",
      "name": "John",
      "position": "Developer"
    }
  ]
}
```

## Error Handling

The serializer provides descriptive error messages for common issues:

```dart
try {
  final user = serializer.fromJson(invalidJson);
} on DeserializationException catch (e) {
  print('Failed to deserialize: ${e.message}');
  print('Expected type: ${e.expectedType}');
  print('Field: ${e.field}');
}
```

Common error scenarios:
- Missing required fields
- Invalid field types
- Malformed JSON structure
- Invalid UUID or DateTime formats

## DDD Compliance

This package generates serializers for these DDDart domain base hierarchies:

### ✅ Allowed
- **AggregateRoots**: The consistency boundaries of your domain
- **Entities**: Identity-bearing domain objects, whether serialized directly or nested in an aggregate
- **Values**: Value objects with application-owned immutability
- **DomainEvents**: Typed aggregate references and event occurrence data

Types outside these actual DDDart base-class hierarchies are rejected, even if
an application class happens to use one of the same class names.

## Performance

- **Code generation**: No reflection - all serialization logic generated at build time
- **Type safety**: Full compile-time checking with zero runtime type discovery
- **Efficient JSON handling**: Direct Map<String, dynamic> operations
- **Tree shaking**: Generated code optimized for dead code elimination

## Troubleshooting

### Build Issues

If code generation fails:

```bash
# Clean and rebuild
dart run build_runner clean
dart run build_runner build --delete-conflicting-outputs
```

### Missing Generated Files

Ensure you have:
1. Added the `part` directive: `part 'filename.g.dart';`
2. Annotated classes with `@Serializable()`
3. Run `dart run build_runner build`

### Type Errors

Generated serializers are strongly typed. Ensure:
- JSON structure matches expected field types
- All required fields are present
- Nested objects are properly structured
- The unnamed constructor accepts same-name named arguments for concrete fields
- Inherited fields have a same-name named super-formal chain to their declarations

## Contributing

This package is part of the DDDart monorepo. See the main repository for contributing guidelines.
