import 'dart:convert';
import 'dart:io' as io;

import 'package:dddart/dddart.dart';
import 'package:dddart_rest/src/crud_resource.dart';
import 'package:dddart_rest/src/http_server.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:test/test.dart';

// Test aggregate root
class TestUser extends AggregateRoot {
  TestUser({
    required this.name,
    required this.email,
    super.id,
    super.createdAt,
    super.updatedAt,
  });

  final String name;
  final String email;
}

// Test serializer
class TestUserSerializer implements Serializer<TestUser> {
  @override
  String serialize(TestUser user, [dynamic config]) {
    return jsonEncode({
      'id': user.id.toString(),
      'name': user.name,
      'email': user.email,
      'createdAt': user.createdAt.toIso8601String(),
      'updatedAt': user.updatedAt.toIso8601String(),
    });
  }

  @override
  TestUser deserialize(String data, [dynamic config]) {
    final json = jsonDecode(data);
    return TestUser(
      id: UuidValue.fromString(json['id']),
      name: json['name'],
      email: json['email'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }
}

// Test product aggregate for multi-resource testing
class TestProduct extends AggregateRoot {
  TestProduct({
    required this.name,
    required this.price,
    super.id,
    super.createdAt,
    super.updatedAt,
  });

  final String name;
  final double price;
}

// Test product serializer
class TestProductSerializer implements Serializer<TestProduct> {
  @override
  String serialize(TestProduct product, [dynamic config]) {
    return jsonEncode({
      'id': product.id.toString(),
      'name': product.name,
      'price': product.price,
      'createdAt': product.createdAt.toIso8601String(),
      'updatedAt': product.updatedAt.toIso8601String(),
    });
  }

  @override
  TestProduct deserialize(String data, [dynamic config]) {
    final json = jsonDecode(data);
    return TestProduct(
      id: UuidValue.fromString(json['id']),
      name: json['name'],
      price: json['price'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }
}

void main() {
  group('HttpServer - Resource Registration', () {
    test('registerResource() adds resource to internal list', () async {
      // Arrange
      final server = HttpServer(port: 8081);
      final repository = InMemoryRepository<TestUser>();
      final serializer = TestUserSerializer();
      final resource = CrudResource<TestUser, dynamic>(
        path: '/users',
        repository: repository,
        serializers: {'application/json': serializer},
      );

      // Act
      server.registerResource(resource);

      // Assert - verify by starting server and checking routes work
      await server.start();

      // Make a test request to verify the resource is registered
      final client = io.HttpClient();
      try {
        final request = await client.get('localhost', 8081, '/users');
        final response = await request.close();

        // Should get 200 (empty list) not 404 (route not found)
        expect(response.statusCode, equals(200));
      } finally {
        client.close();
        await server.stop();
      }
    });

    test('multiple resources can be registered', () async {
      // Arrange
      final server = HttpServer(port: 8082);

      final userRepository = InMemoryRepository<TestUser>();
      final userSerializer = TestUserSerializer();
      final userResource = CrudResource<TestUser, dynamic>(
        path: '/users',
        repository: userRepository,
        serializers: {'application/json': userSerializer},
      );

      final productRepository = InMemoryRepository<TestProduct>();
      final productSerializer = TestProductSerializer();
      final productResource = CrudResource<TestProduct, dynamic>(
        path: '/products',
        repository: productRepository,
        serializers: {'application/json': productSerializer},
      );

      // Act
      server.registerResource(userResource);
      server.registerResource(productResource);
      await server.start();

      // Assert - verify both resources are accessible
      final client = io.HttpClient();
      try {
        // Test users endpoint
        final usersRequest = await client.get('localhost', 8082, '/users');
        final usersResponse = await usersRequest.close();
        expect(usersResponse.statusCode, equals(200));

        // Test products endpoint
        final productsRequest =
            await client.get('localhost', 8082, '/products');
        final productsResponse = await productsRequest.close();
        expect(productsResponse.statusCode, equals(200));
      } finally {
        client.close();
        await server.stop();
      }
    });
  });

  group('HttpServer - Server Lifecycle', () {
    test('start() creates router and starts shelf server on configured port',
        () async {
      // Arrange
      final server = HttpServer(port: 8083);
      final repository = InMemoryRepository<TestUser>();
      final serializer = TestUserSerializer();
      final resource = CrudResource<TestUser, dynamic>(
        path: '/users',
        repository: repository,
        serializers: {'application/json': serializer},
      );
      server.registerResource(resource);

      // Act
      await server.start();

      // Assert - verify server is running on the configured port
      final client = io.HttpClient();
      try {
        final request = await client.get('localhost', 8083, '/users');
        final response = await request.close();
        expect(response.statusCode, equals(200));
      } finally {
        client.close();
        await server.stop();
      }
    });

    test('stop() closes shelf server cleanly', () async {
      // Arrange
      final server = HttpServer(port: 8084);
      final repository = InMemoryRepository<TestUser>();
      final serializer = TestUserSerializer();
      final resource = CrudResource<TestUser, dynamic>(
        path: '/users',
        repository: repository,
        serializers: {'application/json': serializer},
      );
      server.registerResource(resource);
      await server.start();

      // Act
      await server.stop();

      // Assert - verify server is no longer accepting connections
      // Poll until the port is actually closed (with timeout)
      final client = io.HttpClient();
      var connectionRefused = false;
      const maxAttempts = 50; // 5 seconds max (50 * 100ms)

      try {
        for (var i = 0; i < maxAttempts; i++) {
          try {
            final request = await client.get('localhost', 8084, '/users');
            await request.close();
            // Connection succeeded, wait a bit and try again
            await Future<void>.delayed(const Duration(milliseconds: 100));
          } on io.SocketException {
            // Connection refused - port is closed!
            connectionRefused = true;
            break;
          }
        }

        expect(
          connectionRefused,
          isTrue,
          reason: 'Server should refuse connections after stop()',
        );
      } finally {
        client.close();
      }
    });

    test('starting already-running server throws StateError', () async {
      // Arrange
      final server = HttpServer(port: 8085);
      final repository = InMemoryRepository<TestUser>();
      final serializer = TestUserSerializer();
      final resource = CrudResource<TestUser, dynamic>(
        path: '/users',
        repository: repository,
        serializers: {'application/json': serializer},
      );
      server.registerResource(resource);
      await server.start();

      // Act & Assert
      try {
        await expectLater(
          server.start(),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('already running'),
            ),
          ),
        );
      } finally {
        await server.stop();
      }
    });

    test('stopping non-running server throws StateError', () async {
      // Arrange
      final server = HttpServer(port: 8086);

      // Act & Assert
      await expectLater(
        server.stop(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('not running'),
          ),
        ),
      );
    });
  });

  group('HttpServer - Route Registration', () {
    test('routes are created for all CRUD operations', () async {
      // Arrange
      final server = HttpServer(port: 8087);
      final repository = InMemoryRepository<TestUser>();
      final serializer = TestUserSerializer();

      // Create a test user
      final testUser = TestUser(
        id: UuidValue.fromString('123e4567-e89b-12d3-a456-426614174000'),
        name: 'Test User',
        email: 'test@example.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repository.save(testUser);

      final resource = CrudResource<TestUser, dynamic>(
        path: '/users',
        repository: repository,
        serializers: {'application/json': serializer},
      );
      server.registerResource(resource);
      await server.start();

      final client = io.HttpClient();
      try {
        // Test GET collection
        final getCollectionRequest =
            await client.get('localhost', 8087, '/users');
        final getCollectionResponse = await getCollectionRequest.close();
        expect(getCollectionResponse.statusCode, equals(200));

        // Test GET by ID
        final getByIdRequest =
            await client.get('localhost', 8087, '/users/${testUser.id}');
        final getByIdResponse = await getByIdRequest.close();
        expect(getByIdResponse.statusCode, equals(200));

        // Test POST
        final postRequest = await client.post('localhost', 8087, '/users');
        postRequest.headers.set('Content-Type', 'application/json');
        final newUser = TestUser(
          id: UuidValue.fromString('999e4567-e89b-12d3-a456-426614174999'),
          name: 'New User',
          email: 'new@example.com',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        postRequest.write(serializer.serialize(newUser));
        final postResponse = await postRequest.close();
        expect(postResponse.statusCode, equals(201));

        // Test PUT
        final putRequest =
            await client.put('localhost', 8087, '/users/${testUser.id}');
        putRequest.headers.set('Content-Type', 'application/json');
        final updatedUser = TestUser(
          id: testUser.id,
          name: 'Updated User',
          email: 'updated@example.com',
          createdAt: testUser.createdAt,
          updatedAt: DateTime.now(),
        );
        putRequest.write(serializer.serialize(updatedUser));
        final putResponse = await putRequest.close();
        expect(putResponse.statusCode, equals(200));

        // Test DELETE
        final deleteRequest =
            await client.delete('localhost', 8087, '/users/${testUser.id}');
        final deleteResponse = await deleteRequest.close();
        expect(deleteResponse.statusCode, equals(204));
      } finally {
        client.close();
        await server.stop();
      }
    });

    test('routes for multiple resources do not conflict', () async {
      // Arrange
      final server = HttpServer(port: 8088);

      // Set up users resource
      final userRepository = InMemoryRepository<TestUser>();
      final userSerializer = TestUserSerializer();
      final testUser = TestUser(
        id: UuidValue.fromString('111e4567-e89b-12d3-a456-426614174111'),
        name: 'Test User',
        email: 'user@example.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await userRepository.save(testUser);

      final userResource = CrudResource<TestUser, dynamic>(
        path: '/users',
        repository: userRepository,
        serializers: {'application/json': userSerializer},
      );

      // Set up products resource
      final productRepository = InMemoryRepository<TestProduct>();
      final productSerializer = TestProductSerializer();
      final testProduct = TestProduct(
        id: UuidValue.fromString('222e4567-e89b-12d3-a456-426614174222'),
        name: 'Test Product',
        price: 99.99,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await productRepository.save(testProduct);

      final productResource = CrudResource<TestProduct, dynamic>(
        path: '/products',
        repository: productRepository,
        serializers: {'application/json': productSerializer},
      );

      server.registerResource(userResource);
      server.registerResource(productResource);
      await server.start();

      final client = io.HttpClient();
      try {
        // Test users routes
        final usersGetRequest = await client.get('localhost', 8088, '/users');
        final usersGetResponse = await usersGetRequest.close();
        expect(usersGetResponse.statusCode, equals(200));

        final userGetByIdRequest =
            await client.get('localhost', 8088, '/users/${testUser.id}');
        final userGetByIdResponse = await userGetByIdRequest.close();
        expect(userGetByIdResponse.statusCode, equals(200));

        // Test products routes
        final productsGetRequest =
            await client.get('localhost', 8088, '/products');
        final productsGetResponse = await productsGetRequest.close();
        expect(productsGetResponse.statusCode, equals(200));

        final productGetByIdRequest =
            await client.get('localhost', 8088, '/products/${testProduct.id}');
        final productGetByIdResponse = await productGetByIdRequest.close();
        expect(productGetByIdResponse.statusCode, equals(200));

        // Verify responses contain correct data
        final userBody =
            await userGetByIdResponse.transform(utf8.decoder).join();
        final userData = jsonDecode(userBody);
        expect(userData['name'], equals('Test User'));

        final productBody =
            await productGetByIdResponse.transform(utf8.decoder).join();
        final productData = jsonDecode(productBody);
        expect(productData['name'], equals('Test Product'));
      } finally {
        client.close();
        await server.stop();
      }
    });

    test('route patterns match expected format', () async {
      // Arrange
      final server = HttpServer(port: 8089);
      final repository = InMemoryRepository<TestUser>();
      final serializer = TestUserSerializer();

      final testUser = TestUser(
        id: UuidValue.fromString('123e4567-e89b-12d3-a456-426614174000'),
        name: 'Test User',
        email: 'test@example.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repository.save(testUser);

      final resource = CrudResource<TestUser, dynamic>(
        path: '/users',
        repository: repository,
        serializers: {'application/json': serializer},
      );
      server.registerResource(resource);
      await server.start();

      final client = io.HttpClient();
      try {
        // Verify collection endpoint pattern: /resource
        final collectionRequest = await client.get('localhost', 8089, '/users');
        final collectionResponse = await collectionRequest.close();
        expect(collectionResponse.statusCode, equals(200));

        // Verify item endpoint pattern: /resource/:id
        final itemRequest =
            await client.get('localhost', 8089, '/users/${testUser.id}');
        final itemResponse = await itemRequest.close();
        expect(itemResponse.statusCode, equals(200));

        // Verify invalid patterns return 404
        final invalidRequest =
            await client.get('localhost', 8089, '/users/invalid/extra/path');
        final invalidResponse = await invalidRequest.close();
        expect(invalidResponse.statusCode, equals(404));
      } finally {
        client.close();
        await server.stop();
      }
    });
  });
}
