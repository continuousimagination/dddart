/// Verifies the real generated example codec, including inherited state.
library;

import 'package:dddart/dddart.dart';
import 'package:dddart_events_distributed_example/custom_stored_event.dart';
import 'package:test/test.dart';

void main() {
  final id = UuidValue.fromString('00000000-0000-4000-8000-000000000001');
  final aggregateId = UuidValue.fromString(
    '00000000-0000-4000-8000-000000000002',
  );
  final created = DateTime.utc(2026, 9, 21);
  final updated = created.add(const Duration(seconds: 1));
  final codec = CustomStoredEventJsonSerializer();
  test('actual example preserves complete inherited and own wire state', () {
    final value = CustomStoredEvent(
      id: id,
      createdAt: created,
      updatedAt: updated,
      aggregateId: aggregateId,
      eventType: 'TestEvent',
      eventJson: '{}',
      userId: 'user',
      tenantId: 'tenant',
      sessionId: 'session',
      userRoles: ['reader'],
      organizationId: 'organization',
    );
    final wire = codec.toJson(value);
    expect(wire.keys.toSet(), {
      'id',
      'createdAt',
      'updatedAt',
      'aggregateId',
      'eventType',
      'eventJson',
      'userId',
      'tenantId',
      'sessionId',
      'userRoles',
      'organizationId',
    });
    final decoded = codec.fromJson(wire);
    expect(codec.toJson(decoded), wire);
    expect(decoded.aggregateId, aggregateId);
    expect(decoded.id, id);
    expect(decoded.createdAt, created);
    expect(decoded.updatedAt, updated);
  });
  test('actual example preserves nullable inherited and own fields', () {
    final value = CustomStoredEvent(
      id: id,
      createdAt: created,
      aggregateId: aggregateId,
      eventType: 'TestEvent',
      eventJson: '{}',
    );
    final decoded = codec.fromJson(codec.toJson(value));
    expect(decoded.userId, isNull);
    expect(decoded.tenantId, isNull);
    expect(decoded.sessionId, isNull);
    expect(decoded.userRoles, isNull);
    expect(decoded.organizationId, isNull);
    expect(decoded.updatedAt, created);
  });
}
