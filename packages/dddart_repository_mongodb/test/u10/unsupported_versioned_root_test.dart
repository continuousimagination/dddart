/// Unsupported conditional persistence fails before generating legacy I/O.
library;

import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:dddart/dddart.dart';
import 'package:dddart_repository_mongodb/src/generators/mongo_repository_generator.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:source_gen/source_gen.dart';
import 'package:test/test.dart';

import '../test_models.dart';

class _Step implements BuildStep {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<String> generate(
  String base, {
  bool conditionalInterface = false,
}) async {
  final library = await resolveSource(
    """
library fixture;
import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_repository_mongodb/dddart_repository_mongodb.dart';
abstract interface class ConditionalStore implements ConditionalRepository<VersionedAggregateRoot> {}
@Serializable()
@GenerateMongoRepository(implements: ${conditionalInterface ? 'ConditionalStore' : 'null'})
class Sample extends $base {
  Sample({required this.name});
  final String name;
}
""",
    (resolver) async => (await resolver.findLibraryByName('fixture'))!,
    readAllSourcesFromFilesystem: true,
  );
  final element = library.children.firstWhere((e) => e.name == 'Sample');
  final annotation = element.metadata.annotations.firstWhere(
    (a) =>
        a.computeConstantValue()?.type?.element?.name ==
        'GenerateMongoRepository',
  );
  return MongoRepositoryGenerator().generateForAnnotatedElement(
    element,
    ConstantReader(annotation.computeConstantValue()),
    _Step(),
  );
}

void main() {
  test(
    'conditional custom interface is rejected before ordinary emission',
    () async {
      await expectLater(
        generate('AggregateRoot', conditionalInterface: true),
        throwsA(
          isA<InvalidGenerationSourceError>().having(
            (e) => e.message,
            'message',
            contains('conditional repository interfaces'),
          ),
        ),
      );
    },
  );

  test(
    'actual generated widened save rejects before touching connection',
    () async {
      final connection = _UnusedConnection();
      final repository = TestUserMongoRepository(connection);
      await expectLater(
        repository.save(_VersionedSubtype()),
        throwsA(isA<RepositoryCapabilityException>()),
      );
      expect(connection.calls, 0);
    },
  );

  test(
    'versioned roots are rejected explicitly before legacy emission',
    () async {
      await expectLater(
        generate('VersionedAggregateRoot'),
        throwsA(
          isA<InvalidGenerationSourceError>().having(
            (e) => e.message,
            'message',
            contains('conditional'),
          ),
        ),
      );
    },
  );
  test(
    'ordinary root generation retains a runtime widened-value guard',
    () async {
      final source = await generate('AggregateRoot');
      expect(source, contains('aggregate is VersionedAggregateRoot'));
      expect(
        source.indexOf('aggregate is VersionedAggregateRoot'),
        lessThan(source.indexOf('try {', source.indexOf('Future<void> save'))),
      );
    },
  );
}

class _UnusedConnection implements Db {
  int calls = 0;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls++;
    throw StateError('Unexpected I/O');
  }
}

class _VersionedSubtype extends TestUser implements VersionedAggregateRoot {
  _VersionedSubtype() : super(name: 'test', email: 'test');
  @override
  Revision get revision => const Revision.zero();
}
