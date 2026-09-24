import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_rest/dddart_rest.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'json_serializer_test_support.dart';

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
class TestUserSerializer extends TestJsonSerializer<TestUser> {
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
  int reads = 0;
  int writes = 0;
  void resetCalls() {
    reads = 0;
    writes = 0;
  }

  @override
  Future<TestUser> getById(UuidValue id) async {
    reads++;
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
    writes++;
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

void main() {
  group('ETag Integration Tests', () {
    late MockRepository repository;
    late CrudResource<TestUser, dynamic> resource;
    late TestUser testUser;

    setUp(() {
      repository = MockRepository();
      resource = CrudResource<TestUser, dynamic>(
        path: '/users',
        repository: repository,
        serializer: TestUserSerializer(),
      );

      testUser = TestUser(
        id: UuidValue.fromString('123e4567-e89b-12d3-a456-426614174000'),
        name: 'John Doe',
        email: 'john@example.com',
        createdAt: DateTime.utc(2024, 1, 15, 10, 30),
        updatedAt: DateTime.utc(2024, 1, 15, 10, 30),
      );
    });

    group('GET requests', () {
      test('includes ETag header in response', () async {
        await repository.save(testUser);

        final request = Request(
          'GET',
          Uri.parse('http://localhost/users/${testUser.id}'),
        );

        final response = await resource.handleGetById(
          request,
          testUser.id.toString(),
        );

        expect(response.statusCode, equals(200));
        expect(response.headers['etag'], isNotNull);
        expect(response.headers['etag'], equals('"2024-01-15T10:30:00.000Z"'));
      });

      test('ETag changes when aggregate is updated', () async {
        await repository.save(testUser);

        final request1 = Request(
          'GET',
          Uri.parse('http://localhost/users/${testUser.id}'),
        );
        final response1 = await resource.handleGetById(
          request1,
          testUser.id.toString(),
        );
        final etag1 = response1.headers['etag'];

        // Update the user
        final updatedUser = TestUser(
          id: testUser.id,
          name: 'Jane Doe',
          email: testUser.email,
          createdAt: testUser.createdAt,
          updatedAt: DateTime.utc(2024, 1, 15, 11),
        );
        await repository.save(updatedUser);

        final request2 = Request(
          'GET',
          Uri.parse('http://localhost/users/${testUser.id}'),
        );
        final response2 = await resource.handleGetById(
          request2,
          testUser.id.toString(),
        );
        final etag2 = response2.headers['etag'];

        expect(etag1, isNot(equals(etag2)));
      });
    });

    group('POST requests', () {
      test('includes ETag header in response', () async {
        final requestBody = jsonEncode({
          'id': testUser.id.toString(),
          'name': testUser.name,
          'email': testUser.email,
          'createdAt': testUser.createdAt.toIso8601String(),
          'updatedAt': testUser.updatedAt.toIso8601String(),
        });

        final request = Request(
          'POST',
          Uri.parse('http://localhost/users'),
          headers: {'content-type': 'application/json'},
          body: requestBody,
        );

        final response = await resource.handleCreate(request);

        expect(response.statusCode, equals(201));
        expect(response.headers['etag'], isNotNull);
      });
    });

    group('PUT requests without If-Match', () {
      test('updates successfully without ETag validation', () async {
        await repository.save(testUser);

        final updatedData = jsonEncode({
          'id': testUser.id.toString(),
          'name': 'Jane Doe',
          'email': testUser.email,
          'createdAt': testUser.createdAt.toIso8601String(),
          'updatedAt': DateTime.utc(2024, 1, 15, 11).toIso8601String(),
        });

        final request = Request(
          'PUT',
          Uri.parse('http://localhost/users/${testUser.id}'),
          headers: {'content-type': 'application/json'},
          body: updatedData,
        );

        final response = await resource.handleUpdate(
          request,
          testUser.id.toString(),
        );

        expect(response.statusCode, equals(200));
        expect(response.headers['etag'], isNull);
        expect(response.headers['last-modified'], isNull);
      });

      test('omits transformed PUT validators', () async {
        await repository.save(testUser);

        final updatedData = jsonEncode({
          'id': testUser.id.toString(),
          'name': 'Jane Doe',
          'email': testUser.email,
          'createdAt': testUser.createdAt.toIso8601String(),
          'updatedAt': DateTime.utc(2024, 1, 15, 11).toIso8601String(),
        });

        final request = Request(
          'PUT',
          Uri.parse('http://localhost/users/${testUser.id}'),
          headers: {'content-type': 'application/json'},
          body: updatedData,
        );

        final response = await resource.handleUpdate(
          request,
          testUser.id.toString(),
        );

        expect(response.headers['etag'], isNull);
        expect(response.headers['last-modified'], isNull);
        expect((await repository.getById(testUser.id)).name, 'Jane Doe');
      });
    });

    group('PUT requests with If-Match', () {
      test(
        'rejects even a matching validator without repository I/O',
        () async {
          await repository.save(testUser);
          repository.resetCalls();

          const currentETag = '"2024-01-15T10:30:00.000Z"';

          final updatedData = jsonEncode({
            'id': testUser.id.toString(),
            'name': 'Jane Doe',
            'email': testUser.email,
            'createdAt': testUser.createdAt.toIso8601String(),
            'updatedAt': DateTime.utc(2024, 1, 15, 11).toIso8601String(),
          });

          final request = Request(
            'PUT',
            Uri.parse('http://localhost/users/${testUser.id}'),
            headers: {
              'content-type': 'application/json',
              'if-match': currentETag,
            },
            body: updatedData,
          );

          final response = await resource.handleUpdate(
            request,
            testUser.id.toString(),
          );

          expect(response.statusCode, equals(501));
          final body = jsonDecode(await response.readAsString());
          expect(body['title'], equals('Not Implemented'));
          expect(repository.reads, 0);
          expect(repository.writes, 0);
        },
      );

      test('returns501 for unsupported conditional writes', () async {
        await repository.save(testUser);
        repository.resetCalls();

        const wrongETag = '"2024-01-15T09:00:00.000Z"';

        final updatedData = jsonEncode({
          'id': testUser.id.toString(),
          'name': 'Jane Doe',
          'email': testUser.email,
          'createdAt': testUser.createdAt.toIso8601String(),
          'updatedAt': DateTime.utc(2024, 1, 15, 11).toIso8601String(),
        });

        final request = Request(
          'PUT',
          Uri.parse('http://localhost/users/${testUser.id}'),
          headers: {'content-type': 'application/json', 'if-match': wrongETag},
          body: updatedData,
        );

        final response = await resource.handleUpdate(
          request,
          testUser.id.toString(),
        );

        expect(response.statusCode, equals(501));
        expect(
          response.headers['content-type'],
          equals('application/problem+json'),
        );
      });

      test(
        'unsupported response does not read or expose current ETag',
        () async {
          await repository.save(testUser);
          repository.resetCalls();

          const wrongETag = '"2024-01-15T09:00:00.000Z"';

          final updatedData = jsonEncode({
            'id': testUser.id.toString(),
            'name': 'Jane Doe',
            'email': testUser.email,
            'createdAt': testUser.createdAt.toIso8601String(),
            'updatedAt': DateTime.utc(2024, 1, 15, 11).toIso8601String(),
          });

          final request = Request(
            'PUT',
            Uri.parse('http://localhost/users/${testUser.id}'),
            headers: {
              'content-type': 'application/json',
              'if-match': wrongETag,
            },
            body: updatedData,
          );

          final response = await resource.handleUpdate(
            request,
            testUser.id.toString(),
          );

          expect(response.headers['etag'], isNull);
          expect(repository.reads, 0);
          expect(repository.writes, 0);
        },
      );

      test('unsupported response follows RFC 7807 format', () async {
        await repository.save(testUser);
        repository.resetCalls();

        const wrongETag = '"2024-01-15T09:00:00.000Z"';

        final updatedData = jsonEncode({
          'id': testUser.id.toString(),
          'name': 'Jane Doe',
          'email': testUser.email,
          'createdAt': testUser.createdAt.toIso8601String(),
          'updatedAt': DateTime.utc(2024, 1, 15, 11).toIso8601String(),
        });

        final request = Request(
          'PUT',
          Uri.parse('http://localhost/users/${testUser.id}'),
          headers: {'content-type': 'application/json', 'if-match': wrongETag},
          body: updatedData,
        );

        final response = await resource.handleUpdate(
          request,
          testUser.id.toString(),
        );
        final body = jsonDecode(await response.readAsString());

        expect(body['type'], equals('about:blank'));
        expect(body['title'], equals('Not Implemented'));
        expect(body['status'], equals(501));
        expect(body['detail'], contains('capability unavailable'));
        expect(repository.reads, 0);
        expect(repository.writes, 0);
      });

      test('does not update aggregate when ETag mismatches', () async {
        await repository.save(testUser);
        repository.resetCalls();

        const wrongETag = '"2024-01-15T09:00:00.000Z"';

        final updatedData = jsonEncode({
          'id': testUser.id.toString(),
          'name': 'Jane Doe',
          'email': testUser.email,
          'createdAt': testUser.createdAt.toIso8601String(),
          'updatedAt': DateTime.utc(2024, 1, 15, 11).toIso8601String(),
        });

        final request = Request(
          'PUT',
          Uri.parse('http://localhost/users/${testUser.id}'),
          headers: {'content-type': 'application/json', 'if-match': wrongETag},
          body: updatedData,
        );

        await resource.handleUpdate(request, testUser.id.toString());

        expect(repository.reads, 0);
        expect(repository.writes, 0);
        // Verify the user was not updated
        final storedUser = await repository.getById(testUser.id);
        expect(storedUser.name, equals('John Doe'));
      });
    });

    group('competing legacy conditional requests', () {
      test('refuses both competing legacy conditional writes', () async {
        // Client A fetches user
        await repository.save(testUser);
        repository.resetCalls();
        final getRequest = Request(
          'GET',
          Uri.parse('http://localhost/users/${testUser.id}'),
        );
        final getResponse = await resource.handleGetById(
          getRequest,
          testUser.id.toString(),
        );
        final etagForClientA = getResponse.headers['etag']!;

        // Client B fetches user (gets same ETag)
        final etagForClientB = etagForClientA;
        repository.resetCalls();

        // Neither client is offered a false atomicity guarantee
        final clientAUpdate = jsonEncode({
          'id': testUser.id.toString(),
          'name': 'Updated by A',
          'email': testUser.email,
          'createdAt': testUser.createdAt.toIso8601String(),
          'updatedAt': DateTime.utc(2024, 1, 15, 11).toIso8601String(),
        });

        final clientARequest = Request(
          'PUT',
          Uri.parse('http://localhost/users/${testUser.id}'),
          headers: {
            'content-type': 'application/json',
            'if-match': etagForClientA,
          },
          body: clientAUpdate,
        );

        final clientAResponse = await resource.handleUpdate(
          clientARequest,
          testUser.id.toString(),
        );
        expect(clientAResponse.statusCode, equals(501));

        // Client B submits the same validator; neither legacy write is atomic.
        final clientBUpdate = jsonEncode({
          'id': testUser.id.toString(),
          'name': 'Updated by B',
          'email': testUser.email,
          'createdAt': testUser.createdAt.toIso8601String(),
          'updatedAt': DateTime.utc(2024, 1, 15, 11, 30).toIso8601String(),
        });

        final clientBRequest = Request(
          'PUT',
          Uri.parse('http://localhost/users/${testUser.id}'),
          headers: {
            'content-type': 'application/json',
            'if-match': etagForClientB,
          },
          body: clientBUpdate,
        );

        final clientBResponse = await resource.handleUpdate(
          clientBRequest,
          testUser.id.toString(),
        );

        // Both conditional attempts are unsupported, with no storage access
        expect(clientBResponse.statusCode, equals(501));
        expect(repository.reads, 0);
        expect(repository.writes, 0);

        // Verify neither unsupported write changed stored data
        final finalUser = await repository.getById(testUser.id);
        expect(finalUser.name, equals('John Doe'));
      });
    });

    group('contentHash strategy', () {
      test('generates different ETags for different content', () async {
        final contentHashResource = CrudResource<TestUser, dynamic>(
          path: '/users',
          repository: repository,
          serializer: TestUserSerializer(),
          etagStrategy: ETagStrategy.contentHash,
        );

        await repository.save(testUser);

        final request1 = Request(
          'GET',
          Uri.parse('http://localhost/users/${testUser.id}'),
        );
        final response1 = await contentHashResource.handleGetById(
          request1,
          testUser.id.toString(),
        );
        final etag1 = response1.headers['etag'];

        // Update user with same timestamp but different content
        final updatedUser = TestUser(
          id: testUser.id,
          name: 'Jane Doe',
          email: testUser.email,
          createdAt: testUser.createdAt,
          updatedAt: testUser.updatedAt, // Same timestamp
        );
        await repository.save(updatedUser);

        final request2 = Request(
          'GET',
          Uri.parse('http://localhost/users/${testUser.id}'),
        );
        final response2 = await contentHashResource.handleGetById(
          request2,
          testUser.id.toString(),
        );
        final etag2 = response2.headers['etag'];

        // Content hash should detect the change even with same timestamp
        expect(etag1, isNot(equals(etag2)));
      });
    });
  });
}
