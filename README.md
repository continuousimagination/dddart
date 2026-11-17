# DDDart Monorepo

A collection of packages for Domain-Driven Design in Dart with automatic JSON serialization.

**[Homepage and documentation](https://continuousimagination.github.io/dddart/)** ·
[Philosophy](https://continuousimagination.github.io/dddart/docs/philosophy/) ·
[Getting started](https://continuousimagination.github.io/dddart/docs/getting-started/) ·
[Package map](https://continuousimagination.github.io/dddart/docs/packages/)

## Packages

The [aggregate events and AppSync guide](docs/DISTRIBUTED_EVENTS.md) describes
aggregate watches, HTTP polling, optional AppSync Events, DynamoDB history,
authorization, deployment and migration.

### [dddart](packages/dddart/)
Core DDDart framework providing base classes for entities, aggregate roots, and value objects, plus serialization interfaces.

### [dddart_serialization](packages/dddart_serialization/)
Serialization framework providing the `@Serializable` annotation and configuration classes for DDDart objects.

### [dddart_json](packages/dddart_json/)
JSON serialization code generation for DDDart objects. Generates type-safe serializer service classes.

### [dddart_events_distributed](packages/dddart_events_distributed/)
Transport-independent aggregate watches, retained history contracts, HTTP polling,
shared authorization and bounded event publication.

### [dddart_events_dynamodb](packages/dddart_events_dynamodb/)
Server-side DynamoDB event history and shared random channel mappings for Lambda
and other concurrent servers. InMemory remains available for local tests.

### [dddart_events_appsync](packages/dddart_events_appsync/)
Optional AWS AppSync Events live transport, native Lambda handlers and
CloudFormation deployment. Uses existing JWT authentication or Cognito/OIDC.

### [dddart_repository_indexeddb](packages/dddart_repository_indexeddb/)
Browser IndexedDB persistence with typed identities, application-owned codecs,
atomic conditional transactions and durable operation receipts. Physical WebKit
and separate-tab/lifecycle guarantees remain explicit follow-ups.

## Quick Start

Start with the [complete core example](docs/quickstarts/core/README.md), or follow
the JSON workflow below. [All quickstarts and classifications](docs/QUICKSTARTS.md)
list service/platform prerequisites and the additional examples.

Use Dart **3.13.7**, the development SDK used for these checks. This is a verified
setup, not a claim about the minimum SDK on every platform (#98 tracks that).
The DDDart dependencies below use one immutable Git revision; they do not require
published DDDart packages. See [Git installation](https://github.com/continuousimagination/dddart/blob/main/docs/GIT_INSTALLATION.md)
for source overrides and [the support matrix](https://continuousimagination.github.io/dddart/docs/contracts/) for platform limits.

Create an empty directory **outside this repository**, then create the named files:

```sh
mkdir dddart_json_quickstart
cd dddart_json_quickstart
mkdir -p bin lib
```

Save as `pubspec.yaml` (the fixture uses `.txt` only to keep it out of the monorepo workspace):

<!-- dddart-source: docs/quickstarts/json/pubspec.yaml.txt -->
```yaml
name: dddart_json_quickstart
publish_to: none
environment:
  sdk: '>=3.13.7 <4.0.0'
dependencies:
  dddart:
    git:
      url: https://github.com/continuousimagination/dddart.git
      ref: 56607ac8d3913b8e896ac03f8ecff58473d62ce2
      path: packages/dddart
  dddart_json:
    git:
      url: https://github.com/continuousimagination/dddart.git
      ref: 56607ac8d3913b8e896ac03f8ecff58473d62ce2
      path: packages/dddart_json
  dddart_serialization:
    git:
      url: https://github.com/continuousimagination/dddart.git
      ref: 56607ac8d3913b8e896ac03f8ecff58473d62ce2
      path: packages/dddart_serialization
dev_dependencies:
  build_runner: ^2.4.0
```
<!-- /dddart-source -->

Save as `bin/main.dart`:

<!-- dddart-source: docs/quickstarts/json/bin/main.dart -->
```dart
import '../lib/reservation.dart';

void main() {
  final serializer = ReservationJsonSerializer();
  final original = Reservation(
    guestName: 'Sam',
    seats: SeatCount(value: 2),
  );

  final json = serializer.toJson(original);
  final text = serializer.serialize(original);
  final restored = serializer.deserialize(text);

  print(json['guestName']); // Sam
  print(restored.id == original.id); // true
  print(restored.seats == original.seats); // true
}
```
<!-- /dddart-source -->

Save as `lib/reservation.dart`:

<!-- dddart-source: docs/quickstarts/json/lib/reservation.dart -->
```dart
import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

part 'reservation.g.dart';

@Serializable()
class Reservation extends AggregateRoot<UuidValue> {
  Reservation({
    required this.guestName,
    required this.seats,
    this.note,
    UuidValue? id,
    super.createdAt,
    super.updatedAt,
  }) : super(id: id ?? UuidValue.generate());

  final String guestName;
  final SeatCount seats;
  final String? note;
}

@Serializable()
class SeatCount extends Value {
  factory SeatCount({required int value}) {
    if (value < 1) throw ArgumentError('At least one seat is required');
    return SeatCount._(value);
  }

  const SeatCount._(this.value);
  final int value;

  @override
  List<Object?> get props => [value];
}
```
<!-- /dddart-source -->

Resolve dependencies, generate from clean build state, analyze, and run:

```sh
dart pub get
dart run build_runner clean
dart run build_runner build --delete-conflicting-outputs
dart analyze --fatal-infos
dart run bin/main.dart
```

Expected output for `bin/main.dart`:

```text
Sam
true
true
```

The program finishes and closes its resources. Delete the temporary application directory when finished.

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
