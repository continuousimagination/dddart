@Tags(['generator'])
library;

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:dddart_repository_rest/src/generators/rest_repository_generator.dart';
import 'package:source_gen/source_gen.dart';
import 'package:test/test.dart';

void main() {
  group('RestRepositoryGenerator validation', () {
    late RestRepositoryGenerator generator;

    setUp(() {
      generator = RestRepositoryGenerator();
    });

    tearDown(() async {
      // Give the build system time to clean up file handles
      await Future.delayed(const Duration(milliseconds: 100));
    });

    test('non-class element fails with clear error', () async {
      // Arrange: Create a library with annotation on a function
      final library = await resolveSource(
        '''
library test;

import 'package:dddart_repository_rest/dddart_repository_rest.dart';

@GenerateRestRepository()
void myFunction() {}
''',
        (resolver) async => (await resolver.findLibraryByName('test'))!,
      );

      final function = library.topLevelElements
          .whereType<FunctionElement>()
          .firstWhere((e) => e.name == 'myFunction');

      // Act & Assert: Expect InvalidGenerationSourceError
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

    test('class not extending AggregateRoot fails with clear error', () async {
      // Arrange: Create a library with a class that doesn't extend AggregateRoot
      final library = await resolveSource(
        '''
library test;

import 'package:dddart_repository_rest/dddart_repository_rest.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

@Serializable()
@GenerateRestRepository()
class NotAnAggregate {
  final String id;
  NotAnAggregate(this.id);
}
''',
        (resolver) async => (await resolver.findLibraryByName('test'))!,
      );

      final classElement = library.topLevelElements
          .whereType<ClassElement>()
          .firstWhere((e) => e.name == 'NotAnAggregate');

      final annotation = classElement.metadata.firstWhere(
        (a) =>
            a.computeConstantValue()?.type?.element?.name ==
            'GenerateRestRepository',
      );

      // Act & Assert: Expect InvalidGenerationSourceError
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

    test('class without @Serializable fails with clear error', () async {
      // Arrange: Create a library with AggregateRoot but no @Serializable
      final library = await resolveSource(
        '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_repository_rest/dddart_repository_rest.dart';

@GenerateRestRepository()
class User extends AggregateRoot {
  final String name;
  User({required this.name});
}
''',
        (resolver) async => (await resolver.findLibraryByName('test'))!,
      );

      final classElement = library.topLevelElements
          .whereType<ClassElement>()
          .firstWhere((e) => e.name == 'User');

      final annotation = classElement.metadata.firstWhere(
        (a) =>
            a.computeConstantValue()?.type?.element?.name ==
            'GenerateRestRepository',
      );

      // Act & Assert: Expect InvalidGenerationSourceError
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

    test('valid class passes validation', () async {
      // Arrange: Create a valid library
      final library = await resolveSource(
        '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_repository_rest/dddart_repository_rest.dart';

@Serializable()
@GenerateRestRepository(resourcePath: '/users')
class User extends AggregateRoot {
  final String name;
  User({required this.name});
}
''',
        (resolver) async => (await resolver.findLibraryByName('test'))!,
      );

      final classElement = library.topLevelElements
          .whereType<ClassElement>()
          .firstWhere((e) => e.name == 'User');

      final annotation = classElement.metadata.firstWhere(
        (a) =>
            a.computeConstantValue()?.type?.element?.name ==
            'GenerateRestRepository',
      );

      // Act: Generate code
      final output = generator.generateForAnnotatedElement(
        classElement,
        ConstantReader(annotation.computeConstantValue()),
        _mockBuildStep(),
      );

      // Assert: Verify generated code contains expected elements
      expect(output, contains('class UserRestRepository'));
      expect(output, contains('implements Repository<User>'));
      expect(output, contains('Future<User> getById(UuidValue id)'));
      expect(output, contains('Future<void> save(User aggregate)'));
      expect(output, contains('Future<void> deleteById(UuidValue id)'));
      expect(output, contains("String get _resourcePath => '/users'"));
      expect(output, contains('final _serializer = UserJsonSerializer()'));
      expect(output, contains('RepositoryException _mapHttpException'));
      expect(
        output,
        contains("headers: {'Accept': 'application/json'}"),
      );
      expect(
        output,
        contains("'Content-Type': 'application/json'"),
      );
      expect(
        RegExp(r"headers: \{'Accept': 'application/json'\}").allMatches(output),
        hasLength(2),
      );
    });

    test('custom methods preserve Dart parameter and type parameter forms',
        () async {
      final library = await resolveSource(
        '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_repository_rest/dddart_repository_rest.dart';

abstract interface class UserRepository implements Repository<User> {
  Future<R> transform<R extends Object>(
    R value, {
    required bool enabled,
    String label = 'default',
  });

  Future<List<User>> page(int offset, [int limit = 20]);
}

@Serializable()
@GenerateRestRepository(implements: UserRepository)
class User extends AggregateRoot {
  User({required this.name});

  final String name;
}
''',
        (resolver) async => (await resolver.findLibraryByName('test'))!,
      );

      final classElement = library.topLevelElements
          .whereType<ClassElement>()
          .firstWhere((element) => element.name == 'User');
      final annotation = classElement.metadata.firstWhere(
        (metadata) =>
            metadata.computeConstantValue()?.type?.element?.name ==
            'GenerateRestRepository',
      );

      final output = generator.generateForAnnotatedElement(
        classElement,
        ConstantReader(annotation.computeConstantValue()),
        _mockBuildStep(),
      );

      expect(
        output,
        contains(
          'Future<R> transform<R extends Object>(R value, '
          "{required bool enabled, String label = 'default'});",
        ),
      );
      expect(
        output,
        contains('Future<List<User>> page(int offset, [int limit = 20]);'),
      );
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
