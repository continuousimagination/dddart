import 'package:dddart/dddart.dart';

import 'lib/custom_stored_event.dart';

void main() {
  final event = CustomStoredEvent(
    id: UuidValue.fromString('11111111-1111-4111-8111-111111111111'),
    createdAt: DateTime.utc(2026),
    aggregateId: UuidValue.fromString(
      '22222222-2222-4222-8222-222222222222',
    ),
    eventType: 'ExampleEvent',
    eventJson: '{"example":true}',
    tenantId: 'tenant-1',
    userRoles: const ['reader', 'writer'],
    organizationId: 'org-1',
  );
  final serializer = CustomStoredEventJsonSerializer();
  final restored = serializer.deserialize(serializer.serialize(event));

  if (restored.id != event.id ||
      restored.aggregateId != event.aggregateId ||
      restored.userRoles?.join(',') != event.userRoles?.join(',')) {
    throw StateError('CustomStoredEvent JSON round-trip failed.');
  }
  print('CustomStoredEvent JSON round-trip passed.');
}
