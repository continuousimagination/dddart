import 'dart:io';

import 'package:test/test.dart';

void main() {
  test(
    'generation rejects erased identities and unsupported key declarations',
    () async {
      var root = Directory.current.absolute;
      while (!File('${root.path}/pubspec.yaml').existsSync() ||
          !File('${root.path}/pubspec.yaml')
              .readAsStringSync()
              .contains('name: dddart_json\n')) {
        if (root.parent.path == root.path) {
          throw StateError('JSON package root not found');
        }
        root = root.parent;
      }
      final fixture =
          Directory.systemTemp.createTempSync('identity_generation_failure_');
      addTearDown(() => fixture.deleteSync(recursive: true));
      File('${fixture.path}/pubspec.yaml').writeAsStringSync('''
name: identity_generation_failure
publish_to: none
environment:
  sdk: '>=3.5.0 <4.0.0'
dependencies:
  dddart_json:
    path: ${root.path}
dev_dependencies:
  build_runner: ^2.4.0
dependency_overrides:
  dddart:
    path: ${root.parent.path}/dddart
  dddart_serialization:
    path: ${root.parent.path}/dddart_serialization
''');
      final lib = Directory('${fixture.path}/lib')..createSync();
      Future<ProcessResult> run(List<String> arguments) => Process.run(
            Platform.resolvedExecutable,
            ['--suppress-analytics', ...arguments],
            workingDirectory: fixture.path,
            environment: {...Platform.environment, 'CI': 'true'},
          );
      final resolved = await run(['pub', 'get', '--offline']);
      expect(
        resolved.exitCode,
        0,
        reason: '${resolved.stdout}\n${resolved.stderr}',
      );
      const cases = <String, String>{
        '''
@Serializable()
class ErasedIdentity extends AggregateRoot<Identity> {
  ErasedIdentity({required super.id, super.createdAt, super.updatedAt});
}
''': 'must specify a concrete identity type',
        '''
@Serializable()
class OpenIdentity<I extends Identity> extends AggregateRoot<I> {
  OpenIdentity({required super.id, super.createdAt, super.updatedAt});
}
''': 'Annotate a concrete non-generic consuming class',
        '''
@Serializable()
class UnsupportedKeys extends Value {
  const UnsupportedKeys({required this.labels});
  final Map<int, String> labels;
  @override List<Object?> get props => [labels];
}
''': 'JSON map keys must be non-null strings or concrete identities',
      };
      for (final entry in cases.entries) {
        final source = '''
import 'dart:convert';
import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
__GENERATED_PART_DIRECTIVE__
${entry.key}
'''
            .replaceFirst(
          '__GENERATED_PART_DIRECTIVE__',
          "part 'model.g.dart';",
        );
        File('${lib.path}/model.dart').writeAsStringSync(source);
        final result = await run(
          ['run', 'build_runner', 'build', '--delete-conflicting-outputs'],
        );
        final output = '${result.stdout}\n${result.stderr}';
        expect(result.exitCode, isNot(0), reason: output);
        expect(output, contains(entry.value), reason: output);
        expect(File('${lib.path}/model.g.dart').existsSync(), isFalse);
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
