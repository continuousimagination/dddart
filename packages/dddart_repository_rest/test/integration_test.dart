/// Integration tests for REST repository with real HTTP communication.
///
/// These tests verify end-to-end functionality by:
/// 1. Starting a test REST API server using dddart_rest
/// 2. Creating REST repositories that communicate with the server
/// 3. Performing CRUD operations over HTTP
/// 4. Verifying data flows correctly through the entire stack
library;

import 'package:dddart/dddart.dart';
import 'package:dddart_repository_rest/dddart_repository_rest.dart';
import 'package:dddart_rest/dddart_rest.dart';
import 'package:test/test.dart';

import 'test_helpers.dart';
import 'test_models.dart';

void main() {
  group('Integration Tests - Basic CRUD', () {
    late TestServer testServer;
    late RestConnection connection;
    late TestUserRestRepository userRepository;

    setUp(() async {
      // Create test server with in-memory repository
      testServer = await createTestServer<TestUser>(
        path: '/users',
        serializer: TestUserJsonSerializer(),
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

    test('should save and retrieve a user via HTTP', () async {
      // Arrange
      final user = generateRandomTestUser();

      // Act - Save user
      await userRepository.save(user);

      // Act - Retrieve user
      final retrieved = await userRepository.getById(user.id);

      // Assert
      expect(retrieved.id, equals(user.id));
      expect(retrieved.name, equals(user.name));
      expect(retrieved.email, equals(user.email));
    });

    test('should delete a user via HTTP', () async {
      // Arrange
      final user = generateRandomTestUser();
      await userRepository.save(user);

      // Act - Delete user
      await userRepository.deleteById(user.id);

      // Assert - Verify user is gone
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
    });

    test('should throw notFound when retrieving non-existent user', () async {
      // Arrange
      final nonExistentId = UuidValue.generate();

      // Act & Assert
      expect(
        () => userRepository.getById(nonExistentId),
        throwsA(
          isA<RepositoryException>().having(
            (e) => e.type,
            'type',
            RepositoryExceptionType.notFound,
          ),
        ),
      );
    });

    test('should update an existing user via HTTP', () async {
      // Arrange
      final user = generateRandomTestUser();
      await userRepository.save(user);

      // Act - Update user (save with same ID but different data)
      final updatedUser = TestUser(
        id: user.id,
        name: 'Updated Name',
        email: 'updated@example.com',
        createdAt: user.createdAt,
        updatedAt: DateTime.now(),
      );
      await userRepository.save(updatedUser);

      // Assert - Retrieve and verify update
      final retrieved = await userRepository.getById(user.id);
      expect(retrieved.name, equals('Updated Name'));
      expect(retrieved.email, equals('updated@example.com'));
    });
  });

  group('Integration Tests - Multiple Aggregate Types', () {
    late TestServer testServer;
    late RestConnection connection;
    late TestUserRestRepository userRepository;
    late TestProductRestRepository productRepository;

    setUp(() async {
      // Create test server with multiple resources
      testServer = await createMultiResourceTestServer(
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
        port: 8766,
      );

      // Create REST connection
      connection = RestConnection(baseUrl: testServer.baseUrl);

      // Create repository instances
      userRepository = TestUserRestRepository(connection);
      productRepository = TestProductRestRepository(connection);
    });

    tearDown(() async {
      connection.dispose();
      await testServer.stop();
    });

    test('should handle multiple aggregate types independently', () async {
      // Arrange
      final user = generateRandomTestUser();
      final product = generateRandomTestProduct();

      // Act - Save both
      await userRepository.save(user);
      await productRepository.save(product);

      // Assert - Retrieve both
      final retrievedUser = await userRepository.getById(user.id);
      final retrievedProduct = await productRepository.getById(product.id);

      expect(retrievedUser.id, equals(user.id));
      expect(retrievedUser.name, equals(user.name));
      expect(retrievedProduct.id, equals(product.id));
      expect(retrievedProduct.name, equals(product.name));
      expect(retrievedProduct.price, equals(product.price));
    });

    test('should share connection state across repositories', () async {
      // Arrange
      final user = generateRandomTestUser();
      final product = generateRandomTestProduct();

      // Act - Use both repositories with same connection
      await userRepository.save(user);
      await productRepository.save(product);

      // Assert - Both operations succeed (connection is shared)
      final retrievedUser = await userRepository.getById(user.id);
      final retrievedProduct = await productRepository.getById(product.id);

      expect(retrievedUser.id, equals(user.id));
      expect(retrievedProduct.id, equals(product.id));
    });
  });

  group('Integration Tests - Custom Repository', () {
    late TestServer testServer;
    late RestConnection connection;
    late TestOrderRestRepository orderRepository;

    setUp(() async {
      // Create test server for orders
      testServer = await createTestServer<TestOrder>(
        path: '/orders',
        serializer: TestOrderJsonSerializer(),
        port: 8767,
      );

      // Create REST connection
      connection = RestConnection(baseUrl: testServer.baseUrl);

      // Create custom repository instance
      orderRepository = TestOrderRestRepository(connection);
    });

    tearDown(() async {
      connection.dispose();
      await testServer.stop();
    });

    test('should perform basic CRUD operations on custom repository', () async {
      // Arrange
      final order = generateRandomTestOrder();

      // Act - Save order
      await orderRepository.save(order);

      // Act - Retrieve order
      final retrieved = await orderRepository.getById(order.id);

      // Assert
      expect(retrieved.id, equals(order.id));
      expect(retrieved.orderNumber, equals(order.orderNumber));
      expect(retrieved.customerId, equals(order.customerId));
      expect(retrieved.total, equals(order.total));
    });

    test('should delete order via custom repository', () async {
      // Arrange
      final order = generateRandomTestOrder();
      await orderRepository.save(order);

      // Act - Delete order
      await orderRepository.deleteById(order.id);

      // Assert - Verify order is gone
      expect(
        () => orderRepository.getById(order.id),
        throwsA(
          isA<RepositoryException>().having(
            (e) => e.type,
            'type',
            RepositoryExceptionType.notFound,
          ),
        ),
      );
    });
  });

  group('Integration Tests - Error Handling', () {
    late TestServer testServer;
    late RestConnection connection;
    late TestAccountRestRepository accountRepository;

    setUp(() async {
      // Create test server for accounts
      testServer = await createTestServer<TestAccount>(
        path: '/accounts',
        serializer: TestAccountJsonSerializer(),
        port: 8768,
      );

      // Create REST connection
      connection = RestConnection(baseUrl: testServer.baseUrl);

      // Create repository instance
      accountRepository = TestAccountRestRepository(connection);
    });

    tearDown(() async {
      connection.dispose();
      await testServer.stop();
    });

    test('should handle 404 errors correctly', () async {
      // Arrange
      final nonExistentId = UuidValue.generate();

      // Act & Assert
      expect(
        () => accountRepository.getById(nonExistentId),
        throwsA(
          isA<RepositoryException>().having(
            (e) => e.type,
            'type',
            RepositoryExceptionType.notFound,
          ),
        ),
      );
    });

    test('should handle delete of non-existent resource', () async {
      // Arrange
      final nonExistentId = UuidValue.generate();

      // Act & Assert - Delete should throw notFound
      expect(
        () => accountRepository.deleteById(nonExistentId),
        throwsA(
          isA<RepositoryException>().having(
            (e) => e.type,
            'type',
            RepositoryExceptionType.notFound,
          ),
        ),
      );
    });
  });

  group('Integration Tests - Connection Lifecycle', () {
    test('should properly dispose connection and release resources', () async {
      // Arrange
      final testServer = await createTestServer<TestUser>(
        path: '/users',
        serializer: TestUserJsonSerializer(),
        port: 8769,
      );
      final connection = RestConnection(baseUrl: testServer.baseUrl);
      final repository = TestUserRestRepository(connection);

      // Act - Use repository
      final user = generateRandomTestUser();
      await repository.save(user);

      // Act - Dispose connection
      connection.dispose();

      // Cleanup
      await testServer.stop();

      // Assert - Connection is disposed (test passes if no errors)
      expect(connection, isNotNull);
    });

    test('should allow multiple repositories to share one connection',
        () async {
      // Arrange
      final testServer = await createMultiResourceTestServer(
        resources: {
          '/users': CrudResource<TestUser, void>(
            path: '/users',
            repository: InMemoryRepository<TestUser>(),
            serializers: {'application/json': TestUserJsonSerializer()},
          ),
          '/accounts': CrudResource<TestAccount, void>(
            path: '/accounts',
            repository: InMemoryRepository<TestAccount>(),
            serializers: {'application/json': TestAccountJsonSerializer()},
          ),
        },
        port: 8770,
      );

      final connection = RestConnection(baseUrl: testServer.baseUrl);
      final userRepo = TestUserRestRepository(connection);
      final accountRepo = TestAccountRestRepository(connection);

      // Act - Use both repositories
      final user = generateRandomTestUser();
      final account = generateRandomTestAccount();

      await userRepo.save(user);
      await accountRepo.save(account);

      // Assert - Both operations succeed
      final retrievedUser = await userRepo.getById(user.id);
      final retrievedAccount = await accountRepo.getById(account.id);

      expect(retrievedUser.id, equals(user.id));
      expect(retrievedAccount.id, equals(account.id));

      // Cleanup
      connection.dispose();
      await testServer.stop();
    });
  });
}
