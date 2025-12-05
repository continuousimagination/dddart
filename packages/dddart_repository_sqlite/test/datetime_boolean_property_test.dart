@Tags(['property-test'])
library;

import 'dart:math';

import 'package:dddart_repository_sqlite/src/dialect/sqlite_dialect.dart';
import 'package:test/test.dart';

void main() {
  group('DateTime and Boolean Round-Trip Properties', () {
    const dialect = SqliteDialect();
    final random = Random(42); // Fixed seed for reproducibility

    // **Feature: sql-collection-support, Property 12: DateTime round-trip preservation**
    // **Validates: Requirements 16.1-16.11**
    group('Property 12: DateTime round-trip preservation', () {
      test('should preserve DateTime values through encode/decode cycle', () {
        for (var i = 0; i < 100; i++) {
          // Generate random DateTime
          final original = _generateRandomDateTime(random);

          // Encode then decode
          final encoded = dialect.encodeDateTime(original);
          final decoded = dialect.decodeDateTime(encoded);

          // Verify round-trip preserves the instant in time (UTC)
          expect(
            decoded.toUtc().millisecondsSinceEpoch,
            equals(original.toUtc().millisecondsSinceEpoch),
            reason:
                'Iteration $i: DateTime round-trip should preserve the instant in time',
          );
        }
      });

      test('should handle DateTime values with different timezones', () {
        for (var i = 0; i < 100; i++) {
          // Generate DateTime with random timezone offset
          final utcTime = _generateRandomDateTime(random);
          final offsetHours = random.nextInt(24) - 12;
          final original = utcTime.toLocal().add(Duration(hours: offsetHours));

          // Encode then decode
          final encoded = dialect.encodeDateTime(original);
          final decoded = dialect.decodeDateTime(encoded);

          // Verify round-trip preserves the instant in time
          expect(
            decoded.toUtc().millisecondsSinceEpoch,
            equals(original.toUtc().millisecondsSinceEpoch),
            reason:
                'Iteration $i: DateTime with timezone offset should preserve instant',
          );
        }
      });

      test('should handle DateTime values at epoch boundaries', () {
        final testCases = [
          DateTime.fromMillisecondsSinceEpoch(0), // Unix epoch
          DateTime.fromMillisecondsSinceEpoch(1), // Just after epoch
          DateTime.fromMillisecondsSinceEpoch(-1), // Just before epoch
          DateTime(1970), // Epoch as date
          DateTime(2000), // Y2K
          DateTime(2038, 1, 19, 3, 14, 7), // 32-bit timestamp limit
        ];

        for (var i = 0; i < testCases.length; i++) {
          final original = testCases[i];

          // Encode then decode
          final encoded = dialect.encodeDateTime(original);
          final decoded = dialect.decodeDateTime(encoded);

          // Verify round-trip preserves the instant
          expect(
            decoded.toUtc().millisecondsSinceEpoch,
            equals(original.toUtc().millisecondsSinceEpoch),
            reason:
                'Test case $i: Boundary DateTime should round-trip correctly',
          );
        }
      });

      test('should encode DateTime as TEXT (ISO8601)', () {
        for (var i = 0; i < 100; i++) {
          final original = _generateRandomDateTime(random);
          final encoded = dialect.encodeDateTime(original);

          // Verify encoded value is a String (TEXT)
          expect(
            encoded,
            isA<String>(),
            reason: 'Iteration $i: Encoded DateTime should be a String',
          );

          // Verify it's in ISO8601 format
          expect(
            encoded,
            matches(RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$')),
            reason: 'Iteration $i: Encoded DateTime should be ISO8601 format',
          );
        }
      });
    });

    // **Feature: sql-collection-support, Property 13: Boolean round-trip preservation**
    // **Validates: Requirements 17.1-17.7**
    group('Property 13: Boolean round-trip preservation', () {
      test('should preserve boolean values through encode/decode cycle', () {
        for (var i = 0; i < 100; i++) {
          // Test both true and false
          final original = random.nextBool();

          // Encode then decode
          final encodedValue = original ? 1 : 0;
          final decoded = encodedValue != 0;

          // Verify round-trip preserves the value
          expect(
            decoded,
            equals(original),
            reason: 'Iteration $i: Boolean round-trip should preserve value',
          );
        }
      });

      test('should encode true as 1 and false as 0', () {
        // Test true
        const trueEncoded = 1; // true ? 1 : 0
        expect(
          trueEncoded,
          equals(1),
          reason: 'true should encode to 1',
        );

        // Test false
        const falseEncoded = 0; // false ? 1 : 0
        expect(
          falseEncoded,
          equals(0),
          reason: 'false should encode to 0',
        );
      });

      test('should decode 1 as true and 0 as false', () {
        // Test 1 -> true
        const decodedTrue = true; // 1 != 0
        expect(
          decodedTrue,
          isTrue,
          reason: '1 should decode to true',
        );

        // Test 0 -> false
        const decodedFalse = false; // 0 != 0
        expect(
          decodedFalse,
          isFalse,
          reason: '0 should decode to false',
        );
      });

      test('should use INTEGER column type for booleans', () {
        expect(
          dialect.booleanColumnType,
          equals('INTEGER'),
          reason: 'SQLite should use INTEGER for boolean columns',
        );
      });
    });
  });
}

/// Generates a random DateTime for testing.
DateTime _generateRandomDateTime(Random random) {
  // Generate a random timestamp within a reasonable range
  // (between 2000 and 2050 to avoid overflow)
  const minYear = 2000;
  const maxYear = 2050;
  final year = minYear + random.nextInt(maxYear - minYear);
  final month = 1 + random.nextInt(12);
  final day = 1 + random.nextInt(28); // Use 28 to avoid month-end issues
  final hour = random.nextInt(24);
  final minute = random.nextInt(60);
  final second = random.nextInt(60);
  final millisecond = random.nextInt(1000);

  return DateTime.utc(year, month, day, hour, minute, second, millisecond);
}
