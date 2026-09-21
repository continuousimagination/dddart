/// The portable auth/client entry does not pull native provider implementations.
library;

import 'package:dddart_rest_client/dddart_rest_client_core.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

class _Auth implements AuthProvider {
  @override
  Future<String> getAccessToken() async => 'test-token';
  @override
  Future<String> getIdToken() => getAccessToken();
  @override
  Future<void> login() async {}
  @override
  Future<void> logout() async {}
  @override
  Future<bool> isAuthenticated() async => true;
}

void main() {
  test('portable authenticated client sends once without retry', () async {
    var sends = 0;
    final client = RestClient(
      baseUrl: 'https://example.invalid',
      authProvider: _Auth(),
      httpClient: MockClient((request) async {
        sends++;
        expect(request.headers['authorization'], 'Bearer test-token');
        return http.Response('unavailable', 503);
      }),
    );
    expect(
      (await client.get(Uri.parse('https://example.invalid/test'))).statusCode,
      503,
    );
    expect(sends, 1);
    client.close();
  });
}
