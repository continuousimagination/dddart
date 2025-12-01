/// Property-based tests for MySQL schema generation.
@Tags(['generator'])
library;

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:dddart_repository_mysql/src/generators/mysql_repository_generator.dart';
import 'package:source_gen/source_gen.dart';
import 'package:test/test.dart';

void main() {
  group('MySQL Schema Generation Property Tests', () {
    late MysqlRepositoryGenerator generator;

    setUp(() {
      generator = MysqlRepositoryGenerator();
    });

    tearDown(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });

    // **Feature: mysql-repository, Property 10: Schema generation completeness**
    // **Validates: Requirements 4.1**
    group('Property 10: Schema generation completeness', () {
      test('should generate tables for aggregate root and all entities',
          () async {
        final library = await resolveSource(
          '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_repository_mysql/dddart_repository_mysql.dart';

@Serializable()
class OrderItem extends Entity {
  OrderItem({required this.productId}) : super();
  final UuidValue productId;
}

@Serializable()
class Payment extends Entity {
  Payment({required this.amount}) : super();
  final double amount;
}

@Serializable()
@GenerateMysqlRepository()
class Order extends AggregateRoot {
  Order({required this.items, required this.payments}) : super();
  final List<OrderItem> items;
  final List<Payment> payments;
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

        // Verify all tables are created
        expect(generated, contains('CREATE TABLE IF NOT EXISTS order'));
        expect(generated, contains('CREATE TABLE IF NOT EXISTS order_item'));
        expect(generated, contains('CREATE TABLE IF NOT EXISTS payment'));
      });
    });

    // **Feature: mysql-repository, Property 11: Schema creation idempotence**
    // **Validates: Requirements 4.2**
    group('Property 11: Schema creation idempotence', () {
      test('should use CREATE TABLE IF NOT EXISTS for all tables', () async {
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

        // Count occurrences of CREATE TABLE
        final createTableCount =
            'CREATE TABLE IF NOT EXISTS'.allMatches(generated).length;

        // Should have at least 2 tables (aggregate + entity)
        expect(createTableCount, greaterThanOrEqualTo(2));

        // Verify no plain CREATE TABLE (without IF NOT EXISTS)
        expect(
          generated,
          isNot(contains(RegExp('CREATE TABLE(?! IF NOT EXISTS)'))),
        );
      });
    });

    // **Feature: mysql-repository, Property 12: Entity foreign key constraints**
    // **Validates: Requirements 4.3**
    group('Property 12: Entity foreign key constraints', () {
      test('should add CASCADE foreign keys from entities to aggregate',
          () async {
        final library = await resolveSource(
          '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_repository_mysql/dddart_repository_mysql.dart';

@Serializable()
class LineItem extends Entity {
  LineItem({required this.sku}) : super();
  final String sku;
}

@Serializable()
@GenerateMysqlRepository()
class Invoice extends AggregateRoot {
  Invoice({required this.lineItems}) : super();
  final List<LineItem> lineItems;
}
''',
          (resolver) async => (await resolver.findLibraryByName('test'))!,
        );

        final classElement = library.topLevelElements
            .whereType<ClassElement>()
            .firstWhere((e) => e.name == 'Invoice');

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

        // Verify foreign key with CASCADE
        expect(generated, contains('FOREIGN KEY'));
        expect(generated, contains('REFERENCES invoice'));
        expect(generated, contains('ON DELETE CASCADE'));
      });
    });

    // **Feature: mysql-repository, Property 13: Value object embedding**
    // **Validates: Requirements 4.4, 6.1**
    group('Property 13: Value object embedding', () {
      test('should embed value object fields with prefixed columns', () async {
        final library = await resolveSource(
          '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_repository_mysql/dddart_repository_mysql.dart';

@Serializable()
class Address extends Value {
  const Address({required this.street, required this.city});
  final String street;
  final String city;
}

@Serializable()
@GenerateMysqlRepository()
class Customer extends AggregateRoot {
  Customer({required this.shippingAddress}) : super();
  final Address shippingAddress;
}
''',
          (resolver) async => (await resolver.findLibraryByName('test'))!,
        );

        final classElement = library.topLevelElements
            .whereType<ClassElement>()
            .firstWhere((e) => e.name == 'Customer');

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

        // Value objects should NOT have separate tables
        expect(
          generated,
          isNot(contains('CREATE TABLE IF NOT EXISTS address')),
        );

        // Should have flattening logic for value objects
        expect(generated, contains('_flattenForTable'));
        expect(generated, contains('_rowToJson'));
      });
    });

    // **Feature: mysql-repository, Property 14: Nullable value object handling**
    // **Validates: Requirements 6.2**
    group('Property 14: Nullable value object handling', () {
      test('should handle nullable value objects correctly', () async {
        final library = await resolveSource(
          '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_repository_mysql/dddart_repository_mysql.dart';

@Serializable()
class Notes extends Value {
  const Notes({required this.text});
  final String text;
}

@Serializable()
@GenerateMysqlRepository()
class Task extends AggregateRoot {
  Task({this.notes}) : super();
  final Notes? notes;
}
''',
          (resolver) async => (await resolver.findLibraryByName('test'))!,
        );

        final classElement = library.topLevelElements
            .whereType<ClassElement>()
            .firstWhere((e) => e.name == 'Task');

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

        // Should have logic to handle null value objects
        expect(generated, contains('allNull'));
        expect(generated, contains('_rowToJson'));
      });
    });

    // **Feature: mysql-repository, Property 15: Non-nullable value object handling**
    // **Validates: Requirements 6.3**
    group('Property 15: Non-nullable value object handling', () {
      test('should handle non-nullable value objects correctly', () async {
        final library = await resolveSource(
          '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_repository_mysql/dddart_repository_mysql.dart';

@Serializable()
class Price extends Value {
  const Price({required this.amount, required this.currency});
  final double amount;
  final String currency;
}

@Serializable()
@GenerateMysqlRepository()
class Product extends AggregateRoot {
  Product({required this.price}) : super();
  final Price price;
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

        // Should have flattening logic
        expect(generated, contains('_flattenForTable'));
        expect(generated, contains('_rowToJson'));
      });
    });

    group('MySQL-Specific Schema Features', () {
      test('should use InnoDB engine and utf8mb4 charset', () async {
        final library = await resolveSource(
          '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_repository_mysql/dddart_repository_mysql.dart';

@Serializable()
@GenerateMysqlRepository()
class SimpleAggregate extends AggregateRoot {
  SimpleAggregate({required this.name}) : super();
  final String name;
}
''',
          (resolver) async => (await resolver.findLibraryByName('test'))!,
        );

        final classElement = library.topLevelElements
            .whereType<ClassElement>()
            .firstWhere((e) => e.name == 'SimpleAggregate');

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

        // Verify MySQL-specific features
        expect(generated, contains('ENGINE=InnoDB'));
        expect(generated, contains('DEFAULT CHARSET=utf8mb4'));
      });

      test('should use BINARY(16) for UUID columns', () async {
        final library = await resolveSource(
          '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_repository_mysql/dddart_repository_mysql.dart';

@Serializable()
@GenerateMysqlRepository()
class Entity1 extends AggregateRoot {
  Entity1({required this.referenceId}) : super();
  final UuidValue referenceId;
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

        // Verify BINARY(16) is used for UUIDs
        expect(generated, contains('BINARY(16)'));
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
