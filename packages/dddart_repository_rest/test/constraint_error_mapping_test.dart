import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_repository_rest/dddart_repository_rest.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'test_models.dart';

void main() {
  test('generated repository maps HTTP 422 to constraint', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'type': 'about:blank',
          'title': 'Unprocessable Entity',
          'status': 422,
          'detail': 'Email must be unique',
        }),
        422,
      );
    });
    final connection = RestConnection(
      baseUrl: 'https://api.example.com',
      httpClient: client,
    );
    final repository = TestUserRestRepository(connection);

    try {
      await expectLater(
        repository.getById(UuidValue.generate()),
        throwsA(
          isA<RepositoryException>()
              .having(
                (error) => error.type,
                'type',
                RepositoryExceptionType.constraint,
              )
              .having(
                (error) => error.message,
                'message',
                'Email must be unique',
              ),
        ),
      );
    } finally {
      connection.dispose();
    }
  });
}
