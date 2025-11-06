/// Test to verify constructor-level configuration with optional method overrides.

import 'dart:convert';
import 'package:test/test.dart';
import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_json/dddart_json.dart';

part 'constructor_config_test.g.dart';

/// Test user for constructor configuration testing.
@Serializable()
class ConfigurableUser extends AggregateRoot {
  ConfigurableUser({
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
  group('Constructor Configuration Tests', () {
    test('Default constructor uses camelCase', () {
      final user = ConfigurableUser(
        firstName: 'John',
        lastName: 'Doe',
        emailAddress: 'john.doe@example.com',
      );

      // Default constructor (no config)
      final serializer = ConfigurableUserJsonSerializer();
      final json = serializer.toJson(user);
      
      expect(json['firstName'], equals('John'));
      expect(json['lastName'], equals('Doe'));
      expect(json['emailAddress'], equals('john.doe@example.com'));
    });

    test('Constructor with snake_case config', () {
      final user = ConfigurableUser(
        firstName: 'Jane',
        lastName: 'Smith',
        emailAddress: 'jane.smith@example.com',
      );

      // Constructor with snake_case config
      final snakeConfig = SerializationConfig(fieldRename: FieldRename.snake);
      final serializer = ConfigurableUserJsonSerializer(snakeConfig);
      
      // Uses constructor config by default
      final json = serializer.toJson(user);
      expect(json['first_name'], equals('Jane'));
      expect(json['last_name'], equals('Smith'));
      expect(json['email_address'], equals('jane.smith@example.com'));
      expect(json['created_at'], isA<String>());
      expect(json['updated_at'], isA<String>());
    });

    test('Method-level config overrides constructor config', () {
      final user = ConfigurableUser(
        firstName: 'Bob',
        lastName: 'Wilson',
        emailAddress: 'bob.wilson@example.com',
      );

      // Constructor with snake_case config
      final snakeConfig = SerializationConfig(fieldRename: FieldRename.snake);
      final serializer = ConfigurableUserJsonSerializer(snakeConfig);
      
      // Default method uses constructor config (snake_case)
      final snakeJson = serializer.toJson(user);
      expect(snakeJson['first_name'], equals('Bob'));
      
      // Override with kebab-case at method level
      final kebabConfig = SerializationConfig(fieldRename: FieldRename.kebab);
      final kebabJson = serializer.toJson(user, kebabConfig);
      expect(kebabJson['first-name'], equals('Bob'));
      expect(kebabJson['last-name'], equals('Wilson'));
      expect(kebabJson['email-address'], equals('bob.wilson@example.com'));
    });

    test('Deserialization works with constructor and method configs', () {
      // Snake case serializer
      final snakeConfig = SerializationConfig(fieldRename: FieldRename.snake);
      final serializer = ConfigurableUserJsonSerializer(snakeConfig);

      // Deserialize snake_case JSON using constructor config
      final snakeJson = {
        'first_name': 'Alice',
        'last_name': 'Johnson',
        'email_address': 'alice@example.com',
        'id': '550e8400-e29b-41d4-a716-446655440000',
        'created_at': '2024-01-01T12:00:00.000Z',
        'updated_at': '2024-01-01T12:00:00.000Z',
      };
      
      final user1 = serializer.fromJson(snakeJson);  // Uses constructor config
      expect(user1.firstName, equals('Alice'));
      expect(user1.lastName, equals('Johnson'));

      // Deserialize camelCase JSON by overriding with method config
      final camelJson = {
        'firstName': 'Charlie',
        'lastName': 'Brown',
        'emailAddress': 'charlie@example.com',
        'id': '550e8400-e29b-41d4-a716-446655440001',
        'createdAt': '2024-01-01T12:00:00.000Z',
        'updatedAt': '2024-01-01T12:00:00.000Z',
      };
      
      final defaultConfig = SerializationConfig();  // camelCase
      final user2 = serializer.fromJson(camelJson, defaultConfig);  // Override config
      expect(user2.firstName, equals('Charlie'));
      expect(user2.lastName, equals('Brown'));
    });

    test('String serialization methods work with configs', () {
      final user = ConfigurableUser(
        firstName: 'David',
        lastName: 'Miller',
        emailAddress: 'david@test.com',
      );

      final kebabConfig = SerializationConfig(fieldRename: FieldRename.kebab);
      final serializer = ConfigurableUserJsonSerializer(kebabConfig);

      // Serialize using constructor config
      final kebabString = serializer.serialize(user);
      expect(kebabString, contains('"first-name"'));
      expect(kebabString, contains('"email-address"'));

      // Override with snake_case
      final snakeConfig = SerializationConfig(fieldRename: FieldRename.snake);
      final snakeString = serializer.serialize(user, snakeConfig);
      expect(snakeString, contains('"first_name"'));
      expect(snakeString, contains('"email_address"'));

      // Round-trip with override config
      final restored = serializer.deserialize(snakeString, snakeConfig);
      expect(restored.firstName, equals('David'));
      expect(restored.lastName, equals('Miller'));
    });

    test('Static methods work with optional config', () {
      final user = ConfigurableUser(
        firstName: 'Eva',
        lastName: 'Davis',
        emailAddress: 'eva@example.com',
      );

      // Static methods with default config
      final defaultJson = ConfigurableUserJsonSerializer.encode(user);
      expect(defaultJson['firstName'], equals('Eva'));

      // Static methods with custom config
      final snakeConfig = SerializationConfig(fieldRename: FieldRename.snake);
      final snakeJson = ConfigurableUserJsonSerializer.encode(user, snakeConfig);
      expect(snakeJson['first_name'], equals('Eva'));
      expect(snakeJson['last_name'], equals('Davis'));

      final restored = ConfigurableUserJsonSerializer.decode(snakeJson, snakeConfig);
      expect(restored.firstName, equals('Eva'));
      expect(restored.lastName, equals('Davis'));
    });

    test('Perfect for DI container usage', () {
      // Simulate DI container setup
      final apiConfig = SerializationConfig(fieldRename: FieldRename.snake);
      final apiSerializer = ConfigurableUserJsonSerializer(apiConfig);
      
      final internalConfig = SerializationConfig(fieldRename: FieldRename.none);
      final internalSerializer = ConfigurableUserJsonSerializer(internalConfig);

      final user = ConfigurableUser(
        firstName: 'Frank',
        lastName: 'Wilson',
        emailAddress: 'frank@company.com',
      );

      // API serializer always uses snake_case (from constructor)
      final apiJson = apiSerializer.toJson(user);
      expect(apiJson['first_name'], equals('Frank'));
      expect(apiJson['email_address'], equals('frank@company.com'));

      // Internal serializer always uses camelCase (from constructor)
      final internalJson = internalSerializer.toJson(user);
      expect(internalJson['firstName'], equals('Frank'));
      expect(internalJson['emailAddress'], equals('frank@company.com'));

      // But can still override when needed
      final kebabConfig = SerializationConfig(fieldRename: FieldRename.kebab);
      final specialJson = apiSerializer.toJson(user, kebabConfig);
      expect(specialJson['first-name'], equals('Frank'));
    });
  });
}