import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'validation_core.dart';

enum ValidationMode { local, ci }

const _exampleEntrypointTimeout = Duration(minutes: 2);

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
      case 'example-matrix':
        await _printExampleCiMatrix(
          repositoryRoot,
          inventory,
          serviceKind: _parseMatrixServiceKind(arguments),
        );
      case 'example':
        final exampleName = _requiredPackageArgument(arguments);
        final mode = _parseMode(arguments);
        await _ensureWorkspaceResolution(repositoryRoot);
        await _checkInventory(repositoryRoot, inventory, verbose: false);
        await _validateExample(
          repositoryRoot,
          inventory,
          _examplePolicy(inventory, exampleName),
          mode,
        );
      case 'examples':
        final mode = _parseMode(arguments);
        await _ensureWorkspaceResolution(repositoryRoot);
        await _checkInventory(repositoryRoot, inventory, verbose: false);
        await _validateExamples(repositoryRoot, inventory, mode);
      case 'all':
        final mode = _parseMode(arguments);
        await _runInherited(
          Platform.resolvedExecutable,
          const ['pub', 'get'],
          workingDirectory: repositoryRoot,
        );
        await _checkInventory(repositoryRoot, inventory, verbose: true);
        await _validateAll(repositoryRoot, inventory, mode);
        await _validateExamples(repositoryRoot, inventory, mode);
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
    '<check|matrix|package NAME|consumer NAME|example-matrix|example NAME|'
    'examples|all> '
    '[--mode=local|ci] [--service-kind=none|mongo|dynamodb|mysql]',
  );
}

ExamplePolicy _examplePolicy(
  ValidationInventory inventory,
  String exampleName,
) {
  final policy = inventory.examples[exampleName];
  if (policy == null) {
    throw ValidationFailure(
      '$exampleName is not an example in the validation inventory.',
    );
  }
  return policy;
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
  validateExampleDirectoryCoverage(
    inventory: inventory,
    discoveredExamples: _discoverExamples(repositoryRoot),
  );
  validateConfiguredClosures(
    inventory: inventory,
    dependencyGraph: await _workspaceDependencyGraph(repositoryRoot),
  );
  _validateGenerationPolicies(repositoryRoot, inventory);
  _validateExamplePolicies(repositoryRoot, inventory);
  _validateServiceTags(repositoryRoot, inventory);
  if (verbose) {
    stdout.writeln(
      'Workspace policy covers ${inventory.packages.length} intended public '
      'packages, ${inventory.examples.length} examples, and '
      '${inventory.workspaceExemptions.length} explicitly exempt workspace '
      'members.',
    );
  }
}

Map<String, String> _discoverExamples(String repositoryRoot) {
  final examples = <String, String>{};
  final packagesDirectory = Directory('$repositoryRoot/packages');
  for (final packageDirectory
      in packagesDirectory.listSync().whereType<Directory>()) {
    final exampleDirectory = Directory('${packageDirectory.path}/example');
    final pubspec = File('${exampleDirectory.path}/pubspec.yaml');
    if (!pubspec.existsSync()) {
      continue;
    }
    final name = RegExp(
      r'^name:\s*([a-zA-Z0-9_]+)\s*$',
      multiLine: true,
    ).firstMatch(pubspec.readAsStringSync())?.group(1);
    if (name == null) {
      throw ValidationFailure(
        'Could not read the package name from ${pubspec.path}.',
      );
    }
    final relativePath = exampleDirectory.path.substring(
      Directory(repositoryRoot).absolute.path.length + 1,
    );
    final previous = examples[name];
    if (previous != null) {
      throw ValidationFailure(
        'Discovered duplicate example package $name at $previous and '
        '$relativePath.',
      );
    }
    examples[name] = relativePath;
  }
  return examples;
}

void _validateExamplePolicies(
  String repositoryRoot,
  ValidationInventory inventory,
) {
  for (final example in inventory.examples.values) {
    final exampleDirectory = '$repositoryRoot/${example.path}';
    final pubspec = File('$exampleDirectory/pubspec.yaml').readAsStringSync();
    final hasBuildRunner = RegExp(
      r'^\s*build_runner:',
      multiLine: true,
    ).hasMatch(pubspec);
    final requiresGeneration = example.generation.action == 'required';
    if (hasBuildRunner != requiresGeneration) {
      throw ValidationFailure(
        '${example.name} generation policy drifted: inventory says '
        '${example.generation.action}, but pubspec build_runner presence is '
        '$hasBuildRunner.',
      );
    }

    final analysisOptions = File('$exampleDirectory/analysis_options.yaml');
    if (!analysisOptions.existsSync()) {
      throw ValidationFailure(
        '${example.name} must have local non-excluding analysis options.',
      );
    }
    final analysisOptionsContents = analysisOptions.readAsStringSync();
    if (!RegExp(
      r'^include:\s*package:lints/recommended\.yaml\s*$',
      multiLine: true,
    ).hasMatch(analysisOptionsContents)) {
      throw ValidationFailure(
        '${example.name} must use the explicit example lint baseline.',
      );
    }
    if (RegExp(r'example/\*\*').hasMatch(analysisOptionsContents)) {
      throw ValidationFailure(
        '${example.name} local analysis options exclude example sources.',
      );
    }

    final buildConfig = File('$exampleDirectory/build.yaml');
    if (requiresGeneration != buildConfig.existsSync()) {
      throw ValidationFailure(
        '${example.name} build.yaml presence does not match generation '
        '${example.generation.action}.',
      );
    }
    if (requiresGeneration) {
      _validateExampleBuildConfig(example, buildConfig.readAsStringSync());
    }

    final discoveredEntrypoints = <String>{};
    final discoveredSources = <String>{};
    final declaredGeneratedParts = <String>{};
    final directory = Directory(exampleDirectory);
    for (final file in directory.listSync(recursive: true).whereType<File>()) {
      final relativePath = file.path.substring(exampleDirectory.length + 1);
      if (relativePath.startsWith('.dart_tool/')) {
        continue;
      }
      final isDart = relativePath.endsWith('.dart');
      final isSkippedDart = relativePath.endsWith('.dart.skip');
      if (!isDart && !isSkippedDart) {
        continue;
      }
      if (relativePath.endsWith('.g.dart')) {
        continue;
      }
      final isLibraryOrTest = relativePath.startsWith('lib/') ||
          relativePath.startsWith('test/') ||
          relativePath.contains('/lib/') ||
          relativePath.contains('/test/');
      if (isLibraryOrTest) {
        discoveredSources.add(relativePath);
      } else {
        discoveredEntrypoints.add(relativePath);
      }
      if (isDart) {
        final source = file.readAsStringSync();
        for (final match in RegExp(
          r'''^part\s+['"]([^'"]+\.g\.dart)['"];\s*$''',
          multiLine: true,
        ).allMatches(source)) {
          final parent = relativePath.contains('/')
              ? relativePath.substring(0, relativePath.lastIndexOf('/') + 1)
              : '';
          declaredGeneratedParts.add('$parent${match.group(1)!}');
        }
      }
    }

    final configuredEntrypoints =
        example.entrypoints.map((entrypoint) => entrypoint.path).toSet();
    if (!_sameSet(discoveredEntrypoints, configuredEntrypoints)) {
      throw ValidationFailure(
        '${example.name} entrypoint accounting drifted. Discovered '
        '${_sorted(discoveredEntrypoints)}; configured '
        '${_sorted(configuredEntrypoints)}.',
      );
    }
    final sourceOverrides = {
      for (final source in example.sourceOverrides) source.path: source,
    };
    final staleOverrides = sourceOverrides.keys.toSet().difference(
          discoveredSources,
        );
    if (staleOverrides.isNotEmpty) {
      throw ValidationFailure(
        '${example.name} has stale source overrides: '
        '${_sorted(staleOverrides)}.',
      );
    }
    if (example.category == 'legacy') {
      final implicitLegacy = discoveredSources.difference(
        sourceOverrides.keys.toSet(),
      );
      if (implicitLegacy.isNotEmpty) {
        throw ValidationFailure(
          '${example.name} is legacy and must classify every source exactly: '
          '${_sorted(implicitLegacy)}.',
        );
      }
    }
    if (!_sameSet(declaredGeneratedParts, example.generation.outputs)) {
      throw ValidationFailure(
        '${example.name} generated part topology drifted. Declared parts '
        '${_sorted(declaredGeneratedParts)}; configured outputs '
        '${_sorted(example.generation.outputs)}.',
      );
    }
  }
}

void _validateExampleBuildConfig(ExamplePolicy example, String contents) {
  if (contents.contains('|')) {
    throw ValidationFailure(
      '${example.name} build.yaml uses a non-canonical builder separator.',
    );
  }
  final configured = parseConfiguredExampleBuilderKeys(contents);
  final expected = {
    ...example.generation.builders,
    ...example.generation.disabledBuilders,
  };
  if (!_sameSet(configured, expected)) {
    throw ValidationFailure(
      '${example.name} configured builders drifted. Expected '
      '${_sorted(expected)}; found ${_sorted(configured)}.',
    );
  }
  for (final builder in expected) {
    final enabledMatch = RegExp(
      '^\\s+${RegExp.escape(builder)}:\\s*\\n\\s+enabled:\\s+(true|false)',
      multiLine: true,
    ).firstMatch(contents);
    final expectedEnabled = example.generation.builders.contains(builder);
    if (enabledMatch == null ||
        (enabledMatch.group(1) == 'true') != expectedEnabled) {
      throw ValidationFailure(
        '${example.name} builder $builder enabled state drifted.',
      );
    }
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

Future<void> _printExampleCiMatrix(
  String repositoryRoot,
  ValidationInventory inventory, {
  required String? serviceKind,
}) async {
  validateWorkspaceCoverage(
    repositoryRoot: repositoryRoot,
    inventory: inventory,
    workspacePackages: await _workspacePackages(repositoryRoot),
  );
  validateExampleDirectoryCoverage(
    inventory: inventory,
    discoveredExamples: _discoverExamples(repositoryRoot),
  );
  final supportedKinds = inventory.examples.values
      .where((example) => example.externalService.ciAction == 'run')
      .map((example) => example.externalService.kind)
      .toSet();
  if (serviceKind != null &&
      serviceKind != 'none' &&
      !supportedKinds.contains(serviceKind)) {
    throw ValidationFailure('Unknown example CI service kind: $serviceKind.');
  }

  final include = inventory.examples.values
      .where((example) {
        if (serviceKind == null) {
          return true;
        }
        final service = example.externalService;
        return serviceKind == 'none'
            ? service.ciAction != 'run'
            : service.ciAction == 'run' && service.kind == serviceKind;
      })
      .map(
        (example) => {
          'name': example.name,
          'path': example.path,
        },
      )
      .toList(growable: false);
  stdout.writeln(jsonEncode({'include': include}));
}

Future<void> _validateExamples(
  String repositoryRoot,
  ValidationInventory inventory,
  ValidationMode mode,
) async {
  final failures = <String>[];
  for (final example in inventory.examples.values) {
    try {
      await _validateExample(repositoryRoot, inventory, example, mode);
    } on Object catch (error) {
      failures.add('${example.name} example validation: $error');
    }
  }
  if (failures.isNotEmpty) {
    throw ValidationFailure(failures.join('\n'));
  }
}

Future<void> _validateExample(
  String repositoryRoot,
  ValidationInventory inventory,
  ExamplePolicy example,
  ValidationMode mode,
) async {
  stdout.writeln('\n=== ${example.name}: example validation ===');
  final exampleDirectory = '$repositoryRoot/${example.path}';
  if (example.resolution == 'standalone') {
    await _runInherited(
      Platform.resolvedExecutable,
      const ['pub', 'get'],
      workingDirectory: exampleDirectory,
    );
  }
  final dependencyJson = await _runCapture(
    Platform.resolvedExecutable,
    const ['pub', 'deps', '--json'],
    workingDirectory: exampleDirectory,
  );
  validateExampleDependencyGraph(
    jsonText: dependencyJson,
    policy: example,
    intendedPublicPackages: inventory.packages.keys.toSet(),
  );

  await _runExampleGeneration(exampleDirectory, example);
  await _runInherited(
    Platform.resolvedExecutable,
    const ['analyze', '--fatal-infos', '.'],
    workingDirectory: exampleDirectory,
  );
  await _runInherited(
    Platform.resolvedExecutable,
    const ['format', '--output=none', '--set-exit-if-changed', '.'],
    workingDirectory: exampleDirectory,
  );

  final testDirectory = Directory('$exampleDirectory/test');
  final hasRunnableTests = testDirectory.existsSync() &&
      testDirectory
          .listSync(recursive: true)
          .whereType<File>()
          .any((file) => file.path.endsWith('_test.dart'));
  if (hasRunnableTests) {
    await _runInherited(
      Platform.resolvedExecutable,
      const ['test'],
      workingDirectory: exampleDirectory,
    );
  } else {
    stdout.writeln('${example.name} has no runnable example tests.');
  }

  final compileDirectory = Directory.systemTemp.createTempSync(
    '${example.name}_compile_',
  );
  try {
    for (final entrypoint in example.entrypoints) {
      if (entrypoint.action == 'excluded') {
        stdout.writeln(
          'Excluding ${entrypoint.path} (${entrypoint.classification}): '
          '${entrypoint.reason}',
        );
        continue;
      }
      final outputName = entrypoint.path.replaceAll(
        RegExp(r'[^a-zA-Z0-9]+'),
        '_',
      );
      await _runInherited(
        Platform.resolvedExecutable,
        [
          'compile',
          'kernel',
          entrypoint.path,
          '-o',
          '${compileDirectory.path}/$outputName.dill',
        ],
        workingDirectory: exampleDirectory,
      );
    }
  } finally {
    compileDirectory.deleteSync(recursive: true);
  }

  final service = example.externalService;
  final serviceAction =
      mode == ValidationMode.local ? service.localAction : service.ciAction;
  TestTagPolicy? serviceTagPolicy;
  if (service.testTag case final testTag?) {
    serviceTagPolicy = inventory.testTagPolicies.singleWhere(
      (policy) => policy.tag == testTag,
    );
  }
  var serviceReady = false;
  for (final entrypoint in example.entrypoints) {
    final shouldRun = entrypoint.action == 'run' ||
        (entrypoint.action == 'service' && serviceAction == 'run');
    if (!shouldRun) {
      if (entrypoint.action == 'service') {
        stdout.writeln(
          'Compile-only ${entrypoint.path}: ${service.reason}',
        );
      }
      continue;
    }
    if (entrypoint.action == 'service' && !serviceReady) {
      final concreteService = serviceTagPolicy?.service;
      if (concreteService == null) {
        throw ValidationFailure(
          '${example.name} cannot run service entrypoints without a concrete '
          'service policy.',
        );
      }
      await _waitForService(concreteService, service.testTag!);
      serviceReady = true;
    }
    await _runInherited(
      Platform.resolvedExecutable,
      ['run', entrypoint.path],
      workingDirectory: exampleDirectory,
      environment: serviceTagPolicy?.ciEnvironment ?? const {},
      timeout: _exampleEntrypointTimeout,
    );
  }
}

Future<void> _runExampleGeneration(
  String exampleDirectory,
  ExamplePolicy example,
) async {
  if (example.generation.action == 'none') {
    final unexpected = _discoverGeneratedExampleOutputs(
      exampleDirectory,
      example.name,
    );
    if (unexpected.isNotEmpty) {
      throw ValidationFailure(
        '${example.name} marks generation none but contains generated files: '
        '${_sorted(unexpected)}.',
      );
    }
    return;
  }
  await _runInherited(
    Platform.resolvedExecutable,
    const ['run', 'build_runner', 'clean'],
    workingDirectory: exampleDirectory,
  );
  final existingOutputs = _discoverGeneratedExampleOutputs(
    exampleDirectory,
    example.name,
  );
  for (final output in existingOutputs) {
    final ignoreResult = await Process.run(
      'git',
      ['check-ignore', '--quiet', '--', output],
      workingDirectory: exampleDirectory,
      environment: withoutGitRepositoryEnvironment(),
      includeParentEnvironment: false,
    );
    if (ignoreResult.exitCode != 0) {
      throw ValidationFailure(
        '${example.name} generated file is not ignored and cannot be '
        'safely replaced: $output.',
      );
    }
    final generated = File('$exampleDirectory/$output');
    generated.deleteSync();
  }
  final remainingOutputs = _discoverGeneratedExampleOutputs(
    exampleDirectory,
    example.name,
  );
  if (remainingOutputs.isNotEmpty) {
    throw ValidationFailure(
      '${example.name} generated files could not be cleaned: '
      '${_sorted(remainingOutputs)}.',
    );
  }
  await _runInherited(
    Platform.resolvedExecutable,
    const [
      'run',
      'build_runner',
      'build',
      '--delete-conflicting-outputs',
    ],
    workingDirectory: exampleDirectory,
  );
  final generatedOutputs = _discoverGeneratedExampleOutputs(
    exampleDirectory,
    example.name,
  );
  if (!_sameSet(generatedOutputs, example.generation.outputs)) {
    throw ValidationFailure(
      '${example.name} generated output set drifted. Expected '
      '${_sorted(example.generation.outputs)}; found '
      '${_sorted(generatedOutputs)}.',
    );
  }
  for (final output in generatedOutputs) {
    final generated = File('$exampleDirectory/$output');
    if (generated.lengthSync() == 0) {
      throw ValidationFailure(
        '${example.name} generated an empty output: $output.',
      );
    }
  }
}

Set<String> _discoverGeneratedExampleOutputs(
  String exampleDirectory,
  String exampleName,
) {
  final outputs = <String>{};
  for (final entity in Directory(exampleDirectory).listSync(
    recursive: true,
    followLinks: false,
  )) {
    final relativePath = entity.path.substring(exampleDirectory.length + 1);
    if (relativePath.startsWith('.dart_tool/') ||
        !relativePath.endsWith('.g.dart')) {
      continue;
    }
    if (entity is Link) {
      throw ValidationFailure(
        '$exampleName generated path is a symbolic link: $relativePath.',
      );
    }
    if (entity is File) {
      outputs.add(relativePath);
    }
  }
  return outputs;
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
  Duration? timeout,
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
  final exitCodeFuture = process.exitCode;
  int code;
  try {
    code = timeout == null
        ? await exitCodeFuture
        : await exitCodeFuture.timeout(timeout);
  } on TimeoutException {
    process.kill(ProcessSignal.sigterm);
    try {
      await exitCodeFuture.timeout(const Duration(seconds: 5));
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
    }
    throw ValidationFailure(
      '${_command(executable, arguments)} timed out after '
      '${timeout!.inSeconds} seconds in $workingDirectory.',
    );
  }
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

bool _sameSet(Set<String> first, Set<String> second) {
  return first.length == second.length && first.containsAll(second);
}
