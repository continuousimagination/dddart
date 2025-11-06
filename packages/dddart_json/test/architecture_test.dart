/// Test to verify the new three-package architecture works correctly.

import 'package:test/test.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'test_models.dart';

void main() {
  group('Three-Package Architecture Tests', () {
    test('JsonSerializer service class works for AggregateRoot', () {
      // Create a test user
      final user = TestUser(
        name: 'John Doe',
        email: 'john@example.com',
      );

      // Test serialization using the service class
      final serializer = TestUserJsonSerializer();
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
      const address = TestAddress(
        street: '123 Main St',
        city: 'Anytown',
        zipCode: '12345',
      );

      // Test serialization using the service class
      final serializer = TestAddressJsonSerializer();
      final json = serializer.toJson(address);
      
      expect(json['street'], equals('123 Main St'));
      expect(json['city'], equals('Anytown'));
      expect(json['zipCode'], equals('12345'));

      // Test deserialization using the service class
      final deserialized = serializer.fromJson(json);
      
      expect(deserialized.street, equals('123 Main St'));
      expect(deserialized.city, equals('Anytown'));
      expect(deserialized.zipCode, equals('12345'));
      expect(deserialized, equals(address));
    });

    test('Static convenience methods work', () {
      final user = TestUser(
        name: 'Jane Doe',
        email: 'jane@example.com',
      );

      // Test static encode method
      final json = TestUserJsonSerializer.encode(user);
      expect(json['name'], equals('Jane Doe'));
      expect(json['email'], equals('jane@example.com'));

      // Test static decode method
      final deserialized = TestUserJsonSerializer.decode(json);
      expect(deserialized.name, equals('Jane Doe'));
      expect(deserialized.email, equals('jane@example.com'));
    });

    test('Base Serializer interface methods work', () {
      final user = TestUser(
        name: 'Bob Smith',
        email: 'bob@example.com',
      );

      final serializer = TestUserJsonSerializer();
      
      // Test serialize method (returns JSON string)
      final jsonString = serializer.serialize(user);
      expect(jsonString, isA<String>());
      expect(jsonString, contains('Bob Smith'));
      expect(jsonString, contains('bob@example.com'));

      // Test deserialize method (from JSON string)
      final deserialized = serializer.deserialize(jsonString);
      expect(deserialized.name, equals('Bob Smith'));
      expect(deserialized.email, equals('bob@example.com'));
    });
  });
}