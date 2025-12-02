/// Integration tests for custom REST repositories.
///
/// These tests verify:
/// 1. Custom query methods work end-to-end with real HTTP communication
/// 2. Protected members (_connection, _serializer, _resourcePath, _mapHttpException)
///    are accessible in subclasses
/// 3. Abstract base class generation works correctly
/// 4. Custom repository implementations can extend generated base classes
library;

import 'dart:convert';
import 'dart:io' as io;

import 'package:dddart/dddart.dart';
import 'package:dddart_repository_rest/dddart_repository_rest.dart';
import 'package:test/test.dart';

import 'test_helpers.dart';
import 'test_models.dart';

void main() {
  group('Custom Repository Integration Tests', () {
    late CustomTestServer testServer;
    late RestConnection connection;
    late TestOrderRestRepository orderRepository;

    setUp(() async {
      // Create test server with custom query endpoints
      testServer = await createCustomQueryTestServer();

      // Create REST connection
      connection = RestConnection(baseUrl: testServer.baseUrl);

      // Create custom repository instance
      orderRepository = TestOrderRestRepository(connection);
    });

    tearDown(() async {
      connection.dispose();
      await testServer.stop();
    });

    group('Custom Query Methods', () {
      test('findByCustomerId should return orders for a specific customer',
          () async {
        // Arrange - Create orders for different customers
        final customer1Id = generateRandomCustomerId();
        final customer2Id = generateRandomCustomerId();

        final order1 = TestOrder(
          orderNumber: generateRandomOrderNumber(),
          customerId: customer1Id,
          total: 100,
        );
        final order2 = TestOrder(
          orderNumber: generateRandomOrderNumber(),
          customerId: customer1Id,
          total: 200,
        );
        final order3 = TestOrder(
          orderNumber: generateRandomOrderNumber(),
          customerId: customer2Id,
          total: 300,
        );

        // Save all orders
        await orderRepository.save(order1);
        await orderRepository.save(order2);
        await orderRepository.save(order3);

        // Act - Find orders by customer1Id
        final customer1Orders =
            await orderRepository.findByCustomerId(customer1Id);

        // Assert
        expect(customer1Orders.length, equals(2));
        expect(
          customer1Orders.every((o) => o.customerId == customer1Id),
          isTrue,
        );
        expect(
          customer1Orders.map((o) => o.id).toSet(),
          containsAll([order1.id, order2.id]),
        );
      });

      test('findByCustomerId should return empty list when no orders found',
          () async {
        // Arrange
        final nonExistentCustomerId = generateRandomCustomerId();

        // Act
        final orders =
            await orderRepository.findByCustomerId(nonExistentCustomerId);

        // Assert
        expect(orders, isEmpty);
      });

      test('findByOrderNumber should return order when it exists', () async {
        // Arrange
        final order = TestOrder(
          orderNumber: 'ORD-123456',
          customerId: generateRandomCustomerId(),
          total: 150,
        );
        await orderRepository.save(order);

        // Act
        final found = await orderRepository.findByOrderNumber('ORD-123456');

        // Assert
        expect(found, isNotNull);
        expect(found!.id, equals(order.id));
        expect(found.orderNumber, equals('ORD-123456'));
        expect(found.customerId, equals(order.customerId));
        expect(found.total, equals(150.0));
      });

      test('findByOrderNumber should return null when order does not exist',
          () async {
        // Act
        final found = await orderRepository.findByOrderNumber('NON-EXISTENT');

        // Assert
        expect(found, isNull);
      });

      test('findByOrderNumber should handle multiple orders correctly',
          () async {
        // Arrange - Create multiple orders
        final order1 = TestOrder(
          orderNumber: 'ORD-111111',
          customerId: generateRandomCustomerId(),
          total: 100,
        );
        final order2 = TestOrder(
          orderNumber: 'ORD-222222',
          customerId: generateRandomCustomerId(),
          total: 200,
        );

        await orderRepository.save(order1);
        await orderRepository.save(order2);

        // Act - Find each order by its order number
        final found1 = await orderRepository.findByOrderNumber('ORD-111111');
        final found2 = await orderRepository.findByOrderNumber('ORD-222222');

        // Assert
        expect(found1, isNotNull);
        expect(found1!.id, equals(order1.id));
        expect(found2, isNotNull);
        expect(found2!.id, equals(order2.id));
      });
    });

    group('Protected Members Accessibility', () {
      test('custom repository can access _connection', () async {
        // This test verifies that the custom repository implementation
        // can access the protected _connection member from the base class.
        // The implementation in test_models_impl.dart uses _connection.httpClient
        // which proves accessibility.

        final order = generateRandomTestOrder();
        await orderRepository.save(order);

        // If _connection wasn't accessible, the save would fail to compile
        final retrieved = await orderRepository.getById(order.id);
        expect(retrieved.id, equals(order.id));
      });

      test('custom repository can access _serializer', () async {
        // This test verifies that the custom repository implementation
        // can access the protected _serializer member from the base class.
        // The implementation uses _serializer.fromJson() in custom methods.

        final order = generateRandomTestOrder();
        await orderRepository.save(order);

        // Custom method uses _serializer internally
        final found =
            await orderRepository.findByOrderNumber(order.orderNumber);

        // If _serializer wasn't accessible, findByOrderNumber would fail
        expect(found, isNotNull);
        expect(found!.id, equals(order.id));
      });

      test('custom repository can access _resourcePath', () async {
        // This test verifies that the custom repository implementation
        // can access the protected _resourcePath member from the base class.
        // The implementation uses _resourcePath in URL construction.

        final order = generateRandomTestOrder();
        await orderRepository.save(order);

        // Custom method uses _resourcePath in URL construction
        final orders = await orderRepository.findByCustomerId(order.customerId);

        // If _resourcePath wasn't accessible, the URL would be incorrect
        expect(orders, isNotEmpty);
        expect(orders.first.customerId, equals(order.customerId));
      });

      test('custom repository can access _mapHttpException', () async {
        // This test verifies that the custom repository implementation
        // can access the protected _mapHttpException helper method.
        // The implementation uses it for error mapping in custom methods.

        // Arrange - Try to find order with invalid customer ID that triggers 500
        const invalidCustomerId = 'TRIGGER_ERROR';

        // Act & Assert - The custom method should use _mapHttpException
        // to map the HTTP error to a RepositoryException
        expect(
          () => orderRepository.findByCustomerId(invalidCustomerId),
          throwsA(isA<RepositoryException>()),
        );
      });
    });

    group('Base CRUD Operations', () {
      test('custom repository should support basic save and retrieve',
          () async {
        // Arrange
        final order = generateRandomTestOrder();

        // Act
        await orderRepository.save(order);
        final retrieved = await orderRepository.getById(order.id);

        // Assert
        expect(retrieved.id, equals(order.id));
        expect(retrieved.orderNumber, equals(order.orderNumber));
        expect(retrieved.customerId, equals(order.customerId));
        expect(retrieved.total, equals(order.total));
      });

      test('custom repository should support delete', () async {
        // Arrange
        final order = generateRandomTestOrder();
        await orderRepository.save(order);

        // Act
        await orderRepository.deleteById(order.id);

        // Assert
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

      test('custom repository should handle not found errors', () async {
        // Arrange
        final nonExistentId = UuidValue.generate();

        // Act & Assert
        expect(
          () => orderRepository.getById(nonExistentId),
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

    group('Error Handling in Custom Methods', () {
      test('custom method should handle HTTP errors correctly', () async {
        // Arrange - Use a customer ID that triggers an error
        const errorTriggeringId = 'TRIGGER_ERROR';

        // Act & Assert
        expect(
          () => orderRepository.findByCustomerId(errorTriggeringId),
          throwsA(isA<RepositoryException>()),
        );
      });

      test('custom method should handle malformed responses', () async {
        // Arrange - Use a customer ID that returns malformed JSON
        const malformedId = 'MALFORMED_JSON';

        // Act & Assert
        expect(
          () => orderRepository.findByCustomerId(malformedId),
          throwsA(isA<RepositoryException>()),
        );
      });
    });
  });
}

/// Custom test server that supports query endpoints for testing.
class CustomTestServer {
  /// Creates a custom test server.
  CustomTestServer(this.server, this.baseUrl);

  /// The HTTP server instance.
  final io.HttpServer server;

  /// The base URL for the server.
  final String baseUrl;

  /// Stops the server.
  Future<void> stop() async {
    await server.close(force: true);
  }
}

/// Creates a custom test server with query endpoint support.
///
/// This server provides:
/// - Standard CRUD endpoints for orders
/// - Custom query endpoint: GET /orders?customerId=xxx
/// - Custom query endpoint: GET /orders?orderNumber=xxx
Future<CustomTestServer> createCustomQueryTestServer({
  int port = 8771,
}) async {
  // In-memory storage for orders
  final orders = <String, TestOrder>{};
  final serializer = TestOrderJsonSerializer();

  // Start server
  final server = await io.HttpServer.bind('localhost', port);

  server.listen((request) async {
    try {
      final path = request.uri.path;
      final method = request.method;

      // GET /orders/:id - Get order by ID
      if (method == 'GET' && path.startsWith('/orders/')) {
        final id = path.substring('/orders/'.length);
        final order = orders[id];

        if (order == null) {
          request.response
            ..statusCode = 404
            ..headers.contentType = io.ContentType.json
            ..write(json.encode({'error': 'Order not found'}));
        } else {
          request.response
            ..statusCode = 200
            ..headers.contentType = io.ContentType.json
            ..write(json.encode(serializer.toJson(order)));
        }
        await request.response.close();
        return;
      }

      // GET /orders - Get orders with optional query parameters
      if (method == 'GET' && path == '/orders') {
        final customerId = request.uri.queryParameters['customerId'];
        final orderNumber = request.uri.queryParameters['orderNumber'];

        // Handle error trigger for testing
        if (customerId == 'TRIGGER_ERROR') {
          request.response
            ..statusCode = 500
            ..headers.contentType = io.ContentType.json
            ..write(json.encode({'error': 'Internal server error'}));
          await request.response.close();
          return;
        }

        // Handle malformed JSON trigger for testing
        if (customerId == 'MALFORMED_JSON') {
          request.response
            ..statusCode = 200
            ..headers.contentType = io.ContentType.json
            ..write('This is not valid JSON');
          await request.response.close();
          return;
        }

        List<TestOrder> results;

        if (customerId != null) {
          // Filter by customer ID
          results = orders.values
              .where((order) => order.customerId == customerId)
              .toList();
        } else if (orderNumber != null) {
          // Filter by order number
          results = orders.values
              .where((order) => order.orderNumber == orderNumber)
              .toList();
        } else {
          // Return all orders
          results = orders.values.toList();
        }

        final jsonList = results.map(serializer.toJson).toList();
        request.response
          ..statusCode = 200
          ..headers.contentType = io.ContentType.json
          ..write(json.encode(jsonList));
        await request.response.close();
        return;
      }

      // PUT /orders/:id - Save/update order
      if (method == 'PUT' && path.startsWith('/orders/')) {
        final id = path.substring('/orders/'.length);
        final bodyBytes = await request.toList();
        final body = utf8.decode(bodyBytes.expand((x) => x).toList());
        final jsonData = json.decode(body) as Map<String, dynamic>;
        final order = serializer.fromJson(jsonData);

        orders[id] = order;

        request.response
          ..statusCode = 200
          ..headers.contentType = io.ContentType.json
          ..write(json.encode(serializer.toJson(order)));
        await request.response.close();
        return;
      }

      // DELETE /orders/:id - Delete order
      if (method == 'DELETE' && path.startsWith('/orders/')) {
        final id = path.substring('/orders/'.length);
        final order = orders.remove(id);

        if (order == null) {
          request.response
            ..statusCode = 404
            ..headers.contentType = io.ContentType.json
            ..write(json.encode({'error': 'Order not found'}));
        } else {
          request.response.statusCode = 204; // No content
        }
        await request.response.close();
        return;
      }

      // Not found
      request.response
        ..statusCode = 404
        ..write('Not Found');
      await request.response.close();
    } catch (e, stackTrace) {
      print('Server error: $e');
      print('Stack trace: $stackTrace');
      request.response
        ..statusCode = 500
        ..write('Internal Server Error: $e');
      await request.response.close();
    }
  });

  final baseUrl = 'http://localhost:$port';
  return CustomTestServer(server, baseUrl);
}
