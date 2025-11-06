# DDDart Serialization

Framework package providing serialization annotations and configuration for DDDart objects.

## Overview

This package provides the core serialization framework for DDDart, including:
- `@Serializable` annotation for marking serializable classes
- Configuration classes for customizing serialization behavior
- Common utilities and interfaces used by serialization implementations

This is a framework package - you'll typically use it alongside a specific serialization implementation like `dddart_json`.

## Installation

```yaml
dependencies:
  dddart: ^0.1.0
  dddart_serialization: ^0.1.0
```

## Usage

### @Serializable Annotation

Mark your DDDart classes for serialization:

```dart
import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

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

@Serializable()
class Address extends Value {
  const Address(this.street, this.city, this.zipCode);
  
  final String street;
  final String city;
  final String zipCode;
  
  @override
  List<Object?> get props => [street, city, zipCode];
}
```

### Serialization Configuration

Configure serialization behavior:

```dart
import 'package:dddart_serialization/dddart_serialization.dart';

// Default configuration (camelCase field names)
final defaultConfig = SerializationConfig();

// Snake case field names
final snakeConfig = SerializationConfig(
  fieldRename: FieldRename.snake,
);

// Kebab case field names
final kebabConfig = SerializationConfig(
  fieldRename: FieldRename.kebab,
);

// Include null fields in output
final nullConfig = SerializationConfig(
  includeNullFields: true,
);
```

### Field Naming Strategies

Control how Dart field names are transformed:

```dart
enum FieldRename {
  none,   // Keep original names: firstName -> firstName
  snake,  // Convert to snake_case: firstName -> first_name
  kebab,  // Convert to kebab-case: firstName -> first-name
}
```

Examples:
- `firstName` → `firstName` (none)
- `firstName` → `first_name` (snake)
- `firstName` → `first-name` (kebab)
- `emailAddress` → `email_address` (snake)
- `createdAt` → `created_at` (snake)

## API Reference

### @Serializable Annotation

```dart
class Serializable {
  const Serializable({
    this.includeNullFields = false,
    this.fieldRename = FieldRename.none,
  });

  /// Whether to include fields with null values in serialized output
  final bool includeNullFields;
  
  /// Strategy for transforming field names
  final FieldRename fieldRename;
}
```

### SerializationConfig Class

```dart
class SerializationConfig {
  const SerializationConfig({
    this.fieldRename = FieldRename.none,
    this.includeNullFields = false,
  });

  /// Strategy for transforming field names during serialization
  final FieldRename fieldRename;
  
  /// Whether to include null values in serialized output
  final bool includeNullFields;
}
```

### FieldRename Enum

```dart
enum FieldRename {
  /// Keep field names unchanged (camelCase)
  none,
  
  /// Convert camelCase to snake_case
  snake,
  
  /// Convert camelCase to kebab-case
  kebab,
}
```

## Serialization Implementations

This framework package is designed to work with specific serialization implementations:

- **dddart_json**: JSON serialization using this framework
- **Future implementations**: YAML, Protocol Buffers, etc.

Each implementation provides:
- Code generators that respect the `@Serializable` annotation
- Serializer classes that use `SerializationConfig`
- Format-specific features and optimizations

## DDD Compliance

The framework enforces proper Domain-Driven Design patterns:

### Serializable Types
- ✅ **AggregateRoot**: Domain consistency boundaries
- ✅ **Value**: Immutable, shareable objects
- ❌ **Entity**: Only serializable within their AggregateRoot

### Design Principles
- **Aggregate boundaries**: Only AggregateRoots can be directly serialized
- **Value sharing**: Values can be serialized independently
- **Entity encapsulation**: Entities are serialized as part of their aggregate

This prevents common DDD anti-patterns like:
- Passing entities between aggregates
- Breaking aggregate consistency boundaries
- Exposing internal aggregate structure

## Contributing

This package is part of the DDDart monorepo. See the main repository for contributing guidelines.

## License

MIT License - see the LICENSE file for details.