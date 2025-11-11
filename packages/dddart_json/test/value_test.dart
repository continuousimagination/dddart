import 'package:dddart/dddart.dart';
import 'package:test/test.dart';

import 'test_models.dart';

void main() {
  group('Value Object Serialization', () {
    group('Simple Value objects', () {
      test('serializes simple Value object with primitive fields to JSON', () {
        const address = TestAddress(
          street: '123 Main Street',
          city: 'Springfield',
          zipCode: '12345',
        );

        final serializer = TestAddressJsonSerializer();
        final json = serializer.toJson(address);

        expect(json['street'], equals('123 Main Street'));
        expect(json['city'], equals('Springfield'));
        expect(json['zipCode'], equals('12345'));

        // Verify all props are included
        expect(json.keys.length, equals(3));
        expect(json.keys, containsAll(['street', 'city', 'zipCode']));
      });

      test('deserializes JSON to simple Value object', () {
        final json = {
          'street': '456 Oak Avenue',
          'city': 'Riverside',
          'zipCode': '67890',
        };

        final serializer = TestAddressJsonSerializer();
        final address = serializer.fromJson(json);

        expect(address.street, equals('456 Oak Avenue'));
        expect(address.city, equals('Riverside'));
        expect(address.zipCode, equals('67890'));
      });

      test('round-trip serialization maintains equality for simple Value', () {
        const original = TestAddress(
          street: '789 Pine Road',
          city: 'Hillside',
          zipCode: '54321',
        );

        final serializer = TestAddressJsonSerializer();
        final json = serializer.toJson(original);
        final deserialized = serializer.fromJson(json);

        expect(deserialized, equals(original));
        expect(deserialized.street, equals(original.street));
        expect(deserialized.city, equals(original.city));
        expect(deserialized.zipCode, equals(original.zipCode));
      });
    });

    group('Value objects with special types', () {
      test('serializes Value object with UuidValue and DateTime fields', () {
        final testId =
            UuidValue.fromString('550e8400-e29b-41d4-a716-446655440000');
        final testTime = DateTime.parse('2024-01-01T12:00:00.000Z');
        final value = TestValueWithSpecialTypes(
          id: testId,
          timestamp: testTime,
          name: 'Test Value',
        );

        final serializer = TestValueWithSpecialTypesJsonSerializer();
        final json = serializer.toJson(value);

        expect(json['id'], equals('550e8400-e29b-41d4-a716-446655440000'));
        expect(json['timestamp'], equals('2024-01-01T12:00:00.000Z'));
        expect(json['name'], equals('Test Value'));

        // Verify UUID is serialized as string
        expect(json['id'], isA<String>());
        // Verify DateTime is serialized as ISO 8601 string
        expect(json['timestamp'], isA<String>());
        expect(() => DateTime.parse(json['timestamp']), returnsNormally);
      });

      test('deserializes Value object with UuidValue and DateTime fields', () {
        final json = {
          'id': '550e8400-e29b-41d4-a716-446655440001',
          'timestamp': '2024-01-02T15:30:00.000Z',
          'name': 'Deserialized Value',
        };

        final serializer = TestValueWithSpecialTypesJsonSerializer();
        final value = serializer.fromJson(json);

        expect(value.id.toString(),
            equals('550e8400-e29b-41d4-a716-446655440001'),);
        expect(value.timestamp,
            equals(DateTime.parse('2024-01-02T15:30:00.000Z')),);
        expect(value.name, equals('Deserialized Value'));
      });

      test('round-trip serialization with special types maintains equality',
          () {
        final original = TestValueWithSpecialTypes(
          id: UuidValue.fromString('550e8400-e29b-41d4-a716-446655440002'),
          timestamp: DateTime.parse('2024-01-03T09:45:00.000Z'),
          name: 'Round Trip Test',
        );

        final serializer = TestValueWithSpecialTypesJsonSerializer();
        final json = serializer.toJson(original);
        final deserialized = serializer.fromJson(json);

        expect(deserialized, equals(original));
        expect(deserialized.id, equals(original.id));
        expect(deserialized.timestamp, equals(original.timestamp));
        expect(deserialized.name, equals(original.name));
      });
    });

    group('Props-based field inclusion', () {
      test('verifies only props fields are included in serialization', () {
        const address = TestAddress(
          street: 'Test Street',
          city: 'Test City',
          zipCode: 'Test Zip',
        );

        final serializer = TestAddressJsonSerializer();
        final json = serializer.toJson(address);

        // Verify that only the fields defined in props are serialized
        final expectedProps = address.props;
        expect(json.keys.length, equals(expectedProps.length));

        // The props for TestAddress are [street, city, zipCode]
        expect(json.keys, containsAll(['street', 'city', 'zipCode']));

        // Verify values match props order and content
        expect(json['street'], equals(expectedProps[0]));
        expect(json['city'], equals(expectedProps[1]));
        expect(json['zipCode'], equals(expectedProps[2]));
      });

      test('verifies props-based equality is preserved through serialization',
          () {
        const address1 = TestAddress(
          street: 'Same Street',
          city: 'Same City',
          zipCode: 'Same Zip',
        );
        const address2 = TestAddress(
          street: 'Same Street',
          city: 'Same City',
          zipCode: 'Same Zip',
        );

        // Verify they are equal based on props
        expect(address1, equals(address2));
        expect(address1.props, equals(address2.props));

        // Verify serialization produces identical JSON
        final serializer = TestAddressJsonSerializer();
        final json1 = serializer.toJson(address1);
        final json2 = serializer.toJson(address2);
        expect(json1, equals(json2));

        // Verify deserialization maintains equality
        final deserialized1 = serializer.fromJson(json1);
        final deserialized2 = serializer.fromJson(json2);
        expect(deserialized1, equals(deserialized2));
        expect(deserialized1, equals(address1));
        expect(deserialized2, equals(address2));
      });
    });

    group('Value object immutability', () {
      test('verifies Value objects remain immutable after serialization', () {
        const original = TestAddress(
          street: 'Original Street',
          city: 'Original City',
          zipCode: '00000',
        );
        final serializer = TestAddressJsonSerializer();
        final json = serializer.toJson(original);

        // Modify the JSON
        json['street'] = 'Modified Street';
        json['city'] = 'Modified City';

        // Verify original object is unchanged
        expect(original.street, equals('Original Street'));
        expect(original.city, equals('Original City'));
        expect(original.zipCode, equals('00000'));
      });

      test('verifies deserialized Value objects are properly constructed', () {
        final json = {
          'street': 'New Street',
          'city': 'New City',
          'zipCode': 'New Zip',
        };

        final serializer = TestAddressJsonSerializer();
        final address = serializer.fromJson(json);

        // Verify the object is properly constructed with const constructor
        expect(address.street, equals('New Street'));
        expect(address.city, equals('New City'));
        expect(address.zipCode, equals('New Zip'));

        // Verify props are correctly set
        expect(address.props, equals(['New Street', 'New City', 'New Zip']));
      });
    });

    group('JSON structure verification', () {
      test('verifies Value JSON structure is deterministic', () {
        const address = TestAddress(
          street: 'Deterministic Street',
          city: 'Deterministic City',
          zipCode: '99999',
        );

        final serializer = TestAddressJsonSerializer();
        final json1 = serializer.toJson(address);
        final json2 = serializer.toJson(address);

        // Verify multiple serializations produce identical results
        expect(json1, equals(json2));

        // Verify field ordering is consistent
        expect(json1.keys.toList(), equals(json2.keys.toList()));
      });

      test('verifies Value JSON contains only expected fields', () {
        final value = TestValueWithSpecialTypes(
          id: UuidValue.generate(),
          timestamp: DateTime.now(),
          name: 'Field Test',
        );

        final serializer = TestValueWithSpecialTypesJsonSerializer();
        final json = serializer.toJson(value);

        // Verify exactly the expected fields are present
        expect(json.keys, hasLength(3));
        expect(json.keys, containsAll(['id', 'timestamp', 'name']));

        // Verify no extra fields are included
        expect(json.keys, isNot(contains('props')));
        expect(json.keys, isNot(contains('hashCode')));
        expect(json.keys, isNot(contains('runtimeType')));
      });
    });
  });
}
