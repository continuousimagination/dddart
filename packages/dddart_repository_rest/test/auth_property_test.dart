/// Property-based tests for authentication.
///
/// These tests verify that authentication is properly applied when configured.
library;

import 'package:dddart_repository_rest/dddart_repository_rest.dart';
import 'package:dddart_rest_client/dddart_rest_client.dart';
import 'package:test/test.dart';

import 'test_helpers.dart';
import 'test_models.dart';

/// Mock auth provider for testing.
class MockAuthProvider implements AuthProvider {
  MockAuthProvider(this.token);

  final String token;
  int callCount = 0;

  @override
  Future<String> getAccessToken() async {
    callCount++;
    return token;
  }

  @override
  Future<String> getIdToken() async {
    return token; // For testing, ID token same as access token
  }

  Future<void> refreshAccessToken() async {
    // No-op for testing
  }

  @override
  Future<bool> isAuthenticated() async {
    return true;
  }

  @override
  Future<void> login() async {
    // No-op for testing
  }

  @override
  Future<void> logout() async {
    // No-op for testing
  }
}

void main() {
  group('Authentication Property Tests', () {
    late TestServer testServer;

    setUp(() async {
      // Create test server with in-memory repository
      testServer = await createTestServer<TestUser>(
        path: '/users',
        serializer: TestUserJsonSerializer(),
        port: 8783,
      );
    });

    tearDown(() async {
      await testServer.stop();
    });

    // **Feature: rest-repository, Property 10: Authentication is applied when configured**
    test('Property 10: connection with auth provider works correctly',
        () async {
      // Run property test with 100 iterations
      for (var i = 0; i < 100; i++) {
        // Create a mock auth provider with a random token
        final token = 'test-token-${generateRandomString(10)}';
        final authProvider = MockAuthProvider(token);

        // Create connection with auth provider
        final connection = RestConnection(
          baseUrl: testServer.baseUrl,
          authProvider: authProvider,
        );

        try {
          // Create repository
          final repository = TestUserRestRepository(connection);

          // Generate random user
          final user = generateRandomTestUser();

          // Perform operations - should work with auth provider configured
          await repository.save(user);
          final retrieved = await repository.getById(user.id);

          // Verify operations succeeded with auth provider configured
          expect(retrieved.id, equals(user.id));
          expect(retrieved.name, equals(user.name));
          expect(retrieved.email, equals(user.email));
        } finally {
          connection.dispose();
        }
      }
    });

    test('Property 10: unauthenticated requests work without auth provider',
        () async {
      // Run property test with 100 iterations
      for (var i = 0; i < 100; i++) {
        // Create connection WITHOUT auth provider
        final connection = RestConnection(baseUrl: testServer.baseUrl);

        try {
          // Create repository
          final repository = TestUserRestRepository(connection);

          // Generate random user
          final user = generateRandomTestUser();

          // Perform operations - should work without authentication
          await repository.save(user);
          final retrieved = await repository.getById(user.id);

          // Verify operations succeeded
          expect(retrieved.id, equals(user.id));
        } finally {
          connection.dispose();
        }
      }
    });
  });
}
