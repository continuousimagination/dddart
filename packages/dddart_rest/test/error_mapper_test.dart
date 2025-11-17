import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_rest/src/error_mapper.dart';
import 'package:dddart_rest/src/exceptions.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:test/test.dart';

void main() {
  group('ErrorMapper - RepositoryException mapping', () {
    test('notFound exception maps to 404', () async {
      // Arrange
      const exception = RepositoryException(
        'User with ID 123 not found',
        type: RepositoryExceptionType.notFound,
      );

      // Act
      final response = ErrorMapper.mapException(exception, StackTrace.current);

      // Assert
      expect(response.statusCode, equals(404));
      expect(
          response.headers['Content-Type'], equals('application/problem+json'),);

      final bodyString = await response.readAsString();
      final body = jsonDecode(bodyString);
      expect(body['type'], equals('about:blank'));
      expect(body['title'], equals('Not Found'));
      expect(body['status'], equals(404));
      expect(body['detail'], equals('User with ID 123 not found'));
    });

    test('duplicate exception maps to 409', () async {
      // Arrange
      const exception = RepositoryException(
        'User with email already exists',
        type: RepositoryExceptionType.duplicate,
      );

      // Act
      final response = ErrorMapper.mapException(exception, StackTrace.current);

      // Assert
      expect(response.statusCode, equals(409));
      expect(
          response.headers['Content-Type'], equals('application/problem+json'),);

      final bodyString = await response.readAsString();
      final body = jsonDecode(bodyString);
      expect(body['type'], equals('about:blank'));
      expect(body['title'], equals('Conflict'));
      expect(body['status'], equals(409));
      expect(body['detail'], equals('User with email already exists'));
    });

    test('constraint exception maps to 422', () async {
      // Arrange
      const exception = RepositoryException(
        'Foreign key constraint violation',
        type: RepositoryExceptionType.constraint,
      );

      // Act
      final response = ErrorMapper.mapException(exception, StackTrace.current);

      // Assert
      expect(response.statusCode, equals(422));
      expect(
          response.headers['Content-Type'], equals('application/problem+json'),);

      final bodyString = await response.readAsString();
      final body = jsonDecode(bodyString);
      expect(body['type'], equals('about:blank'));
      expect(body['title'], equals('Unprocessable Entity'));
      expect(body['status'], equals(422));
      expect(body['detail'], equals('Foreign key constraint violation'));
    });

    test('other RepositoryException types map to 500', () async {
      // Arrange
      const exception = RepositoryException(
        'Connection timeout',
        type: RepositoryExceptionType.timeout,
      );

      // Act
      final response = ErrorMapper.mapException(exception, StackTrace.current);

      // Assert
      expect(response.statusCode, equals(500));
      expect(
          response.headers['Content-Type'], equals('application/problem+json'),);

      final bodyString = await response.readAsString();
      final body = jsonDecode(bodyString);
      expect(body['type'], equals('about:blank'));
      expect(body['title'], equals('Internal Server Error'));
      expect(body['status'], equals(500));
      expect(body['detail'], contains('Repository operation failed'));
      expect(body['detail'], contains('Connection timeout'));
    });
  });

  group('ErrorMapper - Serialization exception mapping', () {
    test('DeserializationException maps to 400', () async {
      // Arrange
      const exception = DeserializationException(
        'Invalid JSON format',
        expectedType: 'User',
        field: 'email',
      );

      // Act
      final response = ErrorMapper.mapException(exception, StackTrace.current);

      // Assert
      expect(response.statusCode, equals(400));
      expect(
          response.headers['Content-Type'], equals('application/problem+json'),);

      final bodyString = await response.readAsString();
      final body = jsonDecode(bodyString);
      expect(body['type'], equals('about:blank'));
      expect(body['title'], equals('Bad Request'));
      expect(body['status'], equals(400));
      expect(body['detail'], equals('Invalid JSON format'));
    });

    test('SerializationException maps to 500', () async {
      // Arrange
      const exception = SerializationException(
        'Failed to encode object',
        expectedType: 'User',
      );

      // Act
      final response = ErrorMapper.mapException(exception, StackTrace.current);

      // Assert
      expect(response.statusCode, equals(500));
      expect(
          response.headers['Content-Type'], equals('application/problem+json'),);

      final bodyString = await response.readAsString();
      final body = jsonDecode(bodyString);
      expect(body['type'], equals('about:blank'));
      expect(body['title'], equals('Internal Server Error'));
      expect(body['status'], equals(500));
      expect(body['detail'], contains('Serialization failed'));
      expect(body['detail'], contains('Failed to encode object'));
    });
  });

  group('ErrorMapper - Content negotiation exception mapping', () {
    test('UnsupportedMediaTypeException maps to 406', () async {
      // Arrange
      final exception = UnsupportedMediaTypeException(
        'Accept header specifies unsupported media type: application/xml',
      );

      // Act
      final response = ErrorMapper.mapException(exception, StackTrace.current);

      // Assert
      expect(response.statusCode, equals(406));
      expect(
          response.headers['Content-Type'], equals('application/problem+json'),);

      final bodyString = await response.readAsString();
      final body = jsonDecode(bodyString);
      expect(body['type'], equals('about:blank'));
      expect(body['title'], equals('Not Acceptable'));
      expect(body['status'], equals(406));
      expect(body['detail'],
          contains('Accept header specifies unsupported media type'),);
    });
  });

  group('ErrorMapper - Unknown exception handling', () {
    test('generic exceptions map to 500', () async {
      // Arrange
      final exception = Exception('Something went wrong');

      // Act
      final response = ErrorMapper.mapException(exception, StackTrace.current);

      // Assert
      expect(response.statusCode, equals(500));
      expect(
          response.headers['Content-Type'], equals('application/problem+json'),);

      final bodyString = await response.readAsString();
      final body = jsonDecode(bodyString);
      expect(body['type'], equals('about:blank'));
      expect(body['title'], equals('Internal Server Error'));
      expect(body['status'], equals(500));
      expect(body['detail'], equals('An unexpected error occurred'));
    });

    test('ArgumentError maps to 400 Bad Request', () async {
      // Arrange
      final exception = ArgumentError('Invalid argument');

      // Act
      final response = ErrorMapper.mapException(exception, StackTrace.current);

      // Assert
      expect(response.statusCode, equals(400));
      expect(
          response.headers['Content-Type'], equals('application/problem+json'),);

      final bodyString = await response.readAsString();
      final body = jsonDecode(bodyString);
      expect(body['type'], equals('about:blank'));
      expect(body['title'], equals('Bad Request'));
      expect(body['status'], equals(400));
      expect(body['detail'], equals('Invalid argument'));
    });

    test('custom exceptions map to 500 with default message', () async {
      // Arrange
      final exception = StateError('Invalid state');

      // Act
      final response = ErrorMapper.mapException(exception, StackTrace.current);

      // Assert
      expect(response.statusCode, equals(500));
      expect(
          response.headers['Content-Type'], equals('application/problem+json'),);

      final bodyString = await response.readAsString();
      final body = jsonDecode(bodyString);
      expect(body['type'], equals('about:blank'));
      expect(body['title'], equals('Internal Server Error'));
      expect(body['status'], equals(500));
      expect(body['detail'], equals('An unexpected error occurred'));
    });
  });
}
