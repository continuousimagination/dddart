@Tags(['property'])
library;

import 'dart:convert';
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
          } else if (statusCode == 401) {
            expect(
              exception.type,
              equals(RepositoryExceptionType.unauthorized),
              reason: '401 should map to unauthorized',
            );
            expect(
              exception.message,
              equals('Unauthorized: Authentication required or token expired'),
            );
          } else if (statusCode == 403) {
            expect(
              exception.type,
              equals(RepositoryExceptionType.forbidden),
              reason: '403 should map to forbidden',
            );
            expect(
              exception.message,
              equals(
                'Forbidden: You do not have permission to perform this action',
              ),
            );
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
      'all 401 status codes consistently map to unauthorized',
      () {
        // Test 401 multiple times to ensure consistency
        for (var i = 0; i < 100; i++) {
          final body = 'Unauthorized message $i';
          final exception = repository.testMapHttpException(401, body);

          expect(exception.type, equals(RepositoryExceptionType.unauthorized));
          expect(
            exception.message,
            equals('Unauthorized: Authentication required or token expired'),
          );
        }
      },
    );

    test(
      'all 403 status codes consistently map to forbidden',
      () {
        // Test 403 multiple times to ensure consistency
        for (var i = 0; i < 100; i++) {
          final body = 'Forbidden message $i';
          final exception = repository.testMapHttpException(403, body);

          expect(exception.type, equals(RepositoryExceptionType.forbidden));
          expect(
            exception.message,
            equals(
              'Forbidden: You do not have permission to perform this action',
            ),
          );
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
          400, 402, 405, 406, 407, 410, 411, 412, 413, 414, 415, 416,
          417, 418, // 4xx client errors (excluding 401, 403, 404, 408, 409)
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
          if (statusCode == 401 ||
              statusCode == 403 ||
              statusCode == 404 ||
              statusCode == 408 ||
              statusCode == 409) {
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
        const testCodes = [200, 401, 403, 404, 408, 409, 500, 502, 504];

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

    test(
      'RFC 7807 detail field is extracted when present',
      () {
        // Test that RFC 7807 Problem Details format is parsed correctly
        const testCases = [
          (401, 'Your session has expired'),
          (403, 'You do not have permission to modify this player'),
          (404, 'Player with ID abc123 not found'),
          (409, 'A player with this alias already exists'),
        ];

        for (final (statusCode, detailMessage) in testCases) {
          final rfc7807Body = jsonEncode({
            'type': 'about:blank',
            'title': 'Error',
            'status': statusCode,
            'detail': detailMessage,
          });

          final exception =
              repository.testMapHttpException(statusCode, rfc7807Body);

          expect(
            exception.message,
            equals(detailMessage),
            reason:
                'Should extract detail field from RFC 7807 response for status $statusCode',
          );
        }
      },
    );

    test(
      'falls back to default message when RFC 7807 parsing fails',
      () {
        // Test with invalid JSON
        final exception401 =
            repository.testMapHttpException(401, 'not valid json');
        expect(
          exception401.message,
          equals('Unauthorized: Authentication required or token expired'),
        );

        final exception403 =
            repository.testMapHttpException(403, 'not valid json');
        expect(
          exception403.message,
          equals(
            'Forbidden: You do not have permission to perform this action',
          ),
        );

        // Test with JSON that doesn't have detail field
        final jsonWithoutDetail = jsonEncode({'error': 'something'});
        final exception404 =
            repository.testMapHttpException(404, jsonWithoutDetail);
        expect(exception404.message, equals('Resource not found'));
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
  /// Attempts to parse RFC 7807 Problem Details format from the response body
  /// to extract the 'detail' field for more specific error messages.
  RepositoryException _mapHttpException(int statusCode, String body) {
    // Try to parse RFC 7807 Problem Details format
    String? detail;
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      detail = json['detail'] as String?;
    } catch (_) {
      // If parsing fails, use the raw body
    }

    switch (statusCode) {
      case 401:
        return RepositoryException(
          detail ?? 'Unauthorized: Authentication required or token expired',
          type: RepositoryExceptionType.unauthorized,
        );
      case 403:
        return RepositoryException(
          detail ??
              'Forbidden: You do not have permission to perform this action',
          type: RepositoryExceptionType.forbidden,
        );
      case 404:
        return RepositoryException(
          detail ?? 'Resource not found',
          type: RepositoryExceptionType.notFound,
        );
      case 409:
        return RepositoryException(
          detail ?? 'Duplicate resource',
          type: RepositoryExceptionType.duplicate,
        );
      case 408:
      case 504:
        return RepositoryException(
          detail ?? 'Request timeout',
          type: RepositoryExceptionType.timeout,
        );
      case >= 500:
        return RepositoryException(
          detail ?? 'Server error: $statusCode',
          type: RepositoryExceptionType.connection,
        );
      default:
        return RepositoryException(
          detail ?? 'HTTP error $statusCode: $body',
        );
    }
  }
}
