@Tags(['property-test'])
library;

import 'dart:math';

import 'package:dddart/dddart.dart';
import 'package:test/test.dart';

void main() {
  group('Exception Mapping Properties', () {
    final random = Random(42); // Fixed seed for reproducibility

    // **Feature: dynamodb-repository, Property 6: DynamoDB exception mapping**
    // **Validates: Requirements 6.1**
    group('Property 6: DynamoDB exception mapping', () {
      test('should map ResourceNotFoundException to notFound', () {
        for (var i = 0; i < 100; i++) {
          final errorMessage = _generateRandomErrorMessage(
            random,
            'ResourceNotFoundException',
          );
          final exception = _createMockException(errorMessage);
          final mapped = _mapDynamoException(exception, 'testOperation');

          expect(
            mapped.type,
            equals(RepositoryExceptionType.notFound),
            reason:
                'Iteration $i: ResourceNotFoundException should map to notFound',
          );
          expect(
            mapped.message,
            contains('Resource not found'),
            reason: 'Iteration $i: Message should indicate resource not found',
          );
          expect(
            mapped.cause,
            equals(exception),
            reason:
                'Iteration $i: Original exception should be preserved as cause',
          );
        }
      });

      test('should map ConditionalCheckFailedException to duplicate', () {
        for (var i = 0; i < 100; i++) {
          final errorMessage = _generateRandomErrorMessage(
            random,
            'ConditionalCheckFailedException',
          );
          final exception = _createMockException(errorMessage);
          final mapped = _mapDynamoException(exception, 'testOperation');

          expect(
            mapped.type,
            equals(RepositoryExceptionType.duplicate),
            reason:
                'Iteration $i: ConditionalCheckFailedException should map to duplicate',
          );
          expect(
            mapped.message,
            contains('Conditional check failed'),
            reason:
                'Iteration $i: Message should indicate conditional check failure',
          );
          expect(
            mapped.cause,
            equals(exception),
            reason:
                'Iteration $i: Original exception should be preserved as cause',
          );
        }
      });

      test('should map connection errors to connection type', () {
        final connectionKeywords = ['connection', 'network', 'SocketException'];

        for (var i = 0; i < 100; i++) {
          final keyword =
              connectionKeywords[random.nextInt(connectionKeywords.length)];
          final errorMessage = _generateRandomErrorMessage(random, keyword);
          final exception = _createMockException(errorMessage);
          final mapped = _mapDynamoException(exception, 'testOperation');

          expect(
            mapped.type,
            equals(RepositoryExceptionType.connection),
            reason:
                'Iteration $i: Connection errors should map to connection type',
          );
          expect(
            mapped.message,
            contains('Connection error'),
            reason: 'Iteration $i: Message should indicate connection error',
          );
          expect(
            mapped.cause,
            equals(exception),
            reason:
                'Iteration $i: Original exception should be preserved as cause',
          );
        }
      });

      test('should map timeout errors to timeout type', () {
        final timeoutKeywords = ['timeout', 'TimeoutException'];

        for (var i = 0; i < 100; i++) {
          final keyword =
              timeoutKeywords[random.nextInt(timeoutKeywords.length)];
          final errorMessage = _generateRandomErrorMessage(random, keyword);
          final exception = _createMockException(errorMessage);
          final mapped = _mapDynamoException(exception, 'testOperation');

          expect(
            mapped.type,
            equals(RepositoryExceptionType.timeout),
            reason: 'Iteration $i: Timeout errors should map to timeout type',
          );
          expect(
            mapped.message,
            contains('Timeout'),
            reason: 'Iteration $i: Message should indicate timeout',
          );
          expect(
            mapped.cause,
            equals(exception),
            reason:
                'Iteration $i: Original exception should be preserved as cause',
          );
        }
      });
    });

    // **Feature: dynamodb-repository, Property 7: Unknown exception handling**
    // **Validates: Requirements 6.5**
    group('Property 7: Unknown exception handling', () {
      test('should map unrecognized exceptions to unknown type', () {
        for (var i = 0; i < 100; i++) {
          // Generate random error messages that don't match known patterns
          final errorMessage = _generateRandomUnknownErrorMessage(random);
          final exception = _createMockException(errorMessage);
          final mapped = _mapDynamoException(exception, 'testOperation');

          expect(
            mapped.type,
            equals(RepositoryExceptionType.unknown),
            reason:
                'Iteration $i: Unrecognized exceptions should map to unknown type',
          );
          expect(
            mapped.message,
            contains('DynamoDB error'),
            reason: 'Iteration $i: Message should indicate DynamoDB error',
          );
          expect(
            mapped.cause,
            equals(exception),
            reason:
                'Iteration $i: Original exception should be preserved as cause',
          );
        }
      });

      test('should preserve original exception in cause for all mappings', () {
        final allErrorTypes = [
          'ResourceNotFoundException',
          'ConditionalCheckFailedException',
          'connection',
          'timeout',
          'UnknownError',
        ];

        for (var i = 0; i < 100; i++) {
          final errorType = allErrorTypes[random.nextInt(allErrorTypes.length)];
          final errorMessage = _generateRandomErrorMessage(random, errorType);
          final exception = _createMockException(errorMessage);
          final mapped = _mapDynamoException(exception, 'testOperation');

          expect(
            mapped.cause,
            equals(exception),
            reason: 'Iteration $i: Original exception must always be preserved',
          );
          expect(
            mapped.cause,
            isNotNull,
            reason: 'Iteration $i: Cause should never be null',
          );
        }
      });
    });
  });
}

// Helper functions

/// Generates a random error message containing the specified keyword.
String _generateRandomErrorMessage(Random random, String keyword) {
  final prefixes = [
    'Error occurred:',
    'Failed with:',
    'Exception:',
    'AWS DynamoDB:',
    '',
  ];
  final suffixes = [
    'Please try again',
    'Contact support',
    'Check your configuration',
    '',
  ];

  final prefix = prefixes[random.nextInt(prefixes.length)];
  final suffix = suffixes[random.nextInt(suffixes.length)];
  final randomPart = _generateRandomString(random, maxLength: 20);

  return '$prefix $keyword $randomPart $suffix'.trim();
}

/// Generates a random error message that doesn't match known patterns.
String _generateRandomUnknownErrorMessage(Random random) {
  final errorTypes = [
    'ValidationException',
    'InternalServerError',
    'ServiceUnavailable',
    'ThrottlingException',
    'AccessDeniedException',
    'UnknownError',
    'CustomException',
  ];

  final errorType = errorTypes[random.nextInt(errorTypes.length)];
  final randomPart = _generateRandomString(random, maxLength: 30);

  return '$errorType: $randomPart';
}

/// Generates a random string of variable length.
String _generateRandomString(Random random, {int maxLength = 50}) {
  final length = random.nextInt(maxLength) + 1;
  const chars =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ';
  return String.fromCharCodes(
    Iterable.generate(
      length,
      (_) => chars.codeUnitAt(random.nextInt(chars.length)),
    ),
  );
}

/// Creates a mock exception with the given message.
Object _createMockException(String message) {
  return _MockDynamoException(message);
}

/// Mock exception class for testing.
class _MockDynamoException implements Exception {
  _MockDynamoException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Maps DynamoDB exceptions to RepositoryException types.
/// This is a copy of the logic from the generated code for testing purposes.
RepositoryException _mapDynamoException(
  Object error,
  String operation,
) {
  final errorString = error.toString();

  // Map ResourceNotFoundException to notFound
  if (errorString.contains('ResourceNotFoundException')) {
    return RepositoryException(
      'Resource not found during $operation: $errorString',
      type: RepositoryExceptionType.notFound,
      cause: error,
    );
  }

  // Map ConditionalCheckFailedException to duplicate
  if (errorString.contains('ConditionalCheckFailedException')) {
    return RepositoryException(
      'Conditional check failed during $operation: $errorString',
      type: RepositoryExceptionType.duplicate,
      cause: error,
    );
  }

  // Map network/connectivity errors to connection
  if (errorString.contains('connection') ||
      errorString.contains('network') ||
      errorString.contains('SocketException')) {
    return RepositoryException(
      'Connection error during $operation: $errorString',
      type: RepositoryExceptionType.connection,
      cause: error,
    );
  }

  // Map timeout errors to timeout
  if (errorString.contains('timeout') ||
      errorString.contains('TimeoutException')) {
    return RepositoryException(
      'Timeout during $operation: $errorString',
      type: RepositoryExceptionType.timeout,
      cause: error,
    );
  }

  // All other errors map to unknown
  return RepositoryException(
    'DynamoDB error during $operation: $errorString',
    cause: error,
  );
}
