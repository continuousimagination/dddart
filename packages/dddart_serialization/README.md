# DDDart Serialization

Framework package providing serialization annotations and configuration for DDDart objects.

## Overview

This package provides the core serialization framework for DDDart, including:
- `@Serializable` annotation for marking serializable classes
- Configuration classes for customizing serialization behavior
- Common utilities and interfaces used by serialization implementations
- Explicit JSON/key codecs and instance-local registration for identity kinds

This is a framework package - you'll typically use it alongside a specific serialization implementation like `dddart_json`.

## Installation

Until these packages are published on pub.dev, use the
[Git installation guide](../../docs/GIT_INSTALLATION.md). Pin every direct
dddart dependency to one Git commit. The package's sibling dependency on core
resolves from that same checkout.

## Usage

### @Serializable Annotation

Mark your DDDart classes for serialization:

```dart
import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

@Serializable()
class User extends UuidAggregateRoot {
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

### Identity codecs

`IdentityCodec<I>` defines `toJson`/`fromJson` for structural JSON values and
`toKey`/`fromKey` for canonical, reversible string keys. Include all scope
components in a key. Debugging `toString()` output is never an implicit encoding.

`IdentityCodecRegistry()` registers `UuidIdentityCodec` under the stable key
`uuid`. Add each concrete application identity kind explicitly:

```dart
final codecs = IdentityCodecRegistry()
  ..register<IssueId>('github.issue.v1', IssueIdCodec());
final json = codecs.toJson<IssueId>(issueId);
final restored = codecs.fromJson<IssueId>(json);
final key = codecs.toKey<IssueId>(issueId);
final sameId = codecs.fromKey<IssueId>(key);
```

`IssueId` and `IssueIdCodec` above are application-defined. JSON can contain a
native string, number, or scoped object, as chosen by that codec. Key encoding
checks that decoding preserves identity equality; decoding rejects noncanonical
aliases. URI escaping and database size, type and comparison rules belong to the
transport or repository adapter.

Use `toTaggedJson(identity)` and `fromTaggedJson(value)` for heterogeneous
streams. The envelope is `{"type": "github.issue.v1", "value": ...}`. Its type
key is an explicit wire contract; changing it requires a migration. Duplicate
types/keys, unknown kinds and malformed values fail explicitly. Registries are
injected instances; there is no global registry.

See [JSON identity generation](../dddart_json/README.md#identity-generation)
for sharing these codecs through generated serializers.

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
