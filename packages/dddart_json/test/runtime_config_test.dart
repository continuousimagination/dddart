/// Test to verify runtime configuration works correctly.
library;

import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:test/test.dart';

part 'runtime_config_test.g.dart';

/// Test user with simple annotation - configuration done at runtime.
@Serializable()
class FlexibleUser extends AggregateRoot {
  FlexibleUser({
    required this.firstName,
    required this.lastName,
    required this.emailAddress,
    super.id,
    super.createdAt,
    super.updatedAt,
  });

  final String firstName;
  final String lastName;
  final String emailAddress;
}

void main() {
  group('Runtime Configuration Tests', () {
    test('Same class can be serialized with different field naming strategies',
        () {
      final user = FlexibleUser(
        firstName: 'John',
        lastName: 'Doe',
        emailAddress: 'john.doe@example.com',
      );

      final serializer = FlexibleUserJsonSerializer();

      // Default camelCase
      final camelJson = serializer.toJson(user);
      expect(camelJson['firstName'], equals('John'));
      expect(camelJson['lastName'], equals('Doe'));
      expect(camelJson['emailAddress'], equals('john.doe@example.com'));

      // Snake case configuration - override at method level
      const snakeConfig = SerializationConfig(fieldRename: FieldRename.snake);
      final snakeJson = serializer.toJson(user, snakeConfig);
      expect(snakeJson['first_name'], equals('John'));
      expect(snakeJson['last_name'], equals('Doe'));
      expect(snakeJson['email_address'], equals('john.doe@example.com'));

      // Kebab case configuration - override at method level
      const kebabConfig = SerializationConfig(fieldRename: FieldRename.kebab);
      final kebabJson = serializer.toJson(user, kebabConfig);
      expect(kebabJson['first-name'], equals('John'));
      expect(kebabJson['last-name'], equals('Doe'));
      expect(kebabJson['email-address'], equals('john.doe@example.com'));
    });

    test('Can deserialize JSON with different naming strategies', () {
      final serializer = FlexibleUserJsonSerializer();

      // Deserialize camelCase JSON
      final camelJson = {
        'firstName': 'Jane',
        'lastName': 'Smith',
        'emailAddress': 'jane@example.com',
        'id': '550e8400-e29b-41d4-a716-446655440000',
        'createdAt': '2024-01-01T12:00:00.000Z',
        'updatedAt': '2024-01-01T12:00:00.000Z',
      };
      final camelUser = serializer.fromJson(camelJson);
      expect(camelUser.firstName, equals('Jane'));

      // Deserialize snake_case JSON
      final snakeJson = {
        'first_name': 'Bob',
        'last_name': 'Wilson',
        'email_address': 'bob@api.com',
        'id': '550e8400-e29b-41d4-a716-446655440001',
        'created_at': '2024-01-01T12:00:00.000Z',
        'updated_at': '2024-01-01T12:00:00.000Z',
      };
      const snakeConfig = SerializationConfig(fieldRename: FieldRename.snake);
      final snakeUser = serializer.fromJson(snakeJson, snakeConfig);
      expect(snakeUser.firstName, equals('Bob'));
      expect(snakeUser.lastName, equals('Wilson'));
      expect(snakeUser.emailAddress, equals('bob@api.com'));
    });

    test('String serialization methods work with configuration', () {
      final user = FlexibleUser(
        firstName: 'Alice',
        lastName: 'Johnson',
        emailAddress: 'alice@test.com',
      );

      final serializer = FlexibleUserJsonSerializer();

      // Default serialization
      final defaultJson = serializer.serialize(user);
      expect(defaultJson, contains('"firstName"'));
      expect(defaultJson, contains('"emailAddress"'));

      // Snake case serialization - override at method level
      const snakeConfig = SerializationConfig(fieldRename: FieldRename.snake);
      final snakeJson = serializer.serialize(user, snakeConfig);
      expect(snakeJson, contains('"first_name"'));
      expect(snakeJson, contains('"email_address"'));

      // Round-trip with snake case - override at method level
      final restored = serializer.deserialize(snakeJson, snakeConfig);
      expect(restored.firstName, equals('Alice'));
      expect(restored.lastName, equals('Johnson'));
      expect(restored.emailAddress, equals('alice@test.com'));
    });

    test('Static convenience methods work with configuration', () {
      final user = FlexibleUser(
        firstName: 'Charlie',
        lastName: 'Brown',
        emailAddress: 'charlie@example.com',
      );

      // Default static methods
      final defaultJson = FlexibleUserJsonSerializer.encode(user);
      expect(defaultJson['firstName'], equals('Charlie'));

      // Configured static methods
      const kebabConfig = SerializationConfig(fieldRename: FieldRename.kebab);
      final kebabJson = FlexibleUserJsonSerializer.encode(user, kebabConfig);
      expect(kebabJson['first-name'], equals('Charlie'));
      expect(kebabJson['last-name'], equals('Brown'));

      final restored =
          FlexibleUserJsonSerializer.decode(kebabJson, kebabConfig);
      expect(restored.firstName, equals('Charlie'));
      expect(restored.lastName, equals('Brown'));
    });
  });
}
