import 'package:dddart/src/repository_exception.dart';
import 'package:test/test.dart';

void main() {
  group('RepositoryException', () {
    group('constructor', () {
      test('creates exception with message and default type', () {
        const exception = RepositoryException('Test error message');

        expect(exception.message, equals('Test error message'));
        expect(exception.type, equals(RepositoryExceptionType.unknown));
        expect(exception.cause, isNull);
      });

      test('creates exception with message and specific type', () {
        const exception = RepositoryException(
          'Not found error',
          type: RepositoryExceptionType.notFound,
        );

        expect(exception.message, equals('Not found error'));
        expect(exception.type, equals(RepositoryExceptionType.notFound));
        expect(exception.cause, isNull);
      });

      test('creates exception with message, type, and cause', () {
        final cause = Exception('Underlying error');
        final exception = RepositoryException(
          'Wrapper error',
          type: RepositoryExceptionType.connection,
          cause: cause,
        );

        expect(exception.message, equals('Wrapper error'));
        expect(exception.type, equals(RepositoryExceptionType.connection));
        expect(exception.cause, equals(cause));
      });
    });

    group('toString', () {
      test('formats message without cause', () {
        const exception = RepositoryException(
          'Test error',
          type: RepositoryExceptionType.duplicate,
        );

        final result = exception.toString();

        expect(
            result,
            equals(
                'RepositoryException: Test error (type: RepositoryExceptionType.duplicate)',),);
      });

      test('formats message with cause', () {
        final cause = Exception('Database connection failed');
        final exception = RepositoryException(
          'Failed to save aggregate',
          type: RepositoryExceptionType.connection,
          cause: cause,
        );

        final result = exception.toString();

        expect(
            result, contains('RepositoryException: Failed to save aggregate'),);
        expect(result, contains('type: RepositoryExceptionType.connection'));
        expect(
            result, contains('cause: Exception: Database connection failed'),);
      });

      test('formats message for notFound type', () {
        const exception = RepositoryException(
          'Aggregate not found',
          type: RepositoryExceptionType.notFound,
        );

        final result = exception.toString();

        expect(
            result,
            equals(
                'RepositoryException: Aggregate not found (type: RepositoryExceptionType.notFound)',),);
      });

      test('formats message for constraint type', () {
        const exception = RepositoryException(
          'Constraint violation',
          type: RepositoryExceptionType.constraint,
        );

        final result = exception.toString();

        expect(
            result,
            equals(
                'RepositoryException: Constraint violation (type: RepositoryExceptionType.constraint)',),);
      });

      test('formats message for timeout type', () {
        const exception = RepositoryException(
          'Operation timed out',
          type: RepositoryExceptionType.timeout,
        );

        final result = exception.toString();

        expect(
            result,
            equals(
                'RepositoryException: Operation timed out (type: RepositoryExceptionType.timeout)',),);
      });

      test('formats message for unknown type', () {
        const exception = RepositoryException(
          'Unknown error occurred',
        );

        final result = exception.toString();

        expect(
            result,
            equals(
                'RepositoryException: Unknown error occurred (type: RepositoryExceptionType.unknown)',),);
      });
    });

    group('exception type classification', () {
      test('supports notFound type', () {
        const exception = RepositoryException(
          'Not found',
          type: RepositoryExceptionType.notFound,
        );

        expect(exception.type, equals(RepositoryExceptionType.notFound));
      });

      test('supports duplicate type', () {
        const exception = RepositoryException(
          'Duplicate',
          type: RepositoryExceptionType.duplicate,
        );

        expect(exception.type, equals(RepositoryExceptionType.duplicate));
      });

      test('supports constraint type', () {
        const exception = RepositoryException(
          'Constraint',
          type: RepositoryExceptionType.constraint,
        );

        expect(exception.type, equals(RepositoryExceptionType.constraint));
      });

      test('supports connection type', () {
        const exception = RepositoryException(
          'Connection',
          type: RepositoryExceptionType.connection,
        );

        expect(exception.type, equals(RepositoryExceptionType.connection));
      });

      test('supports timeout type', () {
        const exception = RepositoryException(
          'Timeout',
          type: RepositoryExceptionType.timeout,
        );

        expect(exception.type, equals(RepositoryExceptionType.timeout));
      });

      test('supports unknown type', () {
        const exception = RepositoryException(
          'Unknown',
        );

        expect(exception.type, equals(RepositoryExceptionType.unknown));
      });
    });

    group('cause wrapping', () {
      test('wraps Exception as cause', () {
        final cause = Exception('Original error');
        final exception = RepositoryException(
          'Wrapped error',
          cause: cause,
        );

        expect(exception.cause, equals(cause));
        expect(
            exception.toString(), contains('cause: Exception: Original error'),);
      });

      test('wraps Error as cause', () {
        final cause = ArgumentError('Invalid argument');
        final exception = RepositoryException(
          'Wrapped error',
          cause: cause,
        );

        expect(exception.cause, equals(cause));
        expect(exception.toString(), contains('cause:'));
      });

      test('wraps String as cause', () {
        const cause = 'String error message';
        const exception = RepositoryException(
          'Wrapped error',
          cause: cause,
        );

        expect(exception.cause, equals(cause));
        expect(exception.toString(), contains('cause: String error message'));
      });

      test('handles null cause', () {
        const exception = RepositoryException(
          'Error without cause',
        );

        expect(exception.cause, isNull);
        expect(exception.toString(), isNot(contains('cause:')));
      });
    });
  });

  group('RepositoryExceptionType', () {
    test('enum contains all expected values', () {
      const values = RepositoryExceptionType.values;

      expect(values, contains(RepositoryExceptionType.notFound));
      expect(values, contains(RepositoryExceptionType.duplicate));
      expect(values, contains(RepositoryExceptionType.constraint));
      expect(values, contains(RepositoryExceptionType.connection));
      expect(values, contains(RepositoryExceptionType.timeout));
      expect(values, contains(RepositoryExceptionType.unknown));
    });

    test('enum has exactly 6 values', () {
      expect(RepositoryExceptionType.values.length, equals(6));
    });
  });
}
