/// Property-based tests for MySQL repository code structure consistency.
@Tags(['generator'])
library;

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:dddart_repository_mysql/src/generators/mysql_repository_generator.dart';
import 'package:source_gen/source_gen.dart';
import 'package:test/test.dart';

void main() {
  group('MySQL Repository Code Structure Property Tests', () {
    late MysqlRepositoryGenerator generator;

    setUp(() {
      generator = MysqlRepositoryGenerator();
    });

    tearDown(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });

    // **Feature: mysql-repository, Property 25: Repository interface consistency**
    // **Validates: Requirements 10.1, 10.4**
    group('Property 25: Repository interface consistency', () {
      test('should implement Repository<T> interface', () async {
        final library = await resolveSource(
          '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_repository_mysql/dddart_repository_mysql.dart';

@Serializable()
@GenerateMysqlRepository()
class Order extends AggregateRoot {
  Order({required this.total}) : super();
  final double total;
}
''',
          (resolver) async => (await resolver.findLibraryByName('test'))!,
        );

        final classElement = library.topLevelElements
            .whereType<ClassElement>()
            .firstWhere((e) => e.name == 'Order');

        final annotation = classElement.metadata.firstWhere(
          (a) =>
              a.element is ConstructorElement &&
              (a.element! as ConstructorElement).enclosingElement.name ==
                  'GenerateMysqlRepository',
        );

        final generated = generator.generateForAnnotatedElement(
          classElement,
          ConstantReader(annotation.computeConstantValue()),
          _mockBuildStep(),
        );

        // Verify Repository interface implementation
        expect(generated, contains('implements Repository<Order>'));
        expect(generated, contains('Future<Order> getById(UuidValue id)'));
        expect(generated, contains('Future<void> save(Order aggregate)'));
        expect(generated, contains('Future<void> deleteById(UuidValue id)'));
      });

      test('should use same interface as SQLite repositories', () async {
        final library = await resolveSource(
          '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_repository_mysql/dddart_repository_mysql.dart';

@Serializable()
@GenerateMysqlRepository()
class Product extends AggregateRoot {
  Product({required this.name}) : super();
  final String name;
}
''',
          (resolver) async => (await resolver.findLibraryByName('test'))!,
        );

        final classElement = library.topLevelElements
            .whereType<ClassElement>()
            .firstWhere((e) => e.name == 'Product');

        final annotation = classElement.metadata.firstWhere(
          (a) =>
              a.element is ConstructorElement &&
              (a.element! as ConstructorElement).enclosingElement.name ==
                  'GenerateMysqlRepository',
        );

        final generated = generator.generateForAnnotatedElement(
          classElement,
          ConstantReader(annotation.computeConstantValue()),
          _mockBuildStep(),
        );

        // Verify standard Repository methods
        expect(generated, contains('@override'));
        expect(generated, contains('Future<Product> getById'));
        expect(generated, contains('Future<void> save'));
        expect(generated, contains('Future<void> deleteById'));
      });
    });

    // **Feature: mysql-repository, Property 26: Code structure consistency**
    // **Validates: Requirements 10.3**
    group('Property 26: Code structure consistency', () {
      test('should follow same naming conventions as SQLite', () async {
        final library = await resolveSource(
          '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_repository_mysql/dddart_repository_mysql.dart';

@Serializable()
class Item extends Entity {
  Item({required this.name}) : super();
  final String name;
}

@Serializable()
@GenerateMysqlRepository()
class Container extends AggregateRoot {
  Container({required this.items}) : super();
  final List<Item> items;
}
''',
          (resolver) async => (await resolver.findLibraryByName('test'))!,
        );

        final classElement = library.topLevelElements
            .whereType<ClassElement>()
            .firstWhere((e) => e.name == 'Container');

        final annotation = classElement.metadata.firstWhere(
          (a) =>
              a.element is ConstructorElement &&
              (a.element! as ConstructorElement).enclosingElement.name ==
                  'GenerateMysqlRepository',
        );

        final generated = generator.generateForAnnotatedElement(
          classElement,
          ConstantReader(annotation.computeConstantValue()),
          _mockBuildStep(),
        );

        // Verify naming conventions match SQLite pattern
        expect(generated, contains('class ContainerMysqlRepository'));
        expect(generated, contains('MysqlConnection _connection'));
        expect(generated, contains('MysqlDialect'));
        expect(generated, contains('ContainerJsonSerializer'));

        // Verify helper method naming
        expect(generated, contains('_saveItem'));
        expect(generated, contains('_loadItem'));
        expect(generated, contains('_flattenForTable'));
        expect(generated, contains('_rowToJson'));
        expect(generated, contains('_encodeValue'));
        expect(generated, contains('_decodeValue'));
        expect(generated, contains('_mapMysqlException'));
      });

      test('should have same method structure as SQLite repositories',
          () async {
        final library = await resolveSource(
          '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_repository_mysql/dddart_repository_mysql.dart';

@Serializable()
@GenerateMysqlRepository()
class SimpleEntity extends AggregateRoot {
  SimpleEntity({required this.value}) : super();
  final String value;
}
''',
          (resolver) async => (await resolver.findLibraryByName('test'))!,
        );

        final classElement = library.topLevelElements
            .whereType<ClassElement>()
            .firstWhere((e) => e.name == 'SimpleEntity');

        final annotation = classElement.metadata.firstWhere(
          (a) =>
              a.element is ConstructorElement &&
              (a.element! as ConstructorElement).enclosingElement.name ==
                  'GenerateMysqlRepository',
        );

        final generated = generator.generateForAnnotatedElement(
          classElement,
          ConstantReader(annotation.computeConstantValue()),
          _mockBuildStep(),
        );

        // Verify method structure
        expect(generated, contains('Future<void> createTables()'));
        expect(generated, contains('Future<SimpleEntity> getById'));
        expect(generated, contains('Future<void> save(SimpleEntity'));
        expect(generated, contains('Future<void> deleteById'));

        // Verify transaction usage
        expect(generated, contains('_connection.transaction'));

        // Verify error handling
        expect(generated, contains('on RepositoryException'));
        expect(generated, contains('catch (e)'));
        expect(generated, contains('_mapMysqlException'));
      });

      test('should generate abstract base class for custom interfaces',
          () async {
        final library = await resolveSource(
          '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_repository_mysql/dddart_repository_mysql.dart';

abstract class CustomOrderRepository implements Repository<Order> {
  Future<List<Order>> findByCustomer(String customerId);
}

@Serializable()
@GenerateMysqlRepository(implements: CustomOrderRepository)
class Order extends AggregateRoot {
  Order({required this.customerId}) : super();
  final String customerId;
}
''',
          (resolver) async => (await resolver.findLibraryByName('test'))!,
        );

        final classElement = library.topLevelElements
            .whereType<ClassElement>()
            .firstWhere((e) => e.name == 'Order');

        final annotation = classElement.metadata.firstWhere(
          (a) =>
              a.element is ConstructorElement &&
              (a.element! as ConstructorElement).enclosingElement.name ==
                  'GenerateMysqlRepository',
        );

        final generated = generator.generateForAnnotatedElement(
          classElement,
          ConstantReader(annotation.computeConstantValue()),
          _mockBuildStep(),
        );

        // Verify abstract base class generation
        expect(generated, contains('abstract class OrderMysqlRepositoryBase'));
        expect(generated, contains('implements CustomOrderRepository'));

        // Verify protected members for subclass access
        expect(generated, contains('final MysqlConnection _connection'));
        expect(generated, contains('final _dialect = MysqlDialect()'));
        expect(generated, contains('final _serializer'));

        // Verify abstract method declaration
        expect(
          generated,
          contains('Future<List<Order>> findByCustomer(String customerId)'),
        );
      });

      test('should use MySQL-specific dialect and connection', () async {
        final library = await resolveSource(
          '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_repository_mysql/dddart_repository_mysql.dart';

@Serializable()
@GenerateMysqlRepository()
class TestAggregate extends AggregateRoot {
  TestAggregate({required this.name}) : super();
  final String name;
}
''',
          (resolver) async => (await resolver.findLibraryByName('test'))!,
        );

        final classElement = library.topLevelElements
            .whereType<ClassElement>()
            .firstWhere((e) => e.name == 'TestAggregate');

        final annotation = classElement.metadata.firstWhere(
          (a) =>
              a.element is ConstructorElement &&
              (a.element! as ConstructorElement).enclosingElement.name ==
                  'GenerateMysqlRepository',
        );

        final generated = generator.generateForAnnotatedElement(
          classElement,
          ConstantReader(annotation.computeConstantValue()),
          _mockBuildStep(),
        );

        // Verify MySQL-specific types are used
        expect(generated, contains('MysqlConnection'));
        expect(generated, contains('MysqlDialect'));
        expect(generated, isNot(contains('SqliteConnection')));
        expect(generated, isNot(contains('SqliteDialect')));

        // Verify MySQL-specific SQL syntax
        expect(generated, contains('ON DUPLICATE KEY UPDATE'));
        expect(generated, contains('ENGINE=InnoDB'));
        expect(generated, contains('DEFAULT CHARSET=utf8mb4'));
      });
    });

    group('Error Handling Consistency', () {
      test('should use RepositoryException types consistently', () async {
        final library = await resolveSource(
          '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_repository_mysql/dddart_repository_mysql.dart';

@Serializable()
@GenerateMysqlRepository()
class Entity1 extends AggregateRoot {
  Entity1({required this.name}) : super();
  final String name;
}
''',
          (resolver) async => (await resolver.findLibraryByName('test'))!,
        );

        final classElement = library.topLevelElements
            .whereType<ClassElement>()
            .firstWhere((e) => e.name == 'Entity1');

        final annotation = classElement.metadata.firstWhere(
          (a) =>
              a.element is ConstructorElement &&
              (a.element! as ConstructorElement).enclosingElement.name ==
                  'GenerateMysqlRepository',
        );

        final generated = generator.generateForAnnotatedElement(
          classElement,
          ConstantReader(annotation.computeConstantValue()),
          _mockBuildStep(),
        );

        // Verify RepositoryException usage
        expect(generated, contains('RepositoryException'));
        expect(generated, contains('RepositoryExceptionType.notFound'));
        expect(generated, contains('RepositoryExceptionType.duplicate'));
        expect(generated, contains('RepositoryExceptionType.connection'));
        expect(generated, contains('RepositoryExceptionType.timeout'));
        expect(generated, contains('RepositoryExceptionType.unknown'));
      });
    });
  });
}

/// Creates a stub BuildStep for testing.
/// Note: BuildStep is sealed, so we use a workaround for testing.
/// The generator doesn't actually use the BuildStep in these tests.
BuildStep _mockBuildStep() {
  // Since BuildStep is sealed, we can't implement it.
  // We use a stub that will throw if actually used.
  // ignore: subtype_of_sealed_class
  return _StubBuildStep();
}

// ignore: subtype_of_sealed_class
class _StubBuildStep implements BuildStep {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
        'BuildStep method called in test - this should not happen',
      );
}
