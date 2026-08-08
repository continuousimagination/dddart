import 'dart:io';

import 'package:test/test.dart';

void main() {
  test(
    'generation rejects inherited state without a named super-formal chain',
    () async {
      final packageRoot = _findPackageRoot();
      final packagesRoot = packageRoot.parent;
      final fixture = Directory.systemTemp.createTempSync(
        'dddart_json_inherited_state_failure_',
      );
      addTearDown(() => fixture.deleteSync(recursive: true));

      File('${fixture.path}/pubspec.yaml').writeAsStringSync('''
name: dddart_json_inherited_state_failure
publish_to: none

environment:
  sdk: '>=3.5.0 <4.0.0'

dependencies:
  dddart_json:
    path: ${packageRoot.path}

dev_dependencies:
  build_runner: ^2.4.0

dependency_overrides:
  dddart:
    path: ${packagesRoot.path}/dddart
  dddart_serialization:
    path: ${packagesRoot.path}/dddart_serialization
''');

      final libDirectory = Directory('${fixture.path}/lib')..createSync();
      File('${libDirectory.path}/model.dart').writeAsStringSync(
        '''
import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

__GENERATED_PART_DIRECTIVE__

abstract class InheritedStateBase extends Value {
  const InheritedStateBase({required this.baseState});

  final String baseState;
}

@Serializable()
class MissingInheritedPath extends InheritedStateBase {
  const MissingInheritedPath({required this.childState})
      : super(baseState: 'defaulted');

  final String childState;

  @override
  List<Object?> get props => [baseState, childState];
}
'''
            .replaceFirst(
          '__GENERATED_PART_DIRECTIVE__',
          "part 'model.g.dart';",
        ),
      );

      await _expectDartSuccess(fixture, ['pub', 'get', '--offline']);

      final result = await _runDart(
        fixture,
        [
          'run',
          'build_runner',
          'build',
          '--delete-conflicting-outputs',
        ],
      );
      final output = '${result.stdout}\n${result.stderr}';

      expect(result.exitCode, isNot(0), reason: output);
      expect(
        output,
        contains(
          'Cannot generate JSON serializer for MissingInheritedPath: '
          'inherited application field "baseState" has no reconstruction '
          "path through MissingInheritedPath's unnamed constructor and named "
          'super-parameter chain.',
        ),
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

Directory _findPackageRoot() {
  var current = Directory.current.absolute;
  while (current.parent.path != current.path) {
    final pubspec = File('${current.path}/pubspec.yaml');
    if (pubspec.existsSync() &&
        pubspec.readAsStringSync().contains('name: dddart_json\n')) {
      return current;
    }
    current = current.parent;
  }
  throw StateError('Could not locate the dddart_json package root.');
}

Future<ProcessResult> _runDart(
  Directory workingDirectory,
  List<String> arguments,
) {
  return Process.run(
    Platform.resolvedExecutable,
    arguments,
    workingDirectory: workingDirectory.path,
    environment: {
      ...Platform.environment,
      'CI': 'true',
    },
  );
}

Future<void> _expectDartSuccess(
  Directory workingDirectory,
  List<String> arguments,
) async {
  final result = await _runDart(workingDirectory, arguments);

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
