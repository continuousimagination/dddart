import 'dart:convert';
import 'dart:io' as io;
import 'package:test/test.dart';
import 'package:shelf/shelf.dart';
import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_http/dddart_http.dart';

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

// Alternative serializer for content negotiation tests
class TestUserYamlSerializer implements Serializer<TestUser> {
  @override
  String serialize(TestUser user, [dynamic config]) {
    return 'name: ${user.name}\n'
        'email: ${user.email}\n'
        'id: ${user.id}\n'
        'createdAt: ${user.createdAt.toIso8601String()}\n'
        'updatedAt: ${user.updatedAt.toIso8601String()}';
  }

  @override
  TestUser deserialize(String data, [dynamic config]) {
    final lines = data.split('\n');
    final map = <String, String>{};
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      final parts = line.split(': ');
      if (parts.length == 2) {
        map[parts[0].trim()] = parts[1].trim();
      }
    }
    return TestUser(
      id: UuidValue.fromString(map['id']!),
      name: map['name']!,
      email: map['email']!,
      createdAt: DateTime.parse(map['createdAt']!),
      updatedAt: DateTime.parse(map['updatedAt']!),
    );
  }
}

// Custom exception for testing
class CustomDomainException implements Exception {
  CustomDomainException(this.message);
  final String message;

  @override
  String toString() => message;
}

// Custom repository that can throw custom exceptions
class TestRepository extends InMemoryRepository<TestUser> {
  bool shouldThrowCustomException = false;

  @override
  Future<TestUser> getById(UuidValue id) async {
    if (shouldThrowCustomException) {
      throw CustomDomainException('Custom exception triggered');
    }
    return super.getById(id);
  }
}

// Helper to make HTTP requests
Future<HttpResponse> makeRequest({
  required String method,
  required String path,
  Map<String, String>? headers,
  String? body,
  int port = 8080,
}) async {
  final client = io.HttpClient();
  try {
    final request = await client.openUrl(method, Uri.parse('http://localhost:$port$path'));

    // Add headers
    if (headers != null) {
      headers.forEach((key, value) {
        request.headers.set(key, value);
      });
    }

    // Add body
    if (body != null) {
      request.write(body);
    }

    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();

    return HttpResponse(
      statusCode: response.statusCode,
      headers: response.headers,
      body: responseBody,
    );
  } finally {
    client.close();
  }
}

class HttpResponse {
  HttpResponse({
    required this.statusCode,
    required this.headers,
    required this.body,
  });

  final int statusCode;
  final io.HttpHeaders headers;
  final String body;

  String? header(String name) {
    return headers.value(name);
  }
}

void main() {
  group('Integration Tests - Complete CRUD Lifecycle', () {
    late HttpServer server;
    late InMemoryRepository<TestUser> repository;
    late TestUserSerializer serializer;
    const port = 8081;

    setUp(() async {
      repository = InMemoryRepository<TestUser>();
      serializer = TestUserSerializer();
      server = HttpServer(port: port);

      server.registerResource(
        CrudResource<TestUser>(
          path: '/users',
          repository: repository,
          serializers: {
            'application/json': serializer,
          },
          defaultSkip: 0,
          defaultTake: 50,
          maxTake: 100,
        ),
      );

      await server.start();
    });

    tearDown(() async {
      await server.stop();
    });

    test('complete CRUD lifecycle', () async {
      // Create aggregate via POST
      final createUser = TestUser(
        id: UuidValue.generate(),
        name: 'Integration Test User',
        email: 'integration@example.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final createBody = serializer.serialize(createUser);
      final createResponse = await makeRequest(
        method: 'POST',
        path: '/users',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: createBody,
        port: port,
      );

      expect(createResponse.statusCode, equals(201));
      expect(createResponse.header('content-type'), equals('application/json'));

      final createdUser = jsonDecode(createResponse.body);
      final userId = createdUser['id'];
      expect(createdUser['name'], equals('Integration Test User'));
      expect(createdUser['email'], equals('integration@example.com'));

      // Retrieve aggregate via GET by ID
      final getResponse = await makeRequest(
        method: 'GET',
        path: '/users/$userId',
        headers: {'Accept': 'application/json'},
        port: port,
      );

      expect(getResponse.statusCode, equals(200));
      expect(getResponse.header('content-type'), equals('application/json'));

      final retrievedUser = jsonDecode(getResponse.body);
      expect(retrievedUser['id'], equals(userId));
      expect(retrievedUser['name'], equals('Integration Test User'));

      // Update aggregate via PUT
      final updateUser = TestUser(
        id: UuidValue.fromString(userId),
        name: 'Updated User',
        email: 'updated@example.com',
        createdAt: DateTime.parse(createdUser['createdAt']),
        updatedAt: DateTime.now(),
      );

      final updateBody = serializer.serialize(updateUser);
      final updateResponse = await makeRequest(
        method: 'PUT',
        path: '/users/$userId',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: updateBody,
        port: port,
      );

      expect(updateResponse.statusCode, equals(200));
      expect(updateResponse.header('content-type'), equals('application/json'));

      final updatedUser = jsonDecode(updateResponse.body);
      expect(updatedUser['name'], equals('Updated User'));
      expect(updatedUser['email'], equals('updated@example.com'));

      // List aggregates via GET collection
      final listResponse = await makeRequest(
        method: 'GET',
        path: '/users',
        headers: {'Accept': 'application/json'},
        port: port,
      );

      expect(listResponse.statusCode, equals(200));
      expect(listResponse.header('content-type'), equals('application/json'));
      expect(listResponse.header('x-total-count'), equals('1'));

      final userList = jsonDecode(listResponse.body) as List;
      expect(userList.length, equals(1));
      expect(userList[0]['id'], equals(userId));

      // Delete aggregate via DELETE
      final deleteResponse = await makeRequest(
        method: 'DELETE',
        path: '/users/$userId',
        port: port,
      );

      expect(deleteResponse.statusCode, equals(204));
      expect(deleteResponse.body, isEmpty);

      // Verify 404 after deletion
      final notFoundResponse = await makeRequest(
        method: 'GET',
        path: '/users/$userId',
        headers: {'Accept': 'application/json'},
        port: port,
      );

      expect(notFoundResponse.statusCode, equals(404));
      expect(notFoundResponse.header('content-type'), equals('application/problem+json'));

      final errorBody = jsonDecode(notFoundResponse.body);
      expect(errorBody['type'], equals('about:blank'));
      expect(errorBody['title'], equals('Not Found'));
      expect(errorBody['status'], equals(404));
    });
  });

  group('Integration Tests - Query Handlers', () {
    late HttpServer server;
    late InMemoryRepository<TestUser> repository;
    late TestUserSerializer serializer;
    const port = 8082;

    setUp(() async {
      repository = InMemoryRepository<TestUser>();
      serializer = TestUserSerializer();
      server = HttpServer(port: port);

      // Register custom query handler
      server.registerResource(
        CrudResource<TestUser>(
          path: '/users',
          repository: repository,
          serializers: {
            'application/json': serializer,
          },
          queryHandlers: {
            'name': (repo, params, skip, take) async {
              final name = params['name']!;
              final allUsers = (repo as InMemoryRepository<TestUser>).getAll();
              final filtered = allUsers.where((u) => u.name == name).toList();
              return QueryResult(
                filtered.skip(skip).take(take).toList(),
                totalCount: filtered.length,
              );
            },
          },
          defaultSkip: 0,
          defaultTake: 10,
          maxTake: 50,
        ),
      );

      await server.start();
    });

    tearDown(() async {
      await server.stop();
    });

    test('query handlers end-to-end', () async {
      // Create multiple test aggregates
      final users = [
        TestUser(
          id: UuidValue.generate(),
          name: 'Alice',
          email: 'alice@example.com',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        TestUser(
          id: UuidValue.generate(),
          name: 'Bob',
          email: 'bob@example.com',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        TestUser(
          id: UuidValue.generate(),
          name: 'Alice',
          email: 'alice2@example.com',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      for (final user in users) {
        await repository.save(user);
      }

      // Query with filter parameter
      final queryResponse = await makeRequest(
        method: 'GET',
        path: '/users?name=Alice',
        headers: {'Accept': 'application/json'},
        port: port,
      );

      expect(queryResponse.statusCode, equals(200));
      expect(queryResponse.header('content-type'), equals('application/json'));
      expect(queryResponse.header('x-total-count'), equals('2'));

      final filteredUsers = jsonDecode(queryResponse.body) as List;
      expect(filteredUsers.length, equals(2));
      expect(filteredUsers.every((u) => u['name'] == 'Alice'), isTrue);

      // Test pagination with query filters
      final paginatedResponse = await makeRequest(
        method: 'GET',
        path: '/users?name=Alice&skip=1&take=1',
        headers: {'Accept': 'application/json'},
        port: port,
      );

      expect(paginatedResponse.statusCode, equals(200));
      expect(paginatedResponse.header('x-total-count'), equals('2'));

      final paginatedUsers = jsonDecode(paginatedResponse.body) as List;
      expect(paginatedUsers.length, equals(1));
    });
  });

  group('Integration Tests - Content Negotiation', () {
    late HttpServer server;
    late InMemoryRepository<TestUser> repository;
    late TestUserSerializer jsonSerializer;
    late TestUserYamlSerializer yamlSerializer;
    const port = 8083;

    setUp(() async {
      repository = InMemoryRepository<TestUser>();
      jsonSerializer = TestUserSerializer();
      yamlSerializer = TestUserYamlSerializer();
      server = HttpServer(port: port);

      server.registerResource(
        CrudResource<TestUser>(
          path: '/users',
          repository: repository,
          serializers: {
            'application/json': jsonSerializer,
            'application/yaml': yamlSerializer,
          },
        ),
      );

      await server.start();
    });

    tearDown(() async {
      await server.stop();
    });

    test('content negotiation end-to-end', () async {
      // Test POST with JSON Content-Type
      final jsonUser = TestUser(
        id: UuidValue.generate(),
        name: 'JSON User',
        email: 'json@example.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final jsonBody = jsonSerializer.serialize(jsonUser);
      final jsonCreateResponse = await makeRequest(
        method: 'POST',
        path: '/users',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonBody,
        port: port,
      );

      expect(jsonCreateResponse.statusCode, equals(201));
      expect(jsonCreateResponse.header('content-type'), equals('application/json'));

      final jsonUserId = jsonDecode(jsonCreateResponse.body)['id'];

      // Test POST with YAML Content-Type
      final yamlUser = TestUser(
        id: UuidValue.generate(),
        name: 'YAML User',
        email: 'yaml@example.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final yamlBody = yamlSerializer.serialize(yamlUser);
      final yamlCreateResponse = await makeRequest(
        method: 'POST',
        path: '/users',
        headers: {
          'Content-Type': 'application/yaml',
          'Accept': 'application/yaml',
        },
        body: yamlBody,
        port: port,
      );

      expect(yamlCreateResponse.statusCode, equals(201));
      expect(yamlCreateResponse.header('content-type'), equals('application/yaml'));
      expect(yamlCreateResponse.body, contains('name: YAML User'));

      // Test GET with JSON Accept header
      final jsonGetResponse = await makeRequest(
        method: 'GET',
        path: '/users/$jsonUserId',
        headers: {'Accept': 'application/json'},
        port: port,
      );

      expect(jsonGetResponse.statusCode, equals(200));
      expect(jsonGetResponse.header('content-type'), equals('application/json'));

      final jsonGetUser = jsonDecode(jsonGetResponse.body);
      expect(jsonGetUser['name'], equals('JSON User'));

      // Test GET with YAML Accept header
      final yamlGetResponse = await makeRequest(
        method: 'GET',
        path: '/users/$jsonUserId',
        headers: {'Accept': 'application/yaml'},
        port: port,
      );

      expect(yamlGetResponse.statusCode, equals(200));
      expect(yamlGetResponse.header('content-type'), equals('application/yaml'));
      expect(yamlGetResponse.body, contains('name: JSON User'));

      // Test 415 response for unsupported Content-Type
      final unsupportedContentTypeResponse = await makeRequest(
        method: 'POST',
        path: '/users',
        headers: {
          'Content-Type': 'application/xml',
          'Accept': 'application/json',
        },
        body: '<user><name>XML User</name></user>',
        port: port,
      );

      expect(unsupportedContentTypeResponse.statusCode, equals(415));
      expect(unsupportedContentTypeResponse.header('content-type'), equals('application/problem+json'));

      final unsupportedError = jsonDecode(unsupportedContentTypeResponse.body);
      expect(unsupportedError['title'], equals('Unsupported Media Type'));
      expect(unsupportedError['detail'], contains('application/xml'));

      // Test 406 response for unsupported Accept
      final unsupportedAcceptResponse = await makeRequest(
        method: 'GET',
        path: '/users/$jsonUserId',
        headers: {'Accept': 'application/xml'},
        port: port,
      );

      expect(unsupportedAcceptResponse.statusCode, equals(406));
      expect(unsupportedAcceptResponse.header('content-type'), equals('application/problem+json'));

      final acceptError = jsonDecode(unsupportedAcceptResponse.body);
      expect(acceptError['title'], equals('Not Acceptable'));
      expect(acceptError['detail'], contains('application/xml'));
    });
  });

  group('Integration Tests - Error Scenarios', () {
    late HttpServer server;
    late InMemoryRepository<TestUser> repository;
    late TestUserSerializer serializer;
    const port = 8084;

    setUp(() async {
      repository = InMemoryRepository<TestUser>();
      serializer = TestUserSerializer();
      server = HttpServer(port: port);

      server.registerResource(
        CrudResource<TestUser>(
          path: '/users',
          repository: repository,
          serializers: {
            'application/json': serializer,
          },
          queryHandlers: {
            'name': (repo, params, skip, take) async {
              final name = params['name']!;
              final allUsers = (repo as InMemoryRepository<TestUser>).getAll();
              final filtered = allUsers.where((u) => u.name == name).toList();
              return QueryResult(
                filtered.skip(skip).take(take).toList(),
                totalCount: filtered.length,
              );
            },
          },
        ),
      );

      await server.start();
    });

    tearDown(() async {
      await server.stop();
    });

    test('error scenarios end-to-end', () async {
      // Test 404 response for non-existent aggregate
      final notFoundResponse = await makeRequest(
        method: 'GET',
        path: '/users/123e4567-e89b-12d3-a456-426614174000',
        headers: {'Accept': 'application/json'},
        port: port,
      );

      expect(notFoundResponse.statusCode, equals(404));
      expect(notFoundResponse.header('content-type'), equals('application/problem+json'));

      final notFoundError = jsonDecode(notFoundResponse.body);
      expect(notFoundError['type'], equals('about:blank'));
      expect(notFoundError['title'], equals('Not Found'));
      expect(notFoundError['status'], equals(404));

      // Test 400 response for invalid JSON in request body
      final invalidJsonResponse = await makeRequest(
        method: 'POST',
        path: '/users',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: 'invalid json {{{',
        port: port,
      );

      expect(invalidJsonResponse.statusCode, equals(400));
      expect(invalidJsonResponse.header('content-type'), equals('application/problem+json'));

      final invalidJsonError = jsonDecode(invalidJsonResponse.body);
      expect(invalidJsonError['type'], equals('about:blank'));
      expect(invalidJsonError['title'], equals('Bad Request'));
      expect(invalidJsonError['status'], equals(400));

      // Test 400 response for invalid UUID format
      final invalidUuidResponse = await makeRequest(
        method: 'GET',
        path: '/users/invalid-uuid-format',
        headers: {'Accept': 'application/json'},
        port: port,
      );

      expect(invalidUuidResponse.statusCode, equals(400));
      expect(invalidUuidResponse.header('content-type'), equals('application/problem+json'));

      final invalidUuidError = jsonDecode(invalidUuidResponse.body);
      expect(invalidUuidError['type'], equals('about:blank'));
      expect(invalidUuidError['status'], equals(400));

      // Test 400 response for unsupported query parameters
      final unsupportedParamResponse = await makeRequest(
        method: 'GET',
        path: '/users?unknownParam=value',
        headers: {'Accept': 'application/json'},
        port: port,
      );

      expect(unsupportedParamResponse.statusCode, equals(400));
      expect(unsupportedParamResponse.header('content-type'), equals('application/problem+json'));

      final unsupportedParamError = jsonDecode(unsupportedParamResponse.body);
      expect(unsupportedParamError['type'], equals('about:blank'));
      expect(unsupportedParamError['title'], equals('Bad Request'));
      expect(unsupportedParamError['status'], equals(400));
      expect(unsupportedParamError['detail'], contains('Unsupported query parameter'));

      // Test 400 response for multiple query parameters
      final multipleParamsResponse = await makeRequest(
        method: 'GET',
        path: '/users?name=Alice&email=alice@example.com',
        headers: {'Accept': 'application/json'},
        port: port,
      );

      expect(multipleParamsResponse.statusCode, equals(400));
      expect(multipleParamsResponse.header('content-type'), equals('application/problem+json'));

      final multipleParamsError = jsonDecode(multipleParamsResponse.body);
      expect(multipleParamsError['type'], equals('about:blank'));
      expect(multipleParamsError['title'], equals('Bad Request'));
      expect(multipleParamsError['status'], equals(400));
      expect(multipleParamsError['detail'], contains('Cannot combine multiple query parameters'));
    });
  });

  group('Integration Tests - Custom Exception Handlers', () {
    late HttpServer server;
    late TestRepository repository;
    late TestUserSerializer serializer;
    const port = 8085;

    setUp(() async {
      repository = TestRepository();
      serializer = TestUserSerializer();
      server = HttpServer(port: port);

      server.registerResource(
        CrudResource<TestUser>(
          path: '/users',
          repository: repository,
          serializers: {
            'application/json': serializer,
          },
          customExceptionHandlers: {
            CustomDomainException: (e) {
              return Response(
                418,
                headers: {'Content-Type': 'application/problem+json'},
                body: jsonEncode({
                  'type': 'about:blank',
                  'title': 'Custom Domain Error',
                  'status': 418,
                  'detail': (e as CustomDomainException).message,
                }),
              );
            },
          },
        ),
      );

      await server.start();
    });

    tearDown(() async {
      await server.stop();
    });

    test('custom exception handlers end-to-end', () async {
      // Create a user first
      final user = TestUser(
        id: UuidValue.generate(),
        name: 'Test User',
        email: 'test@example.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repository.save(user);

      // Trigger custom exception
      repository.shouldThrowCustomException = true;

      final customExceptionResponse = await makeRequest(
        method: 'GET',
        path: '/users/${user.id}',
        headers: {'Accept': 'application/json'},
        port: port,
      );

      expect(customExceptionResponse.statusCode, equals(418));
      expect(customExceptionResponse.header('content-type'), equals('application/problem+json'));

      final customError = jsonDecode(customExceptionResponse.body);
      expect(customError['type'], equals('about:blank'));
      expect(customError['title'], equals('Custom Domain Error'));
      expect(customError['status'], equals(418));
      expect(customError['detail'], equals('Custom exception triggered'));

      // Test fallback to default error handling
      repository.shouldThrowCustomException = false;

      final notFoundResponse = await makeRequest(
        method: 'GET',
        path: '/users/123e4567-e89b-12d3-a456-426614174000',
        headers: {'Accept': 'application/json'},
        port: port,
      );

      expect(notFoundResponse.statusCode, equals(404));
      expect(notFoundResponse.header('content-type'), equals('application/problem+json'));

      final notFoundError = jsonDecode(notFoundResponse.body);
      expect(notFoundError['title'], equals('Not Found'));
    });
  });

  group('Integration Tests - Pagination', () {
    late HttpServer server;
    late InMemoryRepository<TestUser> repository;
    late TestUserSerializer serializer;
    const port = 8086;

    setUp(() async {
      repository = InMemoryRepository<TestUser>();
      serializer = TestUserSerializer();
      server = HttpServer(port: port);

      server.registerResource(
        CrudResource<TestUser>(
          path: '/users',
          repository: repository,
          serializers: {
            'application/json': serializer,
          },
          queryHandlers: {
            'name': (repo, params, skip, take) async {
              final name = params['name']!;
              final allUsers = (repo as InMemoryRepository<TestUser>).getAll();
              final filtered = allUsers.where((u) => u.name == name).toList();
              return QueryResult(
                filtered.skip(skip).take(take).toList(),
                totalCount: filtered.length,
              );
            },
          },
          defaultSkip: 0,
          defaultTake: 10,
          maxTake: 20,
        ),
      );

      await server.start();
    });

    tearDown(() async {
      await server.stop();
    });

    test('pagination end-to-end', () async {
      // Create multiple test aggregates
      for (int i = 0; i < 25; i++) {
        final user = TestUser(
          id: UuidValue.generate(),
          name: i < 15 ? 'Alice' : 'Bob',
          email: 'user$i@example.com',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await repository.save(user);
      }

      // Test GET collection with skip and take parameters
      final paginatedResponse = await makeRequest(
        method: 'GET',
        path: '/users?skip=5&take=10',
        headers: {'Accept': 'application/json'},
        port: port,
      );

      expect(paginatedResponse.statusCode, equals(200));
      expect(paginatedResponse.header('content-type'), equals('application/json'));
      expect(paginatedResponse.header('x-total-count'), equals('25'));

      final paginatedUsers = jsonDecode(paginatedResponse.body) as List;
      expect(paginatedUsers.length, equals(10));

      // Test maxTake enforcement
      final maxTakeResponse = await makeRequest(
        method: 'GET',
        path: '/users?take=100',
        headers: {'Accept': 'application/json'},
        port: port,
      );

      expect(maxTakeResponse.statusCode, equals(200));
      expect(maxTakeResponse.header('x-total-count'), equals('25'));

      final maxTakeUsers = jsonDecode(maxTakeResponse.body) as List;
      expect(maxTakeUsers.length, equals(20)); // Limited to maxTake

      // Test pagination with query filters
      final filteredPaginatedResponse = await makeRequest(
        method: 'GET',
        path: '/users?name=Alice&skip=5&take=5',
        headers: {'Accept': 'application/json'},
        port: port,
      );

      expect(filteredPaginatedResponse.statusCode, equals(200));
      expect(filteredPaginatedResponse.header('x-total-count'), equals('15'));

      final filteredPaginatedUsers = jsonDecode(filteredPaginatedResponse.body) as List;
      expect(filteredPaginatedUsers.length, equals(5));
      expect(filteredPaginatedUsers.every((u) => u['name'] == 'Alice'), isTrue);
    });
  });
}
