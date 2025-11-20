import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:test/test.dart';

import 'test_models.dart';

void main() {
  group('Error Handling and Edge Cases', () {
    group('Missing required fields', () {
      test('throws DeserializationException when required field is missing',
          () {
        final json = {
          'email': 'incomplete@example.com',
          // Missing 'name' field
          'id': '550e8400-e29b-41d4-a716-446655440000',
          'createdAt': '2024-01-01T12:00:00.000Z',
          'updatedAt': '2024-01-01T12:30:00.000Z',
        };

        final serializer = TestUserJsonSerializer();
        expect(
          () => serializer.fromJson(json),
          throwsA(isA<DeserializationException>()),
        );
      });

      test('throws descriptive error for missing AggregateRoot base fields',
          () {
        final json = {
          'name': 'Test User',
          'email': 'test@example.com',
          // Missing 'id', 'createdAt', 'updatedAt'
        };

        final serializer = TestUserJsonSerializer();
        expect(
          () => serializer.fromJson(json),
          throwsA(isA<DeserializationException>()),
        );
      });

      test('throws descriptive error for missing nested Value fields', () {
        final json = {
          'name': 'Test User',
          'email': 'test@example.com',
          'address': {
            'street': '123 Main St',
            // Missing 'city' and 'zipCode'
          },
          'id': '550e8400-e29b-41d4-a716-446655440000',
          'createdAt': '2024-01-01T12:00:00.000Z',
          'updatedAt': '2024-01-01T12:30:00.000Z',
        };

        final serializer = TestUserWithAddressJsonSerializer();
        expect(
          () => serializer.fromJson(json),
          throwsA(isA<DeserializationException>()),
        );
      });

      test('provides descriptive error message for missing fields', () {
        final json = {
          'email': 'incomplete@example.com',
          'id': '550e8400-e29b-41d4-a716-446655440000',
          'createdAt': '2024-01-01T12:00:00.000Z',
          'updatedAt': '2024-01-01T12:30:00.000Z',
        };

        try {
          final serializer = TestUserJsonSerializer();
          serializer.fromJson(json);
          fail('Expected DeserializationException to be thrown');
        } catch (e) {
          expect(e, isA<DeserializationException>());
          final exception = e as DeserializationException;
          expect(exception.message, contains('Failed to deserialize TestUser'));
          expect(exception.expectedType, equals('TestUser'));
        }
      });
    });

    group('Invalid field types', () {
      test('throws DeserializationException for wrong field type', () {
        final json = {
          'name': 123, // Should be String, not int
          'email': 'test@example.com',
          'id': '550e8400-e29b-41d4-a716-446655440000',
          'createdAt': '2024-01-01T12:00:00.000Z',
          'updatedAt': '2024-01-01T12:30:00.000Z',
        };

        expect(
          () => TestUserJsonSerializer().fromJson(json),
          throwsA(isA<DeserializationException>()),
        );
      });

      test('throws error for invalid UUID format', () {
        final json = {
          'name': 'Test User',
          'email': 'test@example.com',
          'id': 'invalid-uuid-format',
          'createdAt': '2024-01-01T12:00:00.000Z',
          'updatedAt': '2024-01-01T12:30:00.000Z',
        };

        expect(
          () => TestUserJsonSerializer().fromJson(json),
          throwsA(isA<DeserializationException>()),
        );
      });

      test('throws error for invalid DateTime format', () {
        final json = {
          'name': 'Test User',
          'email': 'test@example.com',
          'id': '550e8400-e29b-41d4-a716-446655440000',
          'createdAt': 'invalid-date-format',
          'updatedAt': '2024-01-01T12:30:00.000Z',
        };

        expect(
          () => TestUserJsonSerializer().fromJson(json),
          throwsA(isA<DeserializationException>()),
        );
      });

      test('throws error for wrong collection type', () {
        final json = {
          'name': 'Complex User',
          'contactInfo': {
            'email': 'complex@example.com',
            'phone': '+1-555-0123',
            'address': {
              'street': '123 Main St',
              'city': 'Test City',
              'zipCode': '12345',
            },
          },
          'addresses': 'should-be-list-not-string',
          'tags': ['tag1', 'tag2'],
          'metadata': {},
          'id': '550e8400-e29b-41d4-a716-446655440000',
          'createdAt': '2024-01-01T12:00:00.000Z',
          'updatedAt': '2024-01-01T12:30:00.000Z',
        };

        expect(
          () => TestComplexUserJsonSerializer().fromJson(json),
          throwsA(isA<DeserializationException>()),
        );
      });

      test('throws error for wrong nested object type', () {
        final json = {
          'name': 'Test User',
          'email': 'test@example.com',
          'address': 'should-be-object-not-string',
          'id': '550e8400-e29b-41d4-a716-446655440000',
          'createdAt': '2024-01-01T12:00:00.000Z',
          'updatedAt': '2024-01-01T12:30:00.000Z',
        };

        expect(
          () => TestUserWithAddressJsonSerializer().fromJson(json),
          throwsA(isA<DeserializationException>()),
        );
      });
    });

    group('Malformed JSON', () {
      test('throws error for null JSON input', () {
        expect(
          () => TestUserJsonSerializer().fromJson(null as dynamic),
          throwsA(isA<DeserializationException>()),
        );
      });

      test('throws error for non-Map JSON input', () {
        expect(
          () => TestUserJsonSerializer().fromJson('not-a-map' as dynamic),
          throwsA(isA<DeserializationException>()),
        );

        expect(
          () => TestUserJsonSerializer().fromJson(123 as dynamic),
          throwsA(isA<DeserializationException>()),
        );

        expect(
          () =>
              TestUserJsonSerializer().fromJson(['not', 'a', 'map'] as dynamic),
          throwsA(isA<DeserializationException>()),
        );
      });

      test('throws error for empty JSON object', () {
        final json = <String, dynamic>{};

        expect(
          () => TestUserJsonSerializer().fromJson(json),
          throwsA(isA<DeserializationException>()),
        );
      });

      test('handles nested malformed JSON gracefully', () {
        final json = {
          'name': 'Test User',
          'email': 'test@example.com',
          'address': null, // Should be an object
          'id': '550e8400-e29b-41d4-a716-446655440000',
          'createdAt': '2024-01-01T12:00:00.000Z',
          'updatedAt': '2024-01-01T12:30:00.000Z',
        };

        expect(
          () => TestUserWithAddressJsonSerializer().fromJson(json),
          throwsA(isA<DeserializationException>()),
        );
      });
    });

    group('Descriptive error messages', () {
      test('error messages include context information', () {
        final json = {
          'name': 123, // Wrong type
          'email': 'test@example.com',
          'id': '550e8400-e29b-41d4-a716-446655440000',
          'createdAt': '2024-01-01T12:00:00.000Z',
          'updatedAt': '2024-01-01T12:30:00.000Z',
        };

        try {
          TestUserJsonSerializer().fromJson(json);
          fail('Expected DeserializationException to be thrown');
        } catch (e) {
          expect(e, isA<DeserializationException>());
          final exception = e as DeserializationException;

          // Verify error message contains useful information
          expect(exception.message, isNotEmpty);
          expect(exception.message, contains('TestUser'));
          expect(exception.expectedType, equals('TestUser'));
          expect(exception.toString(), contains('DeserializationException'));
        }
      });

      test('error messages distinguish between different error types', () {
        // Test missing field error
        final missingFieldJson = {
          'email': 'test@example.com',
          'id': '550e8400-e29b-41d4-a716-446655440000',
          'createdAt': '2024-01-01T12:00:00.000Z',
          'updatedAt': '2024-01-01T12:30:00.000Z',
        };

        // Test wrong type error
        final wrongTypeJson = {
          'name': 123,
          'email': 'test@example.com',
          'id': '550e8400-e29b-41d4-a716-446655440000',
          'createdAt': '2024-01-01T12:00:00.000Z',
          'updatedAt': '2024-01-01T12:30:00.000Z',
        };

        DeserializationException? missingFieldError;
        DeserializationException? wrongTypeError;

        try {
          TestUserJsonSerializer().fromJson(missingFieldJson);
        } catch (e) {
          missingFieldError = e as DeserializationException;
        }

        try {
          TestUserJsonSerializer().fromJson(wrongTypeJson);
        } catch (e) {
          wrongTypeError = e as DeserializationException;
        }

        expect(missingFieldError, isNotNull);
        expect(wrongTypeError, isNotNull);

        // Both should be DeserializationExceptions but with different messages
        expect(
          missingFieldError!.message,
          isNot(equals(wrongTypeError!.message)),
        );
      });

      test('nested deserialization errors provide context', () {
        final json = {
          'name': 'Test User',
          'email': 'test@example.com',
          'address': {
            'street': 123, // Wrong type - should be String
            'city': 'Test City',
            'zipCode': '12345',
          },
          'id': '550e8400-e29b-41d4-a716-446655440000',
          'createdAt': '2024-01-01T12:00:00.000Z',
          'updatedAt': '2024-01-01T12:30:00.000Z',
        };

        try {
          TestUserWithAddressJsonSerializer().fromJson(json);
          fail('Expected DeserializationException to be thrown');
        } catch (e) {
          expect(e, isA<DeserializationException>());
          final exception = e as DeserializationException;
          expect(exception.message, contains('TestUserWithAddress'));
        }
      });
    });

    group('Null handling', () {
      test('handles null values in optional fields correctly', () {
        final json = {
          'level': 1,
          'data': 'Test Data',
          'child': null, // This should be allowed
        };

        final nested = TestNestedValueJsonSerializer().fromJson(json);
        expect(nested.level, equals(1));
        expect(nested.data, equals('Test Data'));
        expect(nested.child, isNull);
      });

      test('rejects null values in required fields', () {
        final json = {
          'level': 1,
          'data': null, // This should not be allowed
          'child': null,
        };

        expect(
          () => TestNestedValueJsonSerializer().fromJson(json),
          throwsA(isA<DeserializationException>()),
        );
      });

      test('handles null values in collections appropriately', () {
        final json = {
          'name': 'Complex User',
          'contactInfo': {
            'email': 'complex@example.com',
            'phone': '+1-555-0123',
            'address': {
              'street': '123 Main St',
              'city': 'Test City',
              'zipCode': '12345',
            },
          },
          'addresses': null, // This should cause an error
          'tags': ['tag1', 'tag2'],
          'metadata': {},
          'id': '550e8400-e29b-41d4-a716-446655440000',
          'createdAt': '2024-01-01T12:00:00.000Z',
          'updatedAt': '2024-01-01T12:30:00.000Z',
        };

        expect(
          () => TestComplexUserJsonSerializer().fromJson(json),
          throwsA(isA<DeserializationException>()),
        );
      });
    });

    group('Edge cases', () {
      test('handles empty collections correctly', () {
        final json = {
          'name': 'Empty Collections User',
          'contactInfo': {
            'email': 'empty@example.com',
            'phone': '+1-555-0000',
            'address': {
              'street': 'Empty Street',
              'city': 'Empty City',
              'zipCode': '00000',
            },
          },
          'addresses': [],
          'tags': [],
          'metadata': {},
          'id': '550e8400-e29b-41d4-a716-446655440000',
          'createdAt': '2024-01-01T12:00:00.000Z',
          'updatedAt': '2024-01-01T12:30:00.000Z',
        };

        final user = TestComplexUserJsonSerializer().fromJson(json);
        expect(user.addresses, isEmpty);
        expect(user.tags, isEmpty);
        expect(user.metadata, isEmpty);
      });

      test('handles very long strings correctly', () {
        final longString = 'x' * 10000;
        final json = {
          'name': longString,
          'email': 'long@example.com',
          'id': '550e8400-e29b-41d4-a716-446655440000',
          'createdAt': '2024-01-01T12:00:00.000Z',
          'updatedAt': '2024-01-01T12:30:00.000Z',
        };

        final user = TestUserJsonSerializer().fromJson(json);
        expect(user.name, equals(longString));
        expect(user.name.length, equals(10000));
      });

      test('handles special characters in strings correctly', () {
        const specialString =
            'Test with émojis 🎉 and ñ special chars & symbols!';
        final json = {
          'name': specialString,
          'email': 'special@example.com',
          'id': '550e8400-e29b-41d4-a716-446655440000',
          'createdAt': '2024-01-01T12:00:00.000Z',
          'updatedAt': '2024-01-01T12:30:00.000Z',
        };

        final user = TestUserJsonSerializer().fromJson(json);
        expect(user.name, equals(specialString));

        // Verify round-trip maintains special characters
        final serializer = TestUserJsonSerializer();
        final roundTripJson = serializer.toJson(user);
        final roundTripUser = serializer.fromJson(roundTripJson);
        expect(roundTripUser.name, equals(specialString));
      });

      test('handles extreme DateTime values correctly', () {
        final json = {
          'name': 'DateTime Test',
          'email': 'datetime@example.com',
          'id': '550e8400-e29b-41d4-a716-446655440000',
          'createdAt': '1970-01-01T00:00:00.000Z', // Unix epoch
          'updatedAt': '2099-12-31T23:59:59.999Z', // Far future
        };

        final user = TestUserJsonSerializer().fromJson(json);
        expect(
          user.createdAt,
          equals(DateTime.parse('1970-01-01T00:00:00.000Z')),
        );
        expect(
          user.updatedAt,
          equals(DateTime.parse('2099-12-31T23:59:59.999Z')),
        );
      });
    });

    group('Application stability', () {
      test('deserialization errors do not crash application', () {
        final badJsonInputs = [
          null,
          'string',
          123,
          [],
          {},
          {'incomplete': 'data'},
          {'name': null, 'email': 'test@example.com'},
        ];

        for (final badInput in badJsonInputs) {
          expect(
            () => TestUserJsonSerializer().fromJson(badInput as dynamic),
            throwsA(isA<DeserializationException>()),
            reason: 'Input: $badInput should throw DeserializationException',
          );
        }

        // Verify application continues to work after errors
        final validJson = {
          'name': 'Valid User',
          'email': 'valid@example.com',
          'id': '550e8400-e29b-41d4-a716-446655440000',
          'createdAt': '2024-01-01T12:00:00.000Z',
          'updatedAt': '2024-01-01T12:30:00.000Z',
        };

        final user = TestUserJsonSerializer().fromJson(validJson);
        expect(user.name, equals('Valid User'));
      });

      test('multiple consecutive errors do not affect subsequent operations',
          () {
        // Cause multiple errors
        for (var i = 0; i < 5; i++) {
          expect(
            () => TestUserJsonSerializer().fromJson({'invalid': 'data$i'}),
            throwsA(isA<DeserializationException>()),
          );
        }

        // Verify normal operation still works
        final validJson = {
          'name': 'Post Error User',
          'email': 'posterror@example.com',
          'id': '550e8400-e29b-41d4-a716-446655440000',
          'createdAt': '2024-01-01T12:00:00.000Z',
          'updatedAt': '2024-01-01T12:30:00.000Z',
        };

        final user = TestUserJsonSerializer().fromJson(validJson);
        expect(user.name, equals('Post Error User'));

        final serializer = TestUserJsonSerializer();
        final json = serializer.toJson(user);
        final roundTrip = serializer.fromJson(json);
        expect(roundTrip, equals(user));
      });
    });
  });
}
