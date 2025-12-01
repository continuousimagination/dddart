import 'package:dddart_repository_sql/src/schema/type_mapper.dart';
import 'package:test/test.dart';

void main() {
  group('TypeMapper', () {
    late TypeMapper mapper;

    setUp(() {
      mapper = const TypeMapper();
    });

    group('getSqlType', () {
      test('should return TEXT for String type', () {
        expect(mapper.getSqlType('String'), equals('TEXT'));
      });

      test('should return INTEGER for int type', () {
        expect(mapper.getSqlType('int'), equals('INTEGER'));
      });

      test('should return REAL for double type', () {
        expect(mapper.getSqlType('double'), equals('REAL'));
      });

      test('should return INTEGER for bool type', () {
        expect(mapper.getSqlType('bool'), equals('INTEGER'));
      });

      test('should return INTEGER for DateTime type', () {
        expect(mapper.getSqlType('DateTime'), equals('INTEGER'));
      });

      test('should return BLOB for UuidValue type', () {
        expect(mapper.getSqlType('UuidValue'), equals('BLOB'));
      });

      test('should return null for custom class types', () {
        expect(mapper.getSqlType('CustomClass'), isNull);
        expect(mapper.getSqlType('Order'), isNull);
        expect(mapper.getSqlType('Money'), isNull);
      });

      test('should return null for List types', () {
        expect(mapper.getSqlType('List<String>'), isNull);
        expect(mapper.getSqlType('List<int>'), isNull);
      });
    });

    group('isNullable', () {
      test('should return true for nullable types', () {
        expect(mapper.isNullable('String?'), isTrue);
        expect(mapper.isNullable('int?'), isTrue);
        expect(mapper.isNullable('double?'), isTrue);
        expect(mapper.isNullable('bool?'), isTrue);
        expect(mapper.isNullable('DateTime?'), isTrue);
        expect(mapper.isNullable('UuidValue?'), isTrue);
        expect(mapper.isNullable('CustomClass?'), isTrue);
      });

      test('should return false for non-nullable types', () {
        expect(mapper.isNullable('String'), isFalse);
        expect(mapper.isNullable('int'), isFalse);
        expect(mapper.isNullable('double'), isFalse);
        expect(mapper.isNullable('bool'), isFalse);
        expect(mapper.isNullable('DateTime'), isFalse);
        expect(mapper.isNullable('UuidValue'), isFalse);
        expect(mapper.isNullable('CustomClass'), isFalse);
      });
    });

    group('removeNullable', () {
      test('should remove nullable marker from types', () {
        expect(mapper.removeNullable('String?'), equals('String'));
        expect(mapper.removeNullable('int?'), equals('int'));
        expect(mapper.removeNullable('double?'), equals('double'));
        expect(mapper.removeNullable('bool?'), equals('bool'));
        expect(mapper.removeNullable('DateTime?'), equals('DateTime'));
        expect(mapper.removeNullable('UuidValue?'), equals('UuidValue'));
        expect(mapper.removeNullable('CustomClass?'), equals('CustomClass'));
      });

      test('should return type unchanged if not nullable', () {
        expect(mapper.removeNullable('String'), equals('String'));
        expect(mapper.removeNullable('int'), equals('int'));
        expect(mapper.removeNullable('double'), equals('double'));
        expect(mapper.removeNullable('bool'), equals('bool'));
        expect(mapper.removeNullable('DateTime'), equals('DateTime'));
        expect(mapper.removeNullable('UuidValue'), equals('UuidValue'));
        expect(mapper.removeNullable('CustomClass'), equals('CustomClass'));
      });
    });
  });
}
