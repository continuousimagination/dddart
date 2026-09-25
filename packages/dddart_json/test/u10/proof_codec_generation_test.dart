/// Required persistent identity/timestamps and safe generated decoding contracts.
library;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:test/test.dart';
import 'inherited_codec_test.dart';

void main() {
  final codec = InheritedRecordJsonSerializer();
  final id = UuidValue.fromString('00000000-0000-4000-8000-000000000001');
  final now = DateTime.utc(2026, 9, 21);
  Map<String, dynamic> wire() => codec.toJson(
    InheritedRecord(
      payload: 'test',
      label: 'test',
      aggregateId: id,
      eventType: 'test',
      eventJson: '{}',
      id: id,
      createdAt: now,
      updatedAt: now,
      userRoles: [],
    ),
  );
  test('preserves explicit persistent identity and timestamps', () {
    final decoded = codec.fromJson(wire());
    expect(decoded.id, id);
    expect(decoded.createdAt, now);
    expect(decoded.updatedAt, now);
  });
  test(
    'required inherited identity and timestamps may not be manufactured',
    () {
      for (final field in ['id', 'createdAt', 'updatedAt']) {
        expect(
          () => codec.fromJson(wire()..remove(field)),
          throwsA(isA<DeserializationException>()),
          reason: 'missing $field',
        );
        expect(
          () => codec.fromJson({...wire(), field: null}),
          throwsA(isA<DeserializationException>()),
          reason: 'null $field',
        );
      }
    },
  );
  test('malformed fields do not appear in public decode messages', () {
    const marker = 'restricted-synthetic-codec-value';
    try {
      codec.fromJson({...wire(), 'aggregateId': marker});
      fail('Expected invalid identity to fail');
    } on DeserializationException catch (error) {
      expect(error.toString(), isNot(contains(marker)));
    }
  });
  test('malformed JSON text has a typed safe decoding failure', () {
    const marker = 'restricted-malformed-json';
    try {
      codec.deserialize(marker);
      fail('Expected malformed JSON rejection');
    } catch (error) {
      expect(error, isA<DeserializationException>());
      expect(error.toString(), isNot(contains(marker)));
    }
  });
}
