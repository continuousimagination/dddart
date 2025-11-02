# Design Document

## Overview

DDDart is a lightweight library that provides foundational classes for implementing Domain-Driven Design patterns in Dart applications. The framework focuses on simplicity and follows Dart conventions while providing essential DDD building blocks: Aggregate Roots, Entities, and Value Objects.

### Cross-Platform Compatibility

The framework is designed to work seamlessly across all Dart platforms:
- **Dart Server**: Full compatibility with server-side Dart applications
- **Flutter Mobile**: Works in iOS and Android Flutter applications
- **Flutter Web**: Compatible with Flutter web compilation and runtime

To ensure cross-platform compatibility, the framework:
- Avoids platform-specific dependencies
- Does not use reflection (dart:mirrors) which is unavailable in Flutter web
- Uses only core Dart libraries and well-supported packages
- Maintains const constructor support for compile-time optimization

## Architecture

### Package Structure
```
dddart/
├── lib/
│   ├── src/
│   │   ├── aggregate_root.dart
│   │   ├── entity.dart
│   │   └── value.dart
│   └── dddart.dart (main export file)
├── test/
│   ├── aggregate_root_test.dart
│   ├── entity_test.dart
│   └── value_test.dart
├── pubspec.yaml
├── README.md
├── CHANGELOG.md
└── .gitignore
```

### Dependencies
- `uuid`: For GUID generation and UuidValue type (^4.0.0) - Cross-platform compatible
- `test`: For unit testing (dev dependency)

### Cross-Platform Design Decisions
- **No dart:mirrors**: Avoided reflection to ensure Flutter web compatibility
- **Pure Dart implementation**: Uses only core Dart features available on all platforms
- **Minimal dependencies**: Only essential, cross-platform packages are used
- **Const constructors**: Maintained throughout for compile-time optimization

## Components and Interfaces

### Entity Base Class

The `Entity` class serves as the foundation for all domain entities:

```dart
abstract class Entity {
  final UuidValue id;
  final DateTime createdAt;
  DateTime updatedAt;
  
  Entity({
    UuidValue? id,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? UuidValue.fromString(Uuid().v4()),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();
       
  // Equality based on ID
  @override
  bool operator ==(Object other) => 
      identical(this, other) || 
      other is Entity && runtimeType == other.runtimeType && id == other.id;
      
  @override
  int get hashCode => id.hashCode;
  
  // Method to update the updatedAt timestamp
  void touch() {
    updatedAt = DateTime.now();
  }
}
```

### Aggregate Root Base Class

The `AggregateRoot` extends `Entity` and serves as the entry point for aggregates:

```dart
abstract class AggregateRoot extends Entity {
  AggregateRoot({
    UuidValue? id,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : super(id: id, createdAt: createdAt, updatedAt: updatedAt);
}
```

### Value Object Base Class

The `Value` class provides a foundation for immutable value objects with automatic equality behavior:

```dart
abstract class Value {
  const Value();
  
  // Properties that define this value object's identity
  List<Object?> get props;
  
  // Automatic equality implementation based on props
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other.runtimeType != runtimeType) return false;
    if (other is! Value) return false;
    
    final thisProps = props;
    final otherProps = other.props;
    
    if (thisProps.length != otherProps.length) return false;
    
    for (int i = 0; i < thisProps.length; i++) {
      if (thisProps[i] != otherProps[i]) return false;
    }
    
    return true;
  }
  
  @override
  int get hashCode => Object.hashAll(props);
  
  @override
  String toString() {
    final className = runtimeType.toString();
    final propsString = props.join(', ');
    return '$className($propsString)';
  }
}
```

**Cross-Platform Note**: This implementation avoids reflection and works identically across all Dart platforms. Subclasses only need to override the `props` getter to specify which properties define equality.

## Data Models

### Entity Identity
- Uses `UuidValue` type from the `uuid` package for type-safe GUID handling
- Auto-generates UUIDs using the `uuid` package with proper type validation
- Provides equality semantics based on ID
- Prevents invalid GUID values through type system

### Timestamps
- `createdAt`: Immutable timestamp set at entity creation
- `updatedAt`: Mutable timestamp that can be updated via `touch()` method
- Both default to current DateTime if not provided

### Value Object Semantics
- Immutable by design (const constructor)
- Equality based on value rather than identity
- Requires subclasses to implement proper equality and hashCode

## Error Handling

### Validation Strategy
- Minimal validation in base classes to maintain flexibility
- ID validation handled by `UuidValue` type system (prevents invalid GUIDs)
- Timestamp validation ensures non-null values
- Subclasses responsible for domain-specific validation

### Exception Types
- Use standard Dart exceptions (`ArgumentError`, `StateError`)
- Clear error messages for common misuse scenarios

## Testing Strategy

### Unit Test Coverage
- **Entity Tests**: Constructor behavior, ID generation, timestamp handling, equality
- **AggregateRoot Tests**: Inheritance behavior, proper Entity functionality
- **Value Tests**: Immutability, equality contracts, abstract method requirements

### Test Structure
- Separate test files for each base class
- Group tests by functionality (construction, equality, timestamps)
- Use descriptive test names following Dart conventions
- Mock DateTime.now() for deterministic timestamp testing

### Test Dependencies
- `test` package for test framework
- `mockito` for mocking (if needed for DateTime testing)

## Implementation Notes

### Dart Conventions
- Follow effective Dart style guide
- Use proper documentation comments (///)
- Implement `toString()` methods for debugging
- Use `final` for immutable fields where appropriate

### Performance Considerations
- Lightweight base classes with minimal overhead
- Efficient equality implementations
- Lazy evaluation where beneficial

### Extensibility
- Abstract classes allow for flexible implementation
- Protected methods for subclass customization
- Clear separation of concerns between Entity and AggregateRoot

### Cross-Platform Validation
- All implementations tested to work on Dart VM, Flutter mobile, and Flutter web
- No platform-specific code paths or conditional compilation
- Consistent behavior across all supported platforms
- Future design decisions will maintain cross-platform compatibility as a primary constraint