@Tags(['generator'])
library;

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:dddart_repository_dynamodb/src/generators/dynamo_repository_generator.dart';
import 'package:source_gen/source_gen.dart';
import 'package:test/test.dart';

void main() {
  test('preserves generic, positional, named, and default parameters',
      () async {
    final library = await resolveSource(
      '''
library signature_fixture;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_repository_dynamodb/dddart_repository_dynamodb.dart';

abstract interface class ReportRepository implements Repository<Report> {
  Future<R> transform<R extends Object?>(
    R value, [
    int retries = 3,
    bool? verbose,
  ]);

  Future<List<Report>> search({
    required String term,
    int offset = 0,
    String? cursor,
  });
}

@Serializable()
@GenerateDynamoRepository(
  tableName: 'reports',
  implements: ReportRepository,
)
class Report extends AggregateRoot {
  Report({super.id, super.createdAt, super.updatedAt});
}
''',
      (resolver) async =>
          (await resolver.findLibraryByName('signature_fixture'))!,
    );
    final aggregate = library.topLevelElements
        .whereType<ClassElement>()
        .firstWhere((element) => element.name == 'Report');
    final annotation = aggregate.metadata.firstWhere(
      (metadata) =>
          metadata.computeConstantValue()?.type?.element?.name ==
          'GenerateDynamoRepository',
    );

    final output = DynamoRepositoryGenerator().generateForAnnotatedElement(
      aggregate,
      ConstantReader(annotation.computeConstantValue()),
      _StubBuildStep(),
    );

    expect(
      output,
      contains(
        'Future<R> transform<R extends Object?>(R value, '
        '[int retries = 3, bool? verbose]);',
      ),
    );
    expect(
      output,
      contains(
        'Future<List<Report>> search({required String term, '
        'int offset = 0, String? cursor});',
      ),
    );
  });

  test('emits each custom read once and prefers the most-derived method',
      () async {
    final library = await resolveSource(
      '''
library read_fixture;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_repository_dynamodb/dddart_repository_dynamodb.dart';

abstract interface class BroadReportReads {
  Future<Iterable<Report>> getAll();
}

abstract interface class ReportRepository
    implements Repository<Report>, BroadReportReads {
  @override
  Future<List<Report>> getAll();

  Future<List<Report>> scanPage({required int limit});

  Future<Report?> findBySlug(String slug);
}

@Serializable()
@GenerateDynamoRepository(
  tableName: 'reports',
  implements: ReportRepository,
)
class Report extends AggregateRoot {
  Report({super.id, super.createdAt, super.updatedAt});
}
''',
      (resolver) async => (await resolver.findLibraryByName('read_fixture'))!,
    );
    final aggregate = library.topLevelElements
        .whereType<ClassElement>()
        .firstWhere((element) => element.name == 'Report');
    final annotation = aggregate.metadata.firstWhere(
      (metadata) =>
          metadata.computeConstantValue()?.type?.element?.name ==
          'GenerateDynamoRepository',
    );

    final output = DynamoRepositoryGenerator().generateForAnnotatedElement(
      aggregate,
      ConstantReader(annotation.computeConstantValue()),
      _StubBuildStep(),
    );

    expect(
      _occurrenceCount(output, 'Future<List<Report>> getAll();'),
      1,
    );
    expect(output, isNot(contains('Future<Iterable<Report>> getAll();')));
    expect(
      _occurrenceCount(
        output,
        'Future<List<Report>> scanPage({required int limit});',
      ),
      1,
    );
    expect(
      _occurrenceCount(output, 'Future<Report?> findBySlug(String slug);'),
      1,
    );
    expect(output, isNot(contains('_connection.client.scan')));
  });
}

int _occurrenceCount(String source, String value) =>
    source.split(value).length - 1;

// ignore: subtype_of_sealed_class
class _StubBuildStep implements BuildStep {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
