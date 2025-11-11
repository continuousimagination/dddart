/// Simple test to verify the new three-package architecture works correctly.
library;

import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:test/test.dart';

part 'simple_architecture_test.g.dart';

/// Simple test user for architecture verification.
@Serializable()
class SimpleUser extends AggregateRoot {
  SimpleUser({
    required this.name,
    required this.email,
    super.id,
    super.createdAt,
    super.updatedAt,
  });

  final String name;
  final String email;
}

/// Simple test address for architecture verification.
@Serializable()
class SimpleAddress extends Value {
  const SimpleAddress({
    required this.street,
    required this.city,
  });

  final String street;
  final String city;

  @override
  List<Object?> get props => [street, city];
}

void main() {
  group('Three-Package Architecture Tests', () {
    test('JsonSerializer service class works for AggregateRoot', () {
      // Create a test user
      final user = SimpleUser(
        name: 'John Doe',
        email: 'john@example.com',
      );

      // Test serialization using the service class
      final serializer = SimpleUserJsonSerializer();
      final json = serializer.toJson(user);

      expect(json['name'], equals('John Doe'));
      expect(json['email'], equals('john@example.com'));
      expect(json['id'], isA<String>());
      expect(json['createdAt'], isA<String>());
      expect(json['updatedAt'], isA<String>());

      // Test deserialization using the service class
      final deserialized = serializer.fromJson(json);

      expect(deserialized.name, equals('John Doe'));
      expect(deserialized.email, equals('john@example.com'));
      expect(deserialized.id, equals(user.id));
      expect(deserialized.createdAt, equals(user.createdAt));
      expect(deserialized.updatedAt, equals(user.updatedAt));
    });

    test('JsonSerializer service class works for Value objects', () {
      // Create a test address
      const address = SimpleAddress(
        street: '123 Main St',
        city: 'Anytown',
      );

      // Test serialization using the service class
      final serializer = SimpleAddressJsonSerializer();
      final json = serializer.toJson(address);

      expect(json['street'], equals('123 Main St'));
      expect(json['city'], equals('Anytown'));

      // Test deserialization using the service class
      final deserialized = serializer.fromJson(json);

      expect(deserialized.street, equals('123 Main St'));
      expect(deserialized.city, equals('Anytown'));
      expect(deserialized, equals(address));
    });

    test('Static convenience methods work', () {
      final user = SimpleUser(
        name: 'Jane Doe',
        email: 'jane@example.com',
      );

      // Test static encode method
      final json = SimpleUserJsonSerializer.encode(user);
      expect(json['name'], equals('Jane Doe'));
      expect(json['email'], equals('jane@example.com'));

      // Test static decode method
      final deserialized = SimpleUserJsonSerializer.decode(json);
      expect(deserialized.name, equals('Jane Doe'));
      expect(deserialized.email, equals('jane@example.com'));
    });
  });
}
