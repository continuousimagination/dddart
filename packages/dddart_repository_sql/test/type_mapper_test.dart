import 'package:dddart/dddart.dart';
import 'package:dddart_repository_sql/dddart_repository_sql.dart';
import 'package:test/test.dart';

/// Mock SQL dialect for testing.
class MockDialect implements SqlDialect {
  const MockDialect();

  @override
  String get uuidColumnType => 'BLOB';

  @override
  String get textColumnType => 'TEXT';

  @override
  String get integerColumnType => 'INTEGER';

  @override
  String get realColumnType => 'REAL';

  @override
  String get booleanColumnType => 'INTEGER';

  @override
  String get dateTimeColumnType => 'INTEGER';

  @override
  Object? encodeUuid(UuidValue uuid) => throw UnimplementedError();

  @override
  UuidValue decodeUuid(Object? value) => throw UnimplementedError();

  @override
  Object? encodeDateTime(DateTime dateTime) => throw UnimplementedError();

  @override
  DateTime decodeDateTime(Object? value) => throw UnimplementedError();

  @override
  String createTableIfNotExists(TableDefinition table) =>
      throw UnimplementedError();

  @override
  String insertOrReplace(String tableName, List<String> columns) =>
      throw UnimplementedError();

  @override
  String selectWithJoins(
    TableDefinition rootTable,
    List<JoinClause> joins,
  ) =>
      throw UnimplementedError();

  @override
  String delete(String tableName) => throw UnimplementedError();
}

void main() {
  group('TypeMapper', () {
    late TypeMapper mapper;
    late SqlDialect dialect;

    setUp(() {
      mapper = const TypeMapper();
      dialect = const MockDialect();
    });

    group('getSqlType', () {
      test('should return dialect text type for String', () {
        expect(mapper.getSqlType('String', dialect), equals('TEXT'));
      });

      test('should return dialect integer type for int', () {
        expect(mapper.getSqlType('int', dialect), equals('INTEGER'));
      });

      test('should return dialect real type for double', () {
        expect(mapper.getSqlType('double', dialect), equals('REAL'));
      });

      test('should return dialect boolean type for bool', () {
        expect(mapper.getSqlType('bool', dialect), equals('INTEGER'));
      });

      test('should return dialect datetime type for DateTime', () {
        expect(mapper.getSqlType('DateTime', dialect), equals('INTEGER'));
      });

      test('should return dialect uuid type for UuidValue', () {
        expect(mapper.getSqlType('UuidValue', dialect), equals('BLOB'));
      });

      test('should return null for custom class types', () {
        expect(mapper.getSqlType('CustomClass', dialect), isNull);
        expect(mapper.getSqlType('Order', dialect), isNull);
        expect(mapper.getSqlType('Money', dialect), isNull);
      });

      test('should return null for List types', () {
        expect(mapper.getSqlType('List<String>', dialect), isNull);
        expect(mapper.getSqlType('List<int>', dialect), isNull);
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
