import 'package:dddart/dddart.dart';
import 'package:dddart_repository_rest/dddart_repository_rest.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'test_models.dart';

void main() {
  test('inferred resource path produces an absolute path from the base URL',
      () async {
    final id = UuidValue.generate();
    Uri? requestedUri;
    final client = MockClient((request) async {
      requestedUri = request.url;
      return http.Response('Not found', 404);
    });
    final connection = RestConnection(
      baseUrl: 'https://api.example.com',
      httpClient: client,
    );
    final repository = InferredResourceRestRepository(connection);

    try {
      await expectLater(
        repository.getById(id),
        throwsA(
          isA<RepositoryException>().having(
            (error) => error.type,
            'type',
            RepositoryExceptionType.notFound,
          ),
        ),
      );
      expect(
        requestedUri,
        Uri.parse('https://api.example.com/inferred-resources/${id.uuid}'),
      );
    } finally {
      connection.dispose();
    }
  });
}
