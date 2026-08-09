import 'dart:async';

import 'package:dddart/dddart.dart';
import 'package:dddart_repository_rest/dddart_repository_rest.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'test_models.dart';

void main() {
  group('generated repository transport errors', () {
    test('all generated HTTP operations map client failures to connection',
        () async {
      final client = MockClient((request) async {
        throw http.ClientException('offline', request.url);
      });
      final connection = RestConnection(
        baseUrl: 'https://api.example.com',
        httpClient: client,
      );
      final repository = TestUserRestRepository(connection);
      final user = TestUser(name: 'Ada', email: 'ada@example.com');
      final operations = <Future<void> Function()>[
        () async => repository.getById(user.id),
        () => repository.save(user),
        () => repository.deleteById(user.id),
      ];

      try {
        for (final operation in operations) {
          await expectLater(
            operation(),
            throwsA(
              isA<RepositoryException>()
                  .having(
                    (error) => error.type,
                    'type',
                    RepositoryExceptionType.connection,
                  )
                  .having(
                    (error) => error.cause,
                    'cause',
                    isA<http.ClientException>(),
                  ),
            ),
          );
        }
      } finally {
        connection.dispose();
      }
    });

    test('maps request timeouts to timeout', () async {
      final client = MockClient((request) async {
        throw TimeoutException('request timed out');
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
                  RepositoryExceptionType.timeout,
                )
                .having(
                  (error) => error.cause,
                  'cause',
                  isA<TimeoutException>(),
                ),
          ),
        );
      } finally {
        connection.dispose();
      }
    });
  });
}
