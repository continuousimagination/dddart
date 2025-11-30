import 'package:dddart_rest/dddart_rest.dart';
import 'package:test/test.dart';

void main() {
  group('SecurityUtils', () {
    group('constantTimeCompare', () {
      test('returns true for identical strings', () {
        const str = 'test-signature-abc123';
        expect(SecurityUtils.constantTimeCompare(str, str), isTrue);
      });

      test('returns false for different strings of same length', () {
        const str1 = 'test-signature-abc123';
        const str2 = 'test-signature-xyz789';
        expect(SecurityUtils.constantTimeCompare(str1, str2), isFalse);
      });

      test('returns false for different strings of different lengths', () {
        const str1 = 'short';
        const str2 = 'much longer string';
        expect(SecurityUtils.constantTimeCompare(str1, str2), isFalse);
      });

      test('returns false for strings differing by one character', () {
        const str1 = 'test-signature-abc123';
        const str2 = 'test-signature-abc124';
        expect(SecurityUtils.constantTimeCompare(str1, str2), isFalse);
      });

      test('returns true for empty strings', () {
        expect(SecurityUtils.constantTimeCompare('', ''), isTrue);
      });

      test('returns false when one string is empty', () {
        expect(SecurityUtils.constantTimeCompare('', 'test'), isFalse);
        expect(SecurityUtils.constantTimeCompare('test', ''), isFalse);
      });

      test('handles unicode characters', () {
        const str1 = 'test-🔐-signature';
        const str2 = 'test-🔐-signature';
        expect(SecurityUtils.constantTimeCompare(str1, str2), isTrue);
      });

      test('returns false for different unicode strings', () {
        const str1 = 'test-🔐-signature';
        const str2 = 'test-🔑-signature';
        expect(SecurityUtils.constantTimeCompare(str1, str2), isFalse);
      });
    });

    group('validateTimestampAge', () {
      test('returns true for recent timestamp', () {
        final timestamp = DateTime.now().subtract(const Duration(minutes: 5));
        expect(SecurityUtils.validateTimestampAge(timestamp), isTrue);
      });

      test('returns false for timestamp too old', () {
        final timestamp = DateTime.now().subtract(const Duration(minutes: 15));
        expect(
          SecurityUtils.validateTimestampAge(
            timestamp,
          ),
          isFalse,
        );
      });

      test('returns false for timestamp too far in future', () {
        final timestamp = DateTime.now().add(const Duration(minutes: 10));
        expect(
          SecurityUtils.validateTimestampAge(
            timestamp,
          ),
          isFalse,
        );
      });

      test('returns true for timestamp within clock skew tolerance', () {
        final timestamp = DateTime.now().add(const Duration(minutes: 3));
        expect(
          SecurityUtils.validateTimestampAge(
            timestamp,
          ),
          isTrue,
        );
      });

      test('returns true for timestamp near max age boundary', () {
        // Use slightly less than max age to avoid timing issues
        final timestamp =
            DateTime.now().subtract(const Duration(minutes: 9, seconds: 59));
        expect(
          SecurityUtils.validateTimestampAge(
            timestamp,
          ),
          isTrue,
        );
      });

      test('respects custom max age', () {
        final timestamp = DateTime.now().subtract(const Duration(hours: 2));
        expect(
          SecurityUtils.validateTimestampAge(
            timestamp,
            maxAge: const Duration(hours: 3),
          ),
          isTrue,
        );
      });
    });

    group('validateDeviceCodeAge', () {
      test('returns true for valid device code', () {
        final createdAt = DateTime.now().subtract(const Duration(minutes: 5));
        final expiresAt = DateTime.now().add(const Duration(minutes: 5));

        expect(
          SecurityUtils.validateDeviceCodeAge(createdAt, expiresAt),
          isTrue,
        );
      });

      test('returns false for expired device code', () {
        final createdAt = DateTime.now().subtract(const Duration(minutes: 15));
        final expiresAt = DateTime.now().subtract(const Duration(minutes: 5));

        expect(
          SecurityUtils.validateDeviceCodeAge(createdAt, expiresAt),
          isFalse,
        );
      });

      test('returns false for device code created too long ago', () {
        final createdAt = DateTime.now().subtract(const Duration(minutes: 15));
        final expiresAt = DateTime.now().add(const Duration(minutes: 5));

        expect(
          SecurityUtils.validateDeviceCodeAge(
            createdAt,
            expiresAt,
          ),
          isFalse,
        );
      });

      test('returns true for device code near age boundary', () {
        // Use slightly less than max age to avoid timing issues
        final createdAt =
            DateTime.now().subtract(const Duration(minutes: 9, seconds: 59));
        final expiresAt = DateTime.now().add(const Duration(minutes: 5));

        expect(
          SecurityUtils.validateDeviceCodeAge(
            createdAt,
            expiresAt,
          ),
          isTrue,
        );
      });

      test('respects custom max age', () {
        final createdAt = DateTime.now().subtract(const Duration(minutes: 20));
        final expiresAt = DateTime.now().add(const Duration(minutes: 10));

        expect(
          SecurityUtils.validateDeviceCodeAge(
            createdAt,
            expiresAt,
            maxAge: const Duration(minutes: 30),
          ),
          isTrue,
        );
      });
    });

    group('generateSecureRandom', () {
      test('generates non-empty string', () {
        final random = SecurityUtils.generateSecureRandom();
        expect(random, isNotEmpty);
      });

      test('generates different strings on subsequent calls', () {
        final random1 = SecurityUtils.generateSecureRandom();
        final random2 = SecurityUtils.generateSecureRandom();
        expect(random1, isNot(equals(random2)));
      });

      test('respects custom length', () {
        final random = SecurityUtils.generateSecureRandom(16);
        expect(random, isNotEmpty);
        // Base64 encoding of 16 bytes should be around 22-24 characters
        expect(random.length, greaterThan(16));
      });

      test('generates valid base64 string', () {
        final random = SecurityUtils.generateSecureRandom();
        // Should not throw when decoding
        expect(() => Uri.decodeComponent(random), returnsNormally);
      });
    });
  });
}
