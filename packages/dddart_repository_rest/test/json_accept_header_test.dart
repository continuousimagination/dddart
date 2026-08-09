import 'package:dddart/dddart.dart';
import 'package:dddart_repository_rest/dddart_repository_rest.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'test_models.dart';

void main() {
  test('generated JSON repository requests JSON responses', () async {
    String? acceptHeader;
    final client = MockClient((request) async {
      acceptHeader = request.headers['accept'];
      return http.Response('Not found', 404);
    });
    final connection = RestConnection(
      baseUrl: 'https://api.example.com',
      httpClient: client,
    );
    final repository = TestUserRestRepository(connection);

    try {
      await expectLater(
        repository.getById(UuidValue.generate()),
        throwsA(isA<RepositoryException>()),
      );
      expect(acceptHeader, 'application/json');
    } finally {
      connection.dispose();
    }
  });
}
