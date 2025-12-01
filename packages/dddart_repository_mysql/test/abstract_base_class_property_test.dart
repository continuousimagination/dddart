/// Property-based tests for abstract base class generation.
@Tags(['generator'])
library;

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:dddart_repository_mysql/src/generators/mysql_repository_generator.dart';
import 'package:source_gen/source_gen.dart';
import 'package:test/test.dart';

void main() {
  group('Abstract Base Class Generation Property Tests', () {
    late MysqlRepositoryGenerator generator;

    setUp(() {
      generator = MysqlRepositoryGenerator();
    });

    tearDown(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });

    // **Feature: mysql-repository, Property 23: Abstract base class generation**
    // **Validates: Requirements 8.1, 8.2**
    group('Property 23: Abstract base class generation', () {
      test(
          'should generate abstract base class when custom interface is specified',
          () async {
        final library = await resolveSource(
          '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_repository_mysql/dddart_repository_mysql.dart';

abstract class CustomOrderRepository implements Repository<Order> {
  Future<List<Order>> findByStatus(String status);
}

@Serializable()
@GenerateMysqlRepository(implements: CustomOrderRepository)
class Order extends AggregateRoot {
  Order({required this.status}) : super();
  final String status;
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

        // Verify abstract base class is generated
        expect(generated, contains('abstract class OrderMysqlRepositoryBase'));
        expect(generated, contains('implements CustomOrderRepository'));

        // Verify it does NOT generate a concrete class
        expect(
          generated,
          isNot(contains('class OrderMysqlRepository implements')),
        );

        // Verify abstract method declaration
        expect(
          generated,
          contains('Future<List<Order>> findByStatus(String status)'),
        );
      });

      test('should expose protected members in abstract base class', () async {
        final library = await resolveSource(
          '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_repository_mysql/dddart_repository_mysql.dart';

abstract class CustomProductRepository implements Repository<Product> {
  Future<List<Product>> findByCategory(String category);
}

@Serializable()
@GenerateMysqlRepository(implements: CustomProductRepository)
class Product extends AggregateRoot {
  Product({required this.category}) : super();
  final String category;
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

        // Verify protected connection member
        expect(generated, contains('final MysqlConnection _connection'));

        // Verify protected dialect member
        expect(generated, contains('final _dialect = MysqlDialect()'));

        // Verify protected serializer member
        expect(generated, contains('final _serializer'));
        expect(generated, contains('ProductJsonSerializer'));

        // Verify tableName getter is accessible
        expect(generated, contains('String get tableName'));
      });

      test(
          'should implement standard Repository methods in abstract base class',
          () async {
        final library = await resolveSource(
          '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_repository_mysql/dddart_repository_mysql.dart';

abstract class CustomCustomerRepository implements Repository<Customer> {
  Future<List<Customer>> findByEmail(String email);
}

@Serializable()
@GenerateMysqlRepository(implements: CustomCustomerRepository)
class Customer extends AggregateRoot {
  Customer({required this.email}) : super();
  final String email;
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

        // Verify standard Repository methods are implemented (not abstract)
        expect(generated, contains('Future<void> createTables()'));
        expect(generated, contains('Future<Customer> getById(UuidValue id)'));
        expect(generated, contains('Future<void> save(Customer aggregate)'));
        expect(
          generated,
          contains('Future<void> deleteById(UuidValue id)'),
        );

        // Verify these are NOT abstract (they have implementations)
        expect(generated, isNot(contains('Future<void> createTables();')));
        expect(
          generated,
          isNot(contains('Future<Customer> getById(UuidValue id);')),
        );
      });

      test('should generate concrete class when no custom interface specified',
          () async {
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

        // Verify concrete class is generated (not abstract)
        expect(
          generated,
          contains('class SimpleAggregateMysqlRepository'),
        );
        expect(
          generated,
          isNot(contains('abstract class SimpleAggregateMysqlRepository')),
        );

        // Verify it implements Repository directly
        expect(
          generated,
          contains('implements Repository<SimpleAggregate>'),
        );
      });

      test('should handle custom interface with multiple custom methods',
          () async {
        final library = await resolveSource(
          '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_repository_mysql/dddart_repository_mysql.dart';

abstract class ComplexRepository implements Repository<ComplexAggregate> {
  Future<List<ComplexAggregate>> findByStatus(String status);
  Future<List<ComplexAggregate>> findByDateRange(DateTime start, DateTime end);
  Future<int> countByStatus(String status);
}

@Serializable()
@GenerateMysqlRepository(implements: ComplexRepository)
class ComplexAggregate extends AggregateRoot {
  ComplexAggregate({required this.status, required this.date}) : super();
  final String status;
  final DateTime date;
}
''',
          (resolver) async => (await resolver.findLibraryByName('test'))!,
        );

        final classElement = library.topLevelElements
            .whereType<ClassElement>()
            .firstWhere((e) => e.name == 'ComplexAggregate');

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

        // Verify all custom methods are declared as abstract
        expect(
          generated,
          contains(
            'Future<List<ComplexAggregate>> findByStatus(String status)',
          ),
        );
        expect(
          generated,
          contains(
            'Future<List<ComplexAggregate>> findByDateRange(DateTime start, DateTime end)',
          ),
        );
        expect(generated, contains('Future<int> countByStatus(String status)'));
      });
    });

    // **Feature: mysql-repository, Property 24: Deserialization helper availability**
    // **Validates: Requirements 8.5**
    group('Property 24: Deserialization helper availability', () {
      test('should provide helper methods for reconstructing aggregates',
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
class OrderItem extends Entity {
  OrderItem({required this.productId}) : super();
  final String productId;
}

@Serializable()
@GenerateMysqlRepository(implements: CustomOrderRepository)
class Order extends AggregateRoot {
  Order({required this.customerId, required this.items}) : super();
  final String customerId;
  final List<OrderItem> items;
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

        // Verify _rowToJson helper is available
        expect(generated, contains('Map<String, dynamic> _rowToJson'));

        // Verify _loadOrderItem helper is available for loading entities
        expect(
          generated,
          contains('Future<List<Map<String, dynamic>>> _loadOrderItem'),
        );

        // Verify _flattenForTable helper is available
        expect(generated, contains('Map<String, dynamic> _flattenForTable'));

        // Verify _decodeValue helper is available
        expect(generated, contains('dynamic _decodeValue'));

        // Verify _encodeValue helper is available
        expect(generated, contains('Object? _encodeValue'));
      });

      test('should provide serializer access for custom queries', () async {
        final library = await resolveSource(
          '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_repository_mysql/dddart_repository_mysql.dart';

abstract class CustomProductRepository implements Repository<Product> {
  Future<List<Product>> searchByName(String name);
}

@Serializable()
@GenerateMysqlRepository(implements: CustomProductRepository)
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

        // Verify serializer is accessible
        expect(generated, contains('final _serializer'));
        expect(generated, contains('ProductJsonSerializer'));

        // Verify serializer can be used to deserialize from JSON
        expect(generated, contains('_serializer.fromJson'));
      });

      test('should provide connection access for custom queries', () async {
        final library = await resolveSource(
          '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_repository_mysql/dddart_repository_mysql.dart';

abstract class CustomCustomerRepository implements Repository<Customer> {
  Future<List<Customer>> findActive();
}

@Serializable()
@GenerateMysqlRepository(implements: CustomCustomerRepository)
class Customer extends AggregateRoot {
  Customer({required this.active}) : super();
  final bool active;
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

        // Verify connection is accessible for custom queries
        expect(generated, contains('final MysqlConnection _connection'));

        // Verify connection methods can be used
        expect(generated, contains('_connection.query'));
        expect(generated, contains('_connection.execute'));
        expect(generated, contains('_connection.transaction'));
      });

      test('should provide dialect access for encoding/decoding', () async {
        final library = await resolveSource(
          '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_repository_mysql/dddart_repository_mysql.dart';

abstract class CustomEventRepository implements Repository<Event> {
  Future<List<Event>> findByDateRange(DateTime start, DateTime end);
}

@Serializable()
@GenerateMysqlRepository(implements: CustomEventRepository)
class Event extends AggregateRoot {
  Event({required this.eventDate}) : super();
  final DateTime eventDate;
}
''',
          (resolver) async => (await resolver.findLibraryByName('test'))!,
        );

        final classElement = library.topLevelElements
            .whereType<ClassElement>()
            .firstWhere((e) => e.name == 'Event');

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

        // Verify dialect is accessible
        expect(generated, contains('final _dialect = MysqlDialect()'));

        // Verify dialect methods are used for encoding
        expect(generated, contains('_dialect.encodeUuid'));
        expect(generated, contains('_dialect.encodeDateTime'));
      });

      test('should provide entity loading helpers for aggregates with entities',
          () async {
        final library = await resolveSource(
          '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_repository_mysql/dddart_repository_mysql.dart';

abstract class CustomCartRepository implements Repository<Cart> {
  Future<List<Cart>> findByUser(String userId);
}

@Serializable()
class CartItem extends Entity {
  CartItem({required this.productId, required this.quantity}) : super();
  final String productId;
  final int quantity;
}

@Serializable()
@GenerateMysqlRepository(implements: CustomCartRepository)
class Cart extends AggregateRoot {
  Cart({required this.userId, required this.items}) : super();
  final String userId;
  final List<CartItem> items;
}
''',
          (resolver) async => (await resolver.findLibraryByName('test'))!,
        );

        final classElement = library.topLevelElements
            .whereType<ClassElement>()
            .firstWhere((e) => e.name == 'Cart');

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

        // Verify entity loading helper is generated
        expect(
          generated,
          contains('Future<List<Map<String, dynamic>>> _loadCartItem'),
        );

        // Verify the helper can be used in custom queries
        expect(generated, contains('await _loadCartItem('));
      });

      test('should provide error mapping helper for custom queries', () async {
        final library = await resolveSource(
          '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_repository_mysql/dddart_repository_mysql.dart';

abstract class CustomAccountRepository implements Repository<Account> {
  Future<List<Account>> findByType(String type);
}

@Serializable()
@GenerateMysqlRepository(implements: CustomAccountRepository)
class Account extends AggregateRoot {
  Account({required this.type}) : super();
  final String type;
}
''',
          (resolver) async => (await resolver.findLibraryByName('test'))!,
        );

        final classElement = library.topLevelElements
            .whereType<ClassElement>()
            .firstWhere((e) => e.name == 'Account');

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

        // Verify error mapping helper is available
        expect(generated, contains('RepositoryException _mapMysqlException'));

        // Verify it can be used in custom queries
        expect(generated, contains('_mapMysqlException(e,'));
      });
    });

    group('Integration with Standard Methods', () {
      test('should allow custom methods to use same transaction context',
          () async {
        final library = await resolveSource(
          '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_repository_mysql/dddart_repository_mysql.dart';

abstract class CustomOrderRepository implements Repository<Order> {
  Future<List<Order>> findPending();
}

@Serializable()
@GenerateMysqlRepository(implements: CustomOrderRepository)
class Order extends AggregateRoot {
  Order({required this.status}) : super();
  final String status;
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

        // Verify connection is available for transaction support
        expect(generated, contains('_connection.transaction'));

        // Verify standard methods use transactions
        expect(generated, contains('await _connection.transaction(() async'));
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
