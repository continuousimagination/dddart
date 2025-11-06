# Design Document

## Overview

DDDart Serialization is a code generation package that provides seamless JSON serialization and deserialization for DDDart aggregate roots and value objects. The package uses Dart's build_runner and source_gen to automatically generate serialization code while preserving the PODO (Plain Old Dart Objects) principle and enforcing proper DDD patterns.

### Cross-Platform Compatibility

The serialization package is designed to work seamlessly across all Dart platforms:
- **Dart Server**: Full compatibility with server-side Dart applications
- **Flutter Mobile**: Works in iOS and Android Flutter applications
- **Flutter Web**: Compatible with Flutter web compilation and runtime

To ensure cross-platform compatibility, the package:
- Uses only code generation (no reflection)
- Generates platform-agnostic Dart code
- Relies on standard Dart libraries and well-supported packages
- Maintains const constructor support where possible

## Architecture

### Three-Package Structure

The serialization functionality is provided through a three-package architecture:

```
packages/
├── dddart/                    # Core DDD + serialization contracts
│   ├── lib/
│   │   ├── src/
│   │   │   ├── aggregate_root.dart
│   │   │   ├── entity.dart
│   │   │   ├── value.dart
│   │   │   ├── uuid_value.dart
│   │   │   └── serialization.dart    # Serializer<T> interface, exceptions
│   │   └── dddart.dart
├── dddart_serialization/      # Serialization framework
│   ├── lib/
│   │   ├── src/
│   │   │   ├── serializable_annotation.dart  # @Serializable annotation
│   │   │   ├── serialization_config.dart     # Configuration classes
│   │   │   └── serialization_utils.dart      # Common utilities
│   │   └── dddart_serialization.dart
└── dddart_json/              # JSON-specific implementation
    ├── lib/
    │   ├── src/
    │   │   ├── json_serializer.dart        # JsonSerializer<T> interface
    │   │   └── generators/
    │   │       └── json_serializer_generator.dart  # JSON code generation
    │   └── dddart_json.dart
    ├── test/
    │   ├── json_serialization_test.dart
    │   ├── aggregate_root_test.dart
    │   └── value_test.dart
    ├── build.yaml
    └── pubspec.yaml
```

### Package Responsibilities

**dddart** (Core Package):
- Core DDD primitives (Entity, AggregateRoot, Value)
- `Serializer<T>` interface defining the serialization contract
- Base serialization exceptions

**dddart_serialization** (Framework Package):
- `@Serializable` annotation for marking serializable types
- Configuration classes for serialization behavior
- Common serialization utilities and helper functions
- Shared serialization logic across different formats

**dddart_json** (JSON Implementation):
- `JsonSerializer<T>` interface extending `Serializer<T>`
- JSON-specific code generation
- Generated `*JsonSerializer` service classes

### Dependencies

**dddart package**:
- No external dependencies (pure Dart)

**dddart_serialization package**:
- `dddart`: Core DDDart framework (path dependency)

**dddart_json package**:
- `dddart`: Core DDDart framework (path dependency)
- `dddart_serialization`: Serialization framework (path dependency)
- `build`: Build system integration (^2.4.0)
- `source_gen`: Code generation framework (^1.4.0)
- `analyzer`: Dart code analysis (^6.0.0)
- `build_runner`: Development dependency for code generation

### DDD Pattern Enforcement
The package enforces proper DDD patterns by:
- **Only allowing AggregateRoot serialization**: Prevents passing entities between aggregates
- **Supporting Value serialization**: Values are immutable and safe to share
- **Nested Entity serialization**: Entities are serialized only as part of their AggregateRoot
- **No direct Entity serialization**: Prevents DDD anti-patterns

## Components and Interfaces

### Annotations

#### @Serializable Annotation
```dart
class Serializable {
  const Serializable({
    this.includeNullFields = false,
    this.fieldRename = FieldRename.none,
  });

  final bool includeNullFields;
  final FieldRename fieldRename;
}

enum FieldRename {
  none,    // Keep field names as-is
  snake,   // Convert camelCase to snake_case
  kebab,   // Convert camelCase to kebab-case
}
```

### Base Interfaces

#### JsonSerializable Interface
```dart
abstract interface class JsonSerializable {
  Map<String, dynamic> toJson();
}
```

#### DeserializationException
```dart
class DeserializationException implements Exception {
  const DeserializationException(this.message, {this.field, this.expectedType});
  
  final String message;
  final String? field;
  final String? expectedType;
}
```

### Code Generation Strategy

#### Service Class Approach
The JSON generator creates dedicated serializer service classes:

```dart
// User-defined class (no mixins required)
import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

@Serializable()
class User extends AggregateRoot {
  const User({required this.name, required this.email, super.id, super.createdAt, super.updatedAt});
  
  final String name;
  final String email;
}

// Generated serializer service class
class UserJsonSerializer implements JsonSerializer<User> {
  @override
  Map<String, dynamic> toJson(User instance) => {
    'id': instance.id.toString(),
    'createdAt': instance.createdAt.toIso8601String(),
    'updatedAt': instance.updatedAt.toIso8601String(),
    'name': instance.name,
    'email': instance.email,
  };
  
  @override
  User fromJson(Map<String, dynamic> json) {
    try {
      return User(
        name: json['name'] as String,
        email: json['email'] as String,
        id: UuidValue.fromString(json['id'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
    } catch (e) {
      throw DeserializationException('Failed to deserialize User: $e');
    }
  }
  
  // Implement base Serializer interface
  @override
  String serialize(User object) => jsonEncode(toJson(object));
  
  @override
  User deserialize(String data) => fromJson(jsonDecode(data));
  
  // Convenience static methods
  static Map<String, dynamic> encode(User instance) => UserJsonSerializer().toJson(instance);
  static User decode(dynamic json) => UserJsonSerializer().fromJson(json as Map<String, dynamic>);
}
```

#### Benefits of Service Class Approach

- **Consistent API**: Both serialization and deserialization use the same pattern
- **No coupling**: Domain classes don't need mixins - they stay pure
- **Extensible**: Easy to add multiple serialization formats (YAML, Protocol Buffers, etc.)
- **Type-safe**: Generic interfaces ensure compile-time safety
- **Testable**: Serializers can be unit tested independently

## Data Models

### AggregateRoot Serialization

#### Field Handling
- **Base Entity fields**: `id`, `createdAt`, `updatedAt` automatically included
- **Custom fields**: All public final fields included
- **Nested entities**: Serialized as nested JSON objects
- **Nested values**: Serialized using their own serialization methods
- **Collections**: Handled with proper type conversion

#### JSON Structure
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "createdAt": "2024-01-01T12:00:00.000Z",
  "updatedAt": "2024-01-01T12:30:00.000Z",
  "customField1": "value1",
  "customField2": 42,
  "nestedEntity": {
    "id": "550e8400-e29b-41d4-a716-446655440001",
    "createdAt": "2024-01-01T12:00:00.000Z",
    "updatedAt": "2024-01-01T12:00:00.000Z",
    "entityField": "value"
  },
  "nestedValue": {
    "valueField1": "value",
    "valueField2": 123
  }
}
```

### Value Object Serialization

#### Field Handling
- **Props-based**: Uses the `props` getter to determine which fields to serialize
- **Type preservation**: Maintains proper Dart types during round-trip serialization
- **Nested values**: Supports values containing other values

#### JSON Structure
```json
{
  "field1": "value1",
  "field2": 42,
  "field3": true
}
```

### Nested Entity Serialization

When entities are nested within AggregateRoots:
- **Full serialization**: Include all Entity base fields plus custom fields
- **Type information**: Maintain proper type relationships
- **Collection handling**: Support List<Entity>, Set<Entity>, etc.

## Error Handling

### Validation Strategy
- **Type checking**: Verify JSON field types match expected Dart types
- **Required fields**: Ensure all non-nullable fields are present
- **Format validation**: Validate UUID and DateTime formats
- **Nested validation**: Propagate validation errors from nested objects

### Exception Hierarchy
```dart
DeserializationException
├── MissingFieldException
├── TypeMismatchException
├── FormatException
└── NestedDeserializationException
```

### Error Messages
- **Descriptive**: Include field names, expected types, and actual values
- **Contextual**: Show the path to nested fields that failed
- **Actionable**: Provide guidance on how to fix the issue

## Testing Strategy

### Unit Test Categories

#### AggregateRoot Serialization Tests
```dart
group('AggregateRoot Serialization', () {
  test('serializes simple aggregate root to JSON', () {
    final user = User(name: 'John', email: 'john@example.com');
    final json = user.toJson();
    
    expect(json['name'], equals('John'));
    expect(json['email'], equals('john@example.com'));
    expect(json['id'], isA<String>());
    expect(json['createdAt'], isA<String>());
    expect(json['updatedAt'], isA<String>());
  });
  
  test('deserializes JSON to aggregate root', () {
    final json = {
      'name': 'John',
      'email': 'john@example.com',
      'id': '550e8400-e29b-41d4-a716-446655440000',
      'createdAt': '2024-01-01T12:00:00.000Z',
      'updatedAt': '2024-01-01T12:00:00.000Z',
    };
    
    final user = User.fromJson(json);
    
    expect(user.name, equals('John'));
    expect(user.email, equals('john@example.com'));
    expect(user.id.toString(), equals('550e8400-e29b-41d4-a716-446655440000'));
  });
  
  test('round-trip serialization maintains equality', () {
    final original = User(name: 'John', email: 'john@example.com');
    final json = original.toJson();
    final deserialized = User.fromJson(json);
    
    expect(deserialized, equals(original));
  });
});
```

#### Value Object Serialization Tests
```dart
group('Value Serialization', () {
  test('serializes value object to JSON', () {
    final address = Address('123 Main St', 'Anytown', '12345');
    final json = address.toJson();
    
    expect(json['street'], equals('123 Main St'));
    expect(json['city'], equals('Anytown'));
    expect(json['zipCode'], equals('12345'));
  });
  
  test('deserializes JSON to value object', () {
    final json = {
      'street': '123 Main St',
      'city': 'Anytown',
      'zipCode': '12345',
    };
    
    final address = Address.fromJson(json);
    
    expect(address.street, equals('123 Main St'));
    expect(address.city, equals('Anytown'));
    expect(address.zipCode, equals('12345'));
  });
});
```

#### Complex Object Graph Tests
```dart
group('Complex Serialization', () {
  test('serializes aggregate root with nested entities and values', () {
    final address = Address('123 Main St', 'Anytown', '12345');
    final profile = UserProfile(address: address, preferences: {...});
    final user = User(name: 'John', email: 'john@example.com', profile: profile);
    
    final json = user.toJson();
    
    expect(json['profile']['address']['street'], equals('123 Main St'));
    // ... more assertions
  });
  
  test('round-trip complex object maintains structure', () {
    final original = createComplexAggregateRoot();
    final json = original.toJson();
    final deserialized = ComplexAggregateRoot.fromJson(json);
    
    expect(deserialized, equals(original));
    expect(deserialized.nestedEntities.length, equals(original.nestedEntities.length));
    expect(deserialized.nestedValues, equals(original.nestedValues));
  });
});
```

### Test Structure
- **Separate test files** for each major component
- **Group tests** by functionality (serialization, deserialization, error handling)
- **Round-trip tests** to ensure data integrity
- **Error condition tests** to verify exception handling
- **Performance tests** for large object graphs

## Implementation Notes

### Code Generation Process
1. **Analysis**: Parse annotated classes using analyzer package
2. **Validation**: Ensure classes extend AggregateRoot or Value
3. **Field Discovery**: Identify serializable fields based on class type
4. **Code Generation**: Create mixin with toJson/fromJson methods
5. **Output**: Write generated code to .g.dart files

### Cross-Platform Considerations
- **No reflection**: All serialization logic is generated at build time
- **Standard libraries**: Use only dart:core, dart:convert, and well-supported packages
- **Const support**: Maintain const constructors where possible
- **Tree shaking**: Generated code is optimized for dead code elimination

### Performance Optimizations
- **Lazy generation**: Only generate code for annotated classes
- **Efficient JSON handling**: Use Map<String, dynamic> directly
- **Type caching**: Cache type information for repeated serialization
- **Minimal allocations**: Reuse objects where safe

### Future Extensibility
- **Custom serializers**: Support for complex field types
- **Validation hooks**: Allow custom validation during deserialization
- **Transformation**: Support field transformations during serialization
- **Schema generation**: Potential JSON schema output for API documentation