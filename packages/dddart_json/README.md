# DDDart JSON

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

Add the required packages to your `pubspec.yaml`:

```yaml
dependencies:
  dddart: ^1.0.0
  dddart_serialization: ^1.0.0
  dddart_json: ^1.0.0

dev_dependencies:
  build_runner: ^2.4.0
```

## Quick Start

### 1. Annotate Your Classes

```dart
import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

part 'user.g.dart';  // Required for code generation

@Serializable()
class User extends AggregateRoot {
  User({
    required this.name,
    required this.email,
    super.id,
    super.createdAt,
    super.updatedAt,
  });
  
  final String name;
  final String email;
}

@Serializable()
class Address extends Value {
  const Address({
    required this.street,
    required this.city,
    required this.zipCode,
  });
  
  final String street;
  final String city;
  final String zipCode;
  
  @override
  List<Object?> get props => [street, city, zipCode];
}
```

Generated deserialization calls the annotated type's unnamed constructor and
passes every serialized field as a same-name named argument. Define that
constructor even when the type has other named constructors.

Inherited application state is supported when the concrete constructor exposes
the field as a same-name named super-formal parameter, and every intermediate
constructor forwards that named super-formal until it reaches the field-formal
parameter that declares the state. If that reconstruction path is absent,
generation fails instead of omitting the field or relying on an initializer or
default value. The annotation on the concrete type controls the representation
of both concrete and inherited fields; ancestor annotations are not merged.

### 2. Generate Code

```bash
dart run build_runner build
```

This generates `*JsonSerializer` service classes for each annotated type.

### 3. Use Serialization

```dart
// Create a serializer instance
final serializer = UserJsonSerializer();

// Serialize to JSON
final user = User(name: 'John Doe', email: 'john@example.com');
final json = serializer.toJson(user);

// Deserialize from JSON
final userFromJson = serializer.fromJson(json);

// String serialization
final jsonString = serializer.serialize(user);
final userFromString = serializer.deserialize(jsonString);

// Static convenience methods
final json2 = UserJsonSerializer.encode(user);
final user2 = UserJsonSerializer.decode(json2);
```

## Configuration

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
class Company extends AggregateRoot {
  Company({
    required this.name,
    required this.address,
    required this.employees,
    super.id,
    super.createdAt,
    super.updatedAt,
  });
  
  final String name;
  final Address address;           // Nested value
  final List<Employee> employees;  // Collection of entities
}

@Serializable()
class Employee extends Entity {
  Employee({
    required this.name,
    required this.position,
    super.id,
    super.createdAt,
    super.updatedAt,
  });
  
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

This package generates serializers only for the three DDDart domain base types:

### ✅ Allowed
- **AggregateRoots**: The consistency boundaries of your domain
- **Entities**: Identity-bearing domain objects, whether serialized directly or nested in an aggregate
- **Values**: Immutable objects that can be safely shared

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
