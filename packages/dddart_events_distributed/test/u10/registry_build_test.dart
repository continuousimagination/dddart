/// Build-level regression for standalone registry output and imports.
library;

import 'dart:io';

import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:dddart_events_distributed/src/generators/event_registry_generator.dart';
import 'package:test/test.dart';

const eventSource = """
import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
@Serializable()
class FixtureEvent extends DomainEvent {
  FixtureEvent({required super.aggregateId});
  static FixtureEvent fromJson(Map<String, dynamic> json) =>
    FixtureEvent(aggregateId: UuidValue.fromString(json['aggregateId'] as String));
}
""";

void main() {
  test('build.yaml and factory own the same standalone output', () {
    final config = File('build.yaml').readAsStringSync();
    expect(config, contains('[".event_registry.g.dart"]'));
    expect(config, contains('build_to: source'));
    expect(config, isNot(contains('combining_builder')));
    expect(
      eventRegistryBuilder(BuilderOptions.empty).buildExtensions['.dart'],
      ['.event_registry.g.dart'],
    );
  });
  test(
    'emits the expected registry and imports its defining library',
    () async {
      await testBuilder(
        eventRegistryBuilder(BuilderOptions.empty),
        {'dddart_events_distributed|test/u10/input.dart': eventSource},
        outputs: {
          'dddart_events_distributed|test/u10/input.event_registry.g.dart':
              decodedMatches(
                allOf(
                  contains("import 'input.dart';"),
                  contains("'FixtureEvent': FixtureEvent.fromJson"),
                ),
              ),
        },
        readerWriter: await _reader(),
      );
    },
  );
  test('no events means no generated registry output', () async {
    await testBuilder(
      eventRegistryBuilder(BuilderOptions.empty),
      {'dddart_events_distributed|test/u10/input.dart': 'class Plain {}'},
      outputs: {},
      readerWriter: await _reader(),
    );
  });
}

Future<TestReaderWriter> _reader() async {
  final reader = TestReaderWriter(rootPackage: 'dddart_events_distributed');
  await reader.testing.loadIsolateSources();
  return reader;
}
