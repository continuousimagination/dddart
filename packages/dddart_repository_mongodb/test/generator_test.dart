@Tags(['generator'])
library;

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:dddart_repository_mongodb/src/generators/mongo_repository_generator.dart';
import 'package:source_gen/source_gen.dart';
import 'package:test/test.dart';

void main() {
  group('MongoRepositoryGenerator', () {
    late MongoRepositoryGenerator generator;

    setUp(() {
      generator = MongoRepositoryGenerator();
    });

    tearDown(() async {
      // Give the build system time to clean up file handles
      await Future.delayed(const Duration(milliseconds: 100));
    });

    test('should validate annotation usage and class requirements', () async {
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

    test('should generate complete repository with all features', () async {
      final library = await resolveSource(
        '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_repository_mongodb/dddart_repository_mongodb.dart';

@Serializable()
@GenerateMongoRepository(collectionName: 'test_products')
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
                'GenerateMongoRepository',
      );

      final output = generator.generateForAnnotatedElement(
        classElement,
        ConstantReader(annotation.computeConstantValue()),
        _mockBuildStep(),
      );

      // Verify all critical features in one comprehensive test
      expect(
        output,
        contains(
          "collectionName => 'test_products'",
        ),
      ); // Custom collection name
      expect(
        output,
        contains('/// Generated MongoDB repository'),
      ); // Documentation
      expect(output, contains('class ProductMongoRepository')); // Class name
      expect(output, contains('implements Repository<Product>')); // Interface
      expect(output, contains('final Db _database')); // Database field
      expect(output, contains('final _serializer')); // Serializer field
      expect(
        output,
        contains('Future<Product> getById(UuidValue id)'),
      ); // getById method
      expect(
        output,
        contains('Future<void> save(Product aggregate)'),
      ); // save method
      expect(
        output,
        contains(
          'Future<void> deleteById(UuidValue id)',
        ),
      ); // deleteById method
      expect(
        output,
        contains("doc['id'] = doc['_id']"),
      ); // ID mapping in getById
      expect(output, contains("doc.remove('_id')")); // ID cleanup in getById
      expect(output, contains("doc['_id'] = doc['id']")); // ID mapping in save
      expect(output, contains("doc.remove('id')")); // ID cleanup in save
      expect(
        output,
        contains(
          'RepositoryException _mapMongoException',
        ),
      ); // Exception mapping
      expect(
        output,
        contains('RepositoryExceptionType.duplicate'),
      ); // Duplicate exception
      expect(
        output,
        contains(
          'RepositoryExceptionType.connection',
        ),
      ); // Connection exception
      expect(
        output,
        contains('RepositoryExceptionType.timeout'),
      ); // Timeout exception
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
