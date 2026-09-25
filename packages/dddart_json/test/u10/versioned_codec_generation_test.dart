/// Public generator characterization across analyzer API versions.
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
  test('rejects a second revision field authority', () async {
    await expectLater(
      _generate('''
class Sample extends VersionedAggregateRoot {
  Sample({required this.revision});
  @override
  final Revision revision;
}
'''),
      throwsA(isA<InvalidGenerationSourceError>()),
    );
  });
  test('rejects a second revision getter authority', () async {
    await expectLater(
      _generate('''
class Sample extends VersionedAggregateRoot {
  @override
  Revision get revision => Revision(1);
}
'''),
      throwsA(isA<InvalidGenerationSourceError>()),
    );
  });
  test('rejects an intermediate inherited revision override', () async {
    await expectLater(
      _generate('''
class Sample extends Middle {
  Sample({required super.revision});
}
class Middle extends VersionedAggregateRoot {
  Middle({required this.revision});
  @override
  final Revision revision;
}
'''),
      throwsA(isA<InvalidGenerationSourceError>()),
    );
  });
  test(
    'same-named user types do not acquire framework revision semantics',
    () async {
      final output = await _generate('''
class Sample extends VersionedAggregateRoot {
  Sample({required this.revision});
  final Revision revision;
}
class VersionedAggregateRoot extends AggregateRoot {}
class Revision extends Value {
  const Revision(this.label);
  final String label;
  @override
  List<Object?> get props => [label];
}
''');
      expect(output, contains('RevisionJsonSerializer().toJson'));
      expect(output, isNot(contains('instance.revision.value')));
    },
  );
  test(
    'rejects an effective revision getter supplied by an applied mixin',
    () async {
      await expectLater(
        _generate('''
class Sample extends VersionedAggregateRoot with OverrideRevision {
  Sample({super.revision});
}
mixin OverrideRevision on VersionedAggregateRoot {
  @override
  Revision get revision => Revision(1);
}
'''),
        throwsA(isA<InvalidGenerationSourceError>()),
      );
    },
  );
  test(
    'rejects an interface-only versioned claim without inherited state',
    () async {
      await expectLater(
        _generate('''
class Sample extends AggregateRoot implements VersionedAggregateRoot {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
'''),
        throwsA(isA<InvalidGenerationSourceError>()),
      );
    },
  );
  test(
    'allows benign mixins while retaining the canonical revision getter',
    () async {
      final output = await _generate('''
class Sample extends VersionedAggregateRoot with Benign {
  Sample({super.revision});
}
mixin Benign on VersionedAggregateRoot {
  String describe() => 'benign';
}
''');
      expect(output, contains('instance.revision.value'));
      expect(output, contains('revision: Revision.fromJson('));
    },
  );
}
