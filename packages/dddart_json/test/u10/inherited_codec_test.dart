/// Executable inherited/generic codec regression and nullable collection cases.
library;

import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:test/test.dart';

part 'inherited_codec_test.g.dart';

/// Generic inherited state, including the stored-event fields.
class GenericRecord<T> extends AggregateRoot {
  /// Creates the inherited test state.
  GenericRecord({
    required this.payload,
    required this.label,
    required this.aggregateId,
    required this.eventType,
    required this.eventJson,
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    this.userId,
    this.tenantId,
    this.sessionId,
  });

  /// A field whose concrete type must be substituted through inheritance.
  final T payload;

  /// A field narrowed by the derived class.
  final Object? label;

  /// Associated aggregate identity.
  final UuidValue aggregateId;

  /// Event name.
  final String eventType;

  /// Serialized event content.
  final String eventJson;

  /// Optional user.
  final String? userId;

  /// Optional tenant.
  final String? tenantId;

  /// Optional session.
  final String? sessionId;
}

/// Derived state with an overridden field and its own nullable/collection data.
@Serializable()
class InheritedRecord extends GenericRecord<String> {
  /// Creates a complete concrete record.
  InheritedRecord({
    required super.payload,
    required this.label,
    required super.aggregateId,
    required super.eventType,
    required super.eventJson,
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    required this.userRoles,
    super.userId,
    super.tenantId,
    super.sessionId,
    this.organizationId,
    this.count,
  }) : super(label: label);

  @override
  // Deliberate field narrowing verifies most-derived codec type precedence.
  // ignore: overridden_fields
  final String label;

  /// Roles may be empty but are always present.
  final List<String> userRoles;

  /// Optional organization.
  final String? organizationId;

  /// Optional scalar value.
  final int? count;
}

void main() {
  final serializer = InheritedRecordJsonSerializer();
  final id = UuidValue.fromString('00000000-0000-4000-8000-000000000001');
  final aggregateId = UuidValue.fromString(
    '00000000-0000-4000-8000-000000000002',
  );
  final created = DateTime.utc(2026, 9, 21);
  final updated = created.add(const Duration(seconds: 1));
  InheritedRecord sample({bool populated = true}) => InheritedRecord(
    payload: 'concrete-generic-string',
    label: 'narrowed-string',
    aggregateId: aggregateId,
    eventType: 'SyntheticEvent',
    eventJson: '{}',
    id: id,
    createdAt: created,
    updatedAt: updated,
    userRoles: populated ? ['reader', 'writer'] : [],
    userId: populated ? 'user' : null,
    tenantId: populated ? 'tenant' : null,
    sessionId: populated ? 'session' : null,
    organizationId: populated ? 'organization' : null,
    count: populated ? 7 : null,
  );

  test('round-trips inherited required/optional and own fields', () {
    final input = sample();
    final wire = serializer.toJson(input);
    expect(
      wire.keys.toSet(),
      containsAll([
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
        'payload',
        'label',
        'count',
      ]),
    );
    final decoded = serializer.fromJson(
      jsonDecode(jsonEncode(wire)) as Map<String, dynamic>,
    );
    expect(decoded.id, id);
    expect(decoded.createdAt, created);
    expect(decoded.updatedAt, updated);
    expect(decoded.aggregateId, aggregateId);
    expect(decoded.eventType, 'SyntheticEvent');
    expect(decoded.eventJson, '{}');
    expect(decoded.userId, 'user');
    expect(decoded.tenantId, 'tenant');
    expect(decoded.sessionId, 'session');
    expect(decoded.userRoles, ['reader', 'writer']);
    expect(decoded.organizationId, 'organization');
    expect(decoded.payload, 'concrete-generic-string');
    expect(decoded.label, 'narrowed-string');
    expect(decoded.count, 7);
  });
  test('round-trips null scalars and empty collections', () {
    final decoded = serializer.fromJson(
      serializer.toJson(sample(populated: false)),
    );
    expect(decoded.count, isNull);
    expect(decoded.organizationId, isNull);
    expect(decoded.userId, isNull);
    expect(decoded.tenantId, isNull);
    expect(decoded.sessionId, isNull);
    expect(decoded.userRoles, isEmpty);
  });
  test('rejects missing required inherited field', () {
    final wire = serializer.toJson(sample())..remove('aggregateId');
    expect(
      () => serializer.fromJson(wire),
      throwsA(isA<DeserializationException>()),
    );
  });
  test('uses concrete substituted generic and overriding field types', () {
    final wire = serializer.toJson(sample());
    expect(
      () => serializer.fromJson({...wire, 'payload': 4}),
      throwsA(isA<DeserializationException>()),
    );
    expect(
      () => serializer.fromJson({...wire, 'label': 4}),
      throwsA(isA<DeserializationException>()),
    );
  });
  test('rejects invalid nullable scalar and collection element types', () {
    final wire = serializer.toJson(sample());
    expect(
      () => serializer.fromJson({...wire, 'count': 'seven'}),
      throwsA(isA<DeserializationException>()),
    );
    expect(
      () => serializer.fromJson({
        ...wire,
        'userRoles': [4],
      }),
      throwsA(isA<DeserializationException>()),
    );
  });
}
