/// Property-based tests for MongoDB repository generator.
@Tags(['generator'])
library;

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:dddart_repository_mongodb/src/generators/mongo_repository_generator.dart';
import 'package:source_gen/source_gen.dart';
import 'package:test/test.dart';

void main() {
  group('MongoRepositoryGenerator Property Tests', () {
    late MongoRepositoryGenerator generator;

    setUp(() {
      generator = MongoRepositoryGenerator();
    });

    tearDown(() async {
      // Give the build system time to clean up file handles
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });

    // Property: Repository generation completeness
    // Validates: Generated code contains all required elements
    group('Property: Repository generation completeness', () {
      test('should generate valid Dart code for any valid aggregate root',
          () async {
        // Test with a simple aggregate
        final library = await resolveSource(
          '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_repository_mongodb/dddart_repository_mongodb.dart';

@Serializable()
@GenerateMongoRepository()
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
                  'GenerateMongoRepository',
        );

        final generated = generator.generateForAnnotatedElement(
          classElement,
          ConstantReader(annotation.computeConstantValue()),
          _mockBuildStep(),
        );

        // Verify generated code contains required elements
        expect(generated, contains('class SimpleAggregateMongoRepository'));
        expect(generated, contains('implements Repository<SimpleAggregate>'));
        expect(generated, contains('String get collectionName'));
        expect(generated, contains('Future<SimpleAggregate> getById'));
        expect(generated, contains('Future<void> save(SimpleAggregate'));
        expect(generated, contains('Future<void> deleteById'));
        expect(generated, contains('Db _database'));
        expect(generated, contains('DbCollection get _collection'));
        expect(generated, contains('SimpleAggregateJsonSerializer'));
      });

      test('should generate code with value objects embedded', () async {
        final library = await resolveSource(
          '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_repository_mongodb/dddart_repository_mongodb.dart';

@Serializable()
class Money extends Value {
  const Money({required this.amount, required this.currency});
  
  final double amount;
  final String currency;
}

@Serializable()
@GenerateMongoRepository()
class Order extends AggregateRoot {
  Order({required this.total}) : super();
  
  final Money total;
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
                  'GenerateMongoRepository',
        );

        final generated = generator.generateForAnnotatedElement(
          classElement,
          ConstantReader(annotation.computeConstantValue()),
          _mockBuildStep(),
        );

        // Verify repository is generated
        expect(generated, contains('OrderMongoRepository'));
        expect(generated, contains('OrderJsonSerializer'));
        // MongoDB stores value objects as embedded documents
        expect(generated, contains('toJson'));
        expect(generated, contains('fromJson'));
      });

      test('should use custom collection name when specified', () async {
        final library = await resolveSource(
          '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_repository_mongodb/dddart_repository_mongodb.dart';

@Serializable()
@GenerateMongoRepository(collectionName: 'custom_orders')
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
                  'GenerateMongoRepository',
        );

        final generated = generator.generateForAnnotatedElement(
          classElement,
          ConstantReader(annotation.computeConstantValue()),
          _mockBuildStep(),
        );

        // Verify custom collection name is used
        expect(generated, contains("'custom_orders'"));
      });

      test('should generate abstract base for custom interface', () async {
        final library = await resolveSource(
          '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_repository_mongodb/dddart_repository_mongodb.dart';

abstract class CustomOrderRepository implements Repository<Order> {
  Future<List<Order>> findByStatus(String status);
}

@Serializable()
@GenerateMongoRepository(implements: CustomOrderRepository)
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
                  'GenerateMongoRepository',
        );

        final generated = generator.generateForAnnotatedElement(
          classElement,
          ConstantReader(annotation.computeConstantValue()),
          _mockBuildStep(),
        );

        // Verify abstract base class is generated
        expect(generated, contains('abstract class OrderMongoRepositoryBase'));
        expect(generated, contains('implements CustomOrderRepository'));
        expect(generated, contains('Future<List<Order>> findByStatus'));
      });
    });

    // Property: Multiple aggregate independence
    // Validates: Repositories for different aggregates are independent
    group('Property: Multiple aggregate independence', () {
      test('should generate independent repositories for multiple aggregates',
          () async {
        // Generate for first aggregate
        final library1 = await resolveSource(
          '''
library test1;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_repository_mongodb/dddart_repository_mongodb.dart';

@Serializable()
@GenerateMongoRepository()
class Order extends AggregateRoot {
  Order({required this.total}) : super();
  
  final double total;
}
''',
          (resolver) async => (await resolver.findLibraryByName('test1'))!,
        );

        final class1 = library1.topLevelElements
            .whereType<ClassElement>()
            .firstWhere((e) => e.name == 'Order');

        final annotation1 = class1.metadata.firstWhere(
          (a) =>
              a.element is ConstructorElement &&
              (a.element! as ConstructorElement).enclosingElement.name ==
                  'GenerateMongoRepository',
        );

        final generated1 = generator.generateForAnnotatedElement(
          class1,
          ConstantReader(annotation1.computeConstantValue()),
          _mockBuildStep(),
        );

        // Generate for second aggregate
        final library2 = await resolveSource(
          '''
library test2;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_repository_mongodb/dddart_repository_mongodb.dart';

@Serializable()
@GenerateMongoRepository()
class Customer extends AggregateRoot {
  Customer({required this.name}) : super();
  
  final String name;
}
''',
          (resolver) async => (await resolver.findLibraryByName('test2'))!,
        );

        final class2 = library2.topLevelElements
            .whereType<ClassElement>()
            .firstWhere((e) => e.name == 'Customer');

        final annotation2 = class2.metadata.firstWhere(
          (a) =>
              a.element is ConstructorElement &&
              (a.element! as ConstructorElement).enclosingElement.name ==
                  'GenerateMongoRepository',
        );

        final generated2 = generator.generateForAnnotatedElement(
          class2,
          ConstantReader(annotation2.computeConstantValue()),
          _mockBuildStep(),
        );

        // Verify independence
        expect(generated1, contains('OrderMongoRepository'));
        expect(generated1, contains('OrderJsonSerializer'));
        expect(generated1, isNot(contains('Customer')));

        expect(generated2, contains('CustomerMongoRepository'));
        expect(generated2, contains('CustomerJsonSerializer'));
        expect(generated2, isNot(contains('Order')));
      });
    });

    group('Generator Validation', () {
      test('should throw error when annotating non-class element', () async {
        final library = await resolveSource(
          '''
library test;

import 'package:dddart_repository_mongodb/dddart_repository_mongodb.dart';

@GenerateMongoRepository()
void notAClass() {}
''',
          (resolver) async => (await resolver.findLibraryByName('test'))!,
        );

        final function = library.topLevelElements
            .whereType<FunctionElement>()
            .firstWhere((e) => e.name == 'notAClass');

        expect(
          () => generator.generateForAnnotatedElement(
            function,
            ConstantReader(null),
            _mockBuildStep(),
          ),
          throwsA(
            isA<InvalidGenerationSourceError>().having(
              (e) => e.message,
              'message',
              contains('Only classes can be annotated'),
            ),
          ),
        );
      });

      test('should throw error when class does not extend AggregateRoot',
          () async {
        final library = await resolveSource(
          '''
library test;

import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_repository_mongodb/dddart_repository_mongodb.dart';

@Serializable()
@GenerateMongoRepository()
class NotAnAggregate {
  NotAnAggregate();
}
''',
          (resolver) async => (await resolver.findLibraryByName('test'))!,
        );

        final classElement = library.topLevelElements
            .whereType<ClassElement>()
            .firstWhere((e) => e.name == 'NotAnAggregate');

        final annotation = classElement.metadata.firstWhere(
          (a) =>
              a.element is ConstructorElement &&
              (a.element! as ConstructorElement).enclosingElement.name ==
                  'GenerateMongoRepository',
        );

        expect(
          () => generator.generateForAnnotatedElement(
            classElement,
            ConstantReader(annotation.computeConstantValue()),
            _mockBuildStep(),
          ),
          throwsA(
            isA<InvalidGenerationSourceError>().having(
              (e) => e.message,
              'message',
              contains('must extend AggregateRoot'),
            ),
          ),
        );
      });

      test('should throw error when class is missing @Serializable annotation',
          () async {
        final library = await resolveSource(
          '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_repository_mongodb/dddart_repository_mongodb.dart';

@GenerateMongoRepository()
class MissingSerializable extends AggregateRoot {
  MissingSerializable() : super();
}
''',
          (resolver) async => (await resolver.findLibraryByName('test'))!,
        );

        final classElement = library.topLevelElements
            .whereType<ClassElement>()
            .firstWhere((e) => e.name == 'MissingSerializable');

        final annotation = classElement.metadata.firstWhere(
          (a) =>
              a.element is ConstructorElement &&
              (a.element! as ConstructorElement).enclosingElement.name ==
                  'GenerateMongoRepository',
        );

        expect(
          () => generator.generateForAnnotatedElement(
            classElement,
            ConstantReader(annotation.computeConstantValue()),
            _mockBuildStep(),
          ),
          throwsA(
            isA<InvalidGenerationSourceError>().having(
              (e) => e.message,
              'message',
              contains('must be annotated with @Serializable()'),
            ),
          ),
        );
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
