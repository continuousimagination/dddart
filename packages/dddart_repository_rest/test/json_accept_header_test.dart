import 'package:dddart/dddart.dart';
import 'package:dddart_repository_rest/dddart_repository_rest.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'test_models.dart';

void main() {
  test('generated CRUD requests declare their JSON media contract', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      return switch (request.method) {
        'GET' => http.Response('Not found', 404),
        'PUT' => http.Response('', 200),
        'DELETE' => http.Response('', 204),
        _ => http.Response('Unexpected request', 500),
      };
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

      final user = TestUser(name: 'Ada', email: 'ada@example.com');
      await repository.save(user);
      await repository.deleteById(user.id);

      expect(requests, hasLength(3));
      expect(requests[0].headers['accept'], 'application/json');
      expect(requests[1].headers['accept'], 'application/json');
      expect(requests[1].headers['content-type'], 'application/json');
      expect(requests[2].headers['accept'], 'application/json');
    } finally {
      connection.dispose();
    }
  });
}
