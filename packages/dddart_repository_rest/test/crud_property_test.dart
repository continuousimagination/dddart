/// Property-based tests for CRUD operations.
///
/// These tests verify universal properties that should hold across all inputs.
library;

import 'package:dddart/dddart.dart';
import 'package:dddart_repository_rest/dddart_repository_rest.dart';
import 'package:test/test.dart';

import 'test_helpers.dart';
import 'test_models.dart';

void main() {
  group('CRUD Property Tests', () {
    late TestServer testServer;
    late RestConnection connection;
    late TestUserRestRepository userRepository;

    setUp(() async {
      // Create test server with in-memory repository
      testServer = await createTestServer<TestUser>(
        path: '/users',
        serializer: TestUserJsonSerializer(),
        port: 8780,
      );

      // Create REST connection pointing to test server
      connection = RestConnection(baseUrl: testServer.baseUrl);

      // Create repository instance using test connection
      userRepository = TestUserRestRepository(connection);
    });

    tearDown(() async {
      // Stop the test server and clean up
      connection.dispose();
      await testServer.stop();
    });

    // **Feature: rest-repository, Property 5: CRUD operations round-trip correctly**
    test('Property 5: save then getById returns equivalent aggregate',
        () async {
      // Run property test with 100 iterations
      for (var i = 0; i < 100; i++) {
        // Generate random user
        final user = generateRandomTestUser();

        // Save the user
        await userRepository.save(user);

        // Retrieve the user
        final retrieved = await userRepository.getById(user.id);

        // Verify equivalence
        expect(retrieved.id, equals(user.id));
        expect(retrieved.name, equals(user.name));
        expect(retrieved.email, equals(user.email));
        expect(retrieved.createdAt, equals(user.createdAt));
        expect(retrieved.updatedAt, equals(user.updatedAt));
      }
    });

    // **Feature: rest-repository, Property 6: Delete removes aggregates**
    test('Property 6: deleteById then getById throws notFound', () async {
      // Run property test with 100 iterations
      for (var i = 0; i < 100; i++) {
        // Generate random user
        final user = generateRandomTestUser();

        // Save the user
        await userRepository.save(user);

        // Delete the user
        await userRepository.deleteById(user.id);

        // Verify getById throws notFound
        expect(
          () => userRepository.getById(user.id),
          throwsA(
            isA<RepositoryException>().having(
              (e) => e.type,
              'type',
              RepositoryExceptionType.notFound,
            ),
          ),
        );
      }
    });

    // **Feature: rest-repository, Property 7: Serialization uses dddart_json serializers**
    test('Property 7: serialization uses dddart_json serializers', () async {
      // Run property test with 100 iterations
      for (var i = 0; i < 100; i++) {
        // Generate random user
        final user = generateRandomTestUser();

        // Save the user (this uses serializer.toJson internally)
        await userRepository.save(user);

        // Retrieve the user (this uses serializer.fromJson internally)
        final retrieved = await userRepository.getById(user.id);

        // Verify that serialization/deserialization worked correctly
        // by checking that all fields match
        expect(retrieved.id, equals(user.id));
        expect(retrieved.name, equals(user.name));
        expect(retrieved.email, equals(user.email));
        expect(retrieved.createdAt, equals(user.createdAt));
        expect(retrieved.updatedAt, equals(user.updatedAt));
      }
    });
  });
}
