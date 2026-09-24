import 'package:dddart/dddart.dart';
import 'package:dddart_repository_rest/dddart_repository_rest.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'test_models.dart';

/// Exercises error mapping through the generated repository's public API.
Future<RepositoryException> invokeGeneratedErrorMapping(
  int statusCode,
  String body,
) async {
  final client = MockClient((request) async {
    return http.Response(body, statusCode);
  });
  final connection = RestConnection(
    baseUrl: 'https://api.example.com',
    httpClient: client,
  );
  final repository = TestUserRestRepository(connection);

  try {
    await repository.getById(UuidValue.generate());
    throw StateError('Expected generated repository request to fail');
  } on RepositoryException catch (error) {
    return error;
  } finally {
    connection.dispose();
  }
}
