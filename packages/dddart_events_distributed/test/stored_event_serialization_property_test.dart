/// Property-based tests for StoredEvent serialization.
///
/// **Feature: distributed-events, Property 2: Serialization preserves event
/// data**
/// **Validates: Requirements 1.3**
@Tags(['property-test'])
library;

import 'dart:math';

import 'package:dddart/dddart.dart';
import 'package:dddart_events_distributed/src/stored_event.dart';
import 'package:test/test.dart';

void main() {
  group('Property 2: Serialization preserves event data', () {
    test(
      'should preserve all StoredEvent fields through toJson/fromJson cycles',
      () {
        final random = Random(42);

        for (var i = 0; i < 100; i++) {
          // Generate random StoredEvent
          final storedEvent = _generateRandomStoredEvent(random);

          // Serialize to JSON
          final json = storedEvent.toJson();

          // Deserialize from JSON
          final deserialized = StoredEvent.fromJson(json);

          // Verify all fields are preserved
          expect(
            deserialized.id,
            equals(storedEvent.id),
            reason: 'Iteration $i: id should be preserved',
          );
          expect(
            deserialized.createdAt.millisecondsSinceEpoch,
            equals(storedEvent.createdAt.millisecondsSinceEpoch),
            reason: 'Iteration $i: createdAt should be preserved',
          );
          expect(
            deserialized.aggregateId,
            equals(storedEvent.aggregateId),
            reason: 'Iteration $i: aggregateId should be preserved',
          );
          expect(
            deserialized.eventType,
            equals(storedEvent.eventType),
            reason: 'Iteration $i: eventType should be preserved',
          );
          expect(
            deserialized.eventJson,
            equals(storedEvent.eventJson),
            reason: 'Iteration $i: eventJson should be preserved',
          );
          expect(
            deserialized.userId,
            equals(storedEvent.userId),
            reason: 'Iteration $i: userId should be preserved',
          );
          expect(
            deserialized.tenantId,
            equals(storedEvent.tenantId),
            reason: 'Iteration $i: tenantId should be preserved',
          );
          expect(
            deserialized.sessionId,
            equals(storedEvent.sessionId),
            reason: 'Iteration $i: sessionId should be preserved',
          );
        }
      },
    );

    test(
      'should handle nullable authorization fields correctly',
      () {
        final random = Random(44);

        for (var i = 0; i < 100; i++) {
          // Randomly include or exclude authorization fields
          final includeUserId = random.nextBool();
          final includeTenantId = random.nextBool();
          final includeSessionId = random.nextBool();

          final storedEvent = StoredEvent(
            id: UuidValue.generate(),
            createdAt: DateTime.now(),
            aggregateId: UuidValue.generate(),
            eventType: 'TestEvent',
            eventJson: '{"data":"test"}',
            userId: includeUserId ? 'user-${random.nextInt(1000)}' : null,
            tenantId: includeTenantId ? 'tenant-${random.nextInt(100)}' : null,
            sessionId:
                includeSessionId ? 'session-${random.nextInt(10000)}' : null,
          );

          // Serialize and deserialize
          final json = storedEvent.toJson();
          final deserialized = StoredEvent.fromJson(json);

          // Verify nullable fields are preserved correctly
          expect(
            deserialized.userId,
            equals(storedEvent.userId),
            reason: 'Iteration $i: userId should be preserved (null or value)',
          );
          expect(
            deserialized.tenantId,
            equals(storedEvent.tenantId),
            reason:
                'Iteration $i: tenantId should be preserved (null or value)',
          );
          expect(
            deserialized.sessionId,
            equals(storedEvent.sessionId),
            reason:
                'Iteration $i: sessionId should be preserved (null or value)',
          );
        }
      },
    );

    test(
      'should preserve StoredEvent created from DomainEvent',
      () {
        final random = Random(45);

        for (var i = 0; i < 100; i++) {
          // Generate random test event
          final testEvent = _generateRandomTestEvent(random);

          // Create StoredEvent from DomainEvent
          final storedEvent = StoredEvent.fromDomainEvent(testEvent);

          // Serialize and deserialize
          final json = storedEvent.toJson();
          final deserialized = StoredEvent.fromJson(json);

          // Verify event data is preserved
          expect(
            deserialized.id,
            equals(testEvent.eventId),
            reason: 'Iteration $i: eventId should become StoredEvent id',
          );
          expect(
            deserialized.createdAt.millisecondsSinceEpoch,
            equals(testEvent.occurredAt.millisecondsSinceEpoch),
            reason: 'Iteration $i: occurredAt should become createdAt',
          );
          expect(
            deserialized.aggregateId,
            equals(testEvent.aggregateId),
            reason: 'Iteration $i: aggregateId should be preserved',
          );
          expect(
            deserialized.eventType,
            equals('TestDomainEvent'),
            reason: 'Iteration $i: eventType should be class name',
          );

          // Verify authorization fields extracted from context
          expect(
            deserialized.userId,
            equals(testEvent.context['userId']),
            reason: 'Iteration $i: userId should be extracted from context',
          );
          expect(
            deserialized.tenantId,
            equals(testEvent.context['tenantId']),
            reason: 'Iteration $i: tenantId should be extracted from context',
          );
          expect(
            deserialized.sessionId,
            equals(testEvent.context['sessionId']),
            reason: 'Iteration $i: sessionId should be extracted from context',
          );
        }
      },
    );

    test(
      'should handle edge case values correctly',
      () {
        final edgeCases = [
          (
            'Empty strings',
            '',
            '',
            '{}',
          ),
          (
            'Very long strings',
            'user-${'a' * 1000}',
            'tenant-${'b' * 1000}',
            '{"data":"${'c' * 1000}"}',
          ),
          (
            'Special characters',
            'user-\n\t\r"\'\\',
            'tenant-\n\t\r"\'\\',
            '{"data":"test\n\t\r"}',
          ),
          (
            'Unicode characters',
            'user-测试',
            'tenant-тест',
            '{"data":"tëst"}',
          ),
        ];

        for (var i = 0; i < edgeCases.length; i++) {
          final (description, userId, tenantId, eventJson) = edgeCases[i];

          final storedEvent = StoredEvent(
            id: UuidValue.generate(),
            createdAt: DateTime.now(),
            aggregateId: UuidValue.generate(),
            eventType: 'EdgeCaseEvent',
            eventJson: eventJson,
            userId: userId,
            tenantId: tenantId,
          );

          // Serialize and deserialize
          final json = storedEvent.toJson();
          final deserialized = StoredEvent.fromJson(json);

          // Verify edge cases are handled
          expect(
            deserialized.userId,
            equals(userId),
            reason: '$description: userId should be preserved',
          );
          expect(
            deserialized.tenantId,
            equals(tenantId),
            reason: '$description: tenantId should be preserved',
          );
          expect(
            deserialized.eventJson,
            equals(eventJson),
            reason: '$description: eventJson should be preserved',
          );
        }
      },
    );
  });
}

// Generator functions

/// Generates a random StoredEvent with various field values.
StoredEvent _generateRandomStoredEvent(Random random) {
  final includeUserId = random.nextBool();
  final includeTenantId = random.nextBool();
  final includeSessionId = random.nextBool();

  return StoredEvent(
    id: UuidValue.generate(),
    createdAt: _generateRandomDateTime(random),
    aggregateId: UuidValue.generate(),
    eventType: _generateRandomEventType(random),
    eventJson: _generateRandomEventJson(random),
    userId: includeUserId ? 'user-${random.nextInt(10000)}' : null,
    tenantId: includeTenantId ? 'tenant-${random.nextInt(1000)}' : null,
    sessionId: includeSessionId ? 'session-${random.nextInt(100000)}' : null,
  );
}

/// Generates a random event type name.
String _generateRandomEventType(Random random) {
  final types = [
    'UserCreatedEvent',
    'UserUpdatedEvent',
    'UserDeletedEvent',
    'OrderPlacedEvent',
    'OrderShippedEvent',
    'PaymentProcessedEvent',
    'InventoryUpdatedEvent',
  ];

  return types[random.nextInt(types.length)];
}

/// Generates random event JSON data.
String _generateRandomEventJson(Random random) {
  final types = [
    () => '{"id":"${random.nextInt(1000)}"}',
    () => '{"name":"User ${random.nextInt(100)}"}',
    () => '{"email":"user${random.nextInt(1000)}@example.com"}',
    () => '{"amount":${random.nextDouble() * 1000}}',
    () => '{"status":"${random.nextBool() ? "active" : "inactive"}"}',
    () => '{"data":{"nested":"value ${random.nextInt(100)}"}}',
  ];

  return types[random.nextInt(types.length)]();
}

/// Generates a random DateTime.
DateTime _generateRandomDateTime(Random random) {
  // Generate dates between 2020 and 2025
  final year = 2020 + random.nextInt(5);
  final month = 1 + random.nextInt(12);
  final day = 1 + random.nextInt(28); // Safe for all months
  final hour = random.nextInt(24);
  final minute = random.nextInt(60);
  final second = random.nextInt(60);
  final millisecond = random.nextInt(1000);

  return DateTime(year, month, day, hour, minute, second, millisecond);
}

/// Generates a random test DomainEvent.
TestDomainEvent _generateRandomTestEvent(Random random) {
  final includeUserId = random.nextBool();
  final includeTenantId = random.nextBool();
  final includeSessionId = random.nextBool();

  final context = <String, dynamic>{};
  if (includeUserId) {
    context['userId'] = 'user-${random.nextInt(10000)}';
  }
  if (includeTenantId) {
    context['tenantId'] = 'tenant-${random.nextInt(1000)}';
  }
  if (includeSessionId) {
    context['sessionId'] = 'session-${random.nextInt(100000)}';
  }

  return TestDomainEvent(
    aggregateId: UuidValue.generate(),
    eventId: UuidValue.generate(),
    occurredAt: _generateRandomDateTime(random),
    context: context,
    data: 'test-data-${random.nextInt(1000)}',
  );
}

/// Test DomainEvent for property testing.
class TestDomainEvent extends DomainEvent {
  TestDomainEvent({
    required super.aggregateId,
    required this.data,
    super.eventId,
    super.occurredAt,
    super.context,
  });

  final String data;
}
