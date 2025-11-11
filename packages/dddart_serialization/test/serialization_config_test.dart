import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:test/test.dart';

void main() {
  group('SerializationConfig', () {
    test('creates with default values', () {
      const config = SerializationConfig();

      expect(config.fieldRename, equals(FieldRename.none));
      expect(config.includeNullFields, isFalse);
    });

    test('creates with custom values', () {
      const config = SerializationConfig(
        fieldRename: FieldRename.snake,
        includeNullFields: true,
      );

      expect(config.fieldRename, equals(FieldRename.snake));
      expect(config.includeNullFields, isTrue);
    });

    test('supports equality comparison', () {
      const config1 = SerializationConfig(fieldRename: FieldRename.snake);
      const config2 = SerializationConfig(fieldRename: FieldRename.snake);
      const config3 = SerializationConfig(fieldRename: FieldRename.kebab);

      expect(config1, equals(config2));
      expect(config1, isNot(equals(config3)));
    });

    test('has proper toString representation', () {
      const config = SerializationConfig(
        fieldRename: FieldRename.snake,
        includeNullFields: true,
      );

      final str = config.toString();
      expect(str, contains('SerializationConfig'));
      expect(str, contains('snake'));
      expect(str, contains('true'));
    });
  });

  group('FieldRename', () {
    test('has correct enum values', () {
      expect(FieldRename.values, hasLength(3));
      expect(FieldRename.values, contains(FieldRename.none));
      expect(FieldRename.values, contains(FieldRename.snake));
      expect(FieldRename.values, contains(FieldRename.kebab));
    });

    test('has correct string representations', () {
      expect(FieldRename.none.toString(), equals('FieldRename.none'));
      expect(FieldRename.snake.toString(), equals('FieldRename.snake'));
      expect(FieldRename.kebab.toString(), equals('FieldRename.kebab'));
    });
  });

  group('Serializable annotation', () {
    test('creates with default values', () {
      const annotation = Serializable();

      expect(annotation.includeNullFields, isFalse);
      expect(annotation.fieldRename, equals(FieldRename.none));
    });

    test('creates with custom values', () {
      const annotation = Serializable(
        includeNullFields: true,
        fieldRename: FieldRename.snake,
      );

      expect(annotation.includeNullFields, isTrue);
      expect(annotation.fieldRename, equals(FieldRename.snake));
    });

    test('supports equality comparison', () {
      const annotation1 = Serializable(fieldRename: FieldRename.snake);
      const annotation2 = Serializable(fieldRename: FieldRename.snake);
      const annotation3 = Serializable(fieldRename: FieldRename.kebab);

      expect(annotation1, equals(annotation2));
      expect(annotation1, isNot(equals(annotation3)));
    });
  });
}
