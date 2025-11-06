# DDDart Monorepo

A collection of packages for Domain-Driven Design in Dart with automatic JSON serialization.

## Packages

### [dddart](packages/dddart/)
Core DDDart framework providing base classes for entities, aggregate roots, and value objects, plus serialization interfaces.

### [dddart_serialization](packages/dddart_serialization/)
Serialization framework providing the `@Serializable` annotation and configuration classes for DDDart objects.

### [dddart_json](packages/dddart_json/)
JSON serialization code generation for DDDart objects. Generates type-safe serializer service classes.

## Quick Start

1. **Add dependencies**:
```yaml
dependencies:
  dddart: ^0.1.0
  dddart_serialization: ^0.1.0
  dddart_json: ^0.1.0

dev_dependencies:
  build_runner: ^2.4.0
```

2. **Create your domain models**:
```dart
import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

part 'user.g.dart';

@Serializable()
class User extends AggregateRoot {
  const User({
    required this.name,
    required this.email,
    super.id,
    super.createdAt,
    super.updatedAt,
  });
  
  final String name;
  final String email;
}
```

3. **Generate serialization code**:
```bash
dart run build_runner build
```

4. **Use serialization**:
```dart
final serializer = UserJsonSerializer();
final user = User(name: 'John', email: 'john@example.com');

// Serialize
final json = serializer.toJson(user);
final jsonString = serializer.serialize(user);

// Deserialize
final userFromJson = serializer.fromJson(json);
final userFromString = serializer.deserialize(jsonString);
```

## Features

- **PODO Preservation**: Domain objects remain Plain Old Dart Objects
- **DDD Compliance**: Enforces proper aggregate boundaries and patterns
- **Type Safety**: Full compile-time type checking with generated code
- **Cross-Platform**: Works on Dart server, Flutter mobile, and Flutter web
- **Flexible Configuration**: Constructor defaults with method-level overrides
- **Nested Serialization**: Handles complex object graphs automatically

## Architecture

The DDDart serialization system uses a three-package architecture:

- **dddart**: Core DDD primitives + serialization contracts
- **dddart_serialization**: Framework with annotations and configuration
- **dddart_json**: JSON-specific implementation with code generation

This design allows for:
- Clean separation of concerns
- Multiple serialization formats (JSON, YAML, Protocol Buffers, etc.)
- Framework-agnostic domain models
- Extensible serialization system

## Development

This is a monorepo containing multiple Dart packages. Each package has its own:
- `pubspec.yaml` for dependencies
- `README.md` for documentation
- `test/` directory for tests

### Running Tests

```bash
# Test all packages
dart test

# Test specific packages
cd packages/dddart && dart test
cd packages/dddart_serialization && dart test
cd packages/dddart_json && dart test
```

### Code Generation

```bash
# Generate serialization code for examples/tests
cd packages/dddart_json && dart run build_runner build
```

### Package Dependencies

```
dddart (core)
├── No external dependencies
│
dddart_serialization (framework)
├── dddart
│
dddart_json (JSON implementation)
├── dddart
├── dddart_serialization
├── build
├── source_gen
└── analyzer
```

## Contributing

1. Make changes in the appropriate package directory
2. Update tests and documentation
3. Run tests for affected packages
4. Ensure code generation works correctly
5. Submit a pull request

## License

MIT License - see individual package directories for details.