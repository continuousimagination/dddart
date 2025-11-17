import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_rest/src/crud_resource.dart';
import 'package:dddart_rest/src/query_handler.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:shelf/shelf.dart';
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

// Helper to create test requests
Request createRequest({
  String method = 'GET',
  String path = '/users',
  Map<String, String>? headers,
  String? body,
}) {
  final uri = Uri.parse('http://localhost:8080$path');
  return Request(
    method,
    uri,
    headers: headers,
    body: body,
  );
}

void main() {
  late InMemoryRepository<TestUser> repository;
  late TestUserSerializer serializer;

  setUp(() {
    repository = InMemoryRepository<TestUser>();
    serializer = TestUserSerializer();
  });

  group('CrudResource - Configuration Validation', () {
    test('empty serializers map throws ArgumentError', () {
      // Act & Assert
      expect(
        () => CrudResource<TestUser>(
          path: '/users',
          repository: repository,
          serializers: {}, // Empty map
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('serializers map cannot be empty'),
          ),
        ),
      );
    });

    test('empty path throws ArgumentError', () {
      // Act & Assert
      expect(
        () => CrudResource<TestUser>(
          path: '', // Empty path
          repository: repository,
          serializers: {'application/json': serializer},
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('path cannot be empty'),
          ),
        ),
      );
    });
  });

  group('CrudResource - Pagination Edge Cases', () {
    test('negative skip is treated as zero', () async {
      // Arrange
      for (var i = 0; i < 5; i++) {
        final user = TestUser(
          id: UuidValue.generate(),
          name: 'User $i',
          email: 'user$i@example.com',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await repository.save(user);
      }

      final resource = CrudResource<TestUser>(
        path: '/users',
        repository: repository,
        serializers: {'application/json': serializer},
        defaultTake: 10,
      );

      final request = createRequest(path: '/users?skip=-5&take=3');

      // Act
      final response = await resource.handleQuery(request);

      // Assert
      expect(response.statusCode, equals(200));

      final bodyString = await response.readAsString();
      final body = jsonDecode(bodyString) as List;
      // Should return first 3 items (skip treated as 0)
      expect(body.length, equals(3));
    });

    test('negative take uses defaultTake', () async {
      // Arrange
      for (var i = 0; i < 5; i++) {
        final user = TestUser(
          id: UuidValue.generate(),
          name: 'User $i',
          email: 'user$i@example.com',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await repository.save(user);
      }

      final resource = CrudResource<TestUser>(
        path: '/users',
        repository: repository,
        serializers: {'application/json': serializer},
        defaultTake: 3,
      );

      final request = createRequest(path: '/users?take=-10');

      // Act
      final response = await resource.handleQuery(request);

      // Assert
      expect(response.statusCode, equals(200));

      final bodyString = await response.readAsString();
      final body = jsonDecode(bodyString) as List;
      // Should return defaultTake (3) items
      expect(body.length, equals(3));
    });

    test('zero take returns empty array', () async {
      // Arrange
      for (var i = 0; i < 5; i++) {
        final user = TestUser(
          id: UuidValue.generate(),
          name: 'User $i',
          email: 'user$i@example.com',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await repository.save(user);
      }

      final resource = CrudResource<TestUser>(
        path: '/users',
        repository: repository,
        serializers: {'application/json': serializer},
      );

      final request = createRequest(path: '/users?take=0');

      // Act
      final response = await resource.handleQuery(request);

      // Assert
      expect(response.statusCode, equals(200));

      final bodyString = await response.readAsString();
      final body = jsonDecode(bodyString) as List;
      expect(body.length, equals(0));

      // X-Total-Count should still reflect total items
      expect(response.headers['X-Total-Count'], equals('5'));
    });

    test('very large skip returns empty array', () async {
      // Arrange
      for (var i = 0; i < 5; i++) {
        final user = TestUser(
          id: UuidValue.generate(),
          name: 'User $i',
          email: 'user$i@example.com',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await repository.save(user);
      }

      final resource = CrudResource<TestUser>(
        path: '/users',
        repository: repository,
        serializers: {'application/json': serializer},
      );

      final request = createRequest(path: '/users?skip=1000&take=10');

      // Act
      final response = await resource.handleQuery(request);

      // Assert
      expect(response.statusCode, equals(200));

      final bodyString = await response.readAsString();
      final body = jsonDecode(bodyString) as List;
      expect(body.length, equals(0));

      // X-Total-Count should still reflect total items
      expect(response.headers['X-Total-Count'], equals('5'));
    });
  });

  group('CrudResource - Content Negotiation Edge Cases', () {
    test('Accept header with quality values', () async {
      // Arrange
      final jsonSerializer = TestUserSerializer();
      final yamlSerializer = TestUserSerializer(); // Using same for simplicity

      final testUser = TestUser(
        id: UuidValue.fromString('123e4567-e89b-12d3-a456-426614174000'),
        name: 'Test User',
        email: 'test@example.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repository.save(testUser);

      final resource = CrudResource<TestUser>(
        path: '/users',
        repository: repository,
        serializers: {
          'application/json': jsonSerializer,
          'application/yaml': yamlSerializer,
        },
      );

      // Request with quality values - YAML has higher priority
      final request = createRequest(
        path: '/users/${testUser.id}',
        headers: {'accept': 'application/json;q=0.8, application/yaml;q=1.0'},
      );

      // Act
      final response =
          await resource.handleGetById(request, testUser.id.toString());

      // Assert
      expect(response.statusCode, equals(200));
      expect(response.headers['Content-Type'], equals('application/yaml'));
    });

    test('Content-Type with charset parameter', () async {
      // Arrange
      final newUser = TestUser(
        id: UuidValue.generate(),
        name: 'New User',
        email: 'new@example.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final resource = CrudResource<TestUser>(
        path: '/users',
        repository: repository,
        serializers: {'application/json': serializer},
      );

      final requestBody = serializer.serialize(newUser);
      final request = createRequest(
        method: 'POST',
        headers: {
          'content-type': 'application/json; charset=utf-8', // With charset
        },
        body: requestBody,
      );

      // Act
      final response = await resource.handleCreate(request);

      // Assert
      expect(response.statusCode, equals(201));

      // Verify the user was saved
      final savedUser = await repository.getById(newUser.id);
      expect(savedUser.name, equals('New User'));
    });

    test('case-insensitive media type matching', () async {
      // Arrange
      final newUser = TestUser(
        id: UuidValue.generate(),
        name: 'New User',
        email: 'new@example.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final resource = CrudResource<TestUser>(
        path: '/users',
        repository: repository,
        serializers: {'application/json': serializer},
      );

      final requestBody = serializer.serialize(newUser);
      final request = createRequest(
        method: 'POST',
        headers: {
          'content-type': 'APPLICATION/JSON', // Uppercase
          'accept': 'Application/Json', // Mixed case
        },
        body: requestBody,
      );

      // Act
      final response = await resource.handleCreate(request);

      // Assert
      expect(response.statusCode, equals(201));
      expect(response.headers['Content-Type'], equals('application/json'));
    });
  });

  group('CrudResource - Query Handler Edge Cases', () {
    test('null totalCount omits X-Total-Count header', () async {
      // Arrange
      final testUser = TestUser(
        id: UuidValue.generate(),
        name: 'Test User',
        email: 'test@example.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      Future<QueryResult<TestUser>> testHandler(
        Repository<TestUser> repo,
        Map<String, String> params,
        int skip,
        int take,
      ) async {
        // Return result with null totalCount
        return QueryResult<TestUser>([testUser]);
      }

      final resource = CrudResource<TestUser>(
        path: '/users',
        repository: repository,
        serializers: {'application/json': serializer},
        queryHandlers: {'name': testHandler},
      );

      final request = createRequest(path: '/users?name=Test');

      // Act
      final response = await resource.handleQuery(request);

      // Assert
      expect(response.statusCode, equals(200));
      expect(response.headers['X-Total-Count'], isNull);
    });

    test('empty results from query handler', () async {
      // Arrange
      Future<QueryResult<TestUser>> testHandler(
        Repository<TestUser> repo,
        Map<String, String> params,
        int skip,
        int take,
      ) async {
        // Return empty result
        return QueryResult<TestUser>([], totalCount: 0);
      }

      final resource = CrudResource<TestUser>(
        path: '/users',
        repository: repository,
        serializers: {'application/json': serializer},
        queryHandlers: {'name': testHandler},
      );

      final request = createRequest(path: '/users?name=NonExistent');

      // Act
      final response = await resource.handleQuery(request);

      // Assert
      expect(response.statusCode, equals(200));

      final bodyString = await response.readAsString();
      final body = jsonDecode(bodyString) as List;
      expect(body.length, equals(0));
      expect(response.headers['X-Total-Count'], equals('0'));
    });
  });
}
