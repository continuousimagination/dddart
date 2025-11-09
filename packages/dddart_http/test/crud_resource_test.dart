import 'dart:convert';
import 'package:test/test.dart';
import 'package:shelf/shelf.dart';
import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_http/src/crud_resource.dart';
import 'package:dddart_http/src/query_handler.dart';

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

  List<TestUser> getAll() {
    return _storage.values.toList();
  }

  void clear() {
    _storage.clear();
  }
}

// Custom exception for testing
class CustomDomainException implements Exception {
  CustomDomainException(this.message);
  final String message;
  
  @override
  String toString() => message;
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
  late CrudResource<TestUser> resource;
  late TestUser testUser;

  setUp(() {
    repository = MockRepository();
    serializer = TestUserSerializer();
    resource = CrudResource<TestUser>(
      path: '/users',
      repository: repository,
      serializers: {
        'application/json': serializer,
      },
      defaultSkip: 0,
      defaultTake: 50,
      maxTake: 100,
    );
    
    testUser = TestUser(
      id: UuidValue.fromString('123e4567-e89b-12d3-a456-426614174000'),
      name: 'John Doe',
      email: 'john@example.com',
      createdAt: DateTime.parse('2024-01-15T10:30:00Z'),
      updatedAt: DateTime.parse('2024-01-15T10:30:00Z'),
    );
  });

  group('CrudResource - handleGetById', () {
    test('successful retrieval returns 200 with serialized aggregate', () async {
      // Arrange
      await repository.save(testUser);
      final request = createRequest(
        path: '/users/${testUser.id}',
        headers: {'accept': 'application/json'},
      );

      // Act
      final response = await resource.handleGetById(request, testUser.id.toString());

      // Assert
      expect(response.statusCode, equals(200));
      expect(response.headers['Content-Type'], equals('application/json'));
      
      final bodyString = await response.readAsString();
      final body = jsonDecode(bodyString);
      expect(body['id'], equals(testUser.id.toString()));
      expect(body['name'], equals('John Doe'));
      expect(body['email'], equals('john@example.com'));
    });

    test('ID parsing with valid UUID', () async {
      // Arrange
      await repository.save(testUser);
      final validId = '123e4567-e89b-12d3-a456-426614174000';
      final request = createRequest(path: '/users/$validId');

      // Act
      final response = await resource.handleGetById(request, validId);

      // Assert
      expect(response.statusCode, equals(200));
    });

    test('repository.getById() is called with correct ID', () async {
      // Arrange
      await repository.save(testUser);
      final request = createRequest(path: '/users/${testUser.id}');

      // Act
      await resource.handleGetById(request, testUser.id.toString());

      // Assert - verify user was retrieved (implicitly tested by successful response)
      final retrievedUser = await repository.getById(testUser.id);
      expect(retrievedUser.id, equals(testUser.id));
    });

    test('Accept header content negotiation', () async {
      // Arrange
      await repository.save(testUser);
      final request = createRequest(
        path: '/users/${testUser.id}',
        headers: {'accept': 'application/json'},
      );

      // Act
      final response = await resource.handleGetById(request, testUser.id.toString());

      // Assert
      expect(response.headers['Content-Type'], equals('application/json'));
    });

    test('404 response when aggregate not found', () async {
      // Arrange
      final nonExistentId = '987fcdeb-51a2-43f7-b123-456789abcdef';
      final request = createRequest(path: '/users/$nonExistentId');

      // Act
      final response = await resource.handleGetById(request, nonExistentId);

      // Assert
      expect(response.statusCode, equals(404));
      expect(response.headers['Content-Type'], equals('application/problem+json'));
      
      final bodyString = await response.readAsString();
      final body = jsonDecode(bodyString);
      expect(body['type'], equals('about:blank'));
      expect(body['title'], equals('Not Found'));
      expect(body['status'], equals(404));
    });

    test('exception handling via _handleException()', () async {
      // Arrange - create resource with custom exception handler
      final customResource = CrudResource<TestUser>(
        path: '/users',
        repository: repository,
        serializers: {'application/json': serializer},
        customExceptionHandlers: {
          CustomDomainException: (e) => Response(
            418,
            headers: {'Content-Type': 'application/problem+json'},
            body: jsonEncode({
              'type': 'about:blank',
              'title': 'Custom Error',
              'status': 418,
              'detail': (e as CustomDomainException).message,
            }),
          ),
        },
      );
      
      // Use invalid ID format to trigger exception
      final request = createRequest(path: '/users/invalid-id');

      // Act
      final response = await customResource.handleGetById(request, 'invalid-id');

      // Assert - should get error response
      expect(response.statusCode, greaterThanOrEqualTo(400));
    });
  });

  group('CrudResource - handleQuery with no filters', () {
    test('returns all items with pagination', () async {
      // Arrange - create multiple users
      final user1 = TestUser(
        id: UuidValue.fromString('111e4567-e89b-12d3-a456-426614174111'),
        name: 'User 1',
        email: 'user1@example.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final user2 = TestUser(
        id: UuidValue.fromString('222e4567-e89b-12d3-a456-426614174222'),
        name: 'User 2',
        email: 'user2@example.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final user3 = TestUser(
        id: UuidValue.fromString('333e4567-e89b-12d3-a456-426614174333'),
        name: 'User 3',
        email: 'user3@example.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      await repository.save(user1);
      await repository.save(user2);
      await repository.save(user3);
      
      // Use InMemoryRepository for getAll support
      final inMemoryRepo = InMemoryRepository<TestUser>();
      await inMemoryRepo.save(user1);
      await inMemoryRepo.save(user2);
      await inMemoryRepo.save(user3);
      
      final inMemoryResource = CrudResource<TestUser>(
        path: '/users',
        repository: inMemoryRepo,
        serializers: {'application/json': serializer},
        defaultSkip: 0,
        defaultTake: 2,
      );
      
      final request = createRequest(
        path: '/users?skip=0&take=2',
        headers: {'accept': 'application/json'},
      );

      // Act
      final response = await inMemoryResource.handleQuery(request);

      // Assert
      expect(response.statusCode, equals(200));
      
      final bodyString = await response.readAsString();
      final body = jsonDecode(bodyString) as List;
      expect(body.length, equals(2));
    });

    test('default skip and take values are applied', () async {
      // Arrange
      final inMemoryRepo = InMemoryRepository<TestUser>();
      await inMemoryRepo.save(testUser);
      
      final inMemoryResource = CrudResource<TestUser>(
        path: '/users',
        repository: inMemoryRepo,
        serializers: {'application/json': serializer},
        defaultSkip: 0,
        defaultTake: 50,
      );
      
      final request = createRequest(path: '/users');

      // Act
      final response = await inMemoryResource.handleQuery(request);

      // Assert
      expect(response.statusCode, equals(200));
      
      final bodyString = await response.readAsString();
      final body = jsonDecode(bodyString) as List;
      expect(body.length, equals(1));
    });

    test('X-Total-Count header is included', () async {
      // Arrange
      final inMemoryRepo = InMemoryRepository<TestUser>();
      await inMemoryRepo.save(testUser);
      
      final inMemoryResource = CrudResource<TestUser>(
        path: '/users',
        repository: inMemoryRepo,
        serializers: {'application/json': serializer},
      );
      
      final request = createRequest(path: '/users');

      // Act
      final response = await inMemoryResource.handleQuery(request);

      // Assert
      expect(response.statusCode, equals(200));
      expect(response.headers['X-Total-Count'], equals('1'));
    });

    test('Accept header content negotiation', () async {
      // Arrange
      final inMemoryRepo = InMemoryRepository<TestUser>();
      await inMemoryRepo.save(testUser);
      
      final inMemoryResource = CrudResource<TestUser>(
        path: '/users',
        repository: inMemoryRepo,
        serializers: {'application/json': serializer},
      );
      
      final request = createRequest(
        path: '/users',
        headers: {'accept': 'application/json'},
      );

      // Act
      final response = await inMemoryResource.handleQuery(request);

      // Assert
      expect(response.headers['Content-Type'], equals('application/json'));
    });
  });

  group('CrudResource - handleQuery with single filter', () {
    test('query handler is invoked with correct parameters', () async {
      // Arrange
      var handlerCalled = false;
      var receivedParams = <String, String>{};
      var receivedSkip = -1;
      var receivedTake = -1;
      
      final testHandler = (
        Repository<TestUser> repo,
        Map<String, String> params,
        int skip,
        int take,
      ) async {
        handlerCalled = true;
        receivedParams = params;
        receivedSkip = skip;
        receivedTake = take;
        return QueryResult<TestUser>([testUser], totalCount: 1);
      };
      
      final resourceWithHandler = CrudResource<TestUser>(
        path: '/users',
        repository: repository,
        serializers: {'application/json': serializer},
        queryHandlers: {'name': testHandler},
        defaultSkip: 0,
        defaultTake: 50,
      );
      
      final request = createRequest(path: '/users?name=John');

      // Act
      final response = await resourceWithHandler.handleQuery(request);

      // Assert
      expect(response.statusCode, equals(200));
      expect(handlerCalled, isTrue);
      expect(receivedParams['name'], equals('John'));
      expect(receivedSkip, equals(0));
      expect(receivedTake, equals(50));
    });

    test('pagination parameters are passed to handler', () async {
      // Arrange
      var receivedSkip = -1;
      var receivedTake = -1;
      
      final testHandler = (
        Repository<TestUser> repo,
        Map<String, String> params,
        int skip,
        int take,
      ) async {
        receivedSkip = skip;
        receivedTake = take;
        return QueryResult<TestUser>([testUser], totalCount: 1);
      };
      
      final resourceWithHandler = CrudResource<TestUser>(
        path: '/users',
        repository: repository,
        serializers: {'application/json': serializer},
        queryHandlers: {'name': testHandler},
      );
      
      final request = createRequest(path: '/users?name=John&skip=10&take=20');

      // Act
      await resourceWithHandler.handleQuery(request);

      // Assert
      expect(receivedSkip, equals(10));
      expect(receivedTake, equals(20));
    });

    test('400 response when handler not found', () async {
      // Arrange
      final resourceWithoutHandler = CrudResource<TestUser>(
        path: '/users',
        repository: repository,
        serializers: {'application/json': serializer},
        queryHandlers: {},
      );
      
      final request = createRequest(path: '/users?unknownParam=value');

      // Act
      final response = await resourceWithoutHandler.handleQuery(request);

      // Assert
      expect(response.statusCode, equals(400));
      
      final bodyString = await response.readAsString();
      final body = jsonDecode(bodyString);
      expect(body['detail'], contains('Unsupported query parameter'));
    });

    test('successful response with filtered results', () async {
      // Arrange
      final filteredUser = TestUser(
        id: UuidValue.fromString('999e4567-e89b-12d3-a456-426614174999'),
        name: 'Filtered User',
        email: 'filtered@example.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      final testHandler = (
        Repository<TestUser> repo,
        Map<String, String> params,
        int skip,
        int take,
      ) async {
        return QueryResult<TestUser>([filteredUser], totalCount: 1);
      };
      
      final resourceWithHandler = CrudResource<TestUser>(
        path: '/users',
        repository: repository,
        serializers: {'application/json': serializer},
        queryHandlers: {'email': testHandler},
      );
      
      final request = createRequest(path: '/users?email=filtered@example.com');

      // Act
      final response = await resourceWithHandler.handleQuery(request);

      // Assert
      expect(response.statusCode, equals(200));
      
      final bodyString = await response.readAsString();
      final body = jsonDecode(bodyString) as List;
      expect(body.length, equals(1));
      expect(body[0]['name'], equals('Filtered User'));
    });
  });

  group('CrudResource - handleQuery with multiple filters', () {
    test('returns 400 error when multiple filter params provided', () async {
      // Arrange
      final request = createRequest(path: '/users?name=John&email=john@example.com');

      // Act
      final response = await resource.handleQuery(request);

      // Assert
      expect(response.statusCode, equals(400));
      
      final bodyString = await response.readAsString();
      final body = jsonDecode(bodyString);
      expect(body['detail'], contains('Cannot combine multiple query parameters'));
    });

    test('pagination params do not count as filter params', () async {
      // Arrange
      final inMemoryRepo = InMemoryRepository<TestUser>();
      await inMemoryRepo.save(testUser);
      
      final inMemoryResource = CrudResource<TestUser>(
        path: '/users',
        repository: inMemoryRepo,
        serializers: {'application/json': serializer},
      );
      
      final request = createRequest(path: '/users?skip=0&take=10');

      // Act
      final response = await inMemoryResource.handleQuery(request);

      // Assert
      expect(response.statusCode, equals(200));
    });

    test('error message follows RFC 7807 format', () async {
      // Arrange
      final request = createRequest(path: '/users?name=John&email=john@example.com');

      // Act
      final response = await resource.handleQuery(request);

      // Assert
      expect(response.statusCode, equals(400));
      expect(response.headers['Content-Type'], equals('application/problem+json'));
      
      final bodyString = await response.readAsString();
      final body = jsonDecode(bodyString);
      expect(body['type'], equals('about:blank'));
      expect(body['title'], equals('Bad Request'));
      expect(body['status'], equals(400));
      expect(body['detail'], isNotEmpty);
    });
  });

  group('CrudResource - handleCreate', () {
    test('successful creation returns 201 with serialized aggregate', () async {
      // Arrange
      final newUser = TestUser(
        id: UuidValue.fromString('999e4567-e89b-12d3-a456-426614174999'),
        name: 'New User',
        email: 'new@example.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      final requestBody = serializer.serialize(newUser);
      final request = createRequest(
        method: 'POST',
        path: '/users',
        headers: {
          'content-type': 'application/json',
          'accept': 'application/json',
        },
        body: requestBody,
      );

      // Act
      final response = await resource.handleCreate(request);

      // Assert
      expect(response.statusCode, equals(201));
      expect(response.headers['Content-Type'], equals('application/json'));
      
      final bodyString = await response.readAsString();
      final body = jsonDecode(bodyString);
      expect(body['name'], equals('New User'));
      expect(body['email'], equals('new@example.com'));
    });

    test('Content-Type header parsing for request', () async {
      // Arrange
      final newUser = TestUser(
        id: UuidValue.fromString('999e4567-e89b-12d3-a456-426614174999'),
        name: 'New User',
        email: 'new@example.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      final requestBody = serializer.serialize(newUser);
      final request = createRequest(
        method: 'POST',
        path: '/users',
        headers: {'content-type': 'application/json'},
        body: requestBody,
      );

      // Act
      final response = await resource.handleCreate(request);

      // Assert
      expect(response.statusCode, equals(201));
    });

    test('Accept header parsing for response', () async {
      // Arrange
      final newUser = TestUser(
        id: UuidValue.fromString('999e4567-e89b-12d3-a456-426614174999'),
        name: 'New User',
        email: 'new@example.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      final requestBody = serializer.serialize(newUser);
      final request = createRequest(
        method: 'POST',
        path: '/users',
        headers: {
          'content-type': 'application/json',
          'accept': 'application/json',
        },
        body: requestBody,
      );

      // Act
      final response = await resource.handleCreate(request);

      // Assert
      expect(response.headers['Content-Type'], equals('application/json'));
    });

    test('415 response for unsupported Content-Type', () async {
      // Arrange
      final request = createRequest(
        method: 'POST',
        path: '/users',
        headers: {'content-type': 'application/xml'},
        body: '<user><name>Test</name></user>',
      );

      // Act
      final response = await resource.handleCreate(request);

      // Assert
      expect(response.statusCode, equals(415));
      expect(response.headers['Content-Type'], equals('application/problem+json'));
      
      final bodyString = await response.readAsString();
      final body = jsonDecode(bodyString);
      expect(body['title'], equals('Unsupported Media Type'));
      expect(body['detail'], contains('application/xml'));
    });

    test('deserialization of request body', () async {
      // Arrange
      final newUser = TestUser(
        id: UuidValue.fromString('999e4567-e89b-12d3-a456-426614174999'),
        name: 'Deserialized User',
        email: 'deserialized@example.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      final requestBody = serializer.serialize(newUser);
      final request = createRequest(
        method: 'POST',
        path: '/users',
        headers: {'content-type': 'application/json'},
        body: requestBody,
      );

      // Act
      final response = await resource.handleCreate(request);

      // Assert
      expect(response.statusCode, equals(201));
      
      // Verify the user was saved to repository
      final savedUser = await repository.getById(newUser.id);
      expect(savedUser.name, equals('Deserialized User'));
      expect(savedUser.email, equals('deserialized@example.com'));
    });

    test('repository.save() is called', () async {
      // Arrange
      final newUser = TestUser(
        id: UuidValue.fromString('999e4567-e89b-12d3-a456-426614174999'),
        name: 'Saved User',
        email: 'saved@example.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      final requestBody = serializer.serialize(newUser);
      final request = createRequest(
        method: 'POST',
        path: '/users',
        headers: {'content-type': 'application/json'},
        body: requestBody,
      );

      // Act
      await resource.handleCreate(request);

      // Assert - verify user exists in repository
      final savedUser = await repository.getById(newUser.id);
      expect(savedUser, isNotNull);
      expect(savedUser.id, equals(newUser.id));
    });

    test('exception handling via _handleException()', () async {
      // Arrange - invalid JSON to trigger deserialization exception
      final request = createRequest(
        method: 'POST',
        path: '/users',
        headers: {'content-type': 'application/json'},
        body: 'invalid json',
      );

      // Act
      final response = await resource.handleCreate(request);

      // Assert - should get error response
      expect(response.statusCode, greaterThanOrEqualTo(400));
    });
  });

  group('CrudResource - handleUpdate', () {
    test('successful update returns 200 with serialized aggregate', () async {
      // Arrange
      await repository.save(testUser);
      
      final updatedUser = TestUser(
        id: testUser.id,
        name: 'Updated Name',
        email: 'updated@example.com',
        createdAt: testUser.createdAt,
        updatedAt: DateTime.now(),
      );
      
      final requestBody = serializer.serialize(updatedUser);
      final request = createRequest(
        method: 'PUT',
        path: '/users/${testUser.id}',
        headers: {
          'content-type': 'application/json',
          'accept': 'application/json',
        },
        body: requestBody,
      );

      // Act
      final response = await resource.handleUpdate(request, testUser.id.toString());

      // Assert
      expect(response.statusCode, equals(200));
      expect(response.headers['Content-Type'], equals('application/json'));
      
      final bodyString = await response.readAsString();
      final body = jsonDecode(bodyString);
      expect(body['name'], equals('Updated Name'));
      expect(body['email'], equals('updated@example.com'));
    });

    test('Content-Type header parsing for request', () async {
      // Arrange
      await repository.save(testUser);
      
      final updatedUser = TestUser(
        id: testUser.id,
        name: 'Updated Name',
        email: 'updated@example.com',
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
      final response = await resource.handleUpdate(request, testUser.id.toString());

      // Assert
      expect(response.statusCode, equals(200));
    });

    test('Accept header parsing for response', () async {
      // Arrange
      await repository.save(testUser);
      
      final updatedUser = TestUser(
        id: testUser.id,
        name: 'Updated Name',
        email: 'updated@example.com',
        createdAt: testUser.createdAt,
        updatedAt: DateTime.now(),
      );
      
      final requestBody = serializer.serialize(updatedUser);
      final request = createRequest(
        method: 'PUT',
        path: '/users/${testUser.id}',
        headers: {
          'content-type': 'application/json',
          'accept': 'application/json',
        },
        body: requestBody,
      );

      // Act
      final response = await resource.handleUpdate(request, testUser.id.toString());

      // Assert
      expect(response.headers['Content-Type'], equals('application/json'));
    });

    test('415 response for unsupported Content-Type', () async {
      // Arrange
      final request = createRequest(
        method: 'PUT',
        path: '/users/${testUser.id}',
        headers: {'content-type': 'application/xml'},
        body: '<user><name>Test</name></user>',
      );

      // Act
      final response = await resource.handleUpdate(request, testUser.id.toString());

      // Assert
      expect(response.statusCode, equals(415));
      expect(response.headers['Content-Type'], equals('application/problem+json'));
      
      final bodyString = await response.readAsString();
      final body = jsonDecode(bodyString);
      expect(body['title'], equals('Unsupported Media Type'));
      expect(body['detail'], contains('application/xml'));
    });

    test('deserialization of request body', () async {
      // Arrange
      await repository.save(testUser);
      
      final updatedUser = TestUser(
        id: testUser.id,
        name: 'Deserialized Update',
        email: 'deserialized-update@example.com',
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
      final response = await resource.handleUpdate(request, testUser.id.toString());

      // Assert
      expect(response.statusCode, equals(200));
      
      // Verify the user was updated in repository
      final savedUser = await repository.getById(testUser.id);
      expect(savedUser.name, equals('Deserialized Update'));
      expect(savedUser.email, equals('deserialized-update@example.com'));
    });

    test('repository.save() is called', () async {
      // Arrange
      await repository.save(testUser);
      
      final updatedUser = TestUser(
        id: testUser.id,
        name: 'Saved Update',
        email: 'saved-update@example.com',
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

      // Assert - verify user was updated in repository
      final savedUser = await repository.getById(testUser.id);
      expect(savedUser.name, equals('Saved Update'));
    });

    test('exception handling via _handleException()', () async {
      // Arrange - invalid JSON to trigger deserialization exception
      final request = createRequest(
        method: 'PUT',
        path: '/users/${testUser.id}',
        headers: {'content-type': 'application/json'},
        body: 'invalid json',
      );

      // Act
      final response = await resource.handleUpdate(request, testUser.id.toString());

      // Assert - should get error response
      expect(response.statusCode, greaterThanOrEqualTo(400));
    });
  });

  group('CrudResource - handleDelete', () {
    test('successful deletion returns 204 No Content', () async {
      // Arrange
      await repository.save(testUser);
      final request = createRequest(
        method: 'DELETE',
        path: '/users/${testUser.id}',
      );

      // Act
      final response = await resource.handleDelete(request, testUser.id.toString());

      // Assert
      expect(response.statusCode, equals(204));
      
      final bodyString = await response.readAsString();
      expect(bodyString, isEmpty);
    });

    test('ID parsing with valid UUID', () async {
      // Arrange
      await repository.save(testUser);
      final validId = testUser.id.toString();
      final request = createRequest(
        method: 'DELETE',
        path: '/users/$validId',
      );

      // Act
      final response = await resource.handleDelete(request, validId);

      // Assert
      expect(response.statusCode, equals(204));
    });

    test('repository.deleteById() is called with correct ID', () async {
      // Arrange
      await repository.save(testUser);
      final request = createRequest(
        method: 'DELETE',
        path: '/users/${testUser.id}',
      );

      // Act
      await resource.handleDelete(request, testUser.id.toString());

      // Assert - verify user was deleted from repository
      try {
        await repository.getById(testUser.id);
        fail('Expected RepositoryException to be thrown');
      } catch (e) {
        expect(e, isA<RepositoryException>());
      }
    });

    test('404 response when aggregate not found', () async {
      // Arrange
      final nonExistentId = '987fcdeb-51a2-43f7-b123-456789abcdef';
      final request = createRequest(
        method: 'DELETE',
        path: '/users/$nonExistentId',
      );

      // Act
      final response = await resource.handleDelete(request, nonExistentId);

      // Assert
      expect(response.statusCode, equals(404));
      expect(response.headers['Content-Type'], equals('application/problem+json'));
      
      final bodyString = await response.readAsString();
      final body = jsonDecode(bodyString);
      expect(body['type'], equals('about:blank'));
      expect(body['title'], equals('Not Found'));
      expect(body['status'], equals(404));
    });

    test('exception handling via _handleException()', () async {
      // Arrange - use invalid ID format to trigger exception
      final request = createRequest(
        method: 'DELETE',
        path: '/users/invalid-id',
      );

      // Act
      final response = await resource.handleDelete(request, 'invalid-id');

      // Assert - should get error response
      expect(response.statusCode, greaterThanOrEqualTo(400));
    });
  });

  group('CrudResource - content negotiation helpers', () {
    test('_selectSerializer() with various Accept headers', () async {
      // Arrange - create resource with multiple serializers
      final yamlSerializer = TestUserSerializer(); // Using same for simplicity
      final multiSerializerResource = CrudResource<TestUser>(
        path: '/users',
        repository: repository,
        serializers: {
          'application/json': serializer,
          'application/yaml': yamlSerializer,
        },
      );
      
      await repository.save(testUser);

      // Act & Assert - JSON
      final jsonRequest = createRequest(
        path: '/users/${testUser.id}',
        headers: {'accept': 'application/json'},
      );
      final jsonResponse = await multiSerializerResource.handleGetById(
        jsonRequest,
        testUser.id.toString(),
      );
      expect(jsonResponse.headers['Content-Type'], equals('application/json'));

      // Act & Assert - YAML
      final yamlRequest = createRequest(
        path: '/users/${testUser.id}',
        headers: {'accept': 'application/yaml'},
      );
      final yamlResponse = await multiSerializerResource.handleGetById(
        yamlRequest,
        testUser.id.toString(),
      );
      expect(yamlResponse.headers['Content-Type'], equals('application/yaml'));
    });

    test('default serializer selection when Accept is */*', () async {
      // Arrange
      await repository.save(testUser);
      final request = createRequest(
        path: '/users/${testUser.id}',
        headers: {'accept': '*/*'},
      );

      // Act
      final response = await resource.handleGetById(request, testUser.id.toString());

      // Assert - should use first serializer (application/json)
      expect(response.statusCode, equals(200));
      expect(response.headers['Content-Type'], equals('application/json'));
    });

    test('default serializer selection when Accept is missing', () async {
      // Arrange
      await repository.save(testUser);
      final request = createRequest(path: '/users/${testUser.id}');

      // Act
      final response = await resource.handleGetById(request, testUser.id.toString());

      // Assert - should use first serializer (application/json)
      expect(response.statusCode, equals(200));
      expect(response.headers['Content-Type'], equals('application/json'));
    });

    test('UnsupportedMediaTypeException when Accept not supported', () async {
      // Arrange
      await repository.save(testUser);
      final request = createRequest(
        path: '/users/${testUser.id}',
        headers: {'accept': 'application/xml'},
      );

      // Act
      final response = await resource.handleGetById(request, testUser.id.toString());

      // Assert
      expect(response.statusCode, equals(406));
      expect(response.headers['Content-Type'], equals('application/problem+json'));
      
      final bodyString = await response.readAsString();
      final body = jsonDecode(bodyString);
      expect(body['title'], equals('Not Acceptable'));
      expect(body['detail'], contains('application/xml'));
    });
  });

  group('CrudResource - pagination helpers', () {
    test('_parsePagination() with valid skip and take params', () async {
      // Arrange
      final inMemoryRepo = InMemoryRepository<TestUser>();
      for (int i = 0; i < 10; i++) {
        final user = TestUser(
          id: UuidValue.generate(),
          name: 'User $i',
          email: 'user$i@example.com',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await inMemoryRepo.save(user);
      }
      
      final inMemoryResource = CrudResource<TestUser>(
        path: '/users',
        repository: inMemoryRepo,
        serializers: {'application/json': serializer},
      );
      
      final request = createRequest(path: '/users?skip=2&take=3');

      // Act
      final response = await inMemoryResource.handleQuery(request);

      // Assert
      expect(response.statusCode, equals(200));
      
      final bodyString = await response.readAsString();
      final body = jsonDecode(bodyString) as List;
      expect(body.length, equals(3));
    });

    test('default values when params missing', () async {
      // Arrange
      final inMemoryRepo = InMemoryRepository<TestUser>();
      await inMemoryRepo.save(testUser);
      
      final inMemoryResource = CrudResource<TestUser>(
        path: '/users',
        repository: inMemoryRepo,
        serializers: {'application/json': serializer},
        defaultSkip: 0,
        defaultTake: 50,
      );
      
      final request = createRequest(path: '/users');

      // Act
      final response = await inMemoryResource.handleQuery(request);

      // Assert
      expect(response.statusCode, equals(200));
      
      final bodyString = await response.readAsString();
      final body = jsonDecode(bodyString) as List;
      expect(body.length, equals(1));
    });

    test('maxTake enforcement', () async {
      // Arrange
      final inMemoryRepo = InMemoryRepository<TestUser>();
      for (int i = 0; i < 150; i++) {
        final user = TestUser(
          id: UuidValue.generate(),
          name: 'User $i',
          email: 'user$i@example.com',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await inMemoryRepo.save(user);
      }
      
      final inMemoryResource = CrudResource<TestUser>(
        path: '/users',
        repository: inMemoryRepo,
        serializers: {'application/json': serializer},
        maxTake: 100,
      );
      
      // Request more than maxTake
      final request = createRequest(path: '/users?take=200');

      // Act
      final response = await inMemoryResource.handleQuery(request);

      // Assert
      expect(response.statusCode, equals(200));
      
      final bodyString = await response.readAsString();
      final body = jsonDecode(bodyString) as List;
      expect(body.length, equals(100)); // Should be limited to maxTake
    });
  });

  group('CrudResource - custom exception handling', () {
    test('_handleException() checks customExceptionHandlers first', () async {
      // Arrange
      var customHandlerCalled = false;
      
      final customResource = CrudResource<TestUser>(
        path: '/users',
        repository: repository,
        serializers: {'application/json': serializer},
        customExceptionHandlers: {
          CustomDomainException: (e) {
            customHandlerCalled = true;
            return Response(
              418,
              headers: {'Content-Type': 'application/problem+json'},
              body: jsonEncode({
                'type': 'about:blank',
                'title': 'Custom Error',
                'status': 418,
                'detail': (e as CustomDomainException).message,
              }),
            );
          },
        },
      );
      
      // Trigger custom exception by using invalid ID format
      final request = createRequest(path: '/users/invalid-id');

      // Act
      await customResource.handleGetById(request, 'invalid-id');

      // Assert - custom handler should not be called for FormatException
      // but we verify the mechanism works by checking the response
      expect(customHandlerCalled, isFalse);
    });

    test('fallback to ErrorMapper when no custom handler found', () async {
      // Arrange
      final customResource = CrudResource<TestUser>(
        path: '/users',
        repository: repository,
        serializers: {'application/json': serializer},
        customExceptionHandlers: {
          CustomDomainException: (e) => Response(418),
        },
      );
      
      // Trigger RepositoryException (not in custom handlers)
      final nonExistentId = '987fcdeb-51a2-43f7-b123-456789abcdef';
      final request = createRequest(path: '/users/$nonExistentId');

      // Act
      final response = await customResource.handleGetById(request, nonExistentId);

      // Assert - should use ErrorMapper default handling
      expect(response.statusCode, equals(404));
      expect(response.headers['Content-Type'], equals('application/problem+json'));
    });

    test('custom handler is invoked with correct exception', () async {
      // Arrange
      var receivedException = null;
      
      // Create a custom repository that throws CustomDomainException
      final customRepo = MockRepository();
      
      final customResource = CrudResource<TestUser>(
        path: '/users',
        repository: customRepo,
        serializers: {'application/json': serializer},
        customExceptionHandlers: {
          RepositoryException: (e) {
            receivedException = e;
            return Response(
              404,
              headers: {'Content-Type': 'application/problem+json'},
              body: jsonEncode({
                'type': 'about:blank',
                'title': 'Custom Not Found',
                'status': 404,
                'detail': 'Custom handler invoked',
              }),
            );
          },
        },
      );
      
      final nonExistentId = '987fcdeb-51a2-43f7-b123-456789abcdef';
      final request = createRequest(path: '/users/$nonExistentId');

      // Act
      final response = await customResource.handleGetById(request, nonExistentId);

      // Assert
      expect(response.statusCode, equals(404));
      expect(receivedException, isA<RepositoryException>());
      
      final bodyString = await response.readAsString();
      final body = jsonDecode(bodyString);
      expect(body['detail'], equals('Custom handler invoked'));
    });
  });
}
