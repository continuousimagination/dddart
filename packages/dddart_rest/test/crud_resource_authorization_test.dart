import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_rest/src/authentication_handler.dart';
import 'package:dddart_rest/src/authentication_result.dart';
import 'package:dddart_rest/src/authorization_handler.dart';
import 'package:dddart_rest/src/authorization_result.dart';
import 'package:dddart_rest/src/crud_resource.dart';
import 'package:dddart_rest/src/query_handler.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'json_serializer_test_support.dart';

// Test aggregate root
class TestUser extends AggregateRoot {
  TestUser({
    required this.name,
    required this.email,
    required this.ownerId,
    super.id,
    super.createdAt,
    super.updatedAt,
  });

  final String name;
  final String email;
  final String ownerId;
}

// Test claims
class TestClaims {
  TestClaims({required this.userId});
  final String userId;
}

// Test serializer
class TestUserSerializer extends TestJsonSerializer<TestUser> {
  @override
  String serialize(TestUser user, [dynamic config]) {
    return jsonEncode({
      'id': user.id.toString(),
      'name': user.name,
      'email': user.email,
      'ownerId': user.ownerId,
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
      ownerId: json['ownerId'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }
}

// Mock repository
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

// Mock authentication handler
class MockAuthenticationHandler implements AuthenticationHandler<TestClaims> {
  bool shouldAuthenticate = true;
  TestClaims? claimsToReturn;

  @override
  Future<AuthenticationResult<TestClaims>> authenticate(Request request) async {
    if (shouldAuthenticate) {
      return AuthenticationResult<TestClaims>(
        isAuthenticated: true,
        claims: claimsToReturn,
      );
    }
    return const AuthenticationResult<TestClaims>(
      isAuthenticated: false,
      errorMessage: 'Authentication failed',
    );
  }
}

// Mock authorization handler
class MockAuthorizationHandler
    implements AuthorizationHandler<TestUser, TestClaims> {
  bool shouldAuthorize = true;
  String? errorMessage;

  // Track which methods were called
  bool createCalled = false;
  bool updateCalled = false;
  bool deleteCalled = false;
  bool queryCalled = false;

  // Track parameters passed to methods
  TestUser? lastAggregate;
  UuidValue? lastAggregateId;
  Map<String, String>? lastQueryParams;
  AuthenticationResult<TestClaims>? lastAuthResult;

  @override
  Future<AuthorizationResult> authorizeCreate(
    TestUser aggregate,
    AuthenticationResult<TestClaims> authResult,
  ) async {
    createCalled = true;
    lastAggregate = aggregate;
    lastAuthResult = authResult;

    if (shouldAuthorize) {
      return AuthorizationResult.allow();
    }
    return AuthorizationResult.deny(
      errorMessage ?? 'You do not have permission to create this resource',
    );
  }

  @override
  Future<AuthorizationResult> authorizeUpdate(
    TestUser aggregate,
    AuthenticationResult<TestClaims> authResult,
  ) async {
    updateCalled = true;
    lastAggregate = aggregate;
    lastAuthResult = authResult;

    if (shouldAuthorize) {
      return AuthorizationResult.allow();
    }
    return AuthorizationResult.deny(
      errorMessage ?? 'You do not have permission to update this resource',
    );
  }

  @override
  Future<AuthorizationResult> authorizeDelete(
    UuidValue aggregateId,
    AuthenticationResult<TestClaims> authResult,
  ) async {
    deleteCalled = true;
    lastAggregateId = aggregateId;
    lastAuthResult = authResult;

    if (shouldAuthorize) {
      return AuthorizationResult.allow();
    }
    return AuthorizationResult.deny(
      errorMessage ?? 'You do not have permission to delete this resource',
    );
  }

  @override
  Future<AuthorizationResult> authorizeQuery(
    Map<String, String> queryParams,
    AuthenticationResult<TestClaims> authResult,
  ) async {
    queryCalled = true;
    lastQueryParams = queryParams;
    lastAuthResult = authResult;

    if (shouldAuthorize) {
      return AuthorizationResult.allow();
    }
    return AuthorizationResult.deny(
      errorMessage ?? 'You do not have permission to query this resource',
    );
  }

  void reset() {
    createCalled = false;
    updateCalled = false;
    deleteCalled = false;
    queryCalled = false;
    lastAggregate = null;
    lastAggregateId = null;
    lastQueryParams = null;
    lastAuthResult = null;
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
  late MockAuthenticationHandler authHandler;
  late MockAuthorizationHandler authzHandler;
  late TestUser testUser;
  late TestClaims testClaims;

  setUp(() {
    repository = MockRepository();
    serializer = TestUserSerializer();
    authHandler = MockAuthenticationHandler();
    authzHandler = MockAuthorizationHandler();

    testClaims = TestClaims(userId: 'user-123');
    authHandler.claimsToReturn = testClaims;

    testUser = TestUser(
      id: UuidValue.fromString('123e4567-e89b-12d3-a456-426614174000'),
      name: 'John Doe',
      email: 'john@example.com',
      ownerId: 'user-123',
      createdAt: DateTime.parse('2024-01-15T10:30:00Z'),
      updatedAt: DateTime.parse('2024-01-15T10:30:00Z'),
    );
  });

  group('CrudResource - Authorization Integration', () {
    group('handleCreate', () {
      test('calls authorization handler after authentication', () async {
        // Arrange
        final resource = CrudResource<TestUser, TestClaims>(
          path: '/users',
          repository: repository,
          serializer: serializer,
          authenticationHandler: authHandler,
          authorizationHandler: authzHandler,
        );

        final requestBody = serializer.serialize(testUser);
        final request = createRequest(
          method: 'POST',
          headers: {'content-type': 'application/json'},
          body: requestBody,
        );

        // Act
        await resource.handleCreate(request);

        // Assert
        expect(authzHandler.createCalled, isTrue);
        expect(authzHandler.lastAggregate?.id, equals(testUser.id));
        expect(authzHandler.lastAuthResult?.claims?.userId, equals('user-123'));
      });

      test('authorization success allows operation to proceed', () async {
        // Arrange
        authzHandler.shouldAuthorize = true;

        final resource = CrudResource<TestUser, TestClaims>(
          path: '/users',
          repository: repository,
          serializer: serializer,
          authenticationHandler: authHandler,
          authorizationHandler: authzHandler,
        );

        final requestBody = serializer.serialize(testUser);
        final request = createRequest(
          method: 'POST',
          headers: {'content-type': 'application/json'},
          body: requestBody,
        );

        // Act
        final response = await resource.handleCreate(request);

        // Assert
        expect(response.statusCode, equals(201));

        // Verify user was saved
        final savedUser = await repository.getById(testUser.id);
        expect(savedUser.id, equals(testUser.id));
      });

      test('authorization failure returns HTTP 403 Forbidden', () async {
        // Arrange
        authzHandler.shouldAuthorize = false;
        authzHandler.errorMessage =
            'You do not have permission to create this user';

        final resource = CrudResource<TestUser, TestClaims>(
          path: '/users',
          repository: repository,
          serializer: serializer,
          authenticationHandler: authHandler,
          authorizationHandler: authzHandler,
        );

        final requestBody = serializer.serialize(testUser);
        final request = createRequest(
          method: 'POST',
          headers: {'content-type': 'application/json'},
          body: requestBody,
        );

        // Act
        final response = await resource.handleCreate(request);

        // Assert
        expect(response.statusCode, equals(403));

        // Verify user was NOT saved
        try {
          await repository.getById(testUser.id);
          fail('Expected RepositoryException to be thrown');
        } catch (e) {
          expect(e, isA<RepositoryException>());
        }
      });

      test('RFC 7807 error response format for authorization failures',
          () async {
        // Arrange
        authzHandler.shouldAuthorize = false;
        authzHandler.errorMessage = 'Custom authorization error message';

        final resource = CrudResource<TestUser, TestClaims>(
          path: '/users',
          repository: repository,
          serializer: serializer,
          authenticationHandler: authHandler,
          authorizationHandler: authzHandler,
        );

        final requestBody = serializer.serialize(testUser);
        final request = createRequest(
          method: 'POST',
          headers: {'content-type': 'application/json'},
          body: requestBody,
        );

        // Act
        final response = await resource.handleCreate(request);

        // Assert
        expect(response.statusCode, equals(403));
        expect(
          response.headers['Content-Type'],
          equals('application/problem+json'),
        );

        final bodyString = await response.readAsString();
        final body = jsonDecode(bodyString);
        expect(body['type'], equals('about:blank'));
        expect(body['title'], equals('Forbidden'));
        expect(body['status'], equals(403));
        expect(body['detail'], equals('Custom authorization error message'));
      });

      test('authorization is skipped when no handler provided', () async {
        // Arrange
        final resource = CrudResource<TestUser, TestClaims>(
          path: '/users',
          repository: repository,
          serializer: serializer,
          authenticationHandler: authHandler,
          // No authorizationHandler provided
        );

        final requestBody = serializer.serialize(testUser);
        final request = createRequest(
          method: 'POST',
          headers: {'content-type': 'application/json'},
          body: requestBody,
        );

        // Act
        final response = await resource.handleCreate(request);

        // Assert
        expect(response.statusCode, equals(201));
        expect(authzHandler.createCalled, isFalse);

        // Verify user was saved
        final savedUser = await repository.getById(testUser.id);
        expect(savedUser.id, equals(testUser.id));
      });
    });

    group('handleUpdate', () {
      test('calls authorization handler after authentication', () async {
        // Arrange
        await repository.save(testUser);

        final resource = CrudResource<TestUser, TestClaims>(
          path: '/users',
          repository: repository,
          serializer: serializer,
          authenticationHandler: authHandler,
          authorizationHandler: authzHandler,
        );

        final updatedUser = TestUser(
          id: testUser.id,
          name: 'Updated Name',
          email: testUser.email,
          ownerId: testUser.ownerId,
          createdAt: testUser.createdAt,
          updatedAt: DateTime.now(),
        );

        final requestBody = serializer.serialize(updatedUser);
        final request = createRequest(
          method: 'PUT',
          path: '/users/${testUser.id}',
          headers: {'content-type': 'application/json'},
          body: requestBody,
        );

        // Act
        await resource.handleUpdate(request, testUser.id.toString());

        // Assert
        expect(authzHandler.updateCalled, isTrue);
        expect(authzHandler.lastAggregate?.id, equals(testUser.id));
        expect(authzHandler.lastAuthResult?.claims?.userId, equals('user-123'));
      });

      test('authorization success allows operation to proceed', () async {
        // Arrange
        await repository.save(testUser);
        authzHandler.shouldAuthorize = true;

        final resource = CrudResource<TestUser, TestClaims>(
          path: '/users',
          repository: repository,
          serializer: serializer,
          authenticationHandler: authHandler,
          authorizationHandler: authzHandler,
        );

        final updatedUser = TestUser(
          id: testUser.id,
          name: 'Updated Name',
          email: testUser.email,
          ownerId: testUser.ownerId,
          createdAt: testUser.createdAt,
          updatedAt: DateTime.now(),
        );

        final requestBody = serializer.serialize(updatedUser);
        final request = createRequest(
          method: 'PUT',
          path: '/users/${testUser.id}',
          headers: {'content-type': 'application/json'},
          body: requestBody,
        );

        // Act
        final response =
            await resource.handleUpdate(request, testUser.id.toString());

        // Assert
        expect(response.statusCode, equals(200));

        // Verify user was updated
        final savedUser = await repository.getById(testUser.id);
        expect(savedUser.name, equals('Updated Name'));
      });

      test('authorization failure returns HTTP 403 Forbidden', () async {
        // Arrange
        await repository.save(testUser);
        authzHandler.shouldAuthorize = false;
        authzHandler.errorMessage =
            'You do not have permission to update this user';

        final resource = CrudResource<TestUser, TestClaims>(
          path: '/users',
          repository: repository,
          serializer: serializer,
          authenticationHandler: authHandler,
          authorizationHandler: authzHandler,
        );

        final updatedUser = TestUser(
          id: testUser.id,
          name: 'Updated Name',
          email: testUser.email,
          ownerId: testUser.ownerId,
          createdAt: testUser.createdAt,
          updatedAt: DateTime.now(),
        );

        final requestBody = serializer.serialize(updatedUser);
        final request = createRequest(
          method: 'PUT',
          path: '/users/${testUser.id}',
          headers: {'content-type': 'application/json'},
          body: requestBody,
        );

        // Act
        final response =
            await resource.handleUpdate(request, testUser.id.toString());

        // Assert
        expect(response.statusCode, equals(403));

        // Verify user was NOT updated
        final savedUser = await repository.getById(testUser.id);
        expect(savedUser.name, equals('John Doe'));
      });

      test('RFC 7807 error response format for authorization failures',
          () async {
        // Arrange
        await repository.save(testUser);
        authzHandler.shouldAuthorize = false;
        authzHandler.errorMessage = 'Custom update authorization error';

        final resource = CrudResource<TestUser, TestClaims>(
          path: '/users',
          repository: repository,
          serializer: serializer,
          authenticationHandler: authHandler,
          authorizationHandler: authzHandler,
        );

        final updatedUser = TestUser(
          id: testUser.id,
          name: 'Updated Name',
          email: testUser.email,
          ownerId: testUser.ownerId,
          createdAt: testUser.createdAt,
          updatedAt: DateTime.now(),
        );

        final requestBody = serializer.serialize(updatedUser);
        final request = createRequest(
          method: 'PUT',
          path: '/users/${testUser.id}',
          headers: {'content-type': 'application/json'},
          body: requestBody,
        );

        // Act
        final response =
            await resource.handleUpdate(request, testUser.id.toString());

        // Assert
        expect(response.statusCode, equals(403));
        expect(
          response.headers['Content-Type'],
          equals('application/problem+json'),
        );

        final bodyString = await response.readAsString();
        final body = jsonDecode(bodyString);
        expect(body['type'], equals('about:blank'));
        expect(body['title'], equals('Forbidden'));
        expect(body['status'], equals(403));
        expect(body['detail'], equals('Custom update authorization error'));
      });

      test('authorization is skipped when no handler provided', () async {
        // Arrange
        await repository.save(testUser);

        final resource = CrudResource<TestUser, TestClaims>(
          path: '/users',
          repository: repository,
          serializer: serializer,
          authenticationHandler: authHandler,
          // No authorizationHandler provided
        );

        final updatedUser = TestUser(
          id: testUser.id,
          name: 'Updated Name',
          email: testUser.email,
          ownerId: testUser.ownerId,
          createdAt: testUser.createdAt,
          updatedAt: DateTime.now(),
        );

        final requestBody = serializer.serialize(updatedUser);
        final request = createRequest(
          method: 'PUT',
          path: '/users/${testUser.id}',
          headers: {'content-type': 'application/json'},
          body: requestBody,
        );

        // Act
        final response =
            await resource.handleUpdate(request, testUser.id.toString());

        // Assert
        expect(response.statusCode, equals(200));
        expect(authzHandler.updateCalled, isFalse);

        // Verify user was updated
        final savedUser = await repository.getById(testUser.id);
        expect(savedUser.name, equals('Updated Name'));
      });
    });

    group('handleDelete', () {
      test('calls authorization handler after authentication', () async {
        // Arrange
        await repository.save(testUser);

        final resource = CrudResource<TestUser, TestClaims>(
          path: '/users',
          repository: repository,
          serializer: serializer,
          authenticationHandler: authHandler,
          authorizationHandler: authzHandler,
        );

        final request = createRequest(
          method: 'DELETE',
          path: '/users/${testUser.id}',
        );

        // Act
        await resource.handleDelete(request, testUser.id.toString());

        // Assert
        expect(authzHandler.deleteCalled, isTrue);
        expect(authzHandler.lastAggregateId, equals(testUser.id));
        expect(authzHandler.lastAuthResult?.claims?.userId, equals('user-123'));
      });

      test('authorization success allows operation to proceed', () async {
        // Arrange
        await repository.save(testUser);
        authzHandler.shouldAuthorize = true;

        final resource = CrudResource<TestUser, TestClaims>(
          path: '/users',
          repository: repository,
          serializer: serializer,
          authenticationHandler: authHandler,
          authorizationHandler: authzHandler,
        );

        final request = createRequest(
          method: 'DELETE',
          path: '/users/${testUser.id}',
        );

        // Act
        final response =
            await resource.handleDelete(request, testUser.id.toString());

        // Assert
        expect(response.statusCode, equals(204));

        // Verify user was deleted
        try {
          await repository.getById(testUser.id);
          fail('Expected RepositoryException to be thrown');
        } catch (e) {
          expect(e, isA<RepositoryException>());
        }
      });

      test('authorization failure returns HTTP 403 Forbidden', () async {
        // Arrange
        await repository.save(testUser);
        authzHandler.shouldAuthorize = false;
        authzHandler.errorMessage =
            'You do not have permission to delete this user';

        final resource = CrudResource<TestUser, TestClaims>(
          path: '/users',
          repository: repository,
          serializer: serializer,
          authenticationHandler: authHandler,
          authorizationHandler: authzHandler,
        );

        final request = createRequest(
          method: 'DELETE',
          path: '/users/${testUser.id}',
        );

        // Act
        final response =
            await resource.handleDelete(request, testUser.id.toString());

        // Assert
        expect(response.statusCode, equals(403));

        // Verify user was NOT deleted
        final savedUser = await repository.getById(testUser.id);
        expect(savedUser.id, equals(testUser.id));
      });

      test('RFC 7807 error response format for authorization failures',
          () async {
        // Arrange
        await repository.save(testUser);
        authzHandler.shouldAuthorize = false;
        authzHandler.errorMessage = 'Custom delete authorization error';

        final resource = CrudResource<TestUser, TestClaims>(
          path: '/users',
          repository: repository,
          serializer: serializer,
          authenticationHandler: authHandler,
          authorizationHandler: authzHandler,
        );

        final request = createRequest(
          method: 'DELETE',
          path: '/users/${testUser.id}',
        );

        // Act
        final response =
            await resource.handleDelete(request, testUser.id.toString());

        // Assert
        expect(response.statusCode, equals(403));
        expect(
          response.headers['Content-Type'],
          equals('application/problem+json'),
        );

        final bodyString = await response.readAsString();
        final body = jsonDecode(bodyString);
        expect(body['type'], equals('about:blank'));
        expect(body['title'], equals('Forbidden'));
        expect(body['status'], equals(403));
        expect(body['detail'], equals('Custom delete authorization error'));
      });

      test('authorization is skipped when no handler provided', () async {
        // Arrange
        await repository.save(testUser);

        final resource = CrudResource<TestUser, TestClaims>(
          path: '/users',
          repository: repository,
          serializer: serializer,
          authenticationHandler: authHandler,
          // No authorizationHandler provided
        );

        final request = createRequest(
          method: 'DELETE',
          path: '/users/${testUser.id}',
        );

        // Act
        final response =
            await resource.handleDelete(request, testUser.id.toString());

        // Assert
        expect(response.statusCode, equals(204));
        expect(authzHandler.deleteCalled, isFalse);

        // Verify user was deleted
        try {
          await repository.getById(testUser.id);
          fail('Expected RepositoryException to be thrown');
        } catch (e) {
          expect(e, isA<RepositoryException>());
        }
      });
    });

    group('handleQuery', () {
      test('calls authorization handler for filtered queries', () async {
        // Arrange
        final resource = CrudResource<TestUser, TestClaims>(
          path: '/users',
          repository: repository,
          serializer: serializer,
          authenticationHandler: authHandler,
          authorizationHandler: authzHandler,
          queryHandlers: {
            'ownerId': (repo, params, skip, take, authResult) async {
              return QueryResult<TestUser>([], totalCount: 0);
            },
          },
        );

        final request = createRequest(
          path: '/users?ownerId=user-123',
        );

        // Act
        await resource.handleQuery(request);

        // Assert
        expect(authzHandler.queryCalled, isTrue);
        expect(authzHandler.lastQueryParams?['ownerId'], equals('user-123'));
        expect(authzHandler.lastAuthResult?.claims?.userId, equals('user-123'));
      });

      test('authorization success allows query to proceed', () async {
        // Arrange
        authzHandler.shouldAuthorize = true;

        final resource = CrudResource<TestUser, TestClaims>(
          path: '/users',
          repository: repository,
          serializer: serializer,
          authenticationHandler: authHandler,
          authorizationHandler: authzHandler,
          queryHandlers: {
            'ownerId': (repo, params, skip, take, authResult) async {
              return QueryResult<TestUser>([testUser], totalCount: 1);
            },
          },
        );

        final request = createRequest(
          path: '/users?ownerId=user-123',
        );

        // Act
        final response = await resource.handleQuery(request);

        // Assert
        expect(response.statusCode, equals(200));

        final bodyString = await response.readAsString();
        final body = jsonDecode(bodyString) as List;
        expect(body.length, equals(1));
      });

      test('authorization failure returns HTTP 403 Forbidden', () async {
        // Arrange
        authzHandler.shouldAuthorize = false;
        authzHandler.errorMessage =
            'You do not have permission to query this resource';

        final resource = CrudResource<TestUser, TestClaims>(
          path: '/users',
          repository: repository,
          serializer: serializer,
          authenticationHandler: authHandler,
          authorizationHandler: authzHandler,
          queryHandlers: {
            'ownerId': (repo, params, skip, take, authResult) async {
              return QueryResult<TestUser>([testUser], totalCount: 1);
            },
          },
        );

        final request = createRequest(
          path: '/users?ownerId=user-123',
        );

        // Act
        final response = await resource.handleQuery(request);

        // Assert
        expect(response.statusCode, equals(403));
      });

      test('RFC 7807 error response format for authorization failures',
          () async {
        // Arrange
        authzHandler.shouldAuthorize = false;
        authzHandler.errorMessage = 'Custom query authorization error';

        final resource = CrudResource<TestUser, TestClaims>(
          path: '/users',
          repository: repository,
          serializer: serializer,
          authenticationHandler: authHandler,
          authorizationHandler: authzHandler,
          queryHandlers: {
            'ownerId': (repo, params, skip, take, authResult) async {
              return QueryResult<TestUser>([testUser], totalCount: 1);
            },
          },
        );

        final request = createRequest(
          path: '/users?ownerId=user-123',
        );

        // Act
        final response = await resource.handleQuery(request);

        // Assert
        expect(response.statusCode, equals(403));
        expect(
          response.headers['Content-Type'],
          equals('application/problem+json'),
        );

        final bodyString = await response.readAsString();
        final body = jsonDecode(bodyString);
        expect(body['type'], equals('about:blank'));
        expect(body['title'], equals('Forbidden'));
        expect(body['status'], equals(403));
        expect(body['detail'], equals('Custom query authorization error'));
      });

      test('authorization is skipped for unfiltered queries', () async {
        // Arrange
        final inMemoryRepo = InMemoryRepository<TestUser>();
        await inMemoryRepo.save(testUser);

        final resource = CrudResource<TestUser, TestClaims>(
          path: '/users',
          repository: inMemoryRepo,
          serializer: serializer,
          authenticationHandler: authHandler,
          authorizationHandler: authzHandler,
          collectionHandler: (repo, params, skip, take, authResult) async {
            return QueryResult<TestUser>([testUser], totalCount: 1);
          },
        );

        final request = createRequest();

        // Act
        final response = await resource.handleQuery(request);

        // Assert
        expect(response.statusCode, equals(200));
        expect(authzHandler.queryCalled, isFalse);
      });

      test('authorization is skipped when no handler provided', () async {
        // Arrange
        final resource = CrudResource<TestUser, TestClaims>(
          path: '/users',
          repository: repository,
          serializer: serializer,
          authenticationHandler: authHandler,
          // No authorizationHandler provided
          queryHandlers: {
            'ownerId': (repo, params, skip, take, authResult) async {
              return QueryResult<TestUser>([testUser], totalCount: 1);
            },
          },
        );

        final request = createRequest(
          path: '/users?ownerId=user-123',
        );

        // Act
        final response = await resource.handleQuery(request);

        // Assert
        expect(response.statusCode, equals(200));
        expect(authzHandler.queryCalled, isFalse);
      });
    });

    group('Authorization without Authentication', () {
      test('authorization is skipped when authentication handler not provided',
          () async {
        // Arrange
        final resource = CrudResource<TestUser, TestClaims>(
          path: '/users',
          repository: repository,
          serializer: serializer,
          // No authenticationHandler provided
          authorizationHandler: authzHandler,
        );

        final requestBody = serializer.serialize(testUser);
        final request = createRequest(
          method: 'POST',
          headers: {'content-type': 'application/json'},
          body: requestBody,
        );

        // Act
        final response = await resource.handleCreate(request);

        // Assert
        expect(response.statusCode, equals(201));
        expect(authzHandler.createCalled, isFalse);
      });
    });

    group('Authorization with Authentication Failure', () {
      test('authorization is not called when authentication fails', () async {
        // Arrange
        authHandler.shouldAuthenticate = false;

        final resource = CrudResource<TestUser, TestClaims>(
          path: '/users',
          repository: repository,
          serializer: serializer,
          authenticationHandler: authHandler,
          authorizationHandler: authzHandler,
        );

        final requestBody = serializer.serialize(testUser);
        final request = createRequest(
          method: 'POST',
          headers: {'content-type': 'application/json'},
          body: requestBody,
        );

        // Act
        final response = await resource.handleCreate(request);

        // Assert
        expect(response.statusCode, equals(401));
        expect(authzHandler.createCalled, isFalse);
      });
    });
  });
}
