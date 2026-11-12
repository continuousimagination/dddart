import 'dart:convert';
import 'dart:io';

import 'validation_core.dart';

/// Verifies the core/IndexedDB Git closure at an immutable published revision.
///
/// Run after Worky publishes the candidate, and again at the accepted main SHA.
Future<void> main(List<String> arguments) async {
  if (arguments.isEmpty ||
      arguments.length > 2 ||
      !RegExp(r'^[0-9a-f]{40}$').hasMatch(arguments.first)) {
    stderr.writeln(
      'Usage: dart tool/validation/verify_indexeddb_git_consumer.dart <full-sha> [repository-url]',
    );
    exitCode = 64;
    return;
  }
  final sha = arguments.first;
  final repository = arguments.length == 2
      ? arguments[1]
      : 'https://github.com/continuousimagination/dddart.git';
  final uri = Uri.parse(repository);
  if (!{'https', 'file'}.contains(uri.scheme) ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment) {
    throw ArgumentError('Use an unauthenticated HTTPS or local file Git URL');
  }
  final root = File.fromUri(Platform.script).parent.parent.parent;
  final fixture = File(
    '${root.path}/packages/dddart_repository_indexeddb/test/'
    'typed_identity_contract.dart',
  );
  final temporary = Directory.systemTemp.createTempSync('indexeddb_git_');
  try {
    File('${temporary.path}/pubspec.yaml').writeAsStringSync('''
name: indexeddb_git_consumer
publish_to: none
environment:
  sdk: '>=3.5.0 <4.0.0'
dependencies:
${[
      for (final name in const [
        'dddart',
        'dddart_serialization',
        'dddart_repository_indexeddb',
      ])
        '''  $name:
    git:
      url: ${jsonEncode(repository)}
      ref: $sha
      path: packages/$name''',
    ].join('\n')}
  idb_shim: 2.10.1+1
dev_dependencies:
  test: ^1.24.0
''');
    Directory('${temporary.path}/test').createSync();
    fixture.copySync('${temporary.path}/test/typed_identity_contract.dart');
    File('${temporary.path}/test/memory_test.dart').writeAsStringSync('''
import 'package:idb_shim/idb_client_memory.dart';
import 'typed_identity_contract.dart';
void main() => typedIdentityContract(newIdbFactoryMemory);
''');
    File('${temporary.path}/test/native_test.dart').writeAsStringSync('''
@TestOn('browser')
library;
import 'package:test/test.dart';
import 'package:idb_shim/idb_client_native.dart';
import 'typed_identity_contract.dart';
void main() => typedIdentityContract(() => idbFactoryNative);
''');
    File('${temporary.path}/dart_test.yaml')
        .writeAsStringSync('platforms: [vm, chrome]\n');

    // Nested Git/Pub must not inherit a hook's repository-local environment.
    final environment = Map<String, String>.from(Platform.environment)
      ..removeWhere((key, _) => key.startsWith('GIT_'));
    Future<void> run(List<String> args) async {
      stdout.writeln('dart ${args.join(' ')}');
      final child = await Process.start(
        Platform.resolvedExecutable,
        args,
        workingDirectory: temporary.path,
        environment: environment,
        includeParentEnvironment: false,
        mode: ProcessStartMode.inheritStdio,
      );
      final result = await child.exitCode;
      if (result != 0) throw StateError('Command exited $result: $args');
    }

    await run(['pub', 'get']);
    final lock = File('${temporary.path}/pubspec.lock').readAsStringSync();
    verifyIndexedDbGitLock(lock, sha);
    if (File('${temporary.path}/pubspec_overrides.yaml').existsSync() ||
        File('${temporary.path}/pubspec.yaml')
            .readAsStringSync()
            .contains('dependency_overrides:')) {
      throw StateError('Consumer must not use dependency overrides');
    }
    await run(['analyze', '--fatal-infos']);
    await run(['test', '--reporter=expanded']);
    stdout.writeln(
      'Verified core, serialization and IndexedDB at $sha without overrides; '
      'typed VM and native Chrome contracts passed.',
    );
  } finally {
    temporary.deleteSync(recursive: true);
  }
}

/// Rejects missing, hosted or differently pinned members of the Git closure.
void verifyIndexedDbGitLock(String lock, String sha) {
  for (final name in const [
    'dddart',
    'dddart_serialization',
    'dddart_repository_indexeddb',
  ]) {
    final block = RegExp(
      '^  $name:\\n((?:    .*\\n|\\n)*)',
      multiLine: true,
    ).firstMatch(lock)?.group(1);
    if (block == null ||
        !RegExp(r'^    source: git$', multiLine: true).hasMatch(block) ||
        !RegExp('resolved-ref: ["\']?$sha["\']?\\s').hasMatch(block)) {
      throw ValidationFailure('$name did not resolve to Git SHA $sha');
    }
  }
}
