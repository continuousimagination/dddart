/// Unsupported conditional persistence fails before generating legacy I/O.
library;

import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:dddart/dddart.dart';
import 'package:dddart_repository_mysql/dddart_repository_mysql.dart';
import 'package:dddart_repository_mysql/src/generators/mysql_repository_generator.dart';
import 'package:source_gen/source_gen.dart';
import 'package:test/test.dart';

import '../integration_test_models.dart';

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
import 'package:dddart_repository_mysql/dddart_repository_mysql.dart';
abstract interface class ConditionalStore implements ConditionalRepository<VersionedAggregateRoot> {}
@Serializable()
@GenerateMysqlRepository(implements: ${conditionalInterface ? 'ConditionalStore' : 'null'})
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
        'GenerateMysqlRepository',
  );
  return MysqlRepositoryGenerator().generateForAnnotatedElement(
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
      final repository = SimpleProductMysqlRepository(connection);
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

class _UnusedConnection implements MysqlConnection {
  int calls = 0;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls++;
    throw StateError('Unexpected I/O');
  }
}

class _VersionedSubtype extends SimpleProduct
    implements VersionedAggregateRoot {
  _VersionedSubtype() : super(name: 'test', price: 1);
  @override
  Revision get revision => const Revision.zero();
}
