/// Property-based tests for primitive collection schema generation.
@Tags(['generator'])
library;

import 'package:analyzer/dart/element/element.dart' hide ElementKind;
import 'package:build_test/build_test.dart';
import 'package:dddart/dddart.dart';
import 'package:dddart_repository_sql/src/dialect/sql_dialect.dart';
import 'package:dddart_repository_sql/src/schema/collection_analyzer.dart';
import 'package:dddart_repository_sql/src/schema/schema_generator.dart';
import 'package:dddart_repository_sql/src/schema/table_definition.dart';
import 'package:test/test.dart';

void main() {
  group('Primitive Collection Schema Generation Property Tests', () {
    late SchemaGenerator generator;
    late MockSqlDialect dialect;

    setUp(() {
      dialect = MockSqlDialect();
      generator = SchemaGenerator(dialect);
    });

    // **Feature: sql-collection-support, Property 14: Schema generation for primitive lists**
    // **Validates: Requirements 9.1**
    group('Property 14: Schema generation for primitive lists', () {
      test(
        'should generate junction table with entity_id, position, and value columns for List<int>',
        () async {
          final library = await resolveSource(
            '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

@Serializable()
class TestAggregate extends AggregateRoot {
  TestAggregate({required this.favoriteNumbers}) : super();
  final List<int> favoriteNumbers;
}
''',
            (resolver) async => (await resolver.findLibraryByName('test'))!,
          );

          final classElement = library.topLevelElements
              .whereType<ClassElement>()
              .firstWhere((e) => e.name == 'TestAggregate');

          final field = classElement.fields
              .firstWhere((f) => f.name == 'favoriteNumbers');

          const analyzer = CollectionAnalyzer();
          final collectionInfo = analyzer.analyzeCollection(field);

          expect(collectionInfo, isNotNull);
          expect(collectionInfo!.kind, equals(CollectionKind.list));
          expect(collectionInfo.elementKind, equals(ElementKind.primitive));

          final tableDefinition = generator.generatePrimitiveCollectionTable(
            parentTable: 'test_aggregate',
            fieldName: 'favoriteNumbers',
            collectionInfo: collectionInfo,
          );

          // Verify table name follows convention
          expect(
            tableDefinition.tableName,
            equals('test_aggregate_favoriteNumbers_items'),
          );

          // Verify columns
          final columnNames =
              tableDefinition.columns.map((c) => c.name).toList();
          expect(columnNames, contains('test_aggregate_id'));
          expect(columnNames, contains('position'));
          expect(columnNames, contains('value'));

          // Verify position column is INTEGER
          final positionColumn =
              tableDefinition.columns.firstWhere((c) => c.name == 'position');
          expect(positionColumn.sqlType, equals('INTEGER'));
          expect(positionColumn.isNullable, isFalse);

          // Verify value column is INTEGER (for int)
          final valueColumn =
              tableDefinition.columns.firstWhere((c) => c.name == 'value');
          expect(valueColumn.sqlType, equals('INTEGER'));
          expect(valueColumn.isNullable, isFalse);

          // Verify foreign key with CASCADE DELETE
          expect(tableDefinition.foreignKeys, hasLength(1));
          final fk = tableDefinition.foreignKeys.first;
          expect(fk.columnName, equals('test_aggregate_id'));
          expect(fk.referencedTable, equals('test_aggregate'));
          expect(fk.referencedColumn, equals('id'));
          expect(fk.onDelete, equals(CascadeAction.cascade));
        },
      );

      test(
        'should generate junction table for List<String> with TEXT value column',
        () async {
          final library = await resolveSource(
            '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

@Serializable()
class TestAggregate extends AggregateRoot {
  TestAggregate({required this.tags}) : super();
  final List<String> tags;
}
''',
            (resolver) async => (await resolver.findLibraryByName('test'))!,
          );

          final classElement = library.topLevelElements
              .whereType<ClassElement>()
              .firstWhere((e) => e.name == 'TestAggregate');

          final field = classElement.fields.firstWhere((f) => f.name == 'tags');

          const analyzer = CollectionAnalyzer();
          final collectionInfo = analyzer.analyzeCollection(field);

          expect(collectionInfo, isNotNull);

          final tableDefinition = generator.generatePrimitiveCollectionTable(
            parentTable: 'test_aggregate',
            fieldName: 'tags',
            collectionInfo: collectionInfo!,
          );

          // Verify value column is TEXT (for String)
          final valueColumn =
              tableDefinition.columns.firstWhere((c) => c.name == 'value');
          expect(valueColumn.sqlType, equals('TEXT'));
          expect(valueColumn.dartType, equals('String'));
        },
      );

      test(
        'should generate junction table for List<double> with REAL value column',
        () async {
          final library = await resolveSource(
            '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

@Serializable()
class TestAggregate extends AggregateRoot {
  TestAggregate({required this.measurements}) : super();
  final List<double> measurements;
}
''',
            (resolver) async => (await resolver.findLibraryByName('test'))!,
          );

          final classElement = library.topLevelElements
              .whereType<ClassElement>()
              .firstWhere((e) => e.name == 'TestAggregate');

          final field =
              classElement.fields.firstWhere((f) => f.name == 'measurements');

          const analyzer = CollectionAnalyzer();
          final collectionInfo = analyzer.analyzeCollection(field);

          expect(collectionInfo, isNotNull);

          final tableDefinition = generator.generatePrimitiveCollectionTable(
            parentTable: 'test_aggregate',
            fieldName: 'measurements',
            collectionInfo: collectionInfo!,
          );

          // Verify value column is REAL (for double)
          final valueColumn =
              tableDefinition.columns.firstWhere((c) => c.name == 'value');
          expect(valueColumn.sqlType, equals('REAL'));
          expect(valueColumn.dartType, equals('double'));
        },
      );

      test(
        'should generate junction table for List<bool> with INTEGER value column',
        () async {
          final library = await resolveSource(
            '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

@Serializable()
class TestAggregate extends AggregateRoot {
  TestAggregate({required this.flags}) : super();
  final List<bool> flags;
}
''',
            (resolver) async => (await resolver.findLibraryByName('test'))!,
          );

          final classElement = library.topLevelElements
              .whereType<ClassElement>()
              .firstWhere((e) => e.name == 'TestAggregate');

          final field =
              classElement.fields.firstWhere((f) => f.name == 'flags');

          const analyzer = CollectionAnalyzer();
          final collectionInfo = analyzer.analyzeCollection(field);

          expect(collectionInfo, isNotNull);

          final tableDefinition = generator.generatePrimitiveCollectionTable(
            parentTable: 'test_aggregate',
            fieldName: 'flags',
            collectionInfo: collectionInfo!,
          );

          // Verify value column is INTEGER (for bool)
          final valueColumn =
              tableDefinition.columns.firstWhere((c) => c.name == 'value');
          expect(valueColumn.sqlType, equals('INTEGER'));
          expect(valueColumn.dartType, equals('bool'));
        },
      );

      test(
        'should generate junction table for List<DateTime> with INTEGER value column',
        () async {
          final library = await resolveSource(
            '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

@Serializable()
class TestAggregate extends AggregateRoot {
  TestAggregate({required this.timestamps}) : super();
  final List<DateTime> timestamps;
}
''',
            (resolver) async => (await resolver.findLibraryByName('test'))!,
          );

          final classElement = library.topLevelElements
              .whereType<ClassElement>()
              .firstWhere((e) => e.name == 'TestAggregate');

          final field =
              classElement.fields.firstWhere((f) => f.name == 'timestamps');

          const analyzer = CollectionAnalyzer();
          final collectionInfo = analyzer.analyzeCollection(field);

          expect(collectionInfo, isNotNull);

          final tableDefinition = generator.generatePrimitiveCollectionTable(
            parentTable: 'test_aggregate',
            fieldName: 'timestamps',
            collectionInfo: collectionInfo!,
          );

          // Verify value column is INTEGER (for DateTime)
          final valueColumn =
              tableDefinition.columns.firstWhere((c) => c.name == 'value');
          expect(valueColumn.sqlType, equals('INTEGER'));
          expect(valueColumn.dartType, equals('DateTime'));
        },
      );

      test(
        'should generate junction table for List<UuidValue> with BLOB value column',
        () async {
          final library = await resolveSource(
            '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

@Serializable()
class TestAggregate extends AggregateRoot {
  TestAggregate({required this.relatedIds}) : super();
  final List<UuidValue> relatedIds;
}
''',
            (resolver) async => (await resolver.findLibraryByName('test'))!,
          );

          final classElement = library.topLevelElements
              .whereType<ClassElement>()
              .firstWhere((e) => e.name == 'TestAggregate');

          final field =
              classElement.fields.firstWhere((f) => f.name == 'relatedIds');

          const analyzer = CollectionAnalyzer();
          final collectionInfo = analyzer.analyzeCollection(field);

          expect(collectionInfo, isNotNull);

          final tableDefinition = generator.generatePrimitiveCollectionTable(
            parentTable: 'test_aggregate',
            fieldName: 'relatedIds',
            collectionInfo: collectionInfo!,
          );

          // Verify value column is BLOB (for UuidValue)
          final valueColumn =
              tableDefinition.columns.firstWhere((c) => c.name == 'value');
          expect(valueColumn.sqlType, equals('BLOB'));
          expect(valueColumn.dartType, equals('UuidValue'));
        },
      );
    });

    // **Feature: sql-collection-support, Property 15: Schema generation for primitive sets**
    // **Validates: Requirements 9.2**
    group('Property 15: Schema generation for primitive sets', () {
      test(
        'should generate junction table with entity_id and value columns (no position) for Set<int>',
        () async {
          final library = await resolveSource(
            '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

@Serializable()
class TestAggregate extends AggregateRoot {
  TestAggregate({required this.uniqueNumbers}) : super();
  final Set<int> uniqueNumbers;
}
''',
            (resolver) async => (await resolver.findLibraryByName('test'))!,
          );

          final classElement = library.topLevelElements
              .whereType<ClassElement>()
              .firstWhere((e) => e.name == 'TestAggregate');

          final field =
              classElement.fields.firstWhere((f) => f.name == 'uniqueNumbers');

          const analyzer = CollectionAnalyzer();
          final collectionInfo = analyzer.analyzeCollection(field);

          expect(collectionInfo, isNotNull);
          expect(collectionInfo!.kind, equals(CollectionKind.set));
          expect(collectionInfo.elementKind, equals(ElementKind.primitive));

          final tableDefinition = generator.generatePrimitiveCollectionTable(
            parentTable: 'test_aggregate',
            fieldName: 'uniqueNumbers',
            collectionInfo: collectionInfo,
          );

          // Verify table name follows convention
          expect(
            tableDefinition.tableName,
            equals('test_aggregate_uniqueNumbers_items'),
          );

          // Verify columns
          final columnNames =
              tableDefinition.columns.map((c) => c.name).toList();
          expect(columnNames, contains('test_aggregate_id'));
          expect(columnNames, contains('value'));
          // Should NOT have position column for sets
          expect(columnNames, isNot(contains('position')));

          // Verify value column is INTEGER (for int)
          final valueColumn =
              tableDefinition.columns.firstWhere((c) => c.name == 'value');
          expect(valueColumn.sqlType, equals('INTEGER'));
          expect(valueColumn.isNullable, isFalse);

          // Verify foreign key with CASCADE DELETE
          expect(tableDefinition.foreignKeys, hasLength(1));
          final fk = tableDefinition.foreignKeys.first;
          expect(fk.columnName, equals('test_aggregate_id'));
          expect(fk.referencedTable, equals('test_aggregate'));
          expect(fk.onDelete, equals(CascadeAction.cascade));
        },
      );

      test(
        'should generate junction table for Set<String> without position column',
        () async {
          final library = await resolveSource(
            '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

@Serializable()
class TestAggregate extends AggregateRoot {
  TestAggregate({required this.categories}) : super();
  final Set<String> categories;
}
''',
            (resolver) async => (await resolver.findLibraryByName('test'))!,
          );

          final classElement = library.topLevelElements
              .whereType<ClassElement>()
              .firstWhere((e) => e.name == 'TestAggregate');

          final field =
              classElement.fields.firstWhere((f) => f.name == 'categories');

          const analyzer = CollectionAnalyzer();
          final collectionInfo = analyzer.analyzeCollection(field);

          expect(collectionInfo, isNotNull);

          final tableDefinition = generator.generatePrimitiveCollectionTable(
            parentTable: 'test_aggregate',
            fieldName: 'categories',
            collectionInfo: collectionInfo!,
          );

          // Verify no position column
          final columnNames =
              tableDefinition.columns.map((c) => c.name).toList();
          expect(columnNames, isNot(contains('position')));

          // Verify value column is TEXT (for String)
          final valueColumn =
              tableDefinition.columns.firstWhere((c) => c.name == 'value');
          expect(valueColumn.sqlType, equals('TEXT'));
        },
      );

      test(
        'should generate junction table for Set<double> without position column',
        () async {
          final library = await resolveSource(
            '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

@Serializable()
class TestAggregate extends AggregateRoot {
  TestAggregate({required this.uniqueScores}) : super();
  final Set<double> uniqueScores;
}
''',
            (resolver) async => (await resolver.findLibraryByName('test'))!,
          );

          final classElement = library.topLevelElements
              .whereType<ClassElement>()
              .firstWhere((e) => e.name == 'TestAggregate');

          final field =
              classElement.fields.firstWhere((f) => f.name == 'uniqueScores');

          const analyzer = CollectionAnalyzer();
          final collectionInfo = analyzer.analyzeCollection(field);

          expect(collectionInfo, isNotNull);

          final tableDefinition = generator.generatePrimitiveCollectionTable(
            parentTable: 'test_aggregate',
            fieldName: 'uniqueScores',
            collectionInfo: collectionInfo!,
          );

          // Verify value column is REAL (for double)
          final valueColumn =
              tableDefinition.columns.firstWhere((c) => c.name == 'value');
          expect(valueColumn.sqlType, equals('REAL'));
        },
      );
    });

    // **Feature: sql-collection-support, Property 16: Schema generation for primitive maps**
    // **Validates: Requirements 9.3**
    group('Property 16: Schema generation for primitive maps', () {
      test(
        'should generate junction table with entity_id, map_key, and value columns for Map<String, int>',
        () async {
          final library = await resolveSource(
            '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

@Serializable()
class TestAggregate extends AggregateRoot {
  TestAggregate({required this.scoresByGame}) : super();
  final Map<String, int> scoresByGame;
}
''',
            (resolver) async => (await resolver.findLibraryByName('test'))!,
          );

          final classElement = library.topLevelElements
              .whereType<ClassElement>()
              .firstWhere((e) => e.name == 'TestAggregate');

          final field =
              classElement.fields.firstWhere((f) => f.name == 'scoresByGame');

          const analyzer = CollectionAnalyzer();
          final collectionInfo = analyzer.analyzeCollection(field);

          expect(collectionInfo, isNotNull);
          expect(collectionInfo!.kind, equals(CollectionKind.map));
          expect(collectionInfo.elementKind, equals(ElementKind.primitive));

          final tableDefinition = generator.generatePrimitiveCollectionTable(
            parentTable: 'test_aggregate',
            fieldName: 'scoresByGame',
            collectionInfo: collectionInfo,
          );

          // Verify table name follows convention
          expect(
            tableDefinition.tableName,
            equals('test_aggregate_scoresByGame_items'),
          );

          // Verify columns
          final columnNames =
              tableDefinition.columns.map((c) => c.name).toList();
          expect(columnNames, contains('test_aggregate_id'));
          expect(columnNames, contains('map_key'));
          expect(columnNames, contains('value'));
          // Should NOT have position column for maps
          expect(columnNames, isNot(contains('position')));

          // Verify map_key column is TEXT (for String key)
          final keyColumn =
              tableDefinition.columns.firstWhere((c) => c.name == 'map_key');
          expect(keyColumn.sqlType, equals('TEXT'));
          expect(keyColumn.dartType, equals('String'));
          expect(keyColumn.isNullable, isFalse);

          // Verify value column is INTEGER (for int value)
          final valueColumn =
              tableDefinition.columns.firstWhere((c) => c.name == 'value');
          expect(valueColumn.sqlType, equals('INTEGER'));
          expect(valueColumn.dartType, equals('int'));
          expect(valueColumn.isNullable, isFalse);

          // Verify foreign key with CASCADE DELETE
          expect(tableDefinition.foreignKeys, hasLength(1));
          final fk = tableDefinition.foreignKeys.first;
          expect(fk.columnName, equals('test_aggregate_id'));
          expect(fk.referencedTable, equals('test_aggregate'));
          expect(fk.onDelete, equals(CascadeAction.cascade));
        },
      );

      test(
        'should generate junction table for Map<int, String> with INTEGER key',
        () async {
          final library = await resolveSource(
            '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

@Serializable()
class TestAggregate extends AggregateRoot {
  TestAggregate({required this.namesByCode}) : super();
  final Map<int, String> namesByCode;
}
''',
            (resolver) async => (await resolver.findLibraryByName('test'))!,
          );

          final classElement = library.topLevelElements
              .whereType<ClassElement>()
              .firstWhere((e) => e.name == 'TestAggregate');

          final field =
              classElement.fields.firstWhere((f) => f.name == 'namesByCode');

          const analyzer = CollectionAnalyzer();
          final collectionInfo = analyzer.analyzeCollection(field);

          expect(collectionInfo, isNotNull);

          final tableDefinition = generator.generatePrimitiveCollectionTable(
            parentTable: 'test_aggregate',
            fieldName: 'namesByCode',
            collectionInfo: collectionInfo!,
          );

          // Verify map_key column is INTEGER (for int key)
          final keyColumn =
              tableDefinition.columns.firstWhere((c) => c.name == 'map_key');
          expect(keyColumn.sqlType, equals('INTEGER'));
          expect(keyColumn.dartType, equals('int'));

          // Verify value column is TEXT (for String value)
          final valueColumn =
              tableDefinition.columns.firstWhere((c) => c.name == 'value');
          expect(valueColumn.sqlType, equals('TEXT'));
          expect(valueColumn.dartType, equals('String'));
        },
      );

      test(
        'should generate junction table for Map<String, double> with REAL value',
        () async {
          final library = await resolveSource(
            '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

@Serializable()
class TestAggregate extends AggregateRoot {
  TestAggregate({required this.ratesByCountry}) : super();
  final Map<String, double> ratesByCountry;
}
''',
            (resolver) async => (await resolver.findLibraryByName('test'))!,
          );

          final classElement = library.topLevelElements
              .whereType<ClassElement>()
              .firstWhere((e) => e.name == 'TestAggregate');

          final field =
              classElement.fields.firstWhere((f) => f.name == 'ratesByCountry');

          const analyzer = CollectionAnalyzer();
          final collectionInfo = analyzer.analyzeCollection(field);

          expect(collectionInfo, isNotNull);

          final tableDefinition = generator.generatePrimitiveCollectionTable(
            parentTable: 'test_aggregate',
            fieldName: 'ratesByCountry',
            collectionInfo: collectionInfo!,
          );

          // Verify map_key column is TEXT (for String key)
          final keyColumn =
              tableDefinition.columns.firstWhere((c) => c.name == 'map_key');
          expect(keyColumn.sqlType, equals('TEXT'));

          // Verify value column is REAL (for double value)
          final valueColumn =
              tableDefinition.columns.firstWhere((c) => c.name == 'value');
          expect(valueColumn.sqlType, equals('REAL'));
          expect(valueColumn.dartType, equals('double'));
        },
      );

      test(
        'should generate junction table for Map<int, bool> with INTEGER value',
        () async {
          final library = await resolveSource(
            '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

@Serializable()
class TestAggregate extends AggregateRoot {
  TestAggregate({required this.flagsById}) : super();
  final Map<int, bool> flagsById;
}
''',
            (resolver) async => (await resolver.findLibraryByName('test'))!,
          );

          final classElement = library.topLevelElements
              .whereType<ClassElement>()
              .firstWhere((e) => e.name == 'TestAggregate');

          final field =
              classElement.fields.firstWhere((f) => f.name == 'flagsById');

          const analyzer = CollectionAnalyzer();
          final collectionInfo = analyzer.analyzeCollection(field);

          expect(collectionInfo, isNotNull);

          final tableDefinition = generator.generatePrimitiveCollectionTable(
            parentTable: 'test_aggregate',
            fieldName: 'flagsById',
            collectionInfo: collectionInfo!,
          );

          // Verify value column is INTEGER (for bool value)
          final valueColumn =
              tableDefinition.columns.firstWhere((c) => c.name == 'value');
          expect(valueColumn.sqlType, equals('INTEGER'));
          expect(valueColumn.dartType, equals('bool'));
        },
      );
    });
  });
}

/// Mock SQL dialect for testing.
class MockSqlDialect implements SqlDialect {
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
  Object? encodeUuid(UuidValue uuid) => uuid.uuid;

  @override
  UuidValue decodeUuid(Object? value) => UuidValue.fromString(value! as String);

  @override
  Object? encodeDateTime(DateTime dateTime) => dateTime.millisecondsSinceEpoch;

  @override
  DateTime decodeDateTime(Object? value) =>
      DateTime.fromMillisecondsSinceEpoch(value! as int);

  @override
  String createTableIfNotExists(TableDefinition table) => '';

  @override
  String insertOrReplace(String tableName, List<String> columns) => '';

  @override
  String selectWithJoins(TableDefinition rootTable, List<JoinClause> joins) =>
      '';

  @override
  String delete(String tableName) => '';
}
