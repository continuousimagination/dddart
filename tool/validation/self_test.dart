import 'dart:convert';
import 'dart:io';

import 'validation_core.dart';

Future<void> main() async {
  final repositoryRoot =
      File.fromUri(Platform.script).parent.parent.parent.absolute.path;
  final inventory = loadInventory(repositoryRoot);

  validateInventoryShape(inventory);
  _expect(
    inventory.packages.isNotEmpty,
    'the shared inventory declares public packages',
  );

  final expandedInventory = ValidationInventory(
    schemaVersion: inventory.schemaVersion,
    packages: {
      ...inventory.packages,
      'future_package': PackagePolicy(
        name: 'future_package',
        path: 'packages/future_package',
        allowedLocalPackages: {'future_package'},
        generationAction: 'none',
        generationPrerequisites: {},
      ),
    },
    workspaceExemptions: inventory.workspaceExemptions,
    testTagPolicies: inventory.testTagPolicies,
  );
  validateInventoryShape(expandedInventory);

  _expect(
    _sameSet(
      parseDeclaredServiceTags(
        'tags:\n  property-test:\n  requires-mongo:\n    timeout: 2x\n',
      ),
      {'requires-mongo'},
    ),
    'service-tag declarations are read from dart_test.yaml',
  );
  _expect(
    _sameSet(
      parseUsedServiceTags([
        "@Tags(['requires-mongo', 'property-test'])\n"
            "test('works', () {}, tags: ['requires-mysql']);",
      ]),
      {'requires-mongo', 'requires-mysql'},
    ),
    'service tags are read from test annotations and arguments',
  );

  final configuredServiceTags = {
    for (final package in inventory.packages.keys) package: <String>{},
  };
  for (final policy in inventory.testTagPolicies) {
    if (!policy.tag.startsWith('requires-')) {
      continue;
    }
    for (final package in policy.packages) {
      configuredServiceTags[package]!.add(policy.tag);
    }
  }
  validateServiceTagCoverage(
    inventory: inventory,
    declaredTagsByPackage: configuredServiceTags,
    usedTagsByPackage: configuredServiceTags,
  );
  final staleDeclarations = {
    for (final entry in configuredServiceTags.entries)
      entry.key: {...entry.value},
  };
  staleDeclarations['dddart_repository_dynamodb']!.add(
    'requires-dynamodb-local',
  );
  _expectFailure(
    () => validateServiceTagCoverage(
      inventory: inventory,
      declaredTagsByPackage: staleDeclarations,
      usedTagsByPackage: configuredServiceTags,
    ),
    'stale service-tag declarations fail policy validation',
  );

  await _testPublishArchiveStaging();

  final closure = localDependencyClosure(
    'adapter',
    {
      'adapter': {'shared'},
      'shared': {'core', 'hosted'},
      'core': {},
    },
    {'adapter', 'shared', 'core'},
  );
  _expect(
    _sameSet(closure, {'adapter', 'shared', 'core'}),
    'local closures ignore hosted packages and include transitives',
  );

  final mysql = inventory.packages['dddart_repository_mysql']!;
  _expect(
    _sameSet(mysql.allowedLocalPackages, {
      'dddart',
      'dddart_serialization',
      'dddart_repository_sql',
      'dddart_repository_mysql',
    }),
    'MySQL closure excludes JSON and unrelated adapters',
  );

  final allowedConsumer = _consumerGraph(
    consumerName: 'mysql_consumer',
    target: mysql.name,
    localPackages: mysql.allowedLocalPackages,
  );
  validateConsumerDependencyGraph(
    jsonText: allowedConsumer,
    consumerName: 'mysql_consumer',
    policy: mysql,
    intendedPublicPackages: inventory.packages.keys.toSet(),
  );

  final forbiddenConsumer = _consumerGraph(
    consumerName: 'mysql_consumer',
    target: mysql.name,
    localPackages: {
      ...mysql.allowedLocalPackages,
      'dddart_repository_mongodb',
    },
  );
  _expectFailure(
    () => validateConsumerDependencyGraph(
      jsonText: forbiddenConsumer,
      consumerName: 'mysql_consumer',
      policy: mysql,
      intendedPublicPackages: inventory.packages.keys.toSet(),
    ),
    'forbidden adapters fail isolated-consumer validation',
  );

  _expect(
    isMarkedPublishable('name: package\nversion: 1.0.0\n'),
    'missing publish_to is publishable',
  );
  _expect(
    !isMarkedPublishable('name: package\npublish_to: none\n'),
    'publish_to none opts out of dry-run publishing',
  );
  _expect(
    !isMarkedPublishable("publish_to: 'none' # intentional\n"),
    'quoted publish_to none is recognized',
  );

  final sanitizedEnvironment = withoutGitRepositoryEnvironment(
    environment: const {
      'PATH': '/test/bin',
      'GIT_DIR': '/wrong/repository',
      'GIT_WORK_TREE': '/wrong/worktree',
      'GIT_INDEX_FILE': '/wrong/index',
      'GIT_CONFIG_COUNT': '1',
    },
    additions: const {
      'CI': 'true',
      'GIT_PREFIX': 'must-not-be-restored',
    },
  );
  _expect(
    sanitizedEnvironment['PATH'] == '/test/bin' &&
        sanitizedEnvironment['CI'] == 'true' &&
        !sanitizedEnvironment.containsKey('GIT_DIR') &&
        !sanitizedEnvironment.containsKey('GIT_WORK_TREE') &&
        !sanitizedEnvironment.containsKey('GIT_INDEX_FILE') &&
        !sanitizedEnvironment.containsKey('GIT_CONFIG_COUNT') &&
        !sanitizedEnvironment.containsKey('GIT_PREFIX'),
    'subprocess environments discard repository-local Git state',
  );

  stdout.writeln('Validation policy self-tests passed.');
}

Future<void> _testPublishArchiveStaging() async {
  final fixture = Directory.systemTemp.createTempSync(
    'dddart_publish_ignore_test_',
  );
  try {
    final source = '${fixture.path}/source';
    final staged = '${fixture.path}/staged';
    Directory('$source/lib/override').createSync(recursive: true);
    File('$source/pubspec.yaml').writeAsStringSync(
      'name: publish_archive_fixture\n'
      'version: 1.0.0\n'
      'publish_to: none\n'
      'environment:\n'
      "  sdk: '>=3.5.0 <4.0.0'\n",
    );
    File('$source/.gitignore').writeAsStringSync(
      '/tracked_ignored.dart\n/generated.g.dart\n!generated.g.dart\n',
    );
    File('$source/tracked_ignored.dart').writeAsStringSync(
      'void ignored() {}\n',
    );
    File('$source/generated.g.dart').writeAsStringSync(
      'void published() {}\n',
    );
    File('$source/visible.txt').writeAsStringSync('visible\n');
    File('$source/lib/override/.gitignore').writeAsStringSync(
      'git_only.dart\n',
    );
    File('$source/lib/override/.pubignore').writeAsStringSync(
      'pub_only.dart\n',
    );
    File('$source/lib/override/git_only.dart').writeAsStringSync(
      'void includedByPubignore() {}\n',
    );
    File('$source/lib/override/pub_only.dart').writeAsStringSync(
      'void excludedByPubignore() {}\n',
    );
    _runFixtureGit(source, const ['init', '--quiet']);
    _runFixtureGit(source, const ['add', '-f', '.']);
    _runFixtureGit(
      source,
      const ['ls-files', '--error-unmatch', 'tracked_ignored.dart'],
    );
    File('$source/visible_untracked.dart').writeAsStringSync(
      'void visibleUntracked() {}\n',
    );

    await stagePublishedPackage(
      sourceDirectory: source,
      destinationDirectory: staged,
      archivePath: '${fixture.path}/fixture.tar.gz',
    );
    _expect(
      !File('$staged/tracked_ignored.dart').existsSync(),
      'tracked files ignored by Pub are excluded from staging',
    );
    _expect(
      File('$staged/generated.g.dart').existsSync(),
      'explicit ignore exceptions are included in staging',
    );
    _expect(
      File('$staged/visible_untracked.dart').existsSync(),
      'untracked files included by Pub are included in staging',
    );
    _expect(
      File('$staged/lib/override/git_only.dart').existsSync() &&
          !File('$staged/lib/override/pub_only.dart').existsSync(),
      'nested .pubignore rules supersede nested .gitignore rules',
    );
    _expect(
      !Directory('$source/.dart_tool').existsSync(),
      'archive staging does not resolve package dependencies',
    );
  } finally {
    fixture.deleteSync(recursive: true);
  }
}

void _runFixtureGit(String workingDirectory, List<String> arguments) {
  final result = Process.runSync(
    'git',
    arguments,
    workingDirectory: workingDirectory,
    environment: withoutGitRepositoryEnvironment(),
    includeParentEnvironment: false,
  );
  if (result.exitCode != 0) {
    throw StateError(
      'Self-test git ${arguments.join(' ')} failed: ${result.stderr}',
    );
  }
}

String _consumerGraph({
  required String consumerName,
  required String target,
  required Set<String> localPackages,
}) {
  return jsonEncode({
    'root': consumerName,
    'packages': [
      {
        'name': consumerName,
        'source': 'root',
        'directDependencies': [target],
      },
      for (final package in localPackages)
        {
          'name': package,
          'source': 'path',
          'directDependencies': const <String>[],
        },
    ],
  });
}

void _expect(bool condition, String description) {
  if (!condition) {
    throw StateError('Self-test failed: $description.');
  }
}

void _expectFailure(void Function() callback, String description) {
  try {
    callback();
  } on ValidationFailure {
    return;
  }
  throw StateError('Self-test failed: $description.');
}

bool _sameSet(Set<String> first, Set<String> second) {
  return first.length == second.length && first.containsAll(second);
}
