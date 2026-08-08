import 'dart:convert';
import 'dart:math';

import 'package:dddart/dddart.dart';
import 'package:test/test.dart';

import 'generated_error_mapping_harness.dart';

void main() {
  group('generated HTTP status mapping properties', () {
    test('any unsuccessful status maps to the repository taxonomy', () async {
      final random = Random(42);

      for (var iteration = 0; iteration < 100; iteration++) {
        var statusCode = random.nextInt(500) + 100;
        if (statusCode == 200) {
          statusCode = 201;
        }
        final body = 'Error message for status $statusCode';

        final exception = await invokeGeneratedErrorMapping(statusCode, body);

        expect(
          exception.type,
          _expectedType(statusCode),
          reason: 'Unexpected mapping for HTTP $statusCode',
        );
      }
    });

    test('mapping type is independent of response body', () async {
      const statusCodes = [
        201,
        400,
        401,
        403,
        404,
        408,
        409,
        422,
        500,
        502,
        504,
      ];

      for (final statusCode in statusCodes) {
        final first = await invokeGeneratedErrorMapping(statusCode, 'first');
        final second = await invokeGeneratedErrorMapping(statusCode, 'second');

        expect(second.type, first.type);
      }
    });

    test('RFC 7807 detail is preserved for every mapped category', () async {
      const statusCodes = [401, 403, 404, 408, 409, 422, 500, 504];

      for (final statusCode in statusCodes) {
        final detail = 'Detail for HTTP $statusCode';
        final exception = await invokeGeneratedErrorMapping(
          statusCode,
          jsonEncode({
            'type': 'about:blank',
            'title': 'Error',
            'status': statusCode,
            'detail': detail,
          }),
        );

        expect(exception.message, detail);
      }
    });
  });
}

RepositoryExceptionType _expectedType(int statusCode) {
  return switch (statusCode) {
    401 => RepositoryExceptionType.unauthorized,
    403 => RepositoryExceptionType.forbidden,
    404 => RepositoryExceptionType.notFound,
    408 || 504 => RepositoryExceptionType.timeout,
    409 => RepositoryExceptionType.duplicate,
    422 => RepositoryExceptionType.constraint,
    >= 500 => RepositoryExceptionType.connection,
    _ => RepositoryExceptionType.unknown,
  };
}
