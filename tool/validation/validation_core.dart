import 'dart:convert';
import 'dart:io';

const _gitRepositoryEnvironmentVariables = {
  'GIT_ALTERNATE_OBJECT_DIRECTORIES',
  'GIT_CONFIG',
  'GIT_CONFIG_PARAMETERS',
  'GIT_CONFIG_COUNT',
  'GIT_OBJECT_DIRECTORY',
  'GIT_DIR',
  'GIT_WORK_TREE',
  'GIT_IMPLICIT_WORK_TREE',
  'GIT_GRAFT_FILE',
  'GIT_INDEX_FILE',
  'GIT_NO_REPLACE_OBJECTS',
  'GIT_REPLACE_REF_BASE',
  'GIT_PREFIX',
  'GIT_SHALLOW_FILE',
  'GIT_COMMON_DIR',
};

/// Builds a subprocess environment that discovers Git state from its own
/// working directory instead of inheriting repository-local state from a hook.
Map<String, String> withoutGitRepositoryEnvironment({
  Map<String, String>? environment,
  Map<String, String> additions = const {},
}) {
  final sanitized = Map<String, String>.from(
    environment ?? Platform.environment,
  )..addAll(additions);
  for (final variable in _gitRepositoryEnvironmentVariables) {
    sanitized.remove(variable);
  }
  return sanitized;
}

final class ValidationFailure implements Exception {
  ValidationFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

final class PackagePolicy {
  PackagePolicy({
    required this.name,
    required this.path,
    required this.allowedLocalPackages,
    required this.generationAction,
    required this.generationPrerequisites,
  });

  factory PackagePolicy.fromJson(Map<String, Object?> json) {
    return PackagePolicy(
      name: _requiredString(json, 'name'),
      path: _requiredString(json, 'path'),
      allowedLocalPackages: _stringSet(json, 'allowedLocalPackages'),
      generationAction: _requiredString(json, 'generation'),
      generationPrerequisites: _stringSet(
        json,
        'generationPrerequisites',
        required: false,
      ),
    );
  }

  final String name;
  final String path;
  final Set<String> allowedLocalPackages;
  final String generationAction;
  final Set<String> generationPrerequisites;
}

final class ExampleGenerationPolicy {
  ExampleGenerationPolicy({
    required this.action,
    required this.builders,
    required this.disabledBuilders,
    required this.outputs,
  });

  factory ExampleGenerationPolicy.fromJson(Map<String, Object?> json) {
    return ExampleGenerationPolicy(
      action: _requiredString(json, 'action'),
      builders: _stringSet(json, 'builders', required: false),
      disabledBuilders: _stringSet(
        json,
        'disabledBuilders',
        required: false,
      ),
      outputs: _stringSet(json, 'outputs', required: false),
    );
  }

  final String action;
  final Set<String> builders;
  final Set<String> disabledBuilders;
  final Set<String> outputs;
}

final class ExampleEntrypointPolicy {
  ExampleEntrypointPolicy({
    required this.path,
    required this.classification,
    required this.action,
    required this.reason,
  });

  factory ExampleEntrypointPolicy.fromJson(Map<String, Object?> json) {
    return ExampleEntrypointPolicy(
      path: _requiredString(json, 'path'),
      classification: _requiredString(json, 'classification'),
      action: _requiredString(json, 'action'),
      reason: _requiredString(json, 'reason'),
    );
  }

  final String path;
  final String classification;
  final String action;
  final String reason;
}

final class ExampleSourcePolicy {
  ExampleSourcePolicy({
    required this.path,
    required this.classification,
    required this.action,
    required this.reason,
  });

  factory ExampleSourcePolicy.fromJson(Map<String, Object?> json) {
    return ExampleSourcePolicy(
      path: _requiredString(json, 'path'),
      classification: _requiredString(json, 'classification'),
      action: _requiredString(json, 'action'),
      reason: _requiredString(json, 'reason'),
    );
  }

  final String path;
  final String classification;
  final String action;
  final String reason;
}

final class ExampleServicePolicy {
  ExampleServicePolicy({
    required this.kind,
    required this.localAction,
    required this.ciAction,
    required this.testTag,
    required this.reason,
  });

  factory ExampleServicePolicy.fromJson(Map<String, Object?> json) {
    final testTag = json['testTag'];
    if (testTag != null && (testTag is! String || testTag.trim().isEmpty)) {
      throw ValidationFailure('testTag must be a non-empty string when set.');
    }
    return ExampleServicePolicy(
      kind: _requiredString(json, 'kind'),
      localAction: _requiredString(json, 'localAction'),
      ciAction: _requiredString(json, 'ciAction'),
      testTag: testTag as String?,
      reason: _requiredString(json, 'reason'),
    );
  }

  final String kind;
  final String localAction;
  final String ciAction;
  final String? testTag;
  final String reason;
}

final class ExamplePolicy {
  ExamplePolicy({
    required this.name,
    required this.path,
    required this.category,
    required this.status,
    required this.owners,
    required this.allowedLocalPackages,
    required this.resolution,
    required this.generation,
    required this.entrypoints,
    required this.sourceOverrides,
    required this.externalService,
  });

  factory ExamplePolicy.fromJson(Map<String, Object?> json) {
    return ExamplePolicy(
      name: _requiredString(json, 'name'),
      path: _requiredString(json, 'path'),
      category: _requiredString(json, 'category'),
      status: _requiredString(json, 'status'),
      owners: _stringSet(json, 'owners'),
      allowedLocalPackages: _stringSet(json, 'allowedLocalPackages'),
      resolution: _requiredString(json, 'resolution'),
      generation: ExampleGenerationPolicy.fromJson(
        _objectMap(json['generation'], 'generation'),
      ),
      entrypoints: _objectList(json, 'entrypoints')
          .map(ExampleEntrypointPolicy.fromJson)
          .toList(growable: false),
      sourceOverrides: _objectList(json, 'sourceOverrides')
          .map(ExampleSourcePolicy.fromJson)
          .toList(growable: false),
      externalService: ExampleServicePolicy.fromJson(
        _objectMap(json['externalService'], 'externalService'),
      ),
    );
  }

  final String name;
  final String path;
  final String category;
  final String status;
  final Set<String> owners;
  final Set<String> allowedLocalPackages;
  final String resolution;
  final ExampleGenerationPolicy generation;
  final List<ExampleEntrypointPolicy> entrypoints;
  final List<ExampleSourcePolicy> sourceOverrides;
  final ExampleServicePolicy externalService;
}

final class WorkspaceExemption {
  WorkspaceExemption({
    required this.name,
    required this.path,
    required this.reason,
  });

  factory WorkspaceExemption.fromJson(Map<String, Object?> json) {
    return WorkspaceExemption(
      name: _requiredString(json, 'name'),
      path: _requiredString(json, 'path'),
      reason: _requiredString(json, 'reason'),
    );
  }

  final String name;
  final String path;
  final String reason;
}

final class ServicePolicy {
  ServicePolicy({
    required this.kind,
    required this.host,
    required this.port,
    required this.timeoutSeconds,
  });

  factory ServicePolicy.fromJson(Map<String, Object?> json) {
    return ServicePolicy(
      kind: _requiredString(json, 'kind'),
      host: _requiredString(json, 'host'),
      port: _requiredInt(json, 'port'),
      timeoutSeconds: _requiredInt(json, 'timeoutSeconds'),
    );
  }

  final String kind;
  final String host;
  final int port;
  final int timeoutSeconds;
}

final class TestTagPolicy {
  TestTagPolicy({
    required this.tag,
    required this.packages,
    required this.localAction,
    required this.ciAction,
    required this.reason,
    required this.service,
    required this.ciEnvironment,
  });

  factory TestTagPolicy.fromJson(Map<String, Object?> json) {
    final serviceJson = json['service'];
    final environmentJson = json['ciEnvironment'];
    return TestTagPolicy(
      tag: _requiredString(json, 'tag'),
      packages: _stringSet(json, 'packages'),
      localAction: _requiredString(json, 'localAction'),
      ciAction: _requiredString(json, 'ciAction'),
      reason: _requiredString(json, 'reason'),
      service: serviceJson == null
          ? null
          : ServicePolicy.fromJson(_objectMap(serviceJson, 'service')),
      ciEnvironment: environmentJson == null
          ? const {}
          : _objectMap(environmentJson, 'ciEnvironment').map(
              (key, value) => MapEntry(key, value.toString()),
            ),
    );
  }

  final String tag;
  final Set<String> packages;
  final String localAction;
  final String ciAction;
  final String reason;
  final ServicePolicy? service;
  final Map<String, String> ciEnvironment;
}

final class ValidationInventory {
  ValidationInventory({
    required this.schemaVersion,
    required this.packages,
    required this.examples,
    required this.workspaceExemptions,
    required this.testTagPolicies,
  });

  factory ValidationInventory.fromJson(Map<String, Object?> json) {
    final packageList = _objectList(json, 'packages')
        .map(PackagePolicy.fromJson)
        .toList(growable: false);
    final exampleList = _objectList(json, 'examples')
        .map(ExamplePolicy.fromJson)
        .toList(growable: false);
    final exemptionList = _objectList(json, 'workspaceExemptions')
        .map(WorkspaceExemption.fromJson)
        .toList(growable: false);
    final testTagList = _objectList(json, 'testTagPolicies')
        .map(TestTagPolicy.fromJson)
        .toList(growable: false);

    return ValidationInventory(
      schemaVersion: _requiredInt(json, 'schemaVersion'),
      packages: {for (final package in packageList) package.name: package},
      examples: {for (final example in exampleList) example.name: example},
      workspaceExemptions: {
        for (final exemption in exemptionList) exemption.name: exemption,
      },
      testTagPolicies: testTagList,
    );
  }

  final int schemaVersion;
  final Map<String, PackagePolicy> packages;
  final Map<String, ExamplePolicy> examples;
  final Map<String, WorkspaceExemption> workspaceExemptions;
  final List<TestTagPolicy> testTagPolicies;
}

final class WorkspacePackage {
  WorkspacePackage({required this.name, required this.path});

  final String name;
  final String path;
}

ValidationInventory loadInventory(String repositoryRoot) {
  final file = File(
    '$repositoryRoot/tool/validation/inventory.json',
  );
  if (!file.existsSync()) {
    throw ValidationFailure('Validation inventory is missing: ${file.path}');
  }

  final decoded = jsonDecode(file.readAsStringSync());
  return ValidationInventory.fromJson(_objectMap(decoded, 'inventory'));
}

List<WorkspacePackage> parseWorkspacePackages(String jsonText) {
  final decoded = _objectMap(jsonDecode(jsonText), 'workspace list');
  return _objectList(decoded, 'packages')
      .map(
        (package) => WorkspacePackage(
          name: _requiredString(package, 'name'),
          path: _requiredString(package, 'path'),
        ),
      )
      .toList(growable: false);
}

Map<String, Set<String>> parseDirectDependencyGraph(String jsonText) {
  final decoded = _objectMap(jsonDecode(jsonText), 'pub dependency graph');
  final graph = <String, Set<String>>{};
  for (final package in _objectList(decoded, 'packages')) {
    graph[_requiredString(package, 'name')] = _stringSet(
      package,
      'directDependencies',
      required: false,
    );
  }
  return graph;
}

Set<String> localDependencyClosure(
  String rootPackage,
  Map<String, Set<String>> dependencyGraph,
  Set<String> localPackageNames,
) {
  if (!dependencyGraph.containsKey(rootPackage)) {
    throw ValidationFailure(
      'Resolved dependency graph does not contain $rootPackage.',
    );
  }

  final closure = <String>{};
  final pending = <String>[rootPackage];
  while (pending.isNotEmpty) {
    final current = pending.removeLast();
    if (!closure.add(current)) {
      continue;
    }
    for (final dependency in dependencyGraph[current] ?? const <String>{}) {
      if (localPackageNames.contains(dependency)) {
        pending.add(dependency);
      }
    }
  }
  return closure;
}

void validateInventoryShape(ValidationInventory inventory) {
  if (inventory.schemaVersion != 2) {
    throw ValidationFailure(
      'Unsupported validation inventory schema ${inventory.schemaVersion}.',
    );
  }
  if (inventory.packages.isEmpty) {
    throw ValidationFailure(
      'The validation inventory must declare at least one public package.',
    );
  }
  if (inventory.examples.isEmpty) {
    throw ValidationFailure(
      'The validation inventory must declare at least one example.',
    );
  }

  final packagePaths = <String>{};
  for (final package in inventory.packages.values) {
    if (!packagePaths.add(package.path)) {
      throw ValidationFailure('Duplicate package path: ${package.path}.');
    }
    if (!package.allowedLocalPackages.contains(package.name)) {
      throw ValidationFailure(
        '${package.name} must include itself in allowedLocalPackages.',
      );
    }
    if (!const {'none', 'required'}.contains(package.generationAction)) {
      throw ValidationFailure(
        '${package.name} has unsupported generation policy '
        '${package.generationAction}.',
      );
    }
    final unknownAllowed = package.allowedLocalPackages
        .difference(inventory.packages.keys.toSet());
    if (unknownAllowed.isNotEmpty) {
      throw ValidationFailure(
        '${package.name} allows unknown local packages: '
        '${_sorted(unknownAllowed)}.',
      );
    }
    final unknownPrerequisites = package.generationPrerequisites
        .difference(inventory.packages.keys.toSet());
    if (unknownPrerequisites.isNotEmpty) {
      throw ValidationFailure(
        '${package.name} has unknown generation prerequisites: '
        '${_sorted(unknownPrerequisites)}.',
      );
    }
    if (package.generationPrerequisites.contains(package.name)) {
      throw ValidationFailure(
        '${package.name} cannot be its own generation prerequisite.',
      );
    }
    for (final prerequisite in package.generationPrerequisites) {
      if (inventory.packages[prerequisite]!.generationAction != 'required') {
        throw ValidationFailure(
          '${package.name} generation prerequisite $prerequisite is not '
          'marked generation: required.',
        );
      }
    }
  }

  for (final exemption in inventory.workspaceExemptions.values) {
    if (exemption.reason.trim().isEmpty) {
      throw ValidationFailure(
        'Workspace exemption ${exemption.name} has no justification.',
      );
    }
    if (inventory.packages.containsKey(exemption.name)) {
      throw ValidationFailure(
        '${exemption.name} cannot be both public and exempt.',
      );
    }
  }

  const classifications = {'runnable', 'illustrative', 'legacy'};
  const exampleStatuses = {'active', 'wip'};
  const resolutions = {'workspace', 'standalone'};
  const generationActions = {'none', 'required'};
  const entrypointActions = {'run', 'compile', 'service', 'excluded'};
  const sourceActions = {'analyze', 'excluded'};
  const exampleServiceKinds = {'none', 'mongo', 'dynamodb', 'mysql', 'slack'};
  const exampleServiceActions = {'not-required', 'compile', 'run'};
  final examplePaths = <String>{};
  for (final example in inventory.examples.values) {
    if (!examplePaths.add(example.path)) {
      throw ValidationFailure('Duplicate example path: ${example.path}.');
    }
    if (!classifications.contains(example.category)) {
      throw ValidationFailure(
        '${example.name} has unsupported category ${example.category}.',
      );
    }
    if (!exampleStatuses.contains(example.status)) {
      throw ValidationFailure(
        '${example.name} has unsupported status ${example.status}.',
      );
    }
    if (!resolutions.contains(example.resolution)) {
      throw ValidationFailure(
        '${example.name} has unsupported resolution ${example.resolution}.',
      );
    }
    final unknownOwners = example.owners.difference(
      inventory.packages.keys.toSet(),
    );
    if (unknownOwners.isNotEmpty) {
      throw ValidationFailure(
        '${example.name} names unknown owners: ${_sorted(unknownOwners)}.',
      );
    }
    final unknownAllowed = example.allowedLocalPackages.difference(
      inventory.packages.keys.toSet(),
    );
    if (unknownAllowed.isNotEmpty) {
      throw ValidationFailure(
        '${example.name} allows unknown local packages: '
        '${_sorted(unknownAllowed)}.',
      );
    }
    if (!generationActions.contains(example.generation.action)) {
      throw ValidationFailure(
        '${example.name} has unsupported generation action '
        '${example.generation.action}.',
      );
    }
    final generation = example.generation;
    final generationMetadata = {
      ...generation.builders,
      ...generation.disabledBuilders,
      ...generation.outputs,
    };
    if (generation.action == 'none' && generationMetadata.isNotEmpty) {
      throw ValidationFailure(
        '${example.name} marks generation none but declares generation '
        'metadata.',
      );
    }
    if (generation.action == 'required' &&
        (generation.builders.isEmpty || generation.outputs.isEmpty)) {
      throw ValidationFailure(
        '${example.name} requires generation and must declare builders and '
        'outputs.',
      );
    }
    final builderOverlap = generation.builders.intersection(
      generation.disabledBuilders,
    );
    if (builderOverlap.isNotEmpty) {
      throw ValidationFailure(
        '${example.name} both enables and disables builders: '
        '${_sorted(builderOverlap)}.',
      );
    }
    for (final builder in {
      ...generation.builders,
      ...generation.disabledBuilders,
    }) {
      if (!RegExp(r'^[a-z0-9_]+:[a-z0-9_]+$').hasMatch(builder)) {
        throw ValidationFailure(
          '${example.name} uses non-canonical builder key $builder.',
        );
      }
    }
    for (final output in generation.outputs) {
      _validateRelativePolicyPath(example.name, output);
      if (!output.endsWith('.g.dart')) {
        throw ValidationFailure(
          '${example.name} generated output must end in .g.dart: $output.',
        );
      }
    }

    if (example.entrypoints.isEmpty) {
      throw ValidationFailure(
        '${example.name} must account for at least one entrypoint.',
      );
    }
    final entrypointPaths = <String>{};
    for (final entrypoint in example.entrypoints) {
      _validateRelativePolicyPath(example.name, entrypoint.path);
      if (!entrypointPaths.add(entrypoint.path)) {
        throw ValidationFailure(
          '${example.name} declares duplicate entrypoint ${entrypoint.path}.',
        );
      }
      if (!classifications.contains(entrypoint.classification)) {
        throw ValidationFailure(
          '${example.name} entrypoint ${entrypoint.path} has unsupported '
          'classification ${entrypoint.classification}.',
        );
      }
      if (!entrypointActions.contains(entrypoint.action)) {
        throw ValidationFailure(
          '${example.name} entrypoint ${entrypoint.path} has unsupported '
          'action ${entrypoint.action}.',
        );
      }
      if (entrypoint.classification == 'runnable' &&
          entrypoint.action == 'excluded') {
        throw ValidationFailure(
          '${example.name} cannot exclude runnable entrypoint '
          '${entrypoint.path}.',
        );
      }
      if (entrypoint.classification == 'illustrative' &&
          entrypoint.action == 'excluded') {
        throw ValidationFailure(
          '${example.name} illustrative entrypoint ${entrypoint.path} must '
          'be analyzed and compiled.',
        );
      }
      if (entrypoint.classification == 'legacy' &&
          entrypoint.action != 'excluded') {
        throw ValidationFailure(
          '${example.name} legacy entrypoint ${entrypoint.path} must be '
          'excluded.',
        );
      }
    }

    final overriddenSourcePaths = <String>{};
    for (final source in example.sourceOverrides) {
      _validateRelativePolicyPath(example.name, source.path);
      if (!overriddenSourcePaths.add(source.path)) {
        throw ValidationFailure(
          '${example.name} declares duplicate source override ${source.path}.',
        );
      }
      if (entrypointPaths.contains(source.path)) {
        throw ValidationFailure(
          '${example.name} source override ${source.path} is already an '
          'entrypoint.',
        );
      }
      if (!classifications.contains(source.classification) ||
          !sourceActions.contains(source.action)) {
        throw ValidationFailure(
          '${example.name} source override ${source.path} has unsupported '
          'classification/action ${source.classification}/${source.action}.',
        );
      }
      if (source.classification == 'runnable' && source.action != 'analyze') {
        throw ValidationFailure(
          '${example.name} runnable source ${source.path} must be analyzed.',
        );
      }
      if (source.classification == 'illustrative' &&
          source.action != 'analyze') {
        throw ValidationFailure(
          '${example.name} illustrative source ${source.path} must be '
          'analyzed.',
        );
      }
      if (source.classification == 'legacy' && source.action != 'excluded') {
        throw ValidationFailure(
          '${example.name} legacy source ${source.path} must be excluded.',
        );
      }
    }

    final service = example.externalService;
    if (!exampleServiceKinds.contains(service.kind) ||
        !exampleServiceActions.contains(service.localAction) ||
        !exampleServiceActions.contains(service.ciAction)) {
      throw ValidationFailure(
        '${example.name} has unsupported external-service policy '
        '${service.kind}/${service.localAction}/${service.ciAction}.',
      );
    }
    if (service.kind == 'none') {
      if (service.localAction != 'not-required' ||
          service.ciAction != 'not-required' ||
          service.testTag != null) {
        throw ValidationFailure(
          '${example.name} has kind none but configures an external service.',
        );
      }
    } else if (service.ciAction == 'run' && service.testTag == null) {
      throw ValidationFailure(
        '${example.name} runs an external service in CI without a testTag.',
      );
    }
    if (example.entrypoints
            .any((entrypoint) => entrypoint.action == 'service') &&
        service.kind == 'none') {
      throw ValidationFailure(
        '${example.name} has service entrypoints without a service policy.',
      );
    }
  }

  const actions = {'exclude', 'run'};
  const serviceKinds = {'mongo', 'dynamodb', 'mysql'};
  final seenTags = <String>{};
  final packageServiceKinds = <String, String>{};
  for (final policy in inventory.testTagPolicies) {
    if (!seenTags.add(policy.tag)) {
      throw ValidationFailure(
        'Test-tag policy ${policy.tag} is declared more than once.',
      );
    }
    if (!actions.contains(policy.localAction) ||
        !actions.contains(policy.ciAction)) {
      throw ValidationFailure(
        'Unsupported action for test tag ${policy.tag}: '
        '${policy.localAction}/${policy.ciAction}.',
      );
    }
    if (policy.reason.trim().isEmpty) {
      throw ValidationFailure(
        'Test-tag policy ${policy.tag} has no justification.',
      );
    }
    final unknownPackages =
        policy.packages.difference(inventory.packages.keys.toSet());
    if (unknownPackages.isNotEmpty) {
      throw ValidationFailure(
        'Test-tag policy ${policy.tag} names unknown packages: '
        '${_sorted(unknownPackages)}.',
      );
    }
    if (policy.service case final service?) {
      if (!serviceKinds.contains(service.kind)) {
        throw ValidationFailure(
          'Test-tag policy ${policy.tag} uses unsupported CI service kind '
          '${service.kind}.',
        );
      }
      if (policy.ciAction != 'run') {
        throw ValidationFailure(
          'Service-backed test tag ${policy.tag} must run in CI.',
        );
      }
      for (final packageName in policy.packages) {
        final previous = packageServiceKinds[packageName];
        if (previous != null && previous != service.kind) {
          throw ValidationFailure(
            '$packageName requires multiple CI service kinds: '
            '$previous and ${service.kind}.',
          );
        }
        packageServiceKinds[packageName] = service.kind;
      }
    }
  }

  final policiesByTag = {
    for (final policy in inventory.testTagPolicies) policy.tag: policy,
  };
  for (final example in inventory.examples.values) {
    final service = example.externalService;
    if (service.testTag case final testTag?) {
      final policy = policiesByTag[testTag];
      if (policy == null || policy.service?.kind != service.kind) {
        throw ValidationFailure(
          '${example.name} external service ${service.kind} references '
          'incompatible test tag $testTag.',
        );
      }
    }
  }
}

void _validateRelativePolicyPath(String exampleName, String path) {
  if (path.startsWith('/') ||
      path.contains(r'\') ||
      RegExp(r'^[a-zA-Z]:').hasMatch(path) ||
      path == '.' ||
      path.split('/').any((segment) => segment.isEmpty || segment == '..')) {
    throw ValidationFailure(
      '$exampleName declares invalid relative path $path.',
    );
  }
}

Set<String> parseDeclaredServiceTags(String dartTestYaml) {
  return RegExp(
    r'^  (requires-[a-z0-9-]+):',
    multiLine: true,
  ).allMatches(dartTestYaml).map((match) => match.group(1)!).toSet();
}

Set<String> parseUsedServiceTags(Iterable<String> dartSources) {
  final tags = <String>{};
  final tagLists = RegExp(
    r'(?:@Tags\s*\(|\btags\s*:)\s*\[([^\]]*)\]',
    multiLine: true,
    dotAll: true,
  );
  final tagValues = RegExp(r'''['"](requires-[a-z0-9-]+)['"]''');
  for (final source in dartSources) {
    for (final listMatch in tagLists.allMatches(source)) {
      for (final tagMatch in tagValues.allMatches(listMatch.group(1)!)) {
        tags.add(tagMatch.group(1)!);
      }
    }
  }
  return tags;
}

Set<String> parseConfiguredExampleBuilderKeys(String buildYaml) {
  return RegExp(
    r'^ {6}([a-z0-9_]+:[a-z0-9_]+):\s*$',
    multiLine: true,
  ).allMatches(buildYaml).map((match) => match.group(1)!).toSet();
}

Future<void> stagePublishedPackage({
  required String sourceDirectory,
  required String destinationDirectory,
  required String archivePath,
}) async {
  final destination = Directory(destinationDirectory);
  if (destination.existsSync() && destination.listSync().isNotEmpty) {
    throw ValidationFailure(
      'Refusing to extract a Pub archive into non-empty directory: '
      '$destinationDirectory.',
    );
  }
  destination.createSync(recursive: true);
  final archive = File(archivePath);
  if (archive.existsSync()) {
    throw ValidationFailure('Refusing to reuse Pub archive: $archivePath.');
  }
  archive.parent.createSync(recursive: true);
  final archiveResult = await Process.run(
    Platform.resolvedExecutable,
    [
      'pub',
      'publish',
      '--skip-validation',
      '--to-archive=$archivePath',
    ],
    workingDirectory: sourceDirectory,
    environment: withoutGitRepositoryEnvironment(
      additions: const {'CI': 'true'},
    ),
    includeParentEnvironment: false,
  );
  if (archiveResult.exitCode != 0 || !archive.existsSync()) {
    throw ValidationFailure(
      'Could not derive Pub archive for $sourceDirectory '
      '(exit ${archiveResult.exitCode}).\n'
      '${archiveResult.stdout}${archiveResult.stderr}',
    );
  }

  final extractResult = await Process.run(
    'tar',
    ['-xzf', archivePath, '-C', destinationDirectory],
  );
  if (extractResult.exitCode != 0) {
    throw ValidationFailure(
      'Could not extract Pub archive for $sourceDirectory '
      '(exit ${extractResult.exitCode}).\n'
      '${extractResult.stdout}${extractResult.stderr}',
    );
  }
}

void validateServiceTagCoverage({
  required ValidationInventory inventory,
  required Map<String, Set<String>> declaredTagsByPackage,
  required Map<String, Set<String>> usedTagsByPackage,
}) {
  for (final package in inventory.packages.values) {
    final declared = declaredTagsByPackage[package.name] ?? const <String>{};
    final used = usedTagsByPackage[package.name] ?? const <String>{};
    if (!_sameSet(declared, used)) {
      throw ValidationFailure(
        '${package.name} service-tag declarations drifted. Declared '
        '${_sorted(declared)}; used ${_sorted(used)}.',
      );
    }

    final configured = inventory.testTagPolicies
        .where((policy) => policy.packages.contains(package.name))
        .map((policy) => policy.tag)
        .where((tag) => tag.startsWith('requires-'))
        .toSet();
    if (!_sameSet(used, configured)) {
      throw ValidationFailure(
        '${package.name} service-tag policy drifted. Used '
        '${_sorted(used)}; configured ${_sorted(configured)}.',
      );
    }
  }
}

void validateWorkspaceCoverage({
  required String repositoryRoot,
  required ValidationInventory inventory,
  required List<WorkspacePackage> workspacePackages,
}) {
  final rootPath = Directory(repositoryRoot).absolute.path;
  final nonRoot = {
    for (final package in workspacePackages)
      if (Directory(package.path).absolute.path != rootPath)
        package.name: package,
  };
  final classifiedNames = <String>{
    ...inventory.packages.keys,
    ...inventory.examples.values
        .where((example) => example.resolution == 'workspace')
        .map((example) => example.name),
    ...inventory.workspaceExemptions.keys,
  };
  final missing = nonRoot.keys.toSet().difference(classifiedNames);
  final stale = classifiedNames.difference(nonRoot.keys.toSet());
  if (missing.isNotEmpty || stale.isNotEmpty) {
    throw ValidationFailure(
      'Workspace inventory drift. Unclassified: ${_sorted(missing)}; '
      'not in workspace: ${_sorted(stale)}.',
    );
  }

  for (final policy in inventory.packages.values) {
    _validateWorkspacePath(
      repositoryRoot: repositoryRoot,
      expectedRelativePath: policy.path,
      workspacePackage: nonRoot[policy.name]!,
    );
  }
  for (final exemption in inventory.workspaceExemptions.values) {
    _validateWorkspacePath(
      repositoryRoot: repositoryRoot,
      expectedRelativePath: exemption.path,
      workspacePackage: nonRoot[exemption.name]!,
    );
  }
  for (final example in inventory.examples.values.where(
    (example) => example.resolution == 'workspace',
  )) {
    _validateWorkspacePath(
      repositoryRoot: repositoryRoot,
      expectedRelativePath: example.path,
      workspacePackage: nonRoot[example.name]!,
    );
  }
}

void validateExampleDirectoryCoverage({
  required ValidationInventory inventory,
  required Map<String, String> discoveredExamples,
}) {
  final configuredNames = inventory.examples.keys.toSet();
  final discoveredNames = discoveredExamples.keys.toSet();
  final missing = discoveredNames.difference(configuredNames);
  final stale = configuredNames.difference(discoveredNames);
  if (missing.isNotEmpty || stale.isNotEmpty) {
    throw ValidationFailure(
      'Example inventory drift. Unclassified: ${_sorted(missing)}; '
      'not discovered: ${_sorted(stale)}.',
    );
  }
  for (final example in inventory.examples.values) {
    final discoveredPath = discoveredExamples[example.name];
    if (discoveredPath != example.path) {
      throw ValidationFailure(
        '${example.name} example path drifted: expected ${example.path}, '
        'found $discoveredPath.',
      );
    }
  }
}

void validateConfiguredClosures({
  required ValidationInventory inventory,
  required Map<String, Set<String>> dependencyGraph,
}) {
  final localNames = inventory.packages.keys.toSet();
  for (final package in inventory.packages.values) {
    final actual = localDependencyClosure(
      package.name,
      dependencyGraph,
      localNames,
    );
    if (!_sameSet(actual, package.allowedLocalPackages)) {
      throw ValidationFailure(
        '${package.name} local dependency closure drifted. Expected '
        '${_sorted(package.allowedLocalPackages)}; resolved ${_sorted(actual)}.',
      );
    }
  }
}

void validateConsumerDependencyGraph({
  required String jsonText,
  required String consumerName,
  required PackagePolicy policy,
  required Set<String> intendedPublicPackages,
}) {
  final decoded = _objectMap(jsonDecode(jsonText), 'consumer dependencies');
  final packages = _objectList(decoded, 'packages');
  final resolvedLocal = <String>{};
  Map<String, Object?>? consumer;

  for (final package in packages) {
    final name = _requiredString(package, 'name');
    if (name == consumerName) {
      consumer = package;
    }
    if (intendedPublicPackages.contains(name)) {
      resolvedLocal.add(name);
      if (_requiredString(package, 'source') != 'path') {
        throw ValidationFailure(
          'Isolated consumer resolved $name from a non-path source.',
        );
      }
    }
  }

  if (consumer == null) {
    throw ValidationFailure('Consumer graph does not contain $consumerName.');
  }
  final directPublic = _stringSet(
    consumer,
    'directDependencies',
    required: false,
  ).intersection(intendedPublicPackages);
  if (!_sameSet(directPublic, {policy.name})) {
    throw ValidationFailure(
      '$consumerName must directly depend only on ${policy.name}; found '
      '${_sorted(directPublic)}.',
    );
  }
  if (!_sameSet(resolvedLocal, policy.allowedLocalPackages)) {
    final forbidden = resolvedLocal.difference(policy.allowedLocalPackages);
    final missing = policy.allowedLocalPackages.difference(resolvedLocal);
    throw ValidationFailure(
      '${policy.name} isolated dependency boundary failed. '
      'Forbidden local packages: ${_sorted(forbidden)}; '
      'missing required packages: ${_sorted(missing)}.',
    );
  }
}

void validateExampleDependencyGraph({
  required String jsonText,
  required ExamplePolicy policy,
  required Set<String> intendedPublicPackages,
}) {
  final decoded = _objectMap(jsonDecode(jsonText), 'example dependencies');
  final packages = _objectList(decoded, 'packages');
  final dependencyGraph = parseDirectDependencyGraph(jsonText);
  final root = packages.where(
    (package) => _requiredString(package, 'name') == policy.name,
  );
  if (root.length != 1) {
    throw ValidationFailure(
      '${policy.name} dependency graph must contain exactly one example root.',
    );
  }
  dependencyGraph[policy.name]!.addAll(
    _stringSet(root.single, 'devDependencies', required: false),
  );
  final actual = localDependencyClosure(
    policy.name,
    dependencyGraph,
    intendedPublicPackages,
  )..remove(policy.name);
  final packagesByName = {
    for (final package in packages) _requiredString(package, 'name'): package,
  };
  for (final packageName in actual) {
    final source = _requiredString(packagesByName[packageName]!, 'source');
    final expectedSource = policy.resolution == 'workspace' ? 'root' : 'path';
    if (source != expectedSource) {
      throw ValidationFailure(
        '${policy.name} resolved $packageName from source $source; expected '
        '$expectedSource for its ${policy.resolution} resolution policy.',
      );
    }
  }
  if (!_sameSet(actual, policy.allowedLocalPackages)) {
    final forbidden = actual.difference(policy.allowedLocalPackages);
    final missing = policy.allowedLocalPackages.difference(actual);
    throw ValidationFailure(
      '${policy.name} example dependency boundary failed. Forbidden local '
      'packages: ${_sorted(forbidden)}; missing required packages: '
      '${_sorted(missing)}.',
    );
  }
}

bool isMarkedPublishable(String pubspecContents) {
  final match = RegExp(
    r'^publish_to:\s*([^#\r\n]+)',
    multiLine: true,
  ).firstMatch(pubspecContents);
  if (match == null) {
    return true;
  }
  final value =
      match.group(1)!.trim().replaceAll(RegExp(r'''^['"]|['"]$'''), '');
  return value != 'none';
}

List<TestTagPolicy> testPoliciesFor(
  ValidationInventory inventory,
  String packageName,
) {
  return inventory.testTagPolicies
      .where((policy) => policy.packages.contains(packageName))
      .toList(growable: false);
}

void _validateWorkspacePath({
  required String repositoryRoot,
  required String expectedRelativePath,
  required WorkspacePackage workspacePackage,
}) {
  final expected = Directory(
    '$repositoryRoot/$expectedRelativePath',
  ).absolute.path;
  final actual = Directory(workspacePackage.path).absolute.path;
  if (actual != expected) {
    throw ValidationFailure(
      '${workspacePackage.name} path drifted: expected $expected, found $actual.',
    );
  }
}

bool _sameSet(Set<String> first, Set<String> second) {
  return first.length == second.length && first.containsAll(second);
}

String _sorted(Iterable<String> values) {
  final sorted = values.toList()..sort();
  return sorted.join(', ');
}

Map<String, Object?> _objectMap(Object? value, String context) {
  if (value is! Map) {
    throw ValidationFailure('$context must be a JSON object.');
  }
  return value.map((key, value) => MapEntry(key.toString(), value));
}

List<Map<String, Object?>> _objectList(
  Map<String, Object?> json,
  String key,
) {
  final value = json[key];
  if (value is! List) {
    throw ValidationFailure('$key must be a JSON array.');
  }
  return value.map((entry) => _objectMap(entry, key)).toList(growable: false);
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw ValidationFailure('$key must be a non-empty string.');
  }
  return value;
}

int _requiredInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int) {
    throw ValidationFailure('$key must be an integer.');
  }
  return value;
}

Set<String> _stringSet(
  Map<String, Object?> json,
  String key, {
  bool required = true,
}) {
  final value = json[key];
  if (value == null && !required) {
    return <String>{};
  }
  if (value is! List || value.any((entry) => entry is! String)) {
    throw ValidationFailure('$key must be an array of strings.');
  }
  final result = value.cast<String>().toSet();
  if (required && result.isEmpty) {
    throw ValidationFailure('$key must not be empty.');
  }
  if (result.length != value.length) {
    throw ValidationFailure('$key must not contain duplicates.');
  }
  return result;
}
