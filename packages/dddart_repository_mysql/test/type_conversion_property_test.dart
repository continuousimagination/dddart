/// Property-based tests for type conversion consistency.
///
/// **Feature: mysql-driver-migration, Property 15: Type conversion consistency**
/// **Validates: Requirements 8.4**
@Tags(['property-test'])
library;

import 'dart:math';
import 'dart:typed_data';

import 'package:dddart/dddart.dart';
import 'package:dddart_repository_mysql/src/dialect/mysql_dialect.dart';
import 'package:test/test.dart';

void main() {
  group('Type Conversion Consistency Property Tests', () {
    late MysqlDialect dialect;

    setUp(() {
      dialect = const MysqlDialect();
    });

    // **Feature: mysql-driver-migration, Property 15: Type conversion consistency**
    // **Validates: Requirements 8.4**
    group('Property 15: Type conversion consistency', () {
      test(
        'should preserve UuidValue through encode/decode round-trip',
        () {
          final random = Random(200);

          for (var i = 0; i < 100; i++) {
            // Generate random UUID
            final originalUuid = _generateRandomUuid(random);

            // Encode to MySQL format
            final encoded = dialect.encodeUuid(originalUuid);

            // Verify encoded format
            expect(
              encoded,
              isA<Uint8List>(),
              reason: 'Iteration $i: Encoded UUID should be Uint8List',
            );
            expect(
              (encoded! as Uint8List).length,
              equals(16),
              reason: 'Iteration $i: Encoded UUID should be 16 bytes',
            );

            // Decode back to UuidValue
            final decoded = dialect.decodeUuid(encoded);

            // Verify round-trip preservation
            expect(
              decoded.uuid,
              equals(originalUuid.uuid),
              reason: 'Iteration $i: UUID should round-trip correctly',
            );
          }
        },
      );

      test(
        'should preserve DateTime through encode/decode round-trip',
        () {
          final random = Random(201);

          for (var i = 0; i < 100; i++) {
            // Generate random DateTime
            final originalDateTime = _generateRandomDateTime(random);

            // Encode to MySQL format
            final encoded = dialect.encodeDateTime(originalDateTime);

            // Verify encoded format - MySQL expects string format
            expect(
              encoded,
              isA<String>(),
              reason: 'Iteration $i: Encoded DateTime should be String',
            );

            // Decode back to DateTime
            final decoded = dialect.decodeDateTime(encoded);

            // Verify round-trip preservation (second precision - MySQL DATETIME truncates milliseconds)
            expect(
              decoded.millisecondsSinceEpoch ~/ 1000,
              equals(originalDateTime.millisecondsSinceEpoch ~/ 1000),
              reason:
                  'Iteration $i: DateTime should round-trip correctly (second precision)',
            );
          }
        },
      );

      test(
        'should handle edge case UUIDs consistently',
        () {
          // Test specific UUID patterns
          final testUuids = [
            UuidValue.fromString('00000000-0000-0000-0000-000000000000'),
            UuidValue.fromString('ffffffff-ffff-ffff-ffff-ffffffffffff'),
            UuidValue.fromString('12345678-1234-5678-1234-567812345678'),
            UuidValue.fromString('abcdef01-2345-6789-abcd-ef0123456789'),
            UuidValue.generate(),
            UuidValue.generate(),
            UuidValue.generate(),
          ];

          for (var i = 0; i < testUuids.length; i++) {
            final originalUuid = testUuids[i];

            // Encode then decode
            final encoded = dialect.encodeUuid(originalUuid);
            final decoded = dialect.decodeUuid(encoded);

            // Verify equivalence
            expect(
              decoded.uuid,
              equals(originalUuid.uuid),
              reason: 'Test case $i: UUID should round-trip correctly',
            );
          }
        },
      );

      test(
        'should handle edge case DateTimes consistently',
        () {
          // Test specific DateTime patterns
          final testDateTimes = [
            DateTime(1970, 1, 1, 0, 0, 1), // Near epoch start
            DateTime(2038, 1, 19, 3, 14, 7), // Near TIMESTAMP limit
            DateTime(2000),
            DateTime(2024, 12, 31, 23, 59, 59),
            DateTime.now(),
            DateTime.now().toUtc(),
          ];

          for (var i = 0; i < testDateTimes.length; i++) {
            final originalDateTime = testDateTimes[i];

            // Encode then decode
            final encoded = dialect.encodeDateTime(originalDateTime);
            final decoded = dialect.decodeDateTime(encoded);

            // Verify equivalence (second precision - MySQL DATETIME truncates milliseconds)
            expect(
              decoded.millisecondsSinceEpoch ~/ 1000,
              equals(originalDateTime.millisecondsSinceEpoch ~/ 1000),
              reason:
                  'Test case $i: DateTime should round-trip correctly (second precision)',
            );
          }
        },
      );

      test(
        'should maintain type mapping consistency',
        () {
          // Verify type mappings are consistent and match expected MySQL types
          expect(
            dialect.uuidColumnType,
            equals('BINARY(16)'),
            reason: 'UuidValue should map to BINARY(16)',
          );
          expect(
            dialect.textColumnType,
            equals('VARCHAR(255)'),
            reason: 'String should map to VARCHAR(255)',
          );
          expect(
            dialect.integerColumnType,
            equals('BIGINT'),
            reason: 'int should map to BIGINT',
          );
          expect(
            dialect.realColumnType,
            equals('DOUBLE'),
            reason: 'double should map to DOUBLE',
          );
          expect(
            dialect.booleanColumnType,
            equals('TINYINT(1)'),
            reason: 'bool should map to TINYINT(1)',
          );
        },
      );

      test(
        'should encode/decode UUIDs consistently across multiple calls',
        () {
          final random = Random(202);

          for (var i = 0; i < 100; i++) {
            final uuid = _generateRandomUuid(random);

            // Encode multiple times
            final encoded1 = dialect.encodeUuid(uuid);
            final encoded2 = dialect.encodeUuid(uuid);

            // Verify encoding is deterministic
            expect(
              encoded1,
              equals(encoded2),
              reason: 'Iteration $i: Encoding should be deterministic',
            );

            // Decode multiple times
            final decoded1 = dialect.decodeUuid(encoded1);
            final decoded2 = dialect.decodeUuid(encoded2);

            // Verify decoding is deterministic
            expect(
              decoded1.uuid,
              equals(decoded2.uuid),
              reason: 'Iteration $i: Decoding should be deterministic',
            );
          }
        },
      );

      test(
        'should encode/decode DateTimes consistently across multiple calls',
        () {
          final random = Random(203);

          for (var i = 0; i < 100; i++) {
            final dateTime = _generateRandomDateTime(random);

            // Encode multiple times
            final encoded1 = dialect.encodeDateTime(dateTime);
            final encoded2 = dialect.encodeDateTime(dateTime);

            // Verify encoding is deterministic
            expect(
              encoded1,
              equals(encoded2),
              reason: 'Iteration $i: Encoding should be deterministic',
            );

            // Decode multiple times
            final decoded1 = dialect.decodeDateTime(encoded1);
            final decoded2 = dialect.decodeDateTime(encoded2);

            // Verify decoding is deterministic
            expect(
              decoded1.millisecondsSinceEpoch,
              equals(decoded2.millisecondsSinceEpoch),
              reason: 'Iteration $i: Decoding should be deterministic',
            );
          }
        },
      );

      test(
        'should handle UUID decoding from List<int> format',
        () {
          final random = Random(204);

          for (var i = 0; i < 100; i++) {
            final uuid = _generateRandomUuid(random);

            // Encode to Uint8List
            final encoded = dialect.encodeUuid(uuid)! as Uint8List;

            // Convert to List<int>
            final listInt = encoded.toList();

            // Decode from List<int>
            final decoded = dialect.decodeUuid(listInt);

            // Verify round-trip preservation
            expect(
              decoded.uuid,
              equals(uuid.uuid),
              reason: 'Iteration $i: Should decode from List<int>',
            );
          }
        },
      );

      test(
        'should handle DateTime decoding from string format',
        () {
          final random = Random(205);

          for (var i = 0; i < 100; i++) {
            final dateTime = _generateRandomDateTime(random);

            // Encode to string
            final encoded = dialect.encodeDateTime(dateTime)! as String;

            // Decode from string
            final decoded = dialect.decodeDateTime(encoded);

            // Verify round-trip preservation (second precision)
            expect(
              decoded.millisecondsSinceEpoch ~/ 1000,
              equals(dateTime.millisecondsSinceEpoch ~/ 1000),
              reason: 'Iteration $i: Should decode from string',
            );
          }
        },
      );

      test(
        'should throw ArgumentError for invalid UUID input',
        () {
          // Test null input
          expect(
            () => dialect.decodeUuid(null),
            throwsA(isA<ArgumentError>()),
            reason: 'Should throw for null UUID',
          );

          // Test wrong type
          expect(
            () => dialect.decodeUuid('not-a-uuid'),
            throwsA(isA<ArgumentError>()),
            reason: 'Should throw for wrong type',
          );

          // Test wrong length
          expect(
            () => dialect.decodeUuid(Uint8List(8)),
            throwsA(isA<ArgumentError>()),
            reason: 'Should throw for wrong length',
          );
        },
      );

      test(
        'should throw ArgumentError for invalid DateTime input',
        () {
          // Test null input
          expect(
            () => dialect.decodeDateTime(null),
            throwsA(isA<ArgumentError>()),
            reason: 'Should throw for null DateTime',
          );

          // Test wrong type
          expect(
            () => dialect.decodeDateTime('not-a-datetime'),
            throwsA(isA<ArgumentError>()),
            reason: 'Should throw for wrong type',
          );
        },
      );
    });
  });
}

// Generator functions

/// Generates a random UUID.
UuidValue _generateRandomUuid(Random random) {
  // Generate random bytes for UUID
  final bytes = List.generate(16, (_) => random.nextInt(256));

  // Convert to hex string with proper UUID format
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  final uuidString = '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
      '${hex.substring(20, 32)}';

  return UuidValue.fromString(uuidString);
}

/// Generates a random DateTime within a reasonable range.
DateTime _generateRandomDateTime(Random random) {
  // Generate DateTime between 2000 and 2030 (safe TIMESTAMP range)
  final minMillis = DateTime(2000).millisecondsSinceEpoch;
  final maxMillis = DateTime(2030).millisecondsSinceEpoch;
  final range = maxMillis - minMillis;

  // Use double to avoid overflow, then convert to int
  final randomOffset = (random.nextDouble() * range).toInt();
  final randomMillis = minMillis + randomOffset;

  return DateTime.fromMillisecondsSinceEpoch(randomMillis);
}
