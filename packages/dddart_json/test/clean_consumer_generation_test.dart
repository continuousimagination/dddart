import 'dart:io';

import 'package:test/test.dart';

void main() {
  test(
    'a clean consumer receives every dependency required for generation',
    () async {
      final packageRoot = _findPackageRoot();
      final packagesRoot = packageRoot.parent;
      final fixture = Directory.systemTemp.createTempSync(
        'dddart_json_clean_consumer_',
      );
      addTearDown(() => fixture.deleteSync(recursive: true));

      File('${fixture.path}/pubspec.yaml').writeAsStringSync('''
name: dddart_json_clean_consumer
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
      File('${libDirectory.path}/model.dart').writeAsStringSync('''
import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

part 'model.g.dart';

@Serializable()
class ConsumerAggregate extends AggregateRoot {
  ConsumerAggregate({
    required this.name,
    super.id,
    super.createdAt,
    super.updatedAt,
  });

  final String name;
}
''');

      final binDirectory = Directory('${fixture.path}/bin')..createSync();
      File('${binDirectory.path}/main.dart').writeAsStringSync('''
import 'package:dddart_json_clean_consumer/model.dart';

void main() {
  final serializer = ConsumerAggregateJsonSerializer();
  final original = ConsumerAggregate(name: 'clean consumer');
  final restored = serializer.deserialize(serializer.serialize(original));
  if (restored.name != original.name || restored.id != original.id) {
    throw StateError('Generated serializer failed to round-trip the aggregate.');
  }
}
''');

      await _expectDartSuccess(fixture, ['pub', 'get', '--offline']);
      await _expectDartSuccess(
        fixture,
        [
          'run',
          'build_runner',
          'build',
          '--delete-conflicting-outputs',
        ],
      );

      expect(File('${libDirectory.path}/model.g.dart').existsSync(), isTrue);
      await _expectDartSuccess(fixture, ['analyze', '--no-fatal-warnings']);
      await _expectDartSuccess(fixture, ['run', 'bin/main.dart']);
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

Future<void> _expectDartSuccess(
  Directory workingDirectory,
  List<String> arguments,
) async {
  final result = await Process.run(
    Platform.resolvedExecutable,
    arguments,
    workingDirectory: workingDirectory.path,
    environment: {
      ...Platform.environment,
      'CI': 'true',
    },
  );

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
