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
    required this.workspaceExemptions,
    required this.testTagPolicies,
  });

  factory ValidationInventory.fromJson(Map<String, Object?> json) {
    final packageList = _objectList(json, 'packages')
        .map(PackagePolicy.fromJson)
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
      workspaceExemptions: {
        for (final exemption in exemptionList) exemption.name: exemption,
      },
      testTagPolicies: testTagList,
    );
  }

  final int schemaVersion;
  final Map<String, PackagePolicy> packages;
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
  if (inventory.schemaVersion != 1) {
    throw ValidationFailure(
      'Unsupported validation inventory schema ${inventory.schemaVersion}.',
    );
  }
  if (inventory.packages.isEmpty) {
    throw ValidationFailure(
      'The validation inventory must declare at least one public package.',
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
