/// Public generator characterization across analyzer API versions.
@Tags(['generator'])
library;

import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:dddart_json/src/generators/serializable_generator.dart';
import 'package:source_gen/source_gen.dart';
import 'package:test/test.dart';

class _Step implements BuildStep {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<String> _generate(String declaration) async {
  final library = await resolveSource(
    '''
library fixture;
import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_json/dddart_json.dart';
@Serializable()
$declaration
''',
    (resolver) async => (await resolver.findLibraryByName('fixture'))!,
    readAllSourcesFromFilesystem: true,
  );
  final element = library.children.firstWhere((e) => e.name == 'Sample');
  final annotation = element.metadata.annotations.firstWhere(
    (a) => a.computeConstantValue()?.type?.element?.name == 'Serializable',
  );
  return SerializableGenerator().generateForAnnotatedElement(
    element,
    ConstantReader(annotation.computeConstantValue()),
    _Step(),
  );
}

void main() {
  test(
    'preserves nullable and collection fields in a generated part',
    () async {
      final output = await _generate('''
class Sample extends AggregateRoot {
  Sample({required this.name, required this.tags, this.count});
  final String name;
  final List<String> tags;
  final int? count;
}
''');
      expect(output, contains('Sample'));
      expect(output, contains('name'));
      expect(output, contains('tags'));
      expect(output, contains('count'));
      expect(output, isNot(contains("import '")));
      expect(output, isNot(contains('part of')));
    },
  );
  test('rejects non-class annotation', () async {
    await expectLater(
      _generate('void Sample() {}'),
      throwsA(isA<InvalidGenerationSourceError>()),
    );
  });
}
