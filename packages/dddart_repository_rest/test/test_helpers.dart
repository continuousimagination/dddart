/// Test helpers and utilities for REST repository testing.
library;

import 'dart:async';
import 'dart:math';

import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_rest/dddart_rest.dart';

import 'test_models.dart';

/// Random number generator for test data.
final _random = Random();

/// Characters for generating random strings.
const _chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

/// Generates a random string of the specified length.
String generateRandomString(int length) {
  return List.generate(
    length,
    (index) => _chars[_random.nextInt(_chars.length)],
  ).join();
}

/// Generates a random email address.
String generateRandomEmail() {
  return '${generateRandomString(8)}@example.com';
}

/// Generates a random price between 1.00 and 999.99.
double generateRandomPrice() {
  return (_random.nextDouble() * 999 + 1).roundToDouble();
}

/// Generates a random balance between -1000.00 and 10000.00.
double generateRandomBalance() {
  return (_random.nextDouble() * 11000 - 1000).roundToDouble();
}

/// Generates a random order number.
String generateRandomOrderNumber() {
  return 'ORD-${_random.nextInt(999999).toString().padLeft(6, '0')}';
}

/// Generates a random customer ID.
String generateRandomCustomerId() {
  return UuidValue.generate().toString();
}

/// Generates a random test user.
TestUser generateRandomTestUser() {
  return TestUser(
    name: generateRandomString(10),
    email: generateRandomEmail(),
  );
}

/// Generates a random test product.
TestProduct generateRandomTestProduct() {
  return TestProduct(
    name: generateRandomString(15),
    price: generateRandomPrice(),
  );
}

/// Generates a random test order.
TestOrder generateRandomTestOrder() {
  return TestOrder(
    orderNumber: generateRandomOrderNumber(),
    customerId: generateRandomCustomerId(),
    total: generateRandomPrice(),
  );
}

/// Generates a random test account.
TestAccount generateRandomTestAccount() {
  return TestAccount(
    accountName: generateRandomString(12),
    accountType: ['checking', 'savings', 'investment'][_random.nextInt(3)],
    balance: generateRandomBalance(),
  );
}

/// Test server wrapper for managing HTTP server lifecycle.
class TestServer {
  /// Creates a test server wrapper.
  TestServer(this.server, this.baseUrl);

  /// The HTTP server instance.
  final HttpServer server;

  /// The base URL for the server.
  final String baseUrl;

  /// Stops the server.
  Future<void> stop() async {
    await server.stop();
  }
}

/// Creates a test REST API server for a specific aggregate type.
///
/// The server uses an in-memory repository and JSON serialization.
/// Returns a [TestServer] instance with the server and base URL.
///
/// Example:
/// ```dart
/// final testServer = await createTestServer<TestUser>(
///   path: '/users',
///   serializer: TestUserJsonSerializer(),
/// );
/// ```
Future<TestServer> createTestServer<T extends AggregateRoot>({
  required String path,
  required JsonSerializer<T> serializer,
  bool withAuth = false,
  int port = 8765, // Use a fixed test port
}) async {
  final repository = InMemoryRepository<T>();
  final server = HttpServer(port: port);

  // Register CRUD resource
  server.registerResource(
    CrudResource<T, void>(
      path: path,
      repository: repository,
      serializers: {'application/json': serializer},
    ),
  );

  await server.start();
  final baseUrl = 'http://localhost:$port';

  return TestServer(server, baseUrl);
}

/// Creates a test REST API server with multiple resources.
///
/// Useful for testing scenarios with multiple aggregate types.
Future<TestServer> createMultiResourceTestServer({
  required Map<String, CrudResource<AggregateRoot, dynamic>> resources,
  bool withAuth = false,
  int port = 8765, // Use a fixed test port
}) async {
  final server = HttpServer(port: port);

  // Register all resources
  for (final resource in resources.values) {
    server.registerResource(resource);
  }

  await server.start();
  final baseUrl = 'http://localhost:$port';

  return TestServer(server, baseUrl);
}

/// Helper for running a test with a REST API server.
///
/// Automatically starts the server before the test and stops it after.
///
/// Example:
/// ```dart
/// await withTestServer<TestUser>(
///   path: '/users',
///   serializer: TestUserJsonSerializer(),
///   (baseUrl) async {
///     final connection = RestConnection(baseUrl: baseUrl);
///     final repository = TestUserRestRepository(connection);
///     // ... test code
///   },
/// );
/// ```
Future<void> withTestServer<T extends AggregateRoot>({
  required String path,
  required JsonSerializer<T> serializer,
  required Future<void> Function(String baseUrl) testFn,
  bool withAuth = false,
}) async {
  final testServer = await createTestServer<T>(
    path: path,
    serializer: serializer,
    withAuth: withAuth,
  );

  try {
    await testFn(testServer.baseUrl);
  } finally {
    await testServer.stop();
  }
}

/// Helper for running a test with multiple REST API resources.
///
/// Automatically starts the server before the test and stops it after.
Future<void> withMultiResourceTestServer({
  required Map<String, CrudResource<AggregateRoot, dynamic>> resources,
  required Future<void> Function(String baseUrl) testFn,
  bool withAuth = false,
}) async {
  final testServer = await createMultiResourceTestServer(
    resources: resources,
    withAuth: withAuth,
  );

  try {
    await testFn(testServer.baseUrl);
  } finally {
    await testServer.stop();
  }
}
