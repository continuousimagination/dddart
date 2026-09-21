/// Exercises the actual generated repository instead of a copied mapper.
@Tags(['unit'])
library;

import 'dart:convert';
import 'package:dddart/dddart.dart';
import 'package:dddart_repository_rest/dddart_repository_rest.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'u10/binding.dart';
import 'u10/shared_model.dart';

void main() {
  final cases = {
    400: RepositoryExceptionType.constraint,
    401: RepositoryExceptionType.unauthorized,
    403: RepositoryExceptionType.forbidden,
    404: RepositoryExceptionType.notFound,
    408: RepositoryExceptionType.timeout,
    409: RepositoryExceptionType.duplicate,
    412: RepositoryExceptionType.constraint,
    418: RepositoryExceptionType.unknown,
    422: RepositoryExceptionType.constraint,
    500: RepositoryExceptionType.connection,
    502: RepositoryExceptionType.connection,
    503: RepositoryExceptionType.connection,
    504: RepositoryExceptionType.timeout,
    599: RepositoryExceptionType.connection,
  };
  for (final entry in cases.entries) {
    test(
      'HTTP ${entry.key} maps to ${entry.value.name} without exposing provider data',
      () async {
        const marker = 'restricted-provider-detail';
        var sends = 0;
        final connection = RestConnection(
          baseUrl: 'https://example.invalid/',
          httpClient: MockClient((request) async {
            sends++;
            expect(request.method, 'PUT');
            return http.Response(jsonEncode({'detail': marker}), entry.key);
          }),
        );
        final now = DateTime.utc(2026);
        final record = RemoteRecord(
          id: UuidValue.generate(),
          createdAt: now,
          updatedAt: now,
          text: 'synthetic',
        );
        try {
          await ProbeRestRepository(connection).save(record);
          fail('Expected typed failure');
        } on RepositoryException catch (error) {
          expect(error.type, entry.value);
          expect(error.toString(), isNot(contains(marker)));
          expect(error.cause, isNull);
        } finally {
          connection.dispose();
        }
        expect(sends, 1);
      },
    );
  }
}
