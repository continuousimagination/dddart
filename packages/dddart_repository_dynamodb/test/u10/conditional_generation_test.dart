/// Conditional binding validation and legacy refusal contracts.
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

Future<String> _generate({
  bool conditional = true,
  bool versioned = true,
  String? port,
  bool fakeBase = false,
  bool shadow = false,
  String authority = 'normal',
  bool wrongPort = false,
  bool reserved = false,
  String members = '',
  bool inheritedPort = false,
}) async {
  final library = await resolveSource(
    """
library fixture;
import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_repository_dynamodb/dddart_repository_dynamodb.dart';
${fakeBase ? 'class VersionedAggregateRoot extends AggregateRoot {}' : ''}
class Record extends ${authority == 'interface'
        ? 'AggregateRoot implements VersionedAggregateRoot'
        : versioned
        ? 'VersionedAggregateRoot'
        : 'AggregateRoot'} ${authority == 'mixin' ? 'with OverrideRevision' : ''} {
  ${shadow ? 'Revision get revision => Revision(1);' : ''}
  ${authority == 'interface' ? 'dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);' : ''}
  ${reserved ? 'final bool __dddart_retired = false;' : ''}
}
mixin OverrideRevision on VersionedAggregateRoot { Revision get revision => Revision(1); }
class OtherRecord extends VersionedAggregateRoot {}
class Codec implements JsonSerializer<Record> {
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
abstract interface class ParentPort<R extends VersionedAggregateRoot> implements ConditionalRepository<R> {
  ${inheritedPort ? members.replaceAll('%MODEL%', 'R') : ''}
}
abstract interface class ConditionalPort implements ${inheritedPort ? 'ParentPort<Record>' : "ConditionalRepository<${wrongPort ? 'OtherRecord' : 'Record'}>"} {
  ${inheritedPort ? '' : members.replaceAll('%MODEL%', 'Record')}
}
abstract interface class LegacyPort implements Repository<Record> {}
@GenerateDynamoRepository(aggregateType: Record, serializerType: Codec,
  generatedBaseName: 'Probe', conditionalWrites: $conditional,
  implements: ${port ?? 'null'}, tableName: 'VersionedRecord',)
class Binding {}
""",
    (r) async => (await r.findLibraryByName('fixture'))!,
    readAllSourcesFromFilesystem: true,
  );
  final element = library.classes.firstWhere((c) => c.name == 'Binding');
  return DynamoRepositoryGenerator().generateForAnnotatedElement(
    element,
    ConstantReader(element.metadata.annotations.first.computeConstantValue()),
    _Step(),
  );
}

void main() {
  test('emits typed conditional repository with explicit mode', () async {
    final code = await _generate();
    expect(code, contains('DynamoConditionalRepository<Record>'));
    expect(code, isNot(contains('Future<void> save(')));
  });
  test('accepts matching conditional interface', () async {
    expect(
      await _generate(port: 'ConditionalPort'),
      contains('implements ConditionalPort'),
    );
  });
  test(
    'rejects every legacy/versioned and conditional/ordinary mismatch',
    () async {
      for (final action in [
        () => _generate(conditional: false),
        () => _generate(versioned: false),
        () => _generate(port: 'LegacyPort'),
        () => _generate(
          conditional: false,
          versioned: false,
          port: 'ConditionalPort',
        ),
      ]) {
        await expectLater(
          action(),
          throwsA(isA<InvalidGenerationSourceError>()),
        );
      }
    },
  );
  test(
    'rejects unrelated same-name versioned root and overridden authority',
    () async {
      await expectLater(
        _generate(fakeBase: true),
        throwsA(isA<InvalidGenerationSourceError>()),
      );
      await expectLater(
        _generate(shadow: true),
        throwsA(isA<InvalidGenerationSourceError>()),
      );
    },
  );

  test('rejects mixin and interface-only revision authorities', () async {
    for (final authority in ['mixin', 'interface']) {
      await expectLater(
        _generate(authority: authority),
        throwsA(isA<InvalidGenerationSourceError>()),
      );
    }
  });
  test(
    'rejects a mismatched conditional port and reserved model metadata',
    () async {
      await expectLater(
        _generate(port: 'ConditionalPort', wrongPort: true),
        throwsA(isA<InvalidGenerationSourceError>()),
      );
      await expectLater(
        _generate(reserved: true),
        throwsA(isA<InvalidGenerationSourceError>()),
      );
    },
  );

  test(
    'rejects optional preconditions and extra save parameters before emission',
    () async {
      for (final members in [
        'Future<%MODEL%> save(%MODEL% value, {WritePrecondition precondition = const WritePrecondition.absent()});',
        'Future<%MODEL%> save(%MODEL% value, {required WritePrecondition precondition, bool audit = false});',
      ]) {
        for (final inherited in [false, true]) {
          await expectLater(
            _generate(
              port: 'ConditionalPort',
              members: members,
              inheritedPort: inherited,
            ),
            throwsA(
              isA<InvalidGenerationSourceError>().having(
                (error) => error.message,
                'member',
                contains('save'),
              ),
            ),
          );
        }
      }
    },
  );
  test(
    'rejects unsupported read/delete parameter, return and generic shapes',
    () async {
      for (final (name, members) in [
        (
          'getById',
          'Future<%MODEL%> getById(UuidValue id, {bool cached = false});',
        ),
        ('getById', 'Future<%MODEL%> getById(Object id);'),
        ('getById', 'Future<Never> getById(UuidValue id);'),
        ('getById', 'Future<T> getById<T extends %MODEL%>(UuidValue id);'),
        (
          'deleteById',
          'Future<void> deleteById(UuidValue id, {WritePrecondition precondition = const WritePrecondition.absent()});',
        ),
        (
          'deleteById',
          'Future<void> deleteById(UuidValue id, {required WritePrecondition precondition, bool audit = false});',
        ),
      ]) {
        await expectLater(
          _generate(port: 'ConditionalPort', members: members),
          throwsA(
            isA<InvalidGenerationSourceError>().having(
              (error) => error.message,
              'member',
              contains(name),
            ),
          ),
        );
      }
    },
  );
  test(
    'preserves exact direct and generically inherited redeclarations plus queries',
    () async {
      const members = '''
Future<%MODEL%> getById(UuidValue key);
Future<%MODEL%> save(%MODEL% value, {required WritePrecondition precondition});
Future<void> deleteById(UuidValue key, {required WritePrecondition precondition});
Future<String> label();
''';
      for (final inherited in [false, true]) {
        final code = await _generate(
          port: 'ConditionalPort',
          members: members,
          inheritedPort: inherited,
        );
        expect(code, contains('implements ConditionalPort'));
        expect(code, contains('Future<String> label()'));
      }
    },
  );
}
