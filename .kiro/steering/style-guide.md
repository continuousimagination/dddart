# Code Style Guide

## Dart Style Standards

All code MUST follow the official [Effective Dart](https://dart.dev/effective-dart) style guide, which covers:

- **Style**: Formatting, naming conventions, ordering
- **Documentation**: Comment best practices, doc comments
- **Usage**: API design, library structure, parameter usage
- **Design**: Type system usage, class design patterns

## Linting

### Lint Package

All packages use **`package:very_good_analysis`** for comprehensive static analysis. This provides:

- All rules from `package:lints/recommended.yaml`
- Additional strict rules for code quality
- Consistent standards across the monorepo

### Configuration

Each package has an `analysis_options.yaml` at its root that:

```yaml
include: package:very_good_analysis/analysis_options.yaml

analyzer:
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
  
linter:
  rules:
    # Add any project-specific overrides here
```

### Running Analysis

```bash
# Analyze all code
dart analyze

# Analyze specific package
cd packages/package_name && dart analyze

# Fix auto-fixable issues
dart fix --apply
```

## Formatting

### Dart Formatter

All code MUST be formatted with `dart format`:

```bash
# Format all Dart files
dart format .

# Format specific directory
dart format lib/

# Check formatting without modifying
dart format --output=none --set-exit-if-changed .
```

### Formatting Rules

- Line length: 80 characters (Dart default)
- 2 spaces for indentation
- No trailing whitespace
- Single blank line at end of file

## Naming Conventions

### Files and Directories

- `lowercase_with_underscores.dart` for all Dart files
- `lowercase_with_underscores/` for directories
- Test files: `*_test.dart`
- Generated files: `*.g.dart`

### Classes and Types

- `UpperCamelCase` for classes, enums, typedefs, type parameters
- Examples: `AggregateRoot`, `DomainEvent`, `EventBus`

### Variables, Functions, Parameters

- `lowerCamelCase` for variables, functions, parameters, named parameters
- Examples: `eventBus`, `publishEvent`, `aggregateId`

### Constants

- `lowerCamelCase` for compile-time constants
- Example: `const maxRetries = 3;`

### Private Members

- Prefix with underscore: `_privateMethod`, `_internalState`
- Use for implementation details not part of public API

## Documentation

### Doc Comments

Use `///` for public API documentation:

```dart
/// Publishes a [DomainEvent] to all registered subscribers.
///
/// The event is delivered synchronously to all handlers that have
/// subscribed to events of type [T] or its supertypes.
///
/// Example:
/// ```dart
/// eventBus.publish(UserCreatedEvent(userId: '123'));
/// ```
void publish<T extends DomainEvent>(T event) {
  // implementation
}
```

### Comment Guidelines

- Document all public APIs (classes, methods, properties)
- Include examples for complex APIs
- Explain *why*, not just *what*
- Use `//` for implementation comments
- Keep comments up-to-date with code changes

## Code Organization

### Import Ordering

1. Dart SDK imports (`dart:`)
2. Package imports (`package:`)
3. Relative imports
4. Blank line between groups

```dart
import 'dart:async';
import 'dart:collection';

import 'package:uuid/uuid.dart';

import '../domain/entity.dart';
import 'event_bus.dart';
```

### Library Structure

```dart
// 1. License header (if applicable)
// 2. Library documentation
// 3. Imports
// 4. Part directives
// 5. Type definitions
// 6. Constants
// 7. Classes
```

## Best Practices

### Type Annotations

- Always specify return types for public methods
- Use type inference for local variables when clear
- Avoid `dynamic` unless necessary

### Null Safety

- Use null-safe types (`String?` vs `String`)
- Prefer non-nullable by default
- Use `late` sparingly and only when necessary
- Avoid `!` null assertion operator when possible

### Constructors

- Use named constructors for clarity: `User.create()`, `Event.fromJson()`
- Make constructors `const` when possible
- Use factory constructors for complex initialization

### Error Handling

- Throw specific exception types
- Document exceptions in doc comments with `/// Throws [ExceptionType] when...`
- Use `ArgumentError` for invalid arguments
- Use `StateError` for invalid state

### Async/Await

- Prefer `async`/`await` over raw `Future` APIs
- Always `await` futures or explicitly ignore with `unawaited()`
- Use `Future<void>` for async functions with no return value

## Quality Checks

Before committing code:

1. `dart format .` - Format all code
2. `dart analyze` - Check for issues
3. `dart test` - Run all tests
4. `dart fix --dry-run` - Check for auto-fixable issues

## IDE Configuration

### VS Code

Recommended settings (`.vscode/settings.json`):

```json
{
  "dart.lineLength": 80,
  "editor.formatOnSave": true,
  "editor.rulers": [80],
  "dart.analysisServerFolding": true
}
```

### IntelliJ/Android Studio

- Enable "Dart Analysis" tool window
- Set line length to 80 in Dart settings
- Enable "Format on save"
- Enable "Optimize imports on save"
