@Tags(['generator'])
library;

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:dddart_repository_dynamodb/src/generators/dynamo_repository_generator.dart';
import 'package:source_gen/source_gen.dart';
import 'package:test/test.dart';

void main() {
  group('DynamoRepositoryGenerator', () {
    late DynamoRepositoryGenerator generator;

    setUp(() {
      generator = DynamoRepositoryGenerator();
    });

    tearDown(() async {
      // Give the build system time to clean up file handles
      await Future.delayed(const Duration(milliseconds: 100));
    });

    test('should throw error when annotating non-class element', () async {
      final library = await resolveSource(
        '''
library test;

import 'package:dddart_repository_dynamodb/dddart_repository_dynamodb.dart';

@GenerateDynamoRepository()
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
import 'package:dddart_repository_dynamodb/dddart_repository_dynamodb.dart';

@Serializable()
@GenerateDynamoRepository()
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
                'GenerateDynamoRepository',
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
import 'package:dddart_repository_dynamodb/dddart_repository_dynamodb.dart';

@GenerateDynamoRepository()
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
                'GenerateDynamoRepository',
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

    test('should extract custom table name from annotation', () async {
      final library = await resolveSource(
        '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_repository_dynamodb/dddart_repository_dynamodb.dart';

@Serializable()
@GenerateDynamoRepository(tableName: 'custom_products')
class Product extends AggregateRoot {
  Product() : super();
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
                'GenerateDynamoRepository',
      );

      final output = generator.generateForAnnotatedElement(
        classElement,
        ConstantReader(annotation.computeConstantValue()),
        _mockBuildStep(),
      );

      expect(output, contains("tableName => 'custom_products'"));
    });

    test('should use snake_case table name when not specified', () async {
      final library = await resolveSource(
        '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_repository_dynamodb/dddart_repository_dynamodb.dart';

@Serializable()
@GenerateDynamoRepository()
class OrderItem extends AggregateRoot {
  OrderItem() : super();
}
''',
        (resolver) async => (await resolver.findLibraryByName('test'))!,
      );

      final classElement = library.topLevelElements
          .whereType<ClassElement>()
          .firstWhere((e) => e.name == 'OrderItem');

      final annotation = classElement.metadata.firstWhere(
        (a) =>
            a.element is ConstructorElement &&
            (a.element! as ConstructorElement).enclosingElement.name ==
                'GenerateDynamoRepository',
      );

      final output = generator.generateForAnnotatedElement(
        classElement,
        ConstantReader(annotation.computeConstantValue()),
        _mockBuildStep(),
      );

      expect(output, contains("tableName => 'order_item'"));
    });

    test('should generate concrete repository without custom interface',
        () async {
      final library = await resolveSource(
        '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_repository_dynamodb/dddart_repository_dynamodb.dart';

@Serializable()
@GenerateDynamoRepository(tableName: 'users')
class User extends AggregateRoot {
  User() : super();
}
''',
        (resolver) async => (await resolver.findLibraryByName('test'))!,
      );

      final classElement = library.topLevelElements
          .whereType<ClassElement>()
          .firstWhere((e) => e.name == 'User');

      final annotation = classElement.metadata.firstWhere(
        (a) =>
            a.element is ConstructorElement &&
            (a.element! as ConstructorElement).enclosingElement.name ==
                'GenerateDynamoRepository',
      );

      final output = generator.generateForAnnotatedElement(
        classElement,
        ConstantReader(annotation.computeConstantValue()),
        _mockBuildStep(),
      );

      expect(output, contains('class UserDynamoRepository'));
      expect(output, contains('implements Repository<User>'));
      expect(output, contains('final DynamoConnection _connection'));
      expect(output, contains("tableName => 'users'"));
      expect(output, contains('final _serializer = UserJsonSerializer()'));
      
      // Verify CRUD methods are generated
      expect(output, contains('Future<User> getById(UuidValue id)'));
      expect(output, contains('Future<void> save(User aggregate)'));
      expect(output, contains('Future<void> deleteById(UuidValue id)'));
      
      // Verify exception mapping method is generated
      expect(output, contains('_mapDynamoException'));
      
      // Verify DynamoDB API calls are present
      expect(output, contains('_connection.client.getItem'));
      expect(output, contains('_connection.client.putItem'));
      expect(output, contains('_connection.client.deleteItem'));
      
      // Verify AttributeValue conversion is used
      expect(output, contains('AttributeValueConverter.attributeMapToJsonMap'));
      expect(output, contains('AttributeValueConverter.jsonMapToAttributeMap'));
    });

    test('should generate concrete repository with custom interface',
        () async {
      final library = await resolveSource(
        '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_repository_dynamodb/dddart_repository_dynamodb.dart';

abstract interface class UserRepository implements Repository<User> {}

@Serializable()
@GenerateDynamoRepository(tableName: 'users', implements: UserRepository)
class User extends AggregateRoot {
  User() : super();
}
''',
        (resolver) async => (await resolver.findLibraryByName('test'))!,
      );

      final classElement = library.topLevelElements
          .whereType<ClassElement>()
          .firstWhere((e) => e.name == 'User');

      final annotation = classElement.metadata.firstWhere(
        (a) =>
            a.element is ConstructorElement &&
            (a.element! as ConstructorElement).enclosingElement.name ==
                'GenerateDynamoRepository',
      );

      final output = generator.generateForAnnotatedElement(
        classElement,
        ConstantReader(annotation.computeConstantValue()),
        _mockBuildStep(),
      );

      expect(output, contains('class UserDynamoRepository'));
      expect(output, contains('implements UserRepository'));
      expect(output, isNot(contains('abstract class')));
    });

    test(
        'should generate abstract base repository with custom interface methods',
        () async {
      final library = await resolveSource(
        '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_repository_dynamodb/dddart_repository_dynamodb.dart';

abstract interface class UserRepository implements Repository<User> {
  Future<User?> findByEmail(String email);
}

@Serializable()
@GenerateDynamoRepository(tableName: 'users', implements: UserRepository)
class User extends AggregateRoot {
  User() : super();
}
''',
        (resolver) async => (await resolver.findLibraryByName('test'))!,
      );

      final classElement = library.topLevelElements
          .whereType<ClassElement>()
          .firstWhere((e) => e.name == 'User');

      final annotation = classElement.metadata.firstWhere(
        (a) =>
            a.element is ConstructorElement &&
            (a.element! as ConstructorElement).enclosingElement.name ==
                'GenerateDynamoRepository',
      );

      final output = generator.generateForAnnotatedElement(
        classElement,
        ConstantReader(annotation.computeConstantValue()),
        _mockBuildStep(),
      );

      expect(output, contains('abstract class UserDynamoRepositoryBase'));
      expect(output, contains('implements UserRepository'));
      expect(output, contains('Future<User?> findByEmail(String email)'));
      expect(
        output,
        contains('// Custom methods (must be implemented by subclass)'),
      );
      
      // Verify CRUD methods are generated as concrete implementations
      expect(output, contains('Future<User> getById(UuidValue id)'));
      expect(output, contains('Future<void> save(User aggregate)'));
      expect(output, contains('Future<void> deleteById(UuidValue id)'));
      
      // Verify exception mapping method is generated
      expect(output, contains('_mapDynamoException'));
      
      // Verify DynamoDB API calls are present
      expect(output, contains('_connection.client.getItem'));
      expect(output, contains('_connection.client.putItem'));
      expect(output, contains('_connection.client.deleteItem'));
    });

    group('Table Creation Utilities', () {
      test('should generate createTable instance method', () async {
        final library = await resolveSource(
          '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_repository_dynamodb/dddart_repository_dynamodb.dart';

@Serializable()
@GenerateDynamoRepository(tableName: 'orders')
class Order extends AggregateRoot {
  Order() : super();
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
                  'GenerateDynamoRepository',
        );

        final output = generator.generateForAnnotatedElement(
          classElement,
          ConstantReader(annotation.computeConstantValue()),
          _mockBuildStep(),
        );

        // Verify createTable method exists
        expect(output, contains('Future<void> createTable()'));
        expect(output, contains('_connection.client.createTable'));
        expect(output, contains('tableName: tableName'));
        expect(output, contains("attributeName: 'id'"));
        expect(output, contains('keyType: KeyType.hash'));
        expect(output, contains('attributeType: ScalarAttributeType.s'));
        expect(output, contains('billingMode: BillingMode.payPerRequest'));
        expect(output, contains('_mapDynamoException(e, \'createTable\')'));
      });

      test('should generate getCreateTableCommand static method', () async {
        final library = await resolveSource(
          '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_repository_dynamodb/dddart_repository_dynamodb.dart';

@Serializable()
@GenerateDynamoRepository(tableName: 'customers')
class Customer extends AggregateRoot {
  Customer() : super();
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
                  'GenerateDynamoRepository',
        );

        final output = generator.generateForAnnotatedElement(
          classElement,
          ConstantReader(annotation.computeConstantValue()),
          _mockBuildStep(),
        );

        // Verify getCreateTableCommand method exists
        expect(output, contains('static String getCreateTableCommand'));
        expect(output, contains('aws dynamodb create-table'));
        expect(output, contains('--table-name'));
        expect(output, contains('--attribute-definitions'));
        expect(output, contains('AttributeName=id,AttributeType=S'));
        expect(output, contains('--key-schema'));
        expect(output, contains('AttributeName=id,KeyType=HASH'));
        expect(output, contains('--billing-mode PAY_PER_REQUEST'));
      });

      test('should generate getCloudFormationTemplate static method',
          () async {
        final library = await resolveSource(
          '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_repository_dynamodb/dddart_repository_dynamodb.dart';

@Serializable()
@GenerateDynamoRepository(tableName: 'inventory')
class Inventory extends AggregateRoot {
  Inventory() : super();
}
''',
          (resolver) async => (await resolver.findLibraryByName('test'))!,
        );

        final classElement = library.topLevelElements
            .whereType<ClassElement>()
            .firstWhere((e) => e.name == 'Inventory');

        final annotation = classElement.metadata.firstWhere(
          (a) =>
              a.element is ConstructorElement &&
              (a.element! as ConstructorElement).enclosingElement.name ==
                  'GenerateDynamoRepository',
        );

        final output = generator.generateForAnnotatedElement(
          classElement,
          ConstantReader(annotation.computeConstantValue()),
          _mockBuildStep(),
        );

        // Verify getCloudFormationTemplate method exists
        expect(output, contains('static String getCloudFormationTemplate'));
        expect(output, contains('Resources:'));
        expect(output, contains('Type: AWS::DynamoDB::Table'));
        expect(output, contains('TableName:'));
        expect(output, contains('AttributeDefinitions:'));
        expect(output, contains('- AttributeName: id'));
        expect(output, contains('AttributeType: S'));
        expect(output, contains('KeySchema:'));
        expect(output, contains('- AttributeName: id'));
        expect(output, contains('KeyType: HASH'));
        expect(output, contains('BillingMode: PAY_PER_REQUEST'));
      });

      test('should configure partition key as id with String type', () async {
        final library = await resolveSource(
          '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_repository_dynamodb/dddart_repository_dynamodb.dart';

@Serializable()
@GenerateDynamoRepository()
class TestAggregate extends AggregateRoot {
  TestAggregate() : super();
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
                  'GenerateDynamoRepository',
        );

        final output = generator.generateForAnnotatedElement(
          classElement,
          ConstantReader(annotation.computeConstantValue()),
          _mockBuildStep(),
        );

        // Verify partition key configuration
        expect(output, contains("attributeName: 'id'"));
        expect(output, contains('keyType: KeyType.hash'));
        expect(output, contains('attributeType: ScalarAttributeType.s'));
      });

      test('should use PAY_PER_REQUEST billing mode', () async {
        final library = await resolveSource(
          '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_repository_dynamodb/dddart_repository_dynamodb.dart';

@Serializable()
@GenerateDynamoRepository()
class BillingTest extends AggregateRoot {
  BillingTest() : super();
}
''',
          (resolver) async => (await resolver.findLibraryByName('test'))!,
        );

        final classElement = library.topLevelElements
            .whereType<ClassElement>()
            .firstWhere((e) => e.name == 'BillingTest');

        final annotation = classElement.metadata.firstWhere(
          (a) =>
              a.element is ConstructorElement &&
              (a.element! as ConstructorElement).enclosingElement.name ==
                  'GenerateDynamoRepository',
        );

        final output = generator.generateForAnnotatedElement(
          classElement,
          ConstantReader(annotation.computeConstantValue()),
          _mockBuildStep(),
        );

        // Verify billing mode in CreateTableInput
        expect(output, contains('billingMode: BillingMode.payPerRequest'));
        
        // Verify billing mode in CLI command
        expect(output, contains('--billing-mode PAY_PER_REQUEST'));
        
        // Verify billing mode in CloudFormation template
        expect(output, contains('BillingMode: PAY_PER_REQUEST'));
      });
    });
  });
}

/// Creates a stub BuildStep for testing.
/// Since BuildStep is sealed and we don't actually use it in the generator,
/// we suppress the warning and return a stub instance.
// ignore: subtype_of_sealed_class
BuildStep _mockBuildStep() => _StubBuildStep();

// ignore: subtype_of_sealed_class
class _StubBuildStep implements BuildStep {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
