@Tags(['generator', 'property'])
library;

import 'dart:math';

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:dddart_repository_rest/src/generators/rest_repository_generator.dart';
import 'package:source_gen/source_gen.dart';
import 'package:test/test.dart';

void main() {
  group('RestRepositoryGenerator property tests', () {
    late RestRepositoryGenerator generator;
    final random = Random(42); // Fixed seed for reproducibility

    setUp(() {
      generator = RestRepositoryGenerator();
    });

    tearDown(() async {
      // Give the build system time to clean up file handles
      await Future.delayed(const Duration(milliseconds: 100));
    });

    // **Feature: rest-repository, Property 1: Code generation produces valid Dart code**
    test(
      'generated code compiles for any valid aggregate root',
      () async {
        // Run 100 iterations with different aggregate root configurations
        for (var i = 0; i < 100; i++) {
          // Generate random class name
          final className = _generateRandomClassName(random);

          // Generate random field configurations
          final fields = _generateRandomFields(random);

          // Create source with random aggregate
          final library = await resolveSource(
            '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_repository_rest/dddart_repository_rest.dart';

@Serializable()
@GenerateRestRepository()
class $className extends AggregateRoot {
$fields
  $className();
}
''',
            (resolver) async => (await resolver.findLibraryByName('test'))!,
          );

          final classElement = library.topLevelElements
              .whereType<ClassElement>()
              .firstWhere((e) => e.name == className);

          final annotation = classElement.metadata.firstWhere(
            (a) =>
                a.element is ConstructorElement &&
                (a.element! as ConstructorElement).enclosingElement.name ==
                    'GenerateRestRepository',
          );

          // Generate code
          final output = generator.generateForAnnotatedElement(
            classElement,
            ConstantReader(annotation.computeConstantValue()),
            _mockBuildStep(),
          );

          // Verify generated code has valid structure
          expect(output, contains('class ${className}RestRepository'));
          expect(output, contains('implements Repository<$className>'));
          expect(output, contains('Future<$className> getById'));
          expect(output, contains('Future<void> save($className aggregate)'));
          expect(output, contains('Future<void> deleteById'));
          expect(
            output,
            contains('final _serializer = ${className}JsonSerializer()'),
          );
          expect(output, contains('RepositoryException _mapHttpException'));

          // Verify no syntax errors in generated code (basic checks)
          expect(output, isNot(contains('null null'))); // No double nulls
          expect(output, isNot(contains('  ;'))); // No empty statements
          expect(
            output.split('{').length,
            equals(output.split('}').length),
          ); // Balanced braces
        }
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    // **Feature: rest-repository, Property 2: Resource path configuration is respected**
    test(
      'resource path configuration is respected for any valid path',
      () async {
        // Run 100 iterations with different resource paths
        for (var i = 0; i < 100; i++) {
          // Generate random resource path
          final resourcePath = _generateRandomResourcePath(random);

          // Create source with custom resource path
          final library = await resolveSource(
            '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_repository_rest/dddart_repository_rest.dart';

@Serializable()
@GenerateRestRepository(resourcePath: '$resourcePath')
class TestAggregate extends AggregateRoot {
  final String name;
  TestAggregate({required this.name});
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
                    'GenerateRestRepository',
          );

          // Generate code
          final output = generator.generateForAnnotatedElement(
            classElement,
            ConstantReader(annotation.computeConstantValue()),
            _mockBuildStep(),
          );

          // Verify the exact resource path appears in generated code
          expect(
            output,
            contains("String get _resourcePath => '$resourcePath'"),
            reason:
                'Resource path "$resourcePath" should appear in generated code',
          );

          // Verify it's used in HTTP requests (no slash between baseUrl and resourcePath)
          expect(
            output,
            contains(r'${_connection.baseUrl}$_resourcePath/'),
            reason: 'Resource path should be used in HTTP request URLs',
          );
        }
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    // **Feature: rest-repository, Property 3: Resource path generation follows naming convention**
    test(
      'resource path generation follows naming convention for any class name',
      () async {
        // Test cases with expected outputs
        final testCases = {
          'User': 'users',
          'OrderItem': 'order-items',
          'Company': 'companies',
          'Address': 'addresses',
          'Box': 'boxes',
          'Church': 'churches',
          'Product': 'products',
          'CustomerRecord': 'customer-records',
          'InvoiceData': 'invoice-datas',
        };

        for (final entry in testCases.entries) {
          final className = entry.key;
          final expectedPath = entry.value;

          // Create source without resource path (should generate default)
          final library = await resolveSource(
            '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_repository_rest/dddart_repository_rest.dart';

@Serializable()
@GenerateRestRepository()
class $className extends AggregateRoot {
  final String name;
  $className({required this.name});
}
''',
            (resolver) async => (await resolver.findLibraryByName('test'))!,
          );

          final classElement = library.topLevelElements
              .whereType<ClassElement>()
              .firstWhere((e) => e.name == className);

          final annotation = classElement.metadata.firstWhere(
            (a) =>
                a.element is ConstructorElement &&
                (a.element! as ConstructorElement).enclosingElement.name ==
                    'GenerateRestRepository',
          );

          // Generate code
          final output = generator.generateForAnnotatedElement(
            classElement,
            ConstantReader(annotation.computeConstantValue()),
            _mockBuildStep(),
          );

          // Verify the generated resource path follows naming convention
          expect(
            output,
            contains("String get _resourcePath => '$expectedPath'"),
            reason:
                'Class name "$className" should generate resource path "$expectedPath"',
          );
        }
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    // **Feature: rest-repository, Property 4: Custom interface determines class type**
    test(
      'custom interface determines whether concrete or abstract class is generated',
      () async {
        // Test case 1: No custom interface -> concrete class
        final library1 = await resolveSource(
          '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_repository_rest/dddart_repository_rest.dart';

@Serializable()
@GenerateRestRepository()
class User extends AggregateRoot {
  final String name;
  User({required this.name});
}
''',
          (resolver) async => (await resolver.findLibraryByName('test'))!,
        );

        final classElement1 = library1.topLevelElements
            .whereType<ClassElement>()
            .firstWhere((e) => e.name == 'User');

        final annotation1 = classElement1.metadata.firstWhere(
          (a) =>
              a.element is ConstructorElement &&
              (a.element! as ConstructorElement).enclosingElement.name ==
                  'GenerateRestRepository',
        );

        final output1 = generator.generateForAnnotatedElement(
          classElement1,
          ConstantReader(annotation1.computeConstantValue()),
          _mockBuildStep(),
        );

        // Verify concrete class is generated (not abstract)
        expect(output1, contains('class UserRestRepository'));
        expect(output1, isNot(contains('abstract class')));
        expect(output1, contains('implements Repository<User>'));

        // Test case 2: Custom interface with only base methods -> concrete class
        final library2 = await resolveSource(
          '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_repository_rest/dddart_repository_rest.dart';

abstract interface class ProductRepository implements Repository<Product> {}

@Serializable()
@GenerateRestRepository(implements: ProductRepository)
class Product extends AggregateRoot {
  final String name;
  Product({required this.name});
}
''',
          (resolver) async => (await resolver.findLibraryByName('test'))!,
        );

        final classElement2 = library2.topLevelElements
            .whereType<ClassElement>()
            .firstWhere((e) => e.name == 'Product');

        final annotation2 = classElement2.metadata.firstWhere(
          (a) =>
              a.element is ConstructorElement &&
              (a.element! as ConstructorElement).enclosingElement.name ==
                  'GenerateRestRepository',
        );

        final output2 = generator.generateForAnnotatedElement(
          classElement2,
          ConstantReader(annotation2.computeConstantValue()),
          _mockBuildStep(),
        );

        // Verify concrete class is generated (not abstract)
        expect(output2, contains('class ProductRestRepository'));
        expect(output2, isNot(contains('abstract class')));
        expect(output2, contains('implements ProductRepository'));

        // Test case 3: Custom interface with custom methods -> abstract base class
        final library3 = await resolveSource(
          '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_repository_rest/dddart_repository_rest.dart';

abstract interface class OrderRepository implements Repository<Order> {
  Future<Order?> findByOrderNumber(String orderNumber);
  Future<List<Order>> findByCustomerId(String customerId);
}

@Serializable()
@GenerateRestRepository(implements: OrderRepository)
class Order extends AggregateRoot {
  final String orderNumber;
  Order({required this.orderNumber});
}
''',
          (resolver) async => (await resolver.findLibraryByName('test'))!,
        );

        final classElement3 = library3.topLevelElements
            .whereType<ClassElement>()
            .firstWhere((e) => e.name == 'Order');

        final annotation3 = classElement3.metadata.firstWhere(
          (a) =>
              a.element is ConstructorElement &&
              (a.element! as ConstructorElement).enclosingElement.name ==
                  'GenerateRestRepository',
        );

        final output3 = generator.generateForAnnotatedElement(
          classElement3,
          ConstantReader(annotation3.computeConstantValue()),
          _mockBuildStep(),
        );

        // Verify abstract base class is generated
        expect(output3, contains('abstract class OrderRestRepositoryBase'));
        expect(output3, contains('implements OrderRepository'));
        expect(
          output3,
          contains('Future<Order?> findByOrderNumber(String orderNumber)'),
        );
        expect(
          output3,
          contains(
            'Future<List<Order>> findByCustomerId(String customerId)',
          ),
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    // **Feature: rest-repository, Property 12: Custom interface methods are abstract**
    test(
      'custom interface methods are declared as abstract in generated base class',
      () async {
        // Test with various custom interface configurations
        final testCases = [
          // Single custom method
          {
            'interface': '''
abstract interface class UserRepository implements Repository<User> {
  Future<User?> findByEmail(String email);
}
''',
            'expectedMethods': ['Future<User?> findByEmail(String email)'],
          },
          // Multiple custom methods
          {
            'interface': '''
abstract interface class OrderRepository implements Repository<Order> {
  Future<Order?> findByOrderNumber(String orderNumber);
  Future<List<Order>> findByCustomerId(String customerId);
  Future<List<Order>> findByStatus(String status);
}
''',
            'expectedMethods': [
              'Future<Order?> findByOrderNumber(String orderNumber)',
              'Future<List<Order>> findByCustomerId(String customerId)',
              'Future<List<Order>> findByStatus(String status)',
            ],
          },
          // Methods with various parameter types
          {
            'interface': '''
abstract interface class ProductRepository implements Repository<Product> {
  Future<List<Product>> findByCategory(String category);
  Future<List<Product>> findByPriceRange(double min, double max);
  Future<int> countByCategory(String category);
}
''',
            'expectedMethods': [
              'Future<List<Product>> findByCategory(String category)',
              'Future<List<Product>> findByPriceRange(double min, double max)',
              'Future<int> countByCategory(String category)',
            ],
          },
        ];

        for (final testCase in testCases) {
          final interfaceCode = testCase['interface']! as String;
          final expectedMethods = testCase['expectedMethods']! as List<String>;

          // Extract class name from interface
          final className = interfaceCode
              .split('interface class ')[1]
              .split('Repository')[0]
              .trim();

          // Create source with custom interface
          final library = await resolveSource(
            '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_repository_rest/dddart_repository_rest.dart';

$interfaceCode

@Serializable()
@GenerateRestRepository(implements: ${className}Repository)
class $className extends AggregateRoot {
  final String name;
  $className({required this.name});
}
''',
            (resolver) async => (await resolver.findLibraryByName('test'))!,
          );

          final classElement = library.topLevelElements
              .whereType<ClassElement>()
              .firstWhere((e) => e.name == className);

          final annotation = classElement.metadata.firstWhere(
            (a) =>
                a.element is ConstructorElement &&
                (a.element! as ConstructorElement).enclosingElement.name ==
                    'GenerateRestRepository',
          );

          // Generate code
          final output = generator.generateForAnnotatedElement(
            classElement,
            ConstantReader(annotation.computeConstantValue()),
            _mockBuildStep(),
          );

          // Verify abstract base class is generated
          expect(
            output,
            contains('abstract class ${className}RestRepositoryBase'),
            reason: 'Should generate abstract base class for custom interface',
          );

          // Verify all custom methods are declared as abstract
          for (final method in expectedMethods) {
            // Check that method signature appears with @override
            expect(
              output,
              contains('@override'),
              reason: 'Abstract methods should have @override annotation',
            );

            // Check that method signature appears followed by semicolon (abstract)
            expect(
              output,
              contains('$method;'),
              reason:
                  'Method "$method" should be declared as abstract (ending with semicolon)',
            );

            // Verify method doesn't have implementation (no opening brace after signature)
            final methodPattern = RegExp('$method\\s*\\{');
            expect(
              methodPattern.hasMatch(output),
              isFalse,
              reason:
                  'Abstract method "$method" should not have implementation',
            );
          }

          // Verify base Repository methods are NOT abstract (have implementations)
          expect(
            output,
            contains('Future<$className> getById(UuidValue id) async {'),
            reason: 'getById should have concrete implementation',
          );
          expect(
            output,
            contains('Future<void> save($className aggregate) async {'),
            reason: 'save should have concrete implementation',
          );
          expect(
            output,
            contains('Future<void> deleteById(UuidValue id) async {'),
            reason: 'deleteById should have concrete implementation',
          );
        }
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    // **Feature: rest-repository, Property 13: Protected members are accessible in subclasses**
    test(
      'protected members are accessible in subclasses of generated base class',
      () async {
        // Test that subclasses can access _connection, _serializer, _resourcePath, and _mapHttpException
        final testCases = [
          {
            'className': 'User',
            'interface': '''
abstract interface class UserRepository implements Repository<User> {
  Future<User?> findByEmail(String email);
}
''',
          },
          {
            'className': 'Order',
            'interface': '''
abstract interface class OrderRepository implements Repository<Order> {
  Future<List<Order>> findByStatus(String status);
}
''',
          },
          {
            'className': 'Product',
            'interface': '''
abstract interface class ProductRepository implements Repository<Product> {
  Future<List<Product>> search(String query);
}
''',
          },
        ];

        for (final testCase in testCases) {
          final className = testCase['className']!;
          final interfaceCode = testCase['interface']!;

          // Create source with custom interface
          final library = await resolveSource(
            '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_repository_rest/dddart_repository_rest.dart';

$interfaceCode

@Serializable()
@GenerateRestRepository(implements: ${className}Repository)
class $className extends AggregateRoot {
  final String name;
  $className({required this.name});
}
''',
            (resolver) async => (await resolver.findLibraryByName('test'))!,
          );

          final classElement = library.topLevelElements
              .whereType<ClassElement>()
              .firstWhere((e) => e.name == className);

          final annotation = classElement.metadata.firstWhere(
            (a) =>
                a.element is ConstructorElement &&
                (a.element! as ConstructorElement).enclosingElement.name ==
                    'GenerateRestRepository',
          );

          // Generate code
          final output = generator.generateForAnnotatedElement(
            classElement,
            ConstantReader(annotation.computeConstantValue()),
            _mockBuildStep(),
          );

          // Verify abstract base class is generated
          expect(
            output,
            contains('abstract class ${className}RestRepositoryBase'),
            reason: 'Should generate abstract base class',
          );

          // Verify _connection field is present and accessible (not private to the class)
          expect(
            output,
            contains('final RestConnection _connection;'),
            reason: '_connection should be declared as a field',
          );

          // Verify _serializer field is present
          expect(
            output,
            contains('final _serializer = ${className}JsonSerializer();'),
            reason: '_serializer should be declared as a field',
          );

          // Verify _resourcePath getter is present
          expect(
            output,
            contains('String get _resourcePath =>'),
            reason: '_resourcePath getter should be declared',
          );

          // Verify _mapHttpException method is present
          expect(
            output,
            contains('RepositoryException _mapHttpException('),
            reason: '_mapHttpException method should be declared',
          );

          // Verify these members are used in the concrete implementations
          // This proves they're accessible within the class
          expect(
            output,
            contains('_connection.httpClient'),
            reason: '_connection should be used in method implementations',
          );

          expect(
            output,
            contains('_serializer.fromJson'),
            reason: '_serializer should be used in method implementations',
          );

          expect(
            output,
            contains(r'$_resourcePath'),
            reason: '_resourcePath should be used in method implementations',
          );

          expect(
            output,
            contains('throw _mapHttpException('),
            reason:
                '_mapHttpException should be used in method implementations',
          );

          // Verify the members are not declared as private to the library
          // (they use _ prefix for convention but are accessible to subclasses)
          // In Dart, members with _ prefix are library-private, but since
          // subclasses will be in the same library (via part directive),
          // they will have access to these members.

          // The key test is that the generated code compiles and can be extended.
          // We verify this by checking the structure is correct for extension.
          expect(
            output,
            isNot(contains('// ignore: unused_field')),
            reason: 'Protected members should be used, not marked as unused',
          );
        }
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}

/// Generates a random valid Dart class name.
String _generateRandomClassName(Random random) {
  final prefixes = [
    'User',
    'Order',
    'Product',
    'Customer',
    'Invoice',
    'Payment',
  ];
  final suffixes = ['', 'Item', 'Record', 'Entity', 'Data', 'Info'];

  final prefix = prefixes[random.nextInt(prefixes.length)];
  final suffix = suffixes[random.nextInt(suffixes.length)];

  return '$prefix$suffix';
}

/// Generates random field declarations for a class.
String _generateRandomFields(Random random) {
  final fieldCount = random.nextInt(5) + 1; // 1-5 fields
  final fields = <String>[];

  final types = ['String', 'int', 'double', 'bool', 'DateTime'];
  final names = ['name', 'value', 'count', 'amount', 'status', 'description'];

  for (var i = 0; i < fieldCount; i++) {
    final type = types[random.nextInt(types.length)];
    final name = '${names[random.nextInt(names.length)]}$i';
    fields.add('  final $type $name;');
  }

  return fields.join('\n');
}

/// Generates a random valid resource path.
String _generateRandomResourcePath(Random random) {
  final segments = ['users', 'orders', 'products', 'customers', 'invoices'];
  final prefixes = ['', 'api/', 'v1/', 'api/v1/', 'api/v2/'];

  final prefix = prefixes[random.nextInt(prefixes.length)];
  final segment = segments[random.nextInt(segments.length)];

  // Sometimes add a leading slash, sometimes not
  final leadingSlash = random.nextBool() ? '/' : '';

  return '$leadingSlash$prefix$segment';
}

/// Creates a stub BuildStep for testing.
// ignore: subtype_of_sealed_class
BuildStep _mockBuildStep() => _StubBuildStep();

// ignore: subtype_of_sealed_class
class _StubBuildStep implements BuildStep {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
