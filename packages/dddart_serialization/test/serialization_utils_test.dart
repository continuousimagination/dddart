import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:test/test.dart';

void main() {
  group('SerializationUtils', () {
    group('applyFieldRename', () {
      test('handles none transformation', () {
        expect(
          SerializationUtils.applyFieldRename('firstName', FieldRename.none),
          equals('firstName'),
        );
        expect(
          SerializationUtils.applyFieldRename('emailAddress', FieldRename.none),
          equals('emailAddress'),
        );
        expect(
          SerializationUtils.applyFieldRename('id', FieldRename.none),
          equals('id'),
        );
      });

      test('handles snake_case transformation', () {
        expect(
          SerializationUtils.applyFieldRename('firstName', FieldRename.snake),
          equals('first_name'),
        );
        expect(
          SerializationUtils.applyFieldRename(
            'emailAddress',
            FieldRename.snake,
          ),
          equals('email_address'),
        );
        expect(
          SerializationUtils.applyFieldRename('createdAt', FieldRename.snake),
          equals('created_at'),
        );
        expect(
          SerializationUtils.applyFieldRename('id', FieldRename.snake),
          equals('id'), // Single lowercase word unchanged
        );
      });

      test('handles kebab-case transformation', () {
        expect(
          SerializationUtils.applyFieldRename('firstName', FieldRename.kebab),
          equals('first-name'),
        );
        expect(
          SerializationUtils.applyFieldRename(
            'emailAddress',
            FieldRename.kebab,
          ),
          equals('email-address'),
        );
        expect(
          SerializationUtils.applyFieldRename('createdAt', FieldRename.kebab),
          equals('created-at'),
        );
        expect(
          SerializationUtils.applyFieldRename('id', FieldRename.kebab),
          equals('id'), // Single lowercase word unchanged
        );
      });
    });

    group('validateNotNull', () {
      test('returns value when not null', () {
        expect(
          SerializationUtils.validateNotNull('test', 'fieldName', 'String'),
          equals('test'),
        );
        expect(
          SerializationUtils.validateNotNull(42, 'fieldName', 'int'),
          equals(42),
        );
      });

      test('throws DeserializationException when null', () {
        expect(
          () =>
              SerializationUtils.validateNotNull(null, 'testField', 'TestType'),
          throwsA(
            isA<DeserializationException>()
                .having(
                  (e) => e.message,
                  'message',
                  contains('Required field "testField" is null'),
                )
                .having(
                  (e) => e.expectedType,
                  'expectedType',
                  equals('TestType'),
                ),
          ),
        );
      });
    });

    group('validateType', () {
      test('returns value when type matches', () {
        expect(
          SerializationUtils.validateType<String>(
            'test',
            'fieldName',
            'String',
          ),
          equals('test'),
        );
        expect(
          SerializationUtils.validateType<int>(42, 'fieldName', 'int'),
          equals(42),
        );
      });

      test('throws DeserializationException when type mismatch', () {
        expect(
          () => SerializationUtils.validateType<String>(
            42,
            'testField',
            'TestType',
          ),
          throwsA(
            isA<DeserializationException>()
                .having(
                  (e) => e.message,
                  'message',
                  contains(
                    'Field "testField" expected type String but got int',
                  ),
                )
                .having(
                  (e) => e.expectedType,
                  'expectedType',
                  equals('TestType'),
                ),
          ),
        );
      });
    });
  });
}
