/// Public binding validation fails at generation time, before emitting bad code.
@Tags(['generator'])
library;

import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:dddart_repository_dynamodb/src/generators/dynamo_repository_generator.dart';
import 'package:source_gen/source_gen.dart';
import 'package:test/test.dart';

class _Step implements BuildStep {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<String> _generate(
  String configuration, {
  String serializerModel = 'RemoteRecord',
  String interfaceModel = 'RemoteRecord',
  bool generic = false,
  bool fakeSerializer = false,
  String constructor = 'Codec();',
  String customMethods = '',
}) async {
  final library = await resolveSource(
    '''
library fixture;
import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_repository_dynamodb/dddart_repository_dynamodb.dart';
class RemoteRecord${generic ? '<T>' : ''} extends AggregateRoot {}
${fakeSerializer ? 'abstract interface class JsonSerializer<T> {}' : ''}
class OtherRecord extends AggregateRoot {}
class Codec implements JsonSerializer<$serializerModel> { $constructor dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i); }
abstract interface class Port implements Repository<$interfaceModel> { $customMethods }
@GenerateDynamoRepository($configuration)
class Binding {}
''',
    (r) async => (await r.findLibraryByName('fixture'))!,
    readAllSourcesFromFilesystem: true,
  );
  final binding = library.classes.firstWhere((c) => c.name == 'Binding');
  final annotation = binding.metadata.annotations.first.computeConstantValue();
  return DynamoRepositoryGenerator().generateForAnnotatedElement(
    binding,
    ConstantReader(annotation),
    _Step(),
  );
}

void main() {
  const valid =
      "aggregateType: RemoteRecord, serializerType: Codec, generatedBaseName: 'Probe'";
  test(
    'rejects unsupported custom record signatures before emission',
    () async {
      await expectLater(
        _generate(
          '$valid, implements: Port',
          customMethods: 'Future<(RemoteRecord, int)> tuple();',
        ),
        throwsA(
          isA<InvalidGenerationSourceError>().having(
            (e) => e.message,
            'message',
            contains('Record-valued'),
          ),
        ),
      );
    },
  );
  test('rejects unsupported object defaults with a targeted error', () async {
    await expectLater(
      _generate(
        '$valid, implements: Port',
        customMethods:
            'Future<RemoteRecord> find({Duration delay = const Duration(seconds: 1)});',
      ),
      throwsA(
        isA<InvalidGenerationSourceError>().having(
          (e) => e.message,
          'message',
          contains('Unsupported default for delay'),
        ),
      ),
    );
  });

  test('uses explicit model serializer and generated base name', () async {
    final code = await _generate(valid);
    expect(code, contains('class ProbeDynamoRepository'));
    expect(code, contains('Future<RemoteRecord> getById'));
    expect(code, contains('final _serializer = Codec()'));
    expect(code, isNot(contains('BindingJsonSerializer')));
  });
  test('accepts correctly typed custom repository interface', () async {
    expect(
      await _generate('$valid, implements: Port'),
      contains('implements Port'),
    );
  });
  test('rejects mismatched serializer aggregate', () async {
    await expectLater(
      _generate(valid, serializerModel: 'OtherRecord'),
      throwsA(isA<InvalidGenerationSourceError>()),
    );
  });
  test('rejects mismatched repository interface aggregate', () async {
    await expectLater(
      _generate('$valid, implements: Port', interfaceModel: 'OtherRecord'),
      throwsA(isA<InvalidGenerationSourceError>()),
    );
  });
  test('rejects missing explicit serializer', () async {
    await expectLater(
      _generate("aggregateType: RemoteRecord, generatedBaseName: 'Probe'"),
      throwsA(isA<InvalidGenerationSourceError>()),
    );
  });
  test('rejects invalid generated identifier', () async {
    await expectLater(
      _generate(
        "aggregateType: RemoteRecord, serializerType: Codec, generatedBaseName: 'Bad-Name'",
      ),
      throwsA(isA<InvalidGenerationSourceError>()),
    );
  });
  test('rejects an unrelated same-name serializer contract', () async {
    await expectLater(
      _generate(valid, fakeSerializer: true),
      throwsA(isA<InvalidGenerationSourceError>()),
    );
  });
  test(
    'rejects a serializer without a public argument-free constructor',
    () async {
      await expectLater(
        _generate(valid, constructor: 'Codec(String requiredValue);'),
        throwsA(isA<InvalidGenerationSourceError>()),
      );
    },
  );
  test('preserves nullable generic model arguments', () async {
    final code = await _generate(
      "aggregateType: RemoteRecord<String?>, serializerType: Codec, generatedBaseName: 'Probe'",
      generic: true,
      serializerModel: 'RemoteRecord<String?>',
    );
    expect(code, contains('Future<RemoteRecord<String?>> getById'));
  });
  test(
    'configuration literals that equal a model name retain their bytes',
    () async {
      final code = await _generate("$valid, tableName: 'RemoteRecord'");
      expect(code, contains("'RemoteRecord'"));
    },
  );
  test(
    'prefixed type references never rewrite configuration literals',
    () async {
      final library = await resolveSources(
        {
          'fixture|lib/model.dart': '''
import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
class RemoteRecord extends AggregateRoot {}
class Codec implements JsonSerializer<RemoteRecord> { Codec(); dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i); }
''',
          'fixture|lib/binding.dart': '''
import 'package:dddart_repository_dynamodb/dddart_repository_dynamodb.dart';
import 'model.dart' as shared;
@GenerateDynamoRepository(aggregateType: shared.RemoteRecord, serializerType: shared.Codec, generatedBaseName: 'Probe', tableName: 'RemoteRecord')
class Binding {}
''',
        },
        (resolver) =>
            resolver.libraryFor(AssetId('fixture', 'lib/binding.dart')),
        rootPackage: 'fixture',
        resolverFor: 'fixture|lib/binding.dart',
        readAllSourcesFromFilesystem: true,
      );
      final binding = library.classes.single;
      final code = DynamoRepositoryGenerator().generateForAnnotatedElement(
        binding,
        ConstantReader(
          binding.metadata.annotations.first.computeConstantValue(),
        ),
        _Step(),
      );
      expect(code, contains('Future<shared.RemoteRecord> getById'));
      expect(code, contains('final _serializer = shared.Codec()'));
      expect(code, contains("'RemoteRecord'"));
      expect(code, isNot(contains("'shared.RemoteRecord'")));
    },
  );
  test(
    'prefixed custom query signature preserves names and nullable types',
    () async {
      final library = await resolveSources(
        {
          'fixture|lib/model.dart': '''
import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
class RemoteRecord extends AggregateRoot {}
class Filter {}
const _pageSize = 20;
class Codec implements JsonSerializer<RemoteRecord> { Codec(); dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i); }
abstract interface class Port implements Repository<RemoteRecord> { Future<RemoteRecord?> find({required Filter filter, int? limit}); Future<RemoteRecord Function(RemoteRecord)> callback({int take = _pageSize}); }
''',
          'fixture|lib/binding.dart': '''
import 'package:dddart_repository_dynamodb/dddart_repository_dynamodb.dart';
import 'model.dart' as shared;
@GenerateDynamoRepository(aggregateType: shared.RemoteRecord, serializerType: shared.Codec, generatedBaseName: 'Probe', implements: shared.Port)
class Binding {}
''',
        },
        (r) => r.libraryFor(AssetId('fixture', 'lib/binding.dart')),
        rootPackage: 'fixture',
        resolverFor: 'fixture|lib/binding.dart',
        readAllSourcesFromFilesystem: true,
      );
      final binding = library.classes.single;
      final code = DynamoRepositoryGenerator().generateForAnnotatedElement(
        binding,
        ConstantReader(
          binding.metadata.annotations.first.computeConstantValue(),
        ),
        _Step(),
      );
      expect(
        code,
        contains(
          'Future<shared.RemoteRecord?> find({required shared.Filter filter, int? limit})',
        ),
      );
      expect(
        code,
        contains('Future<shared.RemoteRecord Function(shared.RemoteRecord'),
      );
      expect(code, contains('int take = 20'));
      expect(code, isNot(contains('_pageSize')));
    },
  );
  test('invalid annotation table name fails before code emission', () async {
    await expectLater(
      _generate("$valid, tableName: 'ab'"),
      throwsA(isA<InvalidGenerationSourceError>()),
    );
  });
}
