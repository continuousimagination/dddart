/// Characterizes SQLite generator output across the analyzer migration.
@Tags(['generator'])
library;

import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:dddart_repository_sqlite/src/generators/sqlite_repository_generator.dart';
import 'package:source_gen/source_gen.dart';
import 'package:test/test.dart';

class _Step implements BuildStep {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<String> _generate(String source, String name) async {
  final library = await resolveSource(
    '''
library fixture;
import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_repository_sqlite/dddart_repository_sqlite.dart';
$source
''',
    (resolver) async => (await resolver.findLibraryByName('fixture'))!,
    readAllSourcesFromFilesystem: true,
  );
  final element = library.children.firstWhere((e) => e.name == name);
  final annotation = element.metadata.annotations.firstWhere(
    (a) =>
        a.computeConstantValue()?.type?.element?.name ==
        'GenerateSqliteRepository',
  );
  return SqliteRepositoryGenerator().generateForAnnotatedElement(
    element,
    ConstantReader(annotation.computeConstantValue()),
    _Step(),
  );
}

void main() {
  test(
    'inherited identity and nested values retain generated ownership',
    () async {
      final output = await _generate('''
class Label extends Value {
  Label(this.text);
  final String text;
  @override List<Object?> get props => [text];
}
@Serializable()
@GenerateSqliteRepository()
class Entry extends AggregateRoot {
  Entry({required this.label, super.id, super.createdAt, super.updatedAt});
  final Label label;
}
''', 'Entry');
      expect(output, contains('class EntrySqliteRepository'));
      expect(output, contains('Future<Entry> getById'));
      expect(output, contains('createdAt'));
      expect(output, contains('label'));
      expect(output, isNot(contains('part of')));
      expect(output, isNot(contains("import '")));
    },
  );
  test('rejects a non-aggregate without silently generating storage', () async {
    await expectLater(
      _generate('''
@Serializable()
@GenerateSqliteRepository()
class Invalid { Invalid(); }
''', 'Invalid'),
      throwsA(isA<InvalidGenerationSourceError>()),
    );
  });
  test('rejects non-class annotations', () async {
    await expectLater(
      _generate('''
@GenerateSqliteRepository()
void invalid() {}
''', 'invalid'),
      throwsA(isA<InvalidGenerationSourceError>()),
    );
  });
}
