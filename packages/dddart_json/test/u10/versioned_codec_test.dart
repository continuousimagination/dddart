/// Executable revision wire contract using the generated codec.
library;

import 'dart:convert';
import 'package:dddart/dddart.dart' hide Revision;
import 'package:dddart/dddart.dart' as domain;
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:test/test.dart';

part 'versioned_codec_test.g.dart';

/// Versioned fixture with a defaulted constructor revision.
@Serializable()
class VersionedRecord extends VersionedAggregateRoot with BenignRevisionMixin {
  /// Creates a fixture; decoding must still require the revision field.
  VersionedRecord({
    required this.label,
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    super.revision,
  });

  /// Ordinary content.
  final String label;
}

void main() {
  final codec = VersionedRecordJsonSerializer();
  VersionedRecord sample(domain.Revision revision) => VersionedRecord(
    label: 'hello',
    id: UuidValue.generate(),
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    revision: revision,
  );

  test(
    'generated codec accepts whole numeric forms and emits canonical integers',
    () {
      final wire = codec.toJson(sample(const domain.Revision.zero()));
      for (final token in ['0.0', '1.0', '1e0', '9007199254740991.0']) {
        final encoded = jsonEncode(
          wire,
        ).replaceFirst('"revision":0', '"revision":$token');
        final value = codec.deserialize(encoded);
        expect(
          value.revision.value,
          token.startsWith('9007')
              ? domain.Revision.maxValue
              : token.startsWith('0')
              ? 0
              : 1,
        );
        expect(
          jsonEncode(codec.toJson(value)['revision']),
          value.revision.value.toString(),
        );
      }
    },
  );

  test('zero, positive and maximum revision round trip as integers', () {
    for (final number in [0, 1, domain.Revision.maxValue]) {
      final value = sample(domain.Revision(number));
      final wire = codec.toJson(value);
      expect(wire['revision'], number);
      final result = codec.deserialize(codec.serialize(value));
      expect(result.id, value.id);
      expect(result.revision, value.revision);
      expect(result.isPersisted, number > 0);
      expect(result.createdAt, value.createdAt);
      expect(result.updatedAt, value.updatedAt);
      expect(result.label, value.label);
    }
  });

  test('missing, null, fractional, string and out-of-range revisions fail', () {
    final wire = codec.toJson(sample(const domain.Revision.zero()));
    expect(
      () => codec.fromJson({...wire}..remove('revision')),
      throwsA(isA<DeserializationException>()),
    );
    for (final invalid in [null, 1.5, '1', -1, 9007199254740992, true]) {
      expect(
        () => codec.fromJson({...wire, 'revision': invalid}),
        throwsA(isA<DeserializationException>()),
        reason: '$invalid',
      );
    }
  });

  test('configured field names retain required revision and timestamps', () {
    const config = SerializationConfig(fieldRename: FieldRename.snake);
    final value = sample(domain.Revision(3));
    final wire = codec.toJson(value, config);
    expect(wire['created_at'], value.createdAt.toIso8601String());
    expect(wire['revision'], 3);
    expect(codec.fromJson(wire, config).revision, domain.Revision(3));
  });
}

/// Benign behavior does not replace persistence authority.
mixin BenignRevisionMixin on VersionedAggregateRoot {
  /// Reads the inherited authority without overriding its getter.
  bool get isPersisted => revision.value > 0;
}
