import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:test/test.dart';

import 'test_models.dart';

void main() {
  group('AggregateRoot Serialization', () {
    group('Simple AggregateRoot', () {
      test('serializes simple AggregateRoot with basic fields to JSON', () {
        final user = TestUser(
          name: 'John Doe',
          email: 'john@example.com',
        );

        final serializer = TestUserJsonSerializer();
        final json = serializer.toJson(user);

        expect(json['name'], equals('John Doe'));
        expect(json['email'], equals('john@example.com'));
        expect(json['id'], isA<String>());
        expect(json['createdAt'], isA<String>());
        expect(json['updatedAt'], isA<String>());

        // Verify UUID format
        expect(
          json['id'],
          matches(
            RegExp(
              r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
            ),
          ),
        );

        // Verify ISO 8601 format
        expect(() => DateTime.parse(json['createdAt']), returnsNormally);
        expect(() => DateTime.parse(json['updatedAt']), returnsNormally);
      });

      test('deserializes JSON to simple AggregateRoot', () {
        final json = {
          'name': 'Jane Smith',
          'email': 'jane@example.com',
          'id': '550e8400-e29b-41d4-a716-446655440000',
          'createdAt': '2024-01-01T12:00:00.000Z',
          'updatedAt': '2024-01-01T12:30:00.000Z',
        };

        final serializer = TestUserJsonSerializer();
        final user = serializer.fromJson(json);

        expect(user.name, equals('Jane Smith'));
        expect(user.email, equals('jane@example.com'));
        expect(
          user.id.toString(),
          equals('550e8400-e29b-41d4-a716-446655440000'),
        );
        expect(
          user.createdAt,
          equals(DateTime.parse('2024-01-01T12:00:00.000Z')),
        );
        expect(
          user.updatedAt,
          equals(DateTime.parse('2024-01-01T12:30:00.000Z')),
        );
      });

      test('round-trip serialization maintains equality', () {
        final original = TestUser(
          name: 'Alice Johnson',
          email: 'alice@example.com',
          id: UuidValue.fromString('550e8400-e29b-41d4-a716-446655440001'),
          createdAt: DateTime.parse('2024-01-01T10:00:00.000Z'),
          updatedAt: DateTime.parse('2024-01-01T10:15:00.000Z'),
        );

        final serializer = TestUserJsonSerializer();
        final json = serializer.toJson(original);
        final deserialized = serializer.fromJson(json);

        expect(deserialized, equals(original));
        expect(deserialized.name, equals(original.name));
        expect(deserialized.email, equals(original.email));
        expect(deserialized.id, equals(original.id));
        expect(deserialized.createdAt, equals(original.createdAt));
        expect(deserialized.updatedAt, equals(original.updatedAt));
      });
    });

    group('AggregateRoot with nested Values', () {
      test('serializes AggregateRoot with nested Value objects', () {
        const address = TestAddress(
          street: '123 Main St',
          city: 'Anytown',
          zipCode: '12345',
        );
        final user = TestUserWithAddress(
          name: 'Bob Wilson',
          email: 'bob@example.com',
          address: address,
        );

        final serializer = TestUserWithAddressJsonSerializer();
        final json = serializer.toJson(user);

        expect(json['name'], equals('Bob Wilson'));
        expect(json['email'], equals('bob@example.com'));
        expect(json['address'], isA<Map<String, dynamic>>());

        final addressJson = json['address'] as Map<String, dynamic>;
        expect(addressJson['street'], equals('123 Main St'));
        expect(addressJson['city'], equals('Anytown'));
        expect(addressJson['zipCode'], equals('12345'));
      });

      test('deserializes AggregateRoot with nested Value objects', () {
        final json = {
          'name': 'Carol Davis',
          'email': 'carol@example.com',
          'address': {
            'street': '456 Oak Ave',
            'city': 'Somewhere',
            'zipCode': '67890',
          },
          'id': '550e8400-e29b-41d4-a716-446655440002',
          'createdAt': '2024-01-02T08:00:00.000Z',
          'updatedAt': '2024-01-02T08:30:00.000Z',
        };

        final serializer = TestUserWithAddressJsonSerializer();
        final user = serializer.fromJson(json);

        expect(user.name, equals('Carol Davis'));
        expect(user.email, equals('carol@example.com'));
        expect(user.address.street, equals('456 Oak Ave'));
        expect(user.address.city, equals('Somewhere'));
        expect(user.address.zipCode, equals('67890'));
      });

      test('round-trip serialization with nested Values maintains equality',
          () {
        const address = TestAddress(
          street: '789 Pine Rd',
          city: 'Elsewhere',
          zipCode: '54321',
        );
        final original = TestUserWithAddress(
          name: 'David Brown',
          email: 'david@example.com',
          address: address,
          id: UuidValue.fromString('550e8400-e29b-41d4-a716-446655440003'),
          createdAt: DateTime.parse('2024-01-03T14:00:00.000Z'),
          updatedAt: DateTime.parse('2024-01-03T14:45:00.000Z'),
        );

        final serializer = TestUserWithAddressJsonSerializer();
        final json = serializer.toJson(original);
        final deserialized = serializer.fromJson(json);

        expect(deserialized, equals(original));
        expect(deserialized.address, equals(original.address));
      });
    });

    group('Field naming strategies', () {
      test('serializes with snake_case field naming', () {
        final user = TestUserSnakeCase(
          firstName: 'Emma',
          lastName: 'Thompson',
          emailAddress: 'emma.thompson@example.com',
        );

        const snakeConfig = SerializationConfig(fieldRename: FieldRename.snake);
        final serializer = TestUserSnakeCaseJsonSerializer(snakeConfig);
        final json = serializer.toJson(user);

        expect(json['first_name'], equals('Emma'));
        expect(json['last_name'], equals('Thompson'));
        expect(json['email_address'], equals('emma.thompson@example.com'));
        expect(json['created_at'], isA<String>());
        expect(json['updated_at'], isA<String>());
      });

      test('deserializes from snake_case field naming', () {
        final json = {
          'first_name': 'Frank',
          'last_name': 'Miller',
          'email_address': 'frank.miller@example.com',
          'id': '550e8400-e29b-41d4-a716-446655440004',
          'created_at': '2024-01-04T09:00:00.000Z',
          'updated_at': '2024-01-04T09:15:00.000Z',
        };

        const snakeConfig = SerializationConfig(fieldRename: FieldRename.snake);
        final serializer = TestUserSnakeCaseJsonSerializer(snakeConfig);
        final user = serializer.fromJson(json);

        expect(user.firstName, equals('Frank'));
        expect(user.lastName, equals('Miller'));
        expect(user.emailAddress, equals('frank.miller@example.com'));
      });

      test('serializes with kebab-case field naming', () {
        final user = TestUserKebabCase(
          firstName: 'Grace',
          lastName: 'Lee',
          emailAddress: 'grace.lee@example.com',
        );

        const kebabConfig = SerializationConfig(fieldRename: FieldRename.kebab);
        final serializer = TestUserKebabCaseJsonSerializer(kebabConfig);
        final json = serializer.toJson(user);

        expect(json['first-name'], equals('Grace'));
        expect(json['last-name'], equals('Lee'));
        expect(json['email-address'], equals('grace.lee@example.com'));
        expect(json['created-at'], isA<String>());
        expect(json['updated-at'], isA<String>());
      });

      test('deserializes from kebab-case field naming', () {
        final json = {
          'first-name': 'Henry',
          'last-name': 'Garcia',
          'email-address': 'henry.garcia@example.com',
          'id': '550e8400-e29b-41d4-a716-446655440005',
          'created-at': '2024-01-05T11:00:00.000Z',
          'updated-at': '2024-01-05T11:20:00.000Z',
        };

        const kebabConfig = SerializationConfig(fieldRename: FieldRename.kebab);
        final serializer = TestUserKebabCaseJsonSerializer(kebabConfig);
        final user = serializer.fromJson(json);

        expect(user.firstName, equals('Henry'));
        expect(user.lastName, equals('Garcia'));
        expect(user.emailAddress, equals('henry.garcia@example.com'));
      });
    });

    group('JSON structure verification', () {
      test('verifies JSON structure matches expected format', () {
        final user = TestUser(
          name: 'Test User',
          email: 'test@example.com',
          id: UuidValue.fromString('550e8400-e29b-41d4-a716-446655440006'),
          createdAt: DateTime.parse('2024-01-06T16:00:00.000Z'),
          updatedAt: DateTime.parse('2024-01-06T16:30:00.000Z'),
        );

        final serializer = TestUserJsonSerializer();
        final json = serializer.toJson(user);

        // Verify all required fields are present
        expect(
          json.keys,
          containsAll(['id', 'createdAt', 'updatedAt', 'name', 'email']),
        );

        // Verify field types
        expect(json['id'], isA<String>());
        expect(json['createdAt'], isA<String>());
        expect(json['updatedAt'], isA<String>());
        expect(json['name'], isA<String>());
        expect(json['email'], isA<String>());

        // Verify deterministic ordering (fields should be consistently ordered)
        final keys = json.keys.toList();
        expect(keys, equals(['id', 'createdAt', 'updatedAt', 'email', 'name']));
      });

      test('verifies nested JSON structure', () {
        const address = TestAddress(
          street: 'Test Street',
          city: 'Test City',
          zipCode: '00000',
        );
        final user = TestUserWithAddress(
          name: 'Nested Test',
          email: 'nested@example.com',
          address: address,
        );

        final serializer = TestUserWithAddressJsonSerializer();
        final json = serializer.toJson(user);

        expect(json['address'], isA<Map<String, dynamic>>());
        final addressJson = json['address'] as Map<String, dynamic>;
        expect(addressJson.keys, containsAll(['street', 'city', 'zipCode']));
      });
    });
  });
}
