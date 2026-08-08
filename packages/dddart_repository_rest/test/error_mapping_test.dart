import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:test/test.dart';

import 'generated_error_mapping_harness.dart';

void main() {
  group('generated HTTP error mapping', () {
    const cases = <({
      int statusCode,
      RepositoryExceptionType type,
      String message,
    })>[
      (
        statusCode: 401,
        type: RepositoryExceptionType.unauthorized,
        message: 'Unauthorized: Authentication required or token expired',
      ),
      (
        statusCode: 403,
        type: RepositoryExceptionType.forbidden,
        message: 'Forbidden: You do not have permission to perform this action',
      ),
      (
        statusCode: 404,
        type: RepositoryExceptionType.notFound,
        message: 'Resource not found',
      ),
      (
        statusCode: 408,
        type: RepositoryExceptionType.timeout,
        message: 'Request timeout',
      ),
      (
        statusCode: 409,
        type: RepositoryExceptionType.duplicate,
        message: 'Duplicate resource',
      ),
      (
        statusCode: 422,
        type: RepositoryExceptionType.constraint,
        message: 'Repository constraint violated',
      ),
      (
        statusCode: 500,
        type: RepositoryExceptionType.connection,
        message: 'Server error: 500',
      ),
      (
        statusCode: 504,
        type: RepositoryExceptionType.timeout,
        message: 'Request timeout',
      ),
      (
        statusCode: 599,
        type: RepositoryExceptionType.connection,
        message: 'Server error: 599',
      ),
    ];

    for (final testCase in cases) {
      test('${testCase.statusCode} maps to ${testCase.type.name}', () async {
        final exception = await invokeGeneratedErrorMapping(
          testCase.statusCode,
          'not-json',
        );

        expect(exception.type, testCase.type);
        expect(exception.message, testCase.message);
      });
    }

    test('unknown status includes the response body', () async {
      final exception = await invokeGeneratedErrorMapping(
        418,
        "I'm a teapot",
      );

      expect(exception.type, RepositoryExceptionType.unknown);
      expect(exception.message, contains('HTTP error 418'));
      expect(exception.message, contains("I'm a teapot"));
    });

    test('RFC 7807 detail overrides the default message', () async {
      final exception = await invokeGeneratedErrorMapping(
        403,
        jsonEncode({
          'type': 'about:blank',
          'title': 'Forbidden',
          'status': 403,
          'detail': 'Only owners may update this aggregate',
        }),
      );

      expect(exception.type, RepositoryExceptionType.forbidden);
      expect(exception.message, 'Only owners may update this aggregate');
    });
  });
}
