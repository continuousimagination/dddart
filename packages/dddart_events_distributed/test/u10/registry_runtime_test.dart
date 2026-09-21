/// Requires and executes the actual generated registry output.
library;

import 'package:dddart/dddart.dart';
import 'package:test/test.dart';

import 'registry_events.dart';
import 'registry_events.event_registry.g.dart';

void main() {
  test('generated registry dispatches to its defining library factory', () {
    final id = UuidValue.fromString('00000000-0000-4000-8000-000000000001');
    expect(generatedEventRegistry.keys, ['RegistryFixtureEvent']);
    final event = generatedEventRegistry['RegistryFixtureEvent']!({
      'aggregateId': id.uuid,
      'message': 'test',
    });
    expect(event, isA<RegistryFixtureEvent>());
    expect(event.aggregateId, id);
    expect((event as RegistryFixtureEvent).message, 'test');
  });
  test('malformed payload remains rejected by the event factory', () {
    expect(
      () => generatedEventRegistry['RegistryFixtureEvent']!({
        'aggregateId': 'invalid',
        'message': 'test',
      }),
      throwsArgumentError,
    );
    expect(
      () => generatedEventRegistry['RegistryFixtureEvent']!({
        'aggregateId': '00000000-0000-4000-8000-000000000001',
        'message': 3,
      }),
      throwsA(isA<TypeError>()),
    );
  });
}
