@Tags(['property'])
library;

import 'dart:math';

import 'package:dddart/dddart.dart';
import 'package:test/test.dart';

void main() {
  group('HTTP status code mapping property tests', () {
    late _TestRepository repository;
    final random = Random(42); // Fixed seed for reproducibility

    setUp(() {
      repository = _TestRepository();
    });

    // **Feature: rest-repository, Property 8: HTTP status codes map to correct exception types**
    test(
      'HTTP status codes map to correct exception types for any status code',
      () {
        // Run 100 iterations with different status codes
        for (var i = 0; i < 100; i++) {
          // Generate random status code (100-599)
          final statusCode = random.nextInt(500) + 100;
          final body = 'Error message for status $statusCode';

          // Act
          final exception = repository.testMapHttpException(statusCode, body);

          // Assert: Verify correct exception type based on status code
          expect(exception, isA<RepositoryException>());

          if (statusCode == 404) {
            expect(
              exception.type,
              equals(RepositoryExceptionType.notFound),
              reason: '404 should map to notFound',
            );
            expect(exception.message, equals('Resource not found'));
          } else if (statusCode == 409) {
            expect(
              exception.type,
              equals(RepositoryExceptionType.duplicate),
              reason: '409 should map to duplicate',
            );
            expect(exception.message, equals('Duplicate resource'));
          } else if (statusCode == 408 || statusCode == 504) {
            expect(
              exception.type,
              equals(RepositoryExceptionType.timeout),
              reason: '408 and 504 should map to timeout',
            );
            expect(exception.message, equals('Request timeout'));
          } else if (statusCode >= 500) {
            expect(
              exception.type,
              equals(RepositoryExceptionType.connection),
              reason: '5xx status codes should map to connection',
            );
            expect(exception.message, contains('Server error: $statusCode'));
          } else {
            expect(
              exception.type,
              equals(RepositoryExceptionType.unknown),
              reason: 'Other status codes should map to unknown',
            );
            expect(exception.message, contains('HTTP error $statusCode'));
            expect(exception.message, contains(body));
          }
        }
      },
    );

    test(
      'all 404 status codes consistently map to notFound',
      () {
        // Test 404 multiple times to ensure consistency
        for (var i = 0; i < 100; i++) {
          final body = 'Not found message $i';
          final exception = repository.testMapHttpException(404, body);

          expect(exception.type, equals(RepositoryExceptionType.notFound));
          expect(exception.message, equals('Resource not found'));
        }
      },
    );

    test(
      'all 409 status codes consistently map to duplicate',
      () {
        // Test 409 multiple times to ensure consistency
        for (var i = 0; i < 100; i++) {
          final body = 'Conflict message $i';
          final exception = repository.testMapHttpException(409, body);

          expect(exception.type, equals(RepositoryExceptionType.duplicate));
          expect(exception.message, equals('Duplicate resource'));
        }
      },
    );

    test(
      'all timeout status codes (408, 504) consistently map to timeout',
      () {
        const timeoutCodes = [408, 504];

        for (var i = 0; i < 100; i++) {
          final statusCode = timeoutCodes[i % timeoutCodes.length];
          final body = 'Timeout message $i';
          final exception = repository.testMapHttpException(statusCode, body);

          expect(
            exception.type,
            equals(RepositoryExceptionType.timeout),
            reason: 'Status code $statusCode should map to timeout',
          );
          expect(exception.message, equals('Request timeout'));
        }
      },
    );

    test(
      'all 5xx status codes consistently map to connection',
      () {
        // Test all 5xx status codes (500-599)
        for (var statusCode = 500; statusCode < 600; statusCode++) {
          // Skip 504 as it maps to timeout
          if (statusCode == 504) continue;

          const body = 'Server error message';
          final exception = repository.testMapHttpException(statusCode, body);

          expect(
            exception.type,
            equals(RepositoryExceptionType.connection),
            reason: 'Status code $statusCode should map to connection',
          );
          expect(exception.message, contains('Server error: $statusCode'));
        }
      },
    );

    test(
      'all non-special status codes consistently map to unknown',
      () {
        // Test various non-special status codes
        const nonSpecialCodes = [
          100, 101, 102, // 1xx informational
          200, 201, 202, 203, 204, // 2xx success
          300, 301, 302, 303, 304, // 3xx redirection
          400, 401, 402, 403, 405, 406, 407, 410, 411, 412, 413, 414, 415, 416,
          417, 418, // 4xx client errors (excluding 404, 408, 409)
        ];

        for (final statusCode in nonSpecialCodes) {
          final body = 'Error body for $statusCode';
          final exception = repository.testMapHttpException(statusCode, body);

          expect(
            exception.type,
            equals(RepositoryExceptionType.unknown),
            reason: 'Status code $statusCode should map to unknown',
          );
          expect(exception.message, contains('HTTP error $statusCode'));
          expect(exception.message, contains(body));
        }
      },
    );

    test(
      'error messages always include response body for unknown status codes',
      () {
        // Test that response body is included in error message
        for (var i = 0; i < 100; i++) {
          // Generate random non-special status code
          final statusCode = random.nextInt(100) + 400; // 400-499
          if (statusCode == 404 || statusCode == 408 || statusCode == 409) {
            continue;
          }

          final body = 'Random error body ${random.nextInt(1000)}';
          final exception = repository.testMapHttpException(statusCode, body);

          expect(
            exception.message,
            contains(body),
            reason: 'Error message should include response body',
          );
        }
      },
    );

    test(
      'exception type is deterministic for any given status code',
      () {
        // Test that the same status code always produces the same exception type
        const testCodes = [200, 404, 408, 409, 500, 502, 504];

        for (final statusCode in testCodes) {
          final firstException =
              repository.testMapHttpException(statusCode, 'body1');

          // Test the same status code 10 times
          for (var i = 0; i < 10; i++) {
            final exception =
                repository.testMapHttpException(statusCode, 'body$i');

            expect(
              exception.type,
              firstException.type,
              reason:
                  'Status code $statusCode should always map to the same exception type',
            );
          }
        }
      },
    );
  });
}

/// Test repository class that exposes the _mapHttpException method for testing.
///
/// This class mimics the structure of generated repository classes and
/// provides a public method to test the private _mapHttpException logic.
class _TestRepository {
  /// Public method to test the private _mapHttpException logic.
  RepositoryException testMapHttpException(int statusCode, String body) {
    return _mapHttpException(statusCode, body);
  }

  /// Maps HTTP status codes to RepositoryException types.
  ///
  /// This is the same implementation that is generated by the
  /// RestRepositoryGenerator for all repository classes.
  RepositoryException _mapHttpException(int statusCode, String body) {
    switch (statusCode) {
      case 404:
        return const RepositoryException(
          'Resource not found',
          type: RepositoryExceptionType.notFound,
        );
      case 409:
        return const RepositoryException(
          'Duplicate resource',
          type: RepositoryExceptionType.duplicate,
        );
      case 408:
      case 504:
        return const RepositoryException(
          'Request timeout',
          type: RepositoryExceptionType.timeout,
        );
      case >= 500:
        return RepositoryException(
          'Server error: $statusCode',
          type: RepositoryExceptionType.connection,
        );
      default:
        return RepositoryException(
          'HTTP error $statusCode: $body',
        );
    }
  }
}
