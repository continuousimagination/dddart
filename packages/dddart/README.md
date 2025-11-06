# DDDart

A lightweight Domain-Driven Design (DDD) framework for Dart that provides base classes and utilities to help developers implement DDD principles in their applications.

## Features

- **Entity**: Base class for domain entities with identity and lifecycle timestamps
- **Aggregate Root**: Base class for aggregate root entities in DDD
- **Value Object**: Base class for immutable value types
- Automatic GUID generation for entity IDs
- Automatic timestamp management (createdAt, updatedAt)

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  dddart: ^0.1.0
```

Then run:

```bash
dart pub get
```

## Usage

### Creating Entities

```dart
import 'package:dddart/dddart.dart';

class User extends Entity {
  final String name;
  final String email;
  
  User({
    required this.name,
    required this.email,
    super.id,
    super.createdAt,
    super.updatedAt,
  });
}
```

### Creating Aggregate Roots

```dart
import 'package:dddart/dddart.dart';

class Order extends AggregateRoot {
  final String customerId;
  final List<OrderItem> items;
  
  Order({
    required this.customerId,
    required this.items,
    super.id,
    super.createdAt,
    super.updatedAt,
  });
}
```

### Creating Value Objects

```dart
import 'package:dddart/dddart.dart';

class Money extends Value {
  final double amount;
  final String currency;
  
  const Money(this.amount, this.currency);
  
  @override
  List<Object?> get props => [amount, currency];
}
```

## Contributing

Contributions are welcome! Please read our contributing guidelines and submit pull requests to our repository.

## License

This project is licensed under the MIT License - see the LICENSE file for details.