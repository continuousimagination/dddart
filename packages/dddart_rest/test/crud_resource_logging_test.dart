import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_rest/src/crud_resource.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:logging/logging.dart';
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

// Serializer that throws exception for testing deserialization failures
class FailingSerializer implements Serializer<TestUser> {
  @override
  String serialize(TestUser user, [dynamic config]) {
    return jsonEncode({'id': user.id.toString()});
  }

  @override
  TestUser deserialize(String data, [dynamic config]) {
    throw const FormatException('Deserialization failed');
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
  late CrudResource<TestUser, dynamic> resource;
  late TestUser testUser;
  late List<LogRecord> logRecords;

  setUp(() {
    repository = MockRepository();
    serializer = TestUserSerializer();
    resource = CrudResource<TestUser, dynamic>(
      path: 'users',
      repository: repository,
      serializers: {
        'application/json': serializer,
      },
    );

    testUser = TestUser(
      id: UuidValue.fromString('123e4567-e89b-12d3-a456-426614174000'),
      name: 'John Doe',
      email: 'john@example.com',
      createdAt: DateTime.parse('2024-01-15T10:30:00Z'),
      updatedAt: DateTime.parse('2024-01-15T10:30:00Z'),
    );

    // Set up logging capture
    logRecords = [];
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      if (record.loggerName == 'dddart.rest') {
        logRecords.add(record);
      }
    });
  });

  tearDown(() {
    Logger.root.clearListeners();
    repository.clear();
    logRecords.clear();
  });

  group('CrudResource Logging - Request Logging', () {
    test('logs GET request at INFO level with method, path, and aggregate type',
        () async {
      // Arrange
      await repository.save(testUser);
      final request = createRequest(
        path: '/users/${testUser.id}',
        headers: {'accept': 'application/json'},
      );

      // Act
      await resource.handleGetById(request, testUser.id.toString());

      // Assert
      final infoLogs = logRecords.where((r) => r.level == Level.INFO).toList();
      expect(infoLogs.length, equals(1));
      expect(infoLogs[0].message, contains('GET'));
      expect(infoLogs[0].message, contains('/users/${testUser.id}'));
      expect(infoLogs[0].message, contains('TestUser'));
    });

    test('logs POST request at INFO level', () async {
      // Arrange
      final newUser = TestUser(
        id: UuidValue.generate(),
        name: 'New User',
        email: 'new@example.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final requestBody = serializer.serialize(newUser);
      final request = createRequest(
        method: 'POST',
        headers: {'content-type': 'application/json'},
        body: requestBody,
      );

      // Act
      await resource.handleCreate(request);

      // Assert
      final infoLogs = logRecords.where((r) => r.level == Level.INFO).toList();
      expect(infoLogs.length, equals(1));
      expect(infoLogs[0].message, contains('POST'));
      expect(infoLogs[0].message, contains('/users'));
      expect(infoLogs[0].message, contains('TestUser'));
    });

    test('logs PUT request at INFO level', () async {
      // Arrange
      await repository.save(testUser);
      final requestBody = serializer.serialize(testUser);
      final request = createRequest(
        method: 'PUT',
        path: '/users/${testUser.id}',
        headers: {'content-type': 'application/json'},
        body: requestBody,
      );

      // Act
      await resource.handleUpdate(request, testUser.id.toString());

      // Assert
      final infoLogs = logRecords.where((r) => r.level == Level.INFO).toList();
      expect(infoLogs.length, equals(1));
      expect(infoLogs[0].message, contains('PUT'));
      expect(infoLogs[0].message, contains('/users/${testUser.id}'));
      expect(infoLogs[0].message, contains('TestUser'));
    });

    test('logs DELETE request at INFO level', () async {
      // Arrange
      await repository.save(testUser);
      final request = createRequest(
        method: 'DELETE',
        path: '/users/${testUser.id}',
      );

      // Act
      await resource.handleDelete(request, testUser.id.toString());

      // Assert
      final infoLogs = logRecords.where((r) => r.level == Level.INFO).toList();
      expect(infoLogs.length, equals(1));
      expect(infoLogs[0].message, contains('DELETE'));
      expect(infoLogs[0].message, contains('/users/${testUser.id}'));
      expect(infoLogs[0].message, contains('TestUser'));
    });

    test('logs query request at INFO level with query string', () async {
      // Arrange
      final inMemoryRepo = InMemoryRepository<TestUser>();
      await inMemoryRepo.save(testUser);

      final inMemoryResource = CrudResource<TestUser, dynamic>(
        path: 'users',
        repository: inMemoryRepo,
        serializers: {'application/json': serializer},
      );

      final request = createRequest(path: '/users?skip=0&take=10');

      // Act
      await inMemoryResource.handleQuery(request);

      // Assert
      final infoLogs = logRecords.where((r) => r.level == Level.INFO).toList();
      expect(infoLogs.length, equals(1));
      expect(infoLogs[0].message, contains('GET'));
      expect(infoLogs[0].message, contains('/users'));
      expect(infoLogs[0].message, contains('skip=0&take=10'));
    });
  });

  group('CrudResource Logging - Response Logging', () {
    test('logs successful GET response at FINE level with status code',
        () async {
      // Arrange
      await repository.save(testUser);
      final request = createRequest(
        path: '/users/${testUser.id}',
        headers: {'accept': 'application/json'},
      );

      // Act
      await resource.handleGetById(request, testUser.id.toString());

      // Assert
      final fineLogs = logRecords.where((r) => r.level == Level.FINE).toList();
      expect(fineLogs.length, equals(1));
      expect(fineLogs[0].message, contains('200'));
    });

    test('logs successful POST response at FINE level with status code',
        () async {
      // Arrange
      final newUser = TestUser(
        id: UuidValue.generate(),
        name: 'New User',
        email: 'new@example.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final requestBody = serializer.serialize(newUser);
      final request = createRequest(
        method: 'POST',
        headers: {'content-type': 'application/json'},
        body: requestBody,
      );

      // Act
      await resource.handleCreate(request);

      // Assert
      final fineLogs = logRecords.where((r) => r.level == Level.FINE).toList();
      expect(fineLogs.length, equals(1));
      expect(fineLogs[0].message, contains('201'));
    });

    test('logs successful PUT response at FINE level with status code',
        () async {
      // Arrange
      await repository.save(testUser);
      final requestBody = serializer.serialize(testUser);
      final request = createRequest(
        method: 'PUT',
        path: '/users/${testUser.id}',
        headers: {'content-type': 'application/json'},
        body: requestBody,
      );

      // Act
      await resource.handleUpdate(request, testUser.id.toString());

      // Assert
      final fineLogs = logRecords.where((r) => r.level == Level.FINE).toList();
      expect(fineLogs.length, equals(1));
      expect(fineLogs[0].message, contains('200'));
    });

    test('logs successful DELETE response at FINE level with status code',
        () async {
      // Arrange
      await repository.save(testUser);
      final request = createRequest(
        method: 'DELETE',
        path: '/users/${testUser.id}',
      );

      // Act
      await resource.handleDelete(request, testUser.id.toString());

      // Assert
      final fineLogs = logRecords.where((r) => r.level == Level.FINE).toList();
      expect(fineLogs.length, equals(1));
      expect(fineLogs[0].message, contains('204'));
    });

    test('logs 415 response at FINE level for unsupported media type',
        () async {
      // Arrange
      final request = createRequest(
        method: 'POST',
        headers: {'content-type': 'application/xml'},
        body: '<user><name>Test</name></user>',
      );

      // Act
      await resource.handleCreate(request);

      // Assert
      final fineLogs = logRecords.where((r) => r.level == Level.FINE).toList();
      expect(fineLogs.length, equals(1));
      expect(fineLogs[0].message, contains('415'));
    });

    test('logs 400 response at FINE level for bad request', () async {
      // Arrange
      final inMemoryRepo = InMemoryRepository<TestUser>();
      final inMemoryResource = CrudResource<TestUser, dynamic>(
        path: 'users',
        repository: inMemoryRepo,
        serializers: {'application/json': serializer},
      );

      final request =
          createRequest(path: '/users?name=John&email=john@example.com');

      // Act
      await inMemoryResource.handleQuery(request);

      // Assert
      final fineLogs = logRecords.where((r) => r.level == Level.FINE).toList();
      expect(fineLogs.length, equals(1));
      expect(fineLogs[0].message, contains('400'));
    });
  });

  group('CrudResource Logging - Deserialization Failures', () {
    test('logs deserialization failure at WARNING level in POST', () async {
      // Arrange
      final failingResource = CrudResource<TestUser, dynamic>(
        path: 'users',
        repository: repository,
        serializers: {
          'application/json': FailingSerializer(),
        },
      );

      final request = createRequest(
        method: 'POST',
        headers: {'content-type': 'application/json'},
        body: '{"name": "Test"}',
      );

      // Act
      await failingResource.handleCreate(request);

      // Assert
      final warningLogs =
          logRecords.where((r) => r.level == Level.WARNING).toList();
      expect(warningLogs.length, equals(1));
      expect(warningLogs[0].message, contains('Deserialization failed'));
    });

    test('logs deserialization failure at WARNING level in PUT', () async {
      // Arrange
      final failingResource = CrudResource<TestUser, dynamic>(
        path: 'users',
        repository: repository,
        serializers: {
          'application/json': FailingSerializer(),
        },
      );

      final request = createRequest(
        method: 'PUT',
        path: '/users/${testUser.id}',
        headers: {'content-type': 'application/json'},
        body: '{"name": "Test"}',
      );

      // Act
      await failingResource.handleUpdate(request, testUser.id.toString());

      // Assert
      final warningLogs =
          logRecords.where((r) => r.level == Level.WARNING).toList();
      expect(warningLogs.length, equals(1));
      expect(warningLogs[0].message, contains('Deserialization failed'));
    });

    test('warning log includes error details', () async {
      // Arrange
      final failingResource = CrudResource<TestUser, dynamic>(
        path: 'users',
        repository: repository,
        serializers: {
          'application/json': FailingSerializer(),
        },
      );

      final request = createRequest(
        method: 'POST',
        headers: {'content-type': 'application/json'},
        body: '{"name": "Test"}',
      );

      // Act
      await failingResource.handleCreate(request);

      // Assert
      final warningLogs =
          logRecords.where((r) => r.level == Level.WARNING).toList();
      expect(warningLogs[0].message, contains('FormatException'));
    });
  });

  group('CrudResource Logging - Exception Handling', () {
    test('logs exception at SEVERE level with error and stack trace', () async {
      // Arrange
      const nonExistentId = '987fcdeb-51a2-43f7-b123-456789abcdef';
      final request = createRequest(path: '/users/$nonExistentId');

      // Act
      await resource.handleGetById(request, nonExistentId);

      // Assert
      final severeLogs =
          logRecords.where((r) => r.level == Level.SEVERE).toList();
      expect(severeLogs.length, equals(1));
      expect(
        severeLogs[0].message,
        contains('Exception during request handling'),
      );
      expect(severeLogs[0].error, isNotNull);
      expect(severeLogs[0].stackTrace, isNotNull);
    });

    test('logs RepositoryException at SEVERE level', () async {
      // Arrange
      const nonExistentId = '987fcdeb-51a2-43f7-b123-456789abcdef';
      final request = createRequest(path: '/users/$nonExistentId');

      // Act
      await resource.handleGetById(request, nonExistentId);

      // Assert
      final severeLogs =
          logRecords.where((r) => r.level == Level.SEVERE).toList();
      expect(severeLogs.length, equals(1));
      expect(severeLogs[0].error, isA<RepositoryException>());
    });

    test('logs ArgumentError at SEVERE level for invalid UUID', () async {
      // Arrange
      final request = createRequest(path: '/users/invalid-id');

      // Act
      await resource.handleGetById(request, 'invalid-id');

      // Assert
      final severeLogs =
          logRecords.where((r) => r.level == Level.SEVERE).toList();
      expect(severeLogs.length, equals(1));
      expect(severeLogs[0].error, isA<ArgumentError>());
    });

    test('stack trace is included in SEVERE log', () async {
      // Arrange
      const nonExistentId = '987fcdeb-51a2-43f7-b123-456789abcdef';
      final request = createRequest(path: '/users/$nonExistentId');

      // Act
      await resource.handleGetById(request, nonExistentId);

      // Assert
      final severeLogs =
          logRecords.where((r) => r.level == Level.SEVERE).toList();
      expect(severeLogs[0].stackTrace, isNotNull);
      expect(severeLogs[0].stackTrace.toString(), isNotEmpty);
    });
  });

  group('CrudResource Logging - Logger Configuration', () {
    test('uses logger named dddart.http', () async {
      // Arrange
      await repository.save(testUser);
      final request = createRequest(path: '/users/${testUser.id}');

      // Act
      await resource.handleGetById(request, testUser.id.toString());

      // Assert
      expect(logRecords.isNotEmpty, isTrue);
      expect(logRecords[0].loggerName, equals('dddart.rest'));
    });

    test('logging works when no handlers configured', () async {
      // Arrange
      Logger.root.clearListeners();
      await repository.save(testUser);
      final request = createRequest(path: '/users/${testUser.id}');

      // Act & Assert - should not throw
      final response =
          await resource.handleGetById(request, testUser.id.toString());
      expect(response.statusCode, equals(200));
    });
  });
}
