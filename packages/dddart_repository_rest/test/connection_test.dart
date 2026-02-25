import 'package:dddart_repository_rest/dddart_repository_rest.dart';
import 'package:dddart_rest_client/dddart_rest_client.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

/// Mock HTTP client for testing
class MockHttpClient extends http.BaseClient {
  bool isClosed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    throw UnimplementedError('Mock client should not send requests');
  }

  @override
  void close() {
    isClosed = true;
    super.close();
  }
}

/// Mock auth provider for testing
class MockAuthProvider implements AuthProvider {
  MockAuthProvider({this.token = 'mock-token'});

  final String token;
  bool loginCalled = false;
  bool logoutCalled = false;

  @override
  Future<String> getAccessToken() async => token;

  @override
  Future<String> getIdToken() async => token;

  @override
  Future<void> login() async {
    loginCalled = true;
  }

  @override
  Future<void> logout() async {
    logoutCalled = true;
  }

  @override
  Future<bool> isAuthenticated() async => true;
}

void main() {
  group('RestConnection', () {
    group('constructor', () {
      test('should create connection with required baseUrl', () {
        final connection = RestConnection(
          baseUrl: 'https://api.example.com',
        );

        expect(connection.baseUrl, equals('https://api.example.com'));
        expect(connection.authProvider, isNull);
      });

      test('should create connection with auth provider', () {
        final authProvider = MockAuthProvider();
        final connection = RestConnection(
          baseUrl: 'https://api.example.com',
          authProvider: authProvider,
        );

        expect(connection.baseUrl, equals('https://api.example.com'));
        expect(connection.authProvider, equals(authProvider));
      });

      test('should create connection with custom HTTP client', () {
        final mockClient = MockHttpClient();
        final connection = RestConnection(
          baseUrl: 'https://api.example.com',
          httpClient: mockClient,
        );

        expect(connection.baseUrl, equals('https://api.example.com'));
        expect(connection.client, equals(mockClient));
      });

      test('should create connection with auth provider and custom client', () {
        final authProvider = MockAuthProvider();
        final mockClient = MockHttpClient();
        final connection = RestConnection(
          baseUrl: 'https://api.example.com',
          authProvider: authProvider,
          httpClient: mockClient,
        );

        expect(connection.baseUrl, equals('https://api.example.com'));
        expect(connection.authProvider, equals(authProvider));
        expect(connection.authProvider != null, isTrue);
      });
    });

    group('baseUrl storage', () {
      test('should store base URL correctly', () {
        final connection = RestConnection(
          baseUrl: 'https://api.example.com',
        );

        expect(connection.baseUrl, equals('https://api.example.com'));
      });

      test('should store different base URLs correctly', () {
        final connection1 = RestConnection(
          baseUrl: 'https://api1.example.com',
        );
        final connection2 = RestConnection(
          baseUrl: 'https://api2.example.com',
        );

        expect(connection1.baseUrl, equals('https://api1.example.com'));
        expect(connection2.baseUrl, equals('https://api2.example.com'));
      });

      test('should store base URL with port', () {
        final connection = RestConnection(
          baseUrl: 'http://localhost:8080',
        );

        expect(connection.baseUrl, equals('http://localhost:8080'));
      });

      test('should store base URL without trailing slash', () {
        final connection = RestConnection(
          baseUrl: 'https://api.example.com',
        );

        expect(connection.baseUrl, equals('https://api.example.com'));
        expect(connection.baseUrl.endsWith('/'), isFalse);
      });
    });

    group('authentication', () {
      test('should have hasAuth false when no auth provider', () {
        final connection = RestConnection(
          baseUrl: 'https://api.example.com',
        );

        expect(connection.authProvider != null, isFalse);
      });

      test('should have hasAuth true when auth provider configured', () {
        final authProvider = MockAuthProvider();
        final connection = RestConnection(
          baseUrl: 'https://api.example.com',
          authProvider: authProvider,
        );

        expect(connection.authProvider != null, isTrue);
      });

      test('should provide access to auth provider', () {
        final authProvider = MockAuthProvider();
        final connection = RestConnection(
          baseUrl: 'https://api.example.com',
          authProvider: authProvider,
        );

        expect(connection.authProvider, equals(authProvider));
      });

      test('should provide HTTP client when no auth provider', () {
        final connection = RestConnection(
          baseUrl: 'https://api.example.com',
        );

        expect(connection.client, isA<http.Client>());
        expect(connection.client, isNot(isA<RestClient>()));
      });

      test('should provide basic HTTP client when no auth configured', () {
        final connection = RestConnection(
          baseUrl: 'https://api.example.com',
        );

        final client = connection.client;
        expect(client, isA<http.Client>());
        // Should be the basic HTTP client, not RestClient
        expect(client, isNot(isA<RestClient>()));
      });

      test('should provide RestClient when auth provider configured', () {
        final authProvider = MockAuthProvider();
        final connection = RestConnection(
          baseUrl: 'https://api.example.com',
          authProvider: authProvider,
        );

        expect(connection.client, isA<RestClient>());
      });
    });

    group('httpClient', () {
      test('should provide HTTP client', () {
        final connection = RestConnection(
          baseUrl: 'https://api.example.com',
        );

        expect(connection.client, isA<http.Client>());
      });

      test('should provide custom HTTP client when provided', () {
        final mockClient = MockHttpClient();
        final connection = RestConnection(
          baseUrl: 'https://api.example.com',
          httpClient: mockClient,
        );

        expect(connection.client, equals(mockClient));
      });
    });

    group('dispose', () {
      test('should close HTTP client when no auth provider', () {
        final mockClient = MockHttpClient();
        final connection = RestConnection(
          baseUrl: 'https://api.example.com',
          httpClient: mockClient,
        );

        expect(mockClient.isClosed, isFalse);

        connection.dispose();

        expect(mockClient.isClosed, isTrue);
      });

      test('should close RestClient when auth provider configured', () {
        final authProvider = MockAuthProvider();
        final mockClient = MockHttpClient();
        final connection = RestConnection(
          baseUrl: 'https://api.example.com',
          authProvider: authProvider,
          httpClient: mockClient,
        );

        expect(mockClient.isClosed, isFalse);

        connection.dispose();

        expect(mockClient.isClosed, isTrue);
      });

      test('should be safe to call dispose multiple times', () {
        final mockClient = MockHttpClient();
        final connection = RestConnection(
          baseUrl: 'https://api.example.com',
          httpClient: mockClient,
        );

        connection.dispose();
        expect(mockClient.isClosed, isTrue);

        // Should not throw
        expect(connection.dispose, returnsNormally);
      });
    });

    group('connection sharing', () {
      test('should allow multiple repositories to share same connection', () {
        final connection = RestConnection(
          baseUrl: 'https://api.example.com',
        );

        // Simulate multiple repositories using the same connection
        final httpClient1 = connection.client;
        final httpClient2 = connection.client;

        expect(httpClient1, equals(httpClient2));
        expect(identical(httpClient1, httpClient2), isTrue);
      });

      test('should share auth provider across multiple accesses', () {
        final authProvider = MockAuthProvider();
        final connection = RestConnection(
          baseUrl: 'https://api.example.com',
          authProvider: authProvider,
        );

        final provider1 = connection.authProvider;
        final provider2 = connection.authProvider;

        expect(provider1, equals(provider2));
        expect(identical(provider1, provider2), isTrue);
      });

      test('should share RestClient instance when auth configured', () {
        final authProvider = MockAuthProvider();
        final connection = RestConnection(
          baseUrl: 'https://api.example.com',
          authProvider: authProvider,
        );

        final client1 = connection.client;
        final client2 = connection.client;

        expect(client1, equals(client2));
        expect(identical(client1, client2), isTrue);
      });

      test('should maintain connection state across multiple uses', () {
        final mockClient = MockHttpClient();
        final connection = RestConnection(
          baseUrl: 'https://api.example.com',
          httpClient: mockClient,
        );

        // Access multiple times
        connection.client;
        connection.client;
        connection.client;

        // Should still be the same client
        expect(connection.client, equals(mockClient));
        expect(mockClient.isClosed, isFalse);

        // Dispose should affect all references
        connection.dispose();
        expect(mockClient.isClosed, isTrue);
      });
    });

    group('different configurations', () {
      test('should support HTTP URLs', () {
        final connection = RestConnection(
          baseUrl: 'http://localhost:8080',
        );

        expect(connection.baseUrl, equals('http://localhost:8080'));
      });

      test('should support HTTPS URLs', () {
        final connection = RestConnection(
          baseUrl: 'https://api.example.com',
        );

        expect(connection.baseUrl, equals('https://api.example.com'));
      });

      test('should support URLs with paths', () {
        final connection = RestConnection(
          baseUrl: 'https://api.example.com/v1',
        );

        expect(connection.baseUrl, equals('https://api.example.com/v1'));
      });

      test('should support localhost URLs', () {
        final connection = RestConnection(
          baseUrl: 'http://localhost:3000',
        );

        expect(connection.baseUrl, equals('http://localhost:3000'));
      });

      test('should support IP address URLs', () {
        final connection = RestConnection(
          baseUrl: 'http://192.168.1.100:8080',
        );

        expect(connection.baseUrl, equals('http://192.168.1.100:8080'));
      });
    });
  });
}
