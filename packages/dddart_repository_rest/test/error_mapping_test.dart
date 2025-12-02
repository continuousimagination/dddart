@Tags(['unit'])
library;

import 'package:dddart/dddart.dart';
import 'package:test/test.dart';

void main() {
  group('HTTP error mapping', () {
    late _TestRepository repository;

    setUp(() {
      repository = _TestRepository();
    });

    test('404 maps to notFound', () {
      // Act
      final exception = repository.testMapHttpException(404, 'Not found');

      // Assert
      expect(exception, isA<RepositoryException>());
      expect(exception.type, equals(RepositoryExceptionType.notFound));
      expect(exception.message, equals('Resource not found'));
    });

    test('409 maps to duplicate', () {
      // Act
      final exception = repository.testMapHttpException(409, 'Conflict');

      // Assert
      expect(exception, isA<RepositoryException>());
      expect(exception.type, equals(RepositoryExceptionType.duplicate));
      expect(exception.message, equals('Duplicate resource'));
    });

    test('408 maps to timeout', () {
      // Act
      final exception = repository.testMapHttpException(408, 'Request timeout');

      // Assert
      expect(exception, isA<RepositoryException>());
      expect(exception.type, equals(RepositoryExceptionType.timeout));
      expect(exception.message, equals('Request timeout'));
    });

    test('504 maps to timeout', () {
      // Act
      final exception = repository.testMapHttpException(504, 'Gateway timeout');

      // Assert
      expect(exception, isA<RepositoryException>());
      expect(exception.type, equals(RepositoryExceptionType.timeout));
      expect(exception.message, equals('Request timeout'));
    });

    test('500 maps to connection', () {
      // Act
      final exception =
          repository.testMapHttpException(500, 'Internal server error');

      // Assert
      expect(exception, isA<RepositoryException>());
      expect(exception.type, equals(RepositoryExceptionType.connection));
      expect(exception.message, contains('Server error: 500'));
    });

    test('502 maps to connection', () {
      // Act
      final exception = repository.testMapHttpException(502, 'Bad gateway');

      // Assert
      expect(exception, isA<RepositoryException>());
      expect(exception.type, equals(RepositoryExceptionType.connection));
      expect(exception.message, contains('Server error: 502'));
    });

    test('503 maps to connection', () {
      // Act
      final exception =
          repository.testMapHttpException(503, 'Service unavailable');

      // Assert
      expect(exception, isA<RepositoryException>());
      expect(exception.type, equals(RepositoryExceptionType.connection));
      expect(exception.message, contains('Server error: 503'));
    });

    test('599 maps to connection', () {
      // Act
      final exception = repository.testMapHttpException(599, 'Network error');

      // Assert
      expect(exception, isA<RepositoryException>());
      expect(exception.type, equals(RepositoryExceptionType.connection));
      expect(exception.message, contains('Server error: 599'));
    });

    test('400 maps to unknown', () {
      // Act
      final exception = repository.testMapHttpException(400, 'Bad request');

      // Assert
      expect(exception, isA<RepositoryException>());
      expect(exception.type, equals(RepositoryExceptionType.unknown));
      expect(exception.message, contains('HTTP error 400'));
      expect(exception.message, contains('Bad request'));
    });

    test('401 maps to unknown', () {
      // Act
      final exception = repository.testMapHttpException(401, 'Unauthorized');

      // Assert
      expect(exception, isA<RepositoryException>());
      expect(exception.type, equals(RepositoryExceptionType.unknown));
      expect(exception.message, contains('HTTP error 401'));
    });

    test('403 maps to unknown', () {
      // Act
      final exception = repository.testMapHttpException(403, 'Forbidden');

      // Assert
      expect(exception, isA<RepositoryException>());
      expect(exception.type, equals(RepositoryExceptionType.unknown));
      expect(exception.message, contains('HTTP error 403'));
    });

    test('418 maps to unknown', () {
      // Act
      final exception = repository.testMapHttpException(418, "I'm a teapot");

      // Assert
      expect(exception, isA<RepositoryException>());
      expect(exception.type, equals(RepositoryExceptionType.unknown));
      expect(exception.message, contains('HTTP error 418'));
    });

    test('error message includes response body', () {
      // Act
      final exception = repository.testMapHttpException(
        400,
        'Detailed error message from server',
      );

      // Assert
      expect(
        exception.message,
        contains('Detailed error message from server'),
      );
    });
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
