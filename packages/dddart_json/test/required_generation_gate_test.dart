import 'dart:io';

import 'package:test/test.dart';

void main() {
  late Directory fixture;
  late File generatedOutput;
  late File generationScript;
  late Directory fakeBin;

  setUp(() async {
    final packageRoot = _findPackageRoot();
    generationScript = File(
      '${packageRoot.parent.parent.path}/scripts/run-required-generation.sh',
    );
    fixture = Directory.systemTemp.createTempSync(
      'dddart_required_generation_',
    );
    addTearDown(() => fixture.deleteSync(recursive: true));

    final libDirectory = Directory('${fixture.path}/lib')..createSync();
    File('${libDirectory.path}/model.dart')
        .writeAsStringSync("part 'model.g.dart';\n");
    generatedOutput = File('${libDirectory.path}/model.g.dart');

    fakeBin = Directory('${fixture.path}/fake-bin')..createSync();
    final fakeDart = File('${fakeBin.path}/dart')
      ..writeAsStringSync(
        [
          '#!/bin/bash',
          r'case "${FAKE_GENERATION_RESULT:-generate}" in',
          '  fail)',
          '    exit 42',
          '    ;;',
          '  skip)',
          '    exit 0',
          '    ;;',
          '  generate)',
          '    touch lib/model.g.dart',
          '    ;;',
          'esac',
        ].join('\n'),
      );
    final chmod = await Process.run('chmod', ['+x', fakeDart.path]);
    expect(chmod.exitCode, 0, reason: chmod.stderr as String?);
  });

  Future<ProcessResult> runGeneration(String result) {
    return Process.run(
      'bash',
      [generationScript.path, '.'],
      workingDirectory: fixture.path,
      environment: {
        ...Platform.environment,
        'FAKE_GENERATION_RESULT': result,
        'PATH': '${fakeBin.path}:${Platform.environment['PATH'] ?? ''}',
      },
    );
  }

  test('a failed build is fatal even when stale output existed', () async {
    generatedOutput.writeAsStringSync('// stale output');

    final result = await runGeneration('fail');

    expect(result.exitCode, isNot(0));
    expect(generatedOutput.existsSync(), isFalse);
  });

  test('a successful build must recreate every declared generated part',
      () async {
    final result = await runGeneration('skip');

    expect(result.exitCode, isNot(0));
    expect(
      '${result.stdout}\n${result.stderr}',
      contains('Expected generated output is missing: lib/model.g.dart'),
    );
  });

  test('generation passes after every declared part is recreated', () async {
    final result = await runGeneration('generate');

    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(generatedOutput.existsSync(), isTrue);
  });
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
