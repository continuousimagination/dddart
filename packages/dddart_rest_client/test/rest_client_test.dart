import 'dart:convert';

import 'package:dddart_rest_client/dddart_rest_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

class MockAuthProvider implements AuthProvider {
  MockAuthProvider({this.token = 'test-token'});

  final String token;

  @override
  Future<String> getAccessToken() async => token;

  @override
  Future<bool> isAuthenticated() async => true;

  @override
  Future<void> login() async {}

  @override
  Future<void> logout() async {}
}

void main() {
  group('RestClient', () {
    late RestClient client;
    late MockAuthProvider authProvider;

    setUp(() {
      authProvider = MockAuthProvider();
    });

    test('should include Authorization header in GET requests', () async {
      final mockClient = MockClient((request) async {
        expect(request.headers['Authorization'], equals('Bearer test-token'));
        expect(request.method, equals('GET'));
        expect(request.url.toString(), equals('https://api.example.com/users'));
        return http.Response('[]', 200);
      });

      client = RestClient(
        baseUrl: 'https://api.example.com',
        authProvider: authProvider,
        httpClient: mockClient,
      );

      await client.get('/users');
    });

    test('should include Authorization header in POST requests', () async {
      final mockClient = MockClient((request) async {
        expect(request.headers['Authorization'], equals('Bearer test-token'));
        expect(request.method, equals('POST'));
        expect(request.url.toString(), equals('https://api.example.com/users'));
        expect(request.headers['Content-Type'], equals('application/json'));
        expect(
          request.body,
          equals(jsonEncode({'name': 'Alice'})),
        );
        return http.Response('{"id": "123"}', 201);
      });

      client = RestClient(
        baseUrl: 'https://api.example.com',
        authProvider: authProvider,
        httpClient: mockClient,
      );

      await client.post('/users', body: {'name': 'Alice'});
    });

    test('should include Authorization header in PUT requests', () async {
      final mockClient = MockClient((request) async {
        expect(request.headers['Authorization'], equals('Bearer test-token'));
        expect(request.method, equals('PUT'));
        expect(
          request.url.toString(),
          equals('https://api.example.com/users/123'),
        );
        return http.Response('{"id": "123"}', 200);
      });

      client = RestClient(
        baseUrl: 'https://api.example.com',
        authProvider: authProvider,
        httpClient: mockClient,
      );

      await client.put('/users/123', body: {'name': 'Alice Updated'});
    });

    test('should include Authorization header in DELETE requests', () async {
      final mockClient = MockClient((request) async {
        expect(request.headers['Authorization'], equals('Bearer test-token'));
        expect(request.method, equals('DELETE'));
        expect(
          request.url.toString(),
          equals('https://api.example.com/users/123'),
        );
        return http.Response('', 204);
      });

      client = RestClient(
        baseUrl: 'https://api.example.com',
        authProvider: authProvider,
        httpClient: mockClient,
      );

      await client.delete('/users/123');
    });

    test('should include Authorization header in PATCH requests', () async {
      final mockClient = MockClient((request) async {
        expect(request.headers['Authorization'], equals('Bearer test-token'));
        expect(request.method, equals('PATCH'));
        expect(
          request.url.toString(),
          equals('https://api.example.com/users/123'),
        );
        return http.Response('{"id": "123"}', 200);
      });

      client = RestClient(
        baseUrl: 'https://api.example.com',
        authProvider: authProvider,
        httpClient: mockClient,
      );

      await client.patch('/users/123', body: {'email': 'new@example.com'});
    });

    test('should allow custom headers', () async {
      final mockClient = MockClient((request) async {
        expect(request.headers['Authorization'], equals('Bearer test-token'));
        expect(request.headers['X-Custom-Header'], equals('custom-value'));
        return http.Response('[]', 200);
      });

      client = RestClient(
        baseUrl: 'https://api.example.com',
        authProvider: authProvider,
        httpClient: mockClient,
      );

      await client.get('/users', headers: {'X-Custom-Header': 'custom-value'});
    });

    test('should get token from auth provider', () async {
      var tokenRequested = false;
      final customAuthProvider = MockAuthProvider(token: 'custom-token');

      final mockClient = MockClient((request) async {
        tokenRequested = true;
        expect(
          request.headers['Authorization'],
          equals('Bearer custom-token'),
        );
        return http.Response('[]', 200);
      });

      client = RestClient(
        baseUrl: 'https://api.example.com',
        authProvider: customAuthProvider,
        httpClient: mockClient,
      );

      await client.get('/users');
      expect(tokenRequested, isTrue);
    });
  });
}
