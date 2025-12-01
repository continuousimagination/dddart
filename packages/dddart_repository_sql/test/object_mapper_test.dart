import 'package:dddart_repository_sql/src/mapping/object_mapper.dart';
import 'package:test/test.dart';

void main() {
  group('ObjectMapper', () {
    late ObjectMapper mapper;

    setUp(() {
      mapper = const ObjectMapper();
    });

    group('flattenValueObject', () {
      test('should flatten simple value object with prefixed columns', () {
        final valueObjectJson = {
          'amount': 100.0,
          'currency': 'USD',
        };

        final flattened =
            mapper.flattenValueObject('totalAmount', valueObjectJson);

        expect(
          flattened,
          equals({
            'totalAmount_amount': 100.0,
            'totalAmount_currency': 'USD',
          }),
        );
      });

      test('should flatten nested value objects with double prefixes', () {
        final valueObjectJson = {
          'street': '123 Main St',
          'city': 'Springfield',
          'country': 'USA',
        };

        final flattened =
            mapper.flattenValueObject('shippingAddress', valueObjectJson);

        expect(
          flattened,
          equals({
            'shippingAddress_street': '123 Main St',
            'shippingAddress_city': 'Springfield',
            'shippingAddress_country': 'USA',
          }),
        );
      });

      test('should handle deeply nested value objects', () {
        final valueObjectJson = {
          'amount': 100.0,
          'currency': 'USD',
          'metadata': {
            'source': 'payment',
            'timestamp': 1234567890,
          },
        };

        final flattened = mapper.flattenValueObject('price', valueObjectJson);

        expect(
          flattened,
          equals({
            'price_amount': 100.0,
            'price_currency': 'USD',
            'price_metadata_source': 'payment',
            'price_metadata_timestamp': 1234567890,
          }),
        );
      });

      test('should handle null values in value objects', () {
        final valueObjectJson = {
          'amount': 100.0,
          'currency': null,
        };

        final flattened =
            mapper.flattenValueObject('totalAmount', valueObjectJson);

        expect(
          flattened,
          equals({
            'totalAmount_amount': 100.0,
            'totalAmount_currency': null,
          }),
        );
      });

      test('should handle empty value objects', () {
        final valueObjectJson = <String, dynamic>{};

        final flattened = mapper.flattenValueObject('empty', valueObjectJson);

        expect(flattened, isEmpty);
      });

      test('should handle value objects with various data types', () {
        final valueObjectJson = {
          'stringField': 'test',
          'intField': 42,
          'doubleField': 3.14,
          'boolField': true,
          'listField': [1, 2, 3],
        };

        final flattened = mapper.flattenValueObject('data', valueObjectJson);

        expect(
          flattened,
          equals({
            'data_stringField': 'test',
            'data_intField': 42,
            'data_doubleField': 3.14,
            'data_boolField': true,
            'data_listField': [1, 2, 3],
          }),
        );
      });
    });

    group('reconstructValueObject', () {
      test('should reconstruct simple value object from prefixed columns', () {
        final row = {
          'id': 'order-123',
          'totalAmount_amount': 100.0,
          'totalAmount_currency': 'USD',
          'status': 'pending',
        };

        final reconstructed = mapper.reconstructValueObject('totalAmount', row);

        expect(
          reconstructed,
          equals({
            'amount': 100.0,
            'currency': 'USD',
          }),
        );
      });

      test('should reconstruct nested value objects', () {
        final row = {
          'id': 'order-123',
          'shippingAddress_street': '123 Main St',
          'shippingAddress_city': 'Springfield',
          'shippingAddress_country': 'USA',
        };

        final reconstructed =
            mapper.reconstructValueObject('shippingAddress', row);

        expect(
          reconstructed,
          equals({
            'street': '123 Main St',
            'city': 'Springfield',
            'country': 'USA',
          }),
        );
      });

      test('should reconstruct deeply nested value objects', () {
        final row = {
          'id': 'order-123',
          'price_amount': 100.0,
          'price_currency': 'USD',
          'price_metadata_source': 'payment',
          'price_metadata_timestamp': 1234567890,
        };

        final reconstructed = mapper.reconstructValueObject('price', row);

        expect(
          reconstructed,
          equals({
            'amount': 100.0,
            'currency': 'USD',
            'metadata': {
              'source': 'payment',
              'timestamp': 1234567890,
            },
          }),
        );
      });

      test('should handle null values when reconstructing', () {
        final row = {
          'id': 'order-123',
          'totalAmount_amount': 100.0,
          'totalAmount_currency': null,
        };

        final reconstructed = mapper.reconstructValueObject('totalAmount', row);

        expect(
          reconstructed,
          equals({
            'amount': 100.0,
            'currency': null,
          }),
        );
      });

      test('should return empty map when no matching columns found', () {
        final row = {
          'id': 'order-123',
          'status': 'pending',
        };

        final reconstructed = mapper.reconstructValueObject('totalAmount', row);

        expect(reconstructed, isEmpty);
      });

      test('should only extract columns with matching prefix', () {
        final row = {
          'id': 'order-123',
          'totalAmount_amount': 100.0,
          'totalAmount_currency': 'USD',
          'shippingAmount_amount': 10.0,
          'shippingAmount_currency': 'USD',
        };

        final reconstructed = mapper.reconstructValueObject('totalAmount', row);

        expect(
          reconstructed,
          equals({
            'amount': 100.0,
            'currency': 'USD',
          }),
        );
      });

      test('should handle various data types when reconstructing', () {
        final row = {
          'data_stringField': 'test',
          'data_intField': 42,
          'data_doubleField': 3.14,
          'data_boolField': true,
          'data_listField': [1, 2, 3],
        };

        final reconstructed = mapper.reconstructValueObject('data', row);

        expect(
          reconstructed,
          equals({
            'stringField': 'test',
            'intField': 42,
            'doubleField': 3.14,
            'boolField': true,
            'listField': [1, 2, 3],
          }),
        );
      });
    });

    group('round-trip', () {
      test('should preserve data through flatten and reconstruct cycle', () {
        final original = {
          'amount': 100.0,
          'currency': 'USD',
        };

        final flattened = mapper.flattenValueObject('totalAmount', original);
        final row = {
          'id': 'order-123',
          ...flattened,
        };
        final reconstructed = mapper.reconstructValueObject('totalAmount', row);

        expect(reconstructed, equals(original));
      });

      test('should preserve nested data through round-trip', () {
        final original = {
          'street': '123 Main St',
          'city': 'Springfield',
          'country': 'USA',
        };

        final flattened = mapper.flattenValueObject('address', original);
        final row = {
          'id': 'order-123',
          ...flattened,
        };
        final reconstructed = mapper.reconstructValueObject('address', row);

        expect(reconstructed, equals(original));
      });

      test('should preserve deeply nested data through round-trip', () {
        final original = {
          'amount': 100.0,
          'currency': 'USD',
          'metadata': {
            'source': 'payment',
            'timestamp': 1234567890,
          },
        };

        final flattened = mapper.flattenValueObject('price', original);
        final row = {
          'id': 'order-123',
          ...flattened,
        };
        final reconstructed = mapper.reconstructValueObject('price', row);

        expect(reconstructed, equals(original));
      });

      test('should preserve null values through round-trip', () {
        final original = {
          'amount': 100.0,
          'currency': null,
        };

        final flattened = mapper.flattenValueObject('totalAmount', original);
        final row = {
          'id': 'order-123',
          ...flattened,
        };
        final reconstructed = mapper.reconstructValueObject('totalAmount', row);

        expect(reconstructed, equals(original));
      });
    });
  });
}
