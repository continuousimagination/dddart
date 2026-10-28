import 'dart:io';

import 'package:test/test.dart';

void main() {
  test(
    'a clean consumer compiles explicit custom read implementations',
    () async {
      final packageRoot = _findPackageRoot();
      final packagesRoot = packageRoot.parent;
      final fixture = Directory.systemTemp.createTempSync(
        'dddart_repository_sqlite_clean_consumer_',
      );
      addTearDown(() => fixture.deleteSync(recursive: true));

      File('${fixture.path}/pubspec.yaml').writeAsStringSync('''
name: dddart_repository_sqlite_clean_consumer
publish_to: none

environment:
  sdk: '>=3.5.0 <4.0.0'

dependencies:
  dddart: any
  dddart_json: any
  dddart_repository_sqlite:
    path: ${packageRoot.path}
  dddart_serialization: any

dev_dependencies:
  build_runner: ^2.4.0

dependency_overrides:
  dddart:
    path: ${packagesRoot.path}/dddart
  dddart_json:
    path: ${packagesRoot.path}/dddart_json
  dddart_repository_sql:
    path: ${packagesRoot.path}/dddart_repository_sql
  dddart_serialization:
    path: ${packagesRoot.path}/dddart_serialization
''');

      final libDirectory = Directory('${fixture.path}/lib')..createSync();
      File('${libDirectory.path}/model.dart').writeAsStringSync(
        '''
import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_repository_sqlite/dddart_repository_sqlite.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

__GENERATED_PART_DIRECTIVE__

class NativeIdentity extends Identity {
  const NativeIdentity(this.value);
  final String value;
  @override List<Object?> get props => [value];
}

class NativeIdentityCodec implements IdentityCodec<NativeIdentity> {
  @override String toJson(NativeIdentity id) => id.value;
  @override NativeIdentity fromJson(Object? value) => NativeIdentity(value as String);
  @override String toKey(NativeIdentity id) => id.value;
  @override NativeIdentity fromKey(String key) => NativeIdentity(key);
}

abstract interface class BroadConsumerReads {
  Future<Iterable<ConsumerAggregate>> getAll();
}

abstract interface class ConsumerRepository
    implements Repository<ConsumerAggregate, NativeIdentity>, BroadConsumerReads {
  @override
  Future<List<ConsumerAggregate>> getAll();

  Future<List<ConsumerAggregate>> scanPage({required int limit});

  Future<ConsumerAggregate?> findBySlug(String slug);
}

@Serializable()
@GenerateSqliteRepository(
  tableName: 'consumer_aggregates',
  implements: ConsumerRepository,
)
class ConsumerAggregate extends AggregateRoot<NativeIdentity> {
  ConsumerAggregate({
    required this.slug,
    required super.id,
    super.createdAt,
    super.updatedAt,
  });

  final String slug;
}

class ConsumerAggregateRepository
    extends ConsumerAggregateSqliteRepositoryBase {
  ConsumerAggregateRepository(super.connection, {super.identityCodecs});

  @override
  Future<List<ConsumerAggregate>> getAll() =>
      Future.value(<ConsumerAggregate>[]);

  @override
  Future<List<ConsumerAggregate>> scanPage({required int limit}) =>
      Future.value(<ConsumerAggregate>[]);

  @override
  Future<ConsumerAggregate?> findBySlug(String slug) => Future.value();
}
'''
            .replaceFirst(
          '__GENERATED_PART_DIRECTIVE__',
          "part 'model.g.dart';",
        ),
      );

      final binDirectory = Directory('${fixture.path}/bin')..createSync();
      File('${binDirectory.path}/main.dart').writeAsStringSync('''
import 'package:dddart_repository_sqlite/dddart_repository_sqlite.dart';
import 'package:dddart_repository_sqlite_clean_consumer/model.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

ConsumerRepository createRepository(SqliteConnection connection) =>
    ConsumerAggregateRepository(connection);

void main() {
  final connection = SqliteConnection.memory();
  createRepository(connection);
  final codecs = IdentityCodecRegistry()..register<NativeIdentity>('native',NativeIdentityCodec());
  final repository = ConsumerAggregateRepository(connection, identityCodecs:codecs);
  Future<ConsumerAggregate> Function(NativeIdentity) lookup = repository.getById;
  Future<void> Function(NativeIdentity) delete = repository.deleteById;
  final serializer = ConsumerAggregateJsonSerializer.withIdentityCodecs(codecs);
  final original = ConsumerAggregate(id:const NativeIdentity('native/%, café'),slug:'issue');
  if(serializer.deserialize(serializer.serialize(original)).id!=original.id || lookup == delete) throw StateError('Typed identity failed');
  connection.close();
}
''');

      await _expectDartSuccess(fixture, ['pub', 'get', '--offline']);
      await _expectDartSuccess(
        fixture,
        [
          'run',
          'build_runner',
          'build',
          '--delete-conflicting-outputs',
        ],
      );

      final generatedFile = File('${libDirectory.path}/model.g.dart');
      expect(generatedFile.existsSync(), isTrue);
      final generated = generatedFile.readAsStringSync();
      expect(
        _occurrenceCount(
          generated,
          'Future<List<ConsumerAggregate>> getAll();',
        ),
        1,
      );
      expect(
        generated,
        isNot(contains('Future<Iterable<ConsumerAggregate>> getAll();')),
      );
      expect(
        _occurrenceCount(
          generated,
          'Future<List<ConsumerAggregate>> scanPage({required int limit});',
        ),
        1,
      );
      expect(
        _occurrenceCount(
          generated,
          'Future<ConsumerAggregate?> findBySlug(String slug);',
        ),
        1,
      );
      expect(generated, isNot(contains('_connection.client.scan')));

      await _expectDartSuccess(fixture, ['analyze', '--fatal-infos']);
      Directory('${fixture.path}/build').createSync();
      await _expectDartSuccess(
        fixture,
        [
          'compile',
          'kernel',
          'bin/main.dart',
          '-o',
          'build/main.dill',
        ],
      );
      await _expectDartSuccess(fixture, ['run', 'bin/main.dart']);
      for (final operation in ['getById', 'deleteById']) {
        File('${binDirectory.path}/wrong_identity.dart').writeAsStringSync('''
import 'package:dddart/dddart.dart';
import 'package:dddart_repository_sqlite_clean_consumer/model.dart';
class OtherIdentity extends Identity {
  const OtherIdentity();
  @override List<Object?> get props => const [];
}
void invalid(ConsumerAggregateRepository repository) {
  repository.$operation(const OtherIdentity());
}
void main() {}
''');
        final rejected = await Process.run(
          Platform.resolvedExecutable,
          [
            'compile',
            'kernel',
            'bin/wrong_identity.dart',
            '-o',
            'build/wrong.dill',
          ],
          workingDirectory: fixture.path,
        );
        final diagnostic = '${rejected.stdout}\n${rejected.stderr}';
        expect(rejected.exitCode, isNot(0), reason: diagnostic);
        expect(diagnostic, contains('OtherIdentity'), reason: diagnostic);
        expect(diagnostic, contains('NativeIdentity'), reason: diagnostic);
        expect(diagnostic, contains("can't be assigned"), reason: diagnostic);
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

Directory _findPackageRoot() {
  var current = Directory.current.absolute;
  while (current.parent.path != current.path) {
    final pubspec = File('${current.path}/pubspec.yaml');
    if (pubspec.existsSync() &&
        pubspec
            .readAsStringSync()
            .contains('name: dddart_repository_sqlite\n')) {
      return current;
    }
    current = current.parent;
  }
  throw StateError(
    'Could not locate the dddart_repository_sqlite package root.',
  );
}

int _occurrenceCount(String source, String value) =>
    source.split(value).length - 1;

Future<void> _expectDartSuccess(
  Directory workingDirectory,
  List<String> arguments,
) async {
  final result = await Process.run(
    Platform.resolvedExecutable,
    arguments,
    workingDirectory: workingDirectory.path,
    environment: {
      ...Platform.environment,
      'CI': 'true',
    },
  );

  expect(
    result.exitCode,
    0,
    reason: [
      'dart ${arguments.join(' ')} failed in ${workingDirectory.path}',
      result.stdout,
      result.stderr,
    ].join('\n'),
  );
}
