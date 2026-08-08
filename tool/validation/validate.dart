import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'validation_core.dart';

enum ValidationMode { local, ci }

Future<void> main(List<String> arguments) async {
  try {
    if (arguments.isEmpty) {
      _usage();
      exitCode = 64;
      return;
    }

    final repositoryRoot = _repositoryRoot();
    final inventory = loadInventory(repositoryRoot);
    validateInventoryShape(inventory);

    switch (arguments.first) {
      case 'check':
        await _ensureWorkspaceResolution(repositoryRoot);
        await _checkInventory(repositoryRoot, inventory, verbose: true);
      case 'matrix':
        await _printCiMatrix(
          repositoryRoot,
          inventory,
          serviceKind: _parseMatrixServiceKind(arguments),
        );
      case 'package':
        final packageName = _requiredPackageArgument(arguments);
        final mode = _parseMode(arguments);
        await _ensureWorkspaceResolution(repositoryRoot);
        await _checkInventory(repositoryRoot, inventory, verbose: false);
        await _validatePackage(
          repositoryRoot,
          inventory,
          _packagePolicy(inventory, packageName),
          mode,
        );
      case 'consumer':
        final packageName = _requiredPackageArgument(arguments);
        await _ensureWorkspaceResolution(repositoryRoot);
        await _checkInventory(repositoryRoot, inventory, verbose: false);
        await _validateConsumer(
          repositoryRoot,
          inventory,
          _packagePolicy(inventory, packageName),
        );
      case 'all':
        final mode = _parseMode(arguments);
        await _runInherited(
          Platform.resolvedExecutable,
          const ['pub', 'get'],
          workingDirectory: repositoryRoot,
        );
        await _checkInventory(repositoryRoot, inventory, verbose: true);
        await _validateAll(repositoryRoot, inventory, mode);
      default:
        throw ValidationFailure('Unknown command: ${arguments.first}.');
    }
  } on ValidationFailure catch (error) {
    stderr.writeln('Validation failed: ${error.message}');
    exitCode = 1;
  } on ProcessException catch (error) {
    stderr.writeln('Validation process failed: $error');
    exitCode = 1;
  }
}

String _repositoryRoot() {
  return File.fromUri(Platform.script).parent.parent.parent.absolute.path;
}

void _usage() {
  stderr.writeln(
    'Usage: dart tool/validation/validate.dart '
    '<check|matrix|package NAME|consumer NAME|all> '
    '[--mode=local|ci] [--service-kind=none|mongo|dynamodb|mysql]',
  );
}

String _requiredPackageArgument(List<String> arguments) {
  if (arguments.length < 2 || arguments[1].startsWith('--')) {
    throw ValidationFailure('${arguments.first} requires a package name.');
  }
  return arguments[1];
}

ValidationMode _parseMode(List<String> arguments) {
  final modeArgument = arguments.where((value) => value.startsWith('--mode='));
  if (modeArgument.isEmpty) {
    return ValidationMode.local;
  }
  if (modeArgument.length != 1) {
    throw ValidationFailure('Specify --mode at most once.');
  }
  return switch (modeArgument.single.substring('--mode='.length)) {
    'local' => ValidationMode.local,
    'ci' => ValidationMode.ci,
    final value => throw ValidationFailure('Unsupported mode: $value.'),
  };
}

String? _parseMatrixServiceKind(List<String> arguments) {
  final serviceArguments = arguments.where(
    (value) => value.startsWith('--service-kind='),
  );
  if (serviceArguments.isEmpty) {
    return null;
  }
  if (serviceArguments.length != 1) {
    throw ValidationFailure('Specify --service-kind at most once.');
  }
  return serviceArguments.single.substring('--service-kind='.length);
}

PackagePolicy _packagePolicy(
  ValidationInventory inventory,
  String packageName,
) {
  final policy = inventory.packages[packageName];
  if (policy == null) {
    throw ValidationFailure(
      '$packageName is not an intended public package in the inventory.',
    );
  }
  return policy;
}

Future<void> _ensureWorkspaceResolution(String repositoryRoot) async {
  if (File('$repositoryRoot/.dart_tool/package_config.json').existsSync()) {
    return;
  }
  await _runInherited(
    Platform.resolvedExecutable,
    const ['pub', 'get'],
    workingDirectory: repositoryRoot,
  );
}

Future<List<WorkspacePackage>> _workspacePackages(
  String repositoryRoot,
) async {
  final output = await _runCapture(
    Platform.resolvedExecutable,
    const ['pub', 'workspace', 'list', '--json'],
    workingDirectory: repositoryRoot,
  );
  return parseWorkspacePackages(output);
}

Future<Map<String, Set<String>>> _workspaceDependencyGraph(
  String repositoryRoot,
) async {
  final output = await _runCapture(
    Platform.resolvedExecutable,
    const ['pub', 'deps', '--json'],
    workingDirectory: repositoryRoot,
  );
  return parseDirectDependencyGraph(output);
}

Future<void> _checkInventory(
  String repositoryRoot,
  ValidationInventory inventory, {
  required bool verbose,
}) async {
  final workspacePackages = await _workspacePackages(repositoryRoot);
  validateWorkspaceCoverage(
    repositoryRoot: repositoryRoot,
    inventory: inventory,
    workspacePackages: workspacePackages,
  );
  validateConfiguredClosures(
    inventory: inventory,
    dependencyGraph: await _workspaceDependencyGraph(repositoryRoot),
  );
  _validateGenerationPolicies(repositoryRoot, inventory);
  _validateServiceTags(repositoryRoot, inventory);
  if (verbose) {
    stdout.writeln(
      'Workspace policy covers ${inventory.packages.length} intended public '
      'packages and ${inventory.workspaceExemptions.length} explicitly '
      'exempt workspace members.',
    );
  }
}

void _validateGenerationPolicies(
  String repositoryRoot,
  ValidationInventory inventory,
) {
  for (final package in inventory.packages.values) {
    final packageDirectory = '$repositoryRoot/${package.path}';
    final pubspec = File('$packageDirectory/pubspec.yaml').readAsStringSync();
    final hasBuildRunner = RegExp(
      r'^\s*build_runner:',
      multiLine: true,
    ).hasMatch(pubspec);
    final requiresGeneration = package.generationAction == 'required';
    if (hasBuildRunner != requiresGeneration) {
      throw ValidationFailure(
        '${package.name} generation policy drifted: inventory says '
        '${package.generationAction}, but pubspec build_runner presence is '
        '$hasBuildRunner.',
      );
    }

    var hasGeneratedPartDirective = false;
    for (final sourceRoot in const ['lib', 'test']) {
      final directory = Directory('$packageDirectory/$sourceRoot');
      if (!directory.existsSync()) {
        continue;
      }
      for (final file in directory
          .listSync(recursive: true)
          .whereType<File>()
          .where(
            (file) =>
                file.path.endsWith('.dart') && !file.path.endsWith('.g.dart'),
          )) {
        if (RegExp(
          r'''^part\s+['"][^'"]+\.g\.dart['"];\s*$''',
          multiLine: true,
        ).hasMatch(file.readAsStringSync())) {
          hasGeneratedPartDirective = true;
          break;
        }
      }
      if (hasGeneratedPartDirective) {
        break;
      }
    }
    if (hasGeneratedPartDirective && !requiresGeneration) {
      throw ValidationFailure(
        '${package.name} contains generated part directives but is marked '
        'generation: none.',
      );
    }
  }
}

Future<void> _printCiMatrix(
  String repositoryRoot,
  ValidationInventory inventory, {
  required String? serviceKind,
}) async {
  validateWorkspaceCoverage(
    repositoryRoot: repositoryRoot,
    inventory: inventory,
    workspacePackages: await _workspacePackages(repositoryRoot),
  );
  final supportedKinds = {
    for (final policy in inventory.testTagPolicies)
      if (policy.service case final service?) service.kind,
  };
  if (serviceKind != null &&
      serviceKind != 'none' &&
      !supportedKinds.contains(serviceKind)) {
    throw ValidationFailure('Unknown CI service kind: $serviceKind.');
  }

  final include = inventory.packages.values
      .where((package) {
        if (serviceKind == null) {
          return true;
        }
        final packageKinds = testPoliciesFor(inventory, package.name)
            .where(
              (policy) => policy.ciAction == 'run' && policy.service != null,
            )
            .map((policy) => policy.service!.kind)
            .toSet();
        return serviceKind == 'none'
            ? packageKinds.isEmpty
            : packageKinds.contains(serviceKind);
      })
      .map(
        (package) => {
          'name': package.name,
          'path': package.path,
        },
      )
      .toList(growable: false);
  stdout.writeln(jsonEncode({'include': include}));
}

Future<void> _validateAll(
  String repositoryRoot,
  ValidationInventory inventory,
  ValidationMode mode,
) async {
  final failures = <String>[];
  for (final package in inventory.packages.values) {
    try {
      await _validatePackage(repositoryRoot, inventory, package, mode);
    } on Object catch (error) {
      failures.add('${package.name} integrated validation: $error');
    }
  }
  for (final package in inventory.packages.values) {
    try {
      await _validateConsumer(repositoryRoot, inventory, package);
    } on Object catch (error) {
      failures.add('${package.name} isolated consumer: $error');
    }
  }
  if (failures.isNotEmpty) {
    throw ValidationFailure(failures.join('\n'));
  }
}

Future<void> _validatePackage(
  String repositoryRoot,
  ValidationInventory inventory,
  PackagePolicy package,
  ValidationMode mode,
) async {
  stdout.writeln('\n=== ${package.name}: integrated validation ===');
  for (final prerequisiteName in package.generationPrerequisites) {
    await _runRequiredGeneration(
      repositoryRoot,
      _packagePolicy(inventory, prerequisiteName),
    );
  }
  await _runRequiredGeneration(repositoryRoot, package);

  final packageDirectory = '$repositoryRoot/${package.path}';
  await _runInherited(
    Platform.resolvedExecutable,
    const ['analyze', '--fatal-infos'],
    workingDirectory: packageDirectory,
  );
  await _runInherited(
    Platform.resolvedExecutable,
    const [
      'format',
      '--output=none',
      '--set-exit-if-changed',
      '.',
    ],
    workingDirectory: packageDirectory,
  );

  final tagPolicies = testPoliciesFor(inventory, package.name);
  final testArguments = <String>['test'];
  final environment = <String, String>{};
  for (final policy in tagPolicies) {
    final action =
        mode == ValidationMode.local ? policy.localAction : policy.ciAction;
    if (action == 'exclude') {
      stdout.writeln(
        'Excluding ${policy.tag} for ${package.name}: ${policy.reason}',
      );
      testArguments.add('--exclude-tags=${policy.tag}');
    } else if (mode == ValidationMode.ci) {
      if (policy.service case final service?) {
        await _waitForService(service, policy.tag);
      }
      environment.addAll(policy.ciEnvironment);
    }
  }
  await _runInherited(
    Platform.resolvedExecutable,
    testArguments,
    workingDirectory: packageDirectory,
    environment: environment,
  );

  final pubspec = File('$packageDirectory/pubspec.yaml').readAsStringSync();
  if (isMarkedPublishable(pubspec)) {
    await _runInherited(
      Platform.resolvedExecutable,
      const ['pub', 'publish', '--dry-run'],
      workingDirectory: packageDirectory,
    );
  } else {
    stdout.writeln(
      'Publish dry-run exempt for ${package.name}: pubspec.yaml sets '
      'publish_to: none.',
    );
  }
}

Future<void> _runRequiredGeneration(
  String repositoryRoot,
  PackagePolicy package,
) async {
  if (package.generationAction == 'none') {
    return;
  }
  final packageDirectory = '$repositoryRoot/${package.path}';
  await _runInherited(
    '$repositoryRoot/scripts/run-required-generation.sh',
    const ['.'],
    workingDirectory: packageDirectory,
  );
}

void _validateServiceTags(
  String repositoryRoot,
  ValidationInventory inventory,
) {
  final declaredTags = <String, Set<String>>{};
  final usedTags = <String, Set<String>>{};
  for (final package in inventory.packages.values) {
    final packageDirectory = '$repositoryRoot/${package.path}';
    final dartTestConfig = File('$packageDirectory/dart_test.yaml');
    declaredTags[package.name] = dartTestConfig.existsSync()
        ? parseDeclaredServiceTags(dartTestConfig.readAsStringSync())
        : <String>{};

    final testDirectory = Directory('$packageDirectory/test');
    final sources = testDirectory.existsSync()
        ? testDirectory
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'))
            .map((file) => file.readAsStringSync())
        : const <String>[];
    usedTags[package.name] = parseUsedServiceTags(sources);
  }
  validateServiceTagCoverage(
    inventory: inventory,
    declaredTagsByPackage: declaredTags,
    usedTagsByPackage: usedTags,
  );
}

Future<void> _validateConsumer(
  String repositoryRoot,
  ValidationInventory inventory,
  PackagePolicy package,
) async {
  stdout.writeln('\n=== ${package.name}: isolated consumer ===');
  final temporaryDirectory = Directory.systemTemp.createTempSync(
    '${package.name}_consumer_',
  );
  final consumerName = '${package.name}_isolated_consumer';
  try {
    final stagedPackagePaths = await _stagePackageClosure(
      repositoryRoot: repositoryRoot,
      temporaryRoot: temporaryDirectory.path,
      inventory: inventory,
      package: package,
    );
    final consumerDirectory = '${temporaryDirectory.path}/consumer';
    Directory('$consumerDirectory/bin').createSync(recursive: true);
    File('$consumerDirectory/pubspec.yaml').writeAsStringSync(
      _consumerPubspec(
        package: package,
        consumerName: consumerName,
        stagedPackagePaths: stagedPackagePaths,
      ),
    );
    File('$consumerDirectory/bin/main.dart').writeAsStringSync(
      '// ignore_for_file: unused_import\n\n'
      "import 'package:${package.name}/${package.name}.dart';\n\n"
      'void main() {}\n',
    );

    await _runInherited(
      Platform.resolvedExecutable,
      const ['pub', 'get'],
      workingDirectory: consumerDirectory,
    );
    await _runInherited(
      Platform.resolvedExecutable,
      const ['analyze', '--fatal-infos'],
      workingDirectory: consumerDirectory,
    );
    await _runInherited(
      Platform.resolvedExecutable,
      const ['run', 'bin/main.dart'],
      workingDirectory: consumerDirectory,
    );
    final dependencyJson = await _runCapture(
      Platform.resolvedExecutable,
      const ['pub', 'deps', '--json'],
      workingDirectory: consumerDirectory,
    );
    validateConsumerDependencyGraph(
      jsonText: dependencyJson,
      consumerName: consumerName,
      policy: package,
      intendedPublicPackages: inventory.packages.keys.toSet(),
    );
    stdout.writeln(
      '${package.name} resolved only its allowed local closure: '
      '${_sorted(package.allowedLocalPackages)}.',
    );
  } finally {
    temporaryDirectory.deleteSync(recursive: true);
  }
}

Future<Map<String, String>> _stagePackageClosure({
  required String repositoryRoot,
  required String temporaryRoot,
  required ValidationInventory inventory,
  required PackagePolicy package,
}) async {
  final stagedPaths = <String, String>{};
  final packageNames = package.allowedLocalPackages.toList()..sort();
  for (final packageName in packageNames) {
    final dependency = _packagePolicy(inventory, packageName);
    final sourceDirectory = '$repositoryRoot/${dependency.path}';
    final stagedDirectory = '$temporaryRoot/packages/$packageName';
    stagedPaths[packageName] = stagedDirectory;
    await stagePublishedPackage(
      sourceDirectory: sourceDirectory,
      destinationDirectory: stagedDirectory,
      archivePath: '$temporaryRoot/archives/$packageName.tar.gz',
    );

    if (!File('$stagedDirectory/pubspec.yaml').existsSync()) {
      throw ValidationFailure(
        'Publishable staging for $packageName did not include pubspec.yaml.',
      );
    }
  }
  return stagedPaths;
}

String _consumerPubspec({
  required PackagePolicy package,
  required String consumerName,
  required Map<String, String> stagedPackagePaths,
}) {
  final overrides = package.allowedLocalPackages.toList()..sort();
  final buffer = StringBuffer()
    ..writeln('name: $consumerName')
    ..writeln('publish_to: none')
    ..writeln('environment:')
    ..writeln("  sdk: '>=3.5.0 <4.0.0'")
    ..writeln('dependencies:')
    ..writeln('  ${package.name}: any')
    ..writeln('dependency_overrides:');
  for (final packageName in overrides) {
    final absolutePath = stagedPackagePaths[packageName]!;
    buffer
      ..writeln('  $packageName:')
      ..writeln('    path: ${jsonEncode(absolutePath)}');
  }
  return buffer.toString();
}

Future<void> _waitForService(ServicePolicy service, String tag) async {
  final deadline = DateTime.now().add(
    Duration(seconds: service.timeoutSeconds),
  );
  stdout.writeln(
    'Waiting for $tag service at ${service.host}:${service.port}...',
  );
  while (DateTime.now().isBefore(deadline)) {
    try {
      final socket = await Socket.connect(
        service.host,
        service.port,
        timeout: const Duration(seconds: 2),
      );
      socket.destroy();
      return;
    } on SocketException {
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }
  throw ValidationFailure(
    '$tag service was not reachable at ${service.host}:${service.port} '
    'within ${service.timeoutSeconds} seconds.',
  );
}

Future<String> _runCapture(
  String executable,
  List<String> arguments, {
  required String workingDirectory,
}) async {
  final result = await Process.run(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    environment: withoutGitRepositoryEnvironment(),
    includeParentEnvironment: false,
  );
  if (result.exitCode != 0) {
    throw ValidationFailure(
      '${_command(executable, arguments)} failed in $workingDirectory '
      '(exit ${result.exitCode}).\n${result.stdout}${result.stderr}',
    );
  }
  return result.stdout.toString();
}

Future<void> _runInherited(
  String executable,
  List<String> arguments, {
  required String workingDirectory,
  Map<String, String> environment = const {},
}) async {
  stdout.writeln('> ${_command(executable, arguments)}');
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    environment: withoutGitRepositoryEnvironment(additions: environment),
    includeParentEnvironment: false,
    mode: ProcessStartMode.inheritStdio,
  );
  final code = await process.exitCode;
  if (code != 0) {
    throw ValidationFailure(
      '${_command(executable, arguments)} failed in $workingDirectory '
      '(exit $code).',
    );
  }
}

String _command(String executable, List<String> arguments) {
  return ([executable, ...arguments]).join(' ');
}

String _sorted(Iterable<String> values) {
  final sorted = values.toList()..sort();
  return sorted.join(', ');
}
