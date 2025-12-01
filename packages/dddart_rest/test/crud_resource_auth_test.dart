import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_rest/src/auth_handler.dart';
import 'package:dddart_rest/src/auth_result.dart';
import 'package:dddart_rest/src/crud_resource.dart';
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

// Mock repository for testing
class MockRepository implements Repository<TestUser> {
  final Map<UuidValue, TestUser> _storage = {};

  @override
  Future<TestUser> getById(UuidValue id) async {
    final user = _storage[id];
    if (user == null) {
      throw RepositoryException(
        'User with ID $id not found',
        type: RepositoryExceptionType.notFound,
      );
    }
    return user;
  }

  @override
  Future<void> save(TestUser aggregate) async {
    _storage[aggregate.id] = aggregate;
  }

  @override
  Future<void> deleteById(UuidValue id) async {
    if (!_storage.containsKey(id)) {
      throw RepositoryException(
        'User with ID $id not found',
        type: RepositoryExceptionType.notFound,
      );
    }
    _storage.remove(id);
  }

  void clear() {
    _storage.clear();
  }
}

// Mock auth handler for testing
class MockAuthHandler implements AuthHandler<String> {
  MockAuthHandler({
    this.shouldAuthenticate = true,
    this.errorMessage,
  });
  final bool shouldAuthenticate;
  final String? errorMessage;

  @override
  Future<AuthResult<String>> authenticate(Request request) async {
    if (shouldAuthenticate) {
      return AuthResult.success(userId: 'test-user-123', claims: 'test-claim');
    } else {
      return AuthResult.failure(errorMessage ?? 'Authentication failed');
    }
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
  late MockRepository repository;
  late TestUserSerializer serializer;
  late TestUser testUser;

  setUp(() {
    repository = MockRepository();
    serializer = TestUserSerializer();

    testUser = TestUser(
      id: UuidValue.fromString('123e4567-e89b-12d3-a456-426614174000'),
      name: 'John Doe',
      email: 'john@example.com',
      createdAt: DateTime.parse('2024-01-15T10:30:00Z'),
      updatedAt: DateTime.parse('2024-01-15T10:30:00Z'),
    );
  });

  group('CrudResource - Authentication', () {
    test('handleGetById returns 401 when authentication fails', () async {
      // Arrange
      final authHandler = MockAuthHandler(
        shouldAuthenticate: false,
        errorMessage: 'Invalid token',
      );
      final resource = CrudResource<TestUser, String>(
        path: '/users',
        repository: repository,
        serializers: {'application/json': serializer},
        authHandler: authHandler,
      );
      await repository.save(testUser);
      final request = createRequest(path: '/users/${testUser.id}');

      // Act
      final response =
          await resource.handleGetById(request, testUser.id.toString());

      // Assert
      expect(response.statusCode, equals(401));
      final body = jsonDecode(await response.readAsString());
      expect(body['status'], equals(401));
      expect(body['title'], equals('Unauthorized'));
      expect(body['detail'], equals('Invalid token'));
    });

    test('handleGetById succeeds when authentication passes', () async {
      // Arrange
      final authHandler = MockAuthHandler();
      final resource = CrudResource<TestUser, String>(
        path: '/users',
        repository: repository,
        serializers: {'application/json': serializer},
        authHandler: authHandler,
      );
      await repository.save(testUser);
      final request = createRequest(path: '/users/${testUser.id}');

      // Act
      final response =
          await resource.handleGetById(request, testUser.id.toString());

      // Assert
      expect(response.statusCode, equals(200));
    });

    test('handleCreate returns 401 when authentication fails', () async {
      // Arrange
      final authHandler = MockAuthHandler(shouldAuthenticate: false);
      final resource = CrudResource<TestUser, String>(
        path: '/users',
        repository: repository,
        serializers: {'application/json': serializer},
        authHandler: authHandler,
      );
      final request = createRequest(
        method: 'POST',
        headers: {'content-type': 'application/json'},
        body: serializer.serialize(testUser),
      );

      // Act
      final response = await resource.handleCreate(request);

      // Assert
      expect(response.statusCode, equals(401));
    });

    test('handleUpdate returns 401 when authentication fails', () async {
      // Arrange
      final authHandler = MockAuthHandler(shouldAuthenticate: false);
      final resource = CrudResource<TestUser, String>(
        path: '/users',
        repository: repository,
        serializers: {'application/json': serializer},
        authHandler: authHandler,
      );
      final request = createRequest(
        method: 'PUT',
        path: '/users/${testUser.id}',
        headers: {'content-type': 'application/json'},
        body: serializer.serialize(testUser),
      );

      // Act
      final response =
          await resource.handleUpdate(request, testUser.id.toString());

      // Assert
      expect(response.statusCode, equals(401));
    });

    test('handleDelete returns 401 when authentication fails', () async {
      // Arrange
      final authHandler = MockAuthHandler(shouldAuthenticate: false);
      final resource = CrudResource<TestUser, String>(
        path: '/users',
        repository: repository,
        serializers: {'application/json': serializer},
        authHandler: authHandler,
      );
      await repository.save(testUser);
      final request = createRequest(
        method: 'DELETE',
        path: '/users/${testUser.id}',
      );

      // Act
      final response =
          await resource.handleDelete(request, testUser.id.toString());

      // Assert
      expect(response.statusCode, equals(401));
    });

    test('handleQuery returns 401 when authentication fails', () async {
      // Arrange
      final authHandler = MockAuthHandler(shouldAuthenticate: false);
      final resource = CrudResource<TestUser, String>(
        path: '/users',
        repository: repository,
        serializers: {'application/json': serializer},
        authHandler: authHandler,
      );
      final request = createRequest();

      // Act
      final response = await resource.handleQuery(request);

      // Assert
      expect(response.statusCode, equals(401));
    });

    test('resource without auth handler allows unauthenticated access',
        () async {
      // Arrange
      final resource = CrudResource<TestUser, dynamic>(
        path: '/users',
        repository: repository,
        serializers: {'application/json': serializer},
      );
      await repository.save(testUser);
      final request = createRequest(path: '/users/${testUser.id}');

      // Act
      final response =
          await resource.handleGetById(request, testUser.id.toString());

      // Assert
      expect(response.statusCode, equals(200));
    });
  });
}
