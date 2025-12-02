/// Property-based tests for connection configuration and sharing.
///
/// These tests verify universal properties related to REST connections.
library;

import 'package:dddart/dddart.dart';
import 'package:dddart_repository_rest/dddart_repository_rest.dart';
import 'package:dddart_rest/dddart_rest.dart';
import 'package:test/test.dart';

import 'test_helpers.dart';
import 'test_models.dart';

void main() {
  group('Connection Property Tests', () {
    late TestServer testServer;
    late RestConnection connection;

    setUp(() async {
      // Create test server with in-memory repository
      testServer = await createTestServer<TestUser>(
        path: '/users',
        serializer: TestUserJsonSerializer(),
        port: 8781,
      );

      // Create REST connection pointing to test server
      connection = RestConnection(baseUrl: testServer.baseUrl);
    });

    tearDown(() async {
      // Stop the test server and clean up
      connection.dispose();
      await testServer.stop();
    });

    // **Feature: rest-repository, Property 9: Connection configuration is used consistently**
    test('Property 9: connection base URL is used in all requests', () async {
      // Run property test with 100 iterations
      for (var i = 0; i < 100; i++) {
        // Generate random user
        final user = generateRandomTestUser();

        // Create repository with the connection
        final repository = TestUserRestRepository(connection);

        // Perform operations - all should use the configured base URL
        await repository.save(user);
        final retrieved = await repository.getById(user.id);
        await repository.deleteById(user.id);

        // Verify the operations worked (which means the base URL was used correctly)
        expect(retrieved.id, equals(user.id));
      }
    });

    // **Feature: rest-repository, Property 11: Multiple repositories share connection state**
    test('Property 11: multiple repositories share same connection', () async {
      // Create test server with multiple resources
      final multiServer = await createMultiResourceTestServer(
        resources: {
          '/users': CrudResource<TestUser, void>(
            path: '/users',
            repository: InMemoryRepository<TestUser>(),
            serializers: {'application/json': TestUserJsonSerializer()},
          ),
          '/products': CrudResource<TestProduct, void>(
            path: '/products',
            repository: InMemoryRepository<TestProduct>(),
            serializers: {'application/json': TestProductJsonSerializer()},
          ),
        },
        port: 8782,
      );

      final sharedConnection = RestConnection(baseUrl: multiServer.baseUrl);

      try {
        // Run property test with 100 iterations
        for (var i = 0; i < 100; i++) {
          // Create multiple repositories with the same connection
          final userRepo = TestUserRestRepository(sharedConnection);
          final productRepo = TestProductRestRepository(sharedConnection);

          // Generate random data
          final user = generateRandomTestUser();
          final product = generateRandomTestProduct();

          // Use both repositories
          await userRepo.save(user);
          await productRepo.save(product);

          // Retrieve from both
          final retrievedUser = await userRepo.getById(user.id);
          final retrievedProduct = await productRepo.getById(product.id);

          // Verify both operations worked (connection was shared correctly)
          expect(retrievedUser.id, equals(user.id));
          expect(retrievedProduct.id, equals(product.id));
        }
      } finally {
        sharedConnection.dispose();
        await multiServer.stop();
      }
    });

    // **Feature: rest-repository, Property 14: Integration test round-trip preserves data**
    test('Property 14: integration round-trip preserves all data', () async {
      // Run property test with 100 iterations
      for (var i = 0; i < 100; i++) {
        // Generate random user
        final user = generateRandomTestUser();

        // Create repository
        final repository = TestUserRestRepository(connection);

        // Save to REST repository → HTTP → in-memory repository
        await repository.save(user);

        // Retrieve from in-memory repository → HTTP → REST repository
        final retrieved = await repository.getById(user.id);

        // Verify all data is preserved through the round-trip
        expect(retrieved.id, equals(user.id));
        expect(retrieved.name, equals(user.name));
        expect(retrieved.email, equals(user.email));
        expect(retrieved.createdAt, equals(user.createdAt));
        expect(retrieved.updatedAt, equals(user.updatedAt));
      }
    });
  });
}
