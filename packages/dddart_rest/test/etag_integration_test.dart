import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_rest/dddart_rest.dart';
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
        serializers: {'application/json': TestUserSerializer()},
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

        final response =
            await resource.handleGetById(request, testUser.id.toString());

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
        final response1 =
            await resource.handleGetById(request1, testUser.id.toString());
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
        final response2 =
            await resource.handleGetById(request2, testUser.id.toString());
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

        final response =
            await resource.handleUpdate(request, testUser.id.toString());

        expect(response.statusCode, equals(200));
        expect(response.headers['etag'], isNotNull);
      });

      test('includes ETag in response', () async {
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

        final response =
            await resource.handleUpdate(request, testUser.id.toString());

        expect(response.headers['etag'], equals('"2024-01-15T11:00:00.000Z"'));
      });
    });

    group('PUT requests with If-Match', () {
      test('succeeds when ETag matches', () async {
        await repository.save(testUser);

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

        final response =
            await resource.handleUpdate(request, testUser.id.toString());

        expect(response.statusCode, equals(200));
        final body = jsonDecode(await response.readAsString());
        expect(body['name'], equals('Jane Doe'));
      });

      test('returns 412 when ETag does not match', () async {
        await repository.save(testUser);

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

        final response =
            await resource.handleUpdate(request, testUser.id.toString());

        expect(response.statusCode, equals(412));
        expect(
          response.headers['content-type'],
          equals('application/problem+json'),
        );
      });

      test('412 response includes current ETag', () async {
        await repository.save(testUser);

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

        final response =
            await resource.handleUpdate(request, testUser.id.toString());

        expect(response.headers['etag'], equals('"2024-01-15T10:30:00.000Z"'));
      });

      test('412 response follows RFC 7807 format', () async {
        await repository.save(testUser);

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

        final response =
            await resource.handleUpdate(request, testUser.id.toString());
        final body = jsonDecode(await response.readAsString());

        expect(body['type'], equals('about:blank'));
        expect(body['title'], equals('Precondition Failed'));
        expect(body['status'], equals(412));
        expect(body['detail'], contains('Resource was modified'));
      });

      test('does not update aggregate when ETag mismatches', () async {
        await repository.save(testUser);

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

        await resource.handleUpdate(request, testUser.id.toString());

        // Verify the user was not updated
        final storedUser = await repository.getById(testUser.id);
        expect(storedUser.name, equals('John Doe'));
      });
    });

    group('concurrent update scenario', () {
      test('prevents lost updates with If-Match', () async {
        // Client A fetches user
        await repository.save(testUser);
        final getRequest = Request(
          'GET',
          Uri.parse('http://localhost/users/${testUser.id}'),
        );
        final getResponse =
            await resource.handleGetById(getRequest, testUser.id.toString());
        final etagForClientA = getResponse.headers['etag']!;

        // Client B fetches user (gets same ETag)
        final etagForClientB = etagForClientA;

        // Client A updates successfully
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
        expect(clientAResponse.statusCode, equals(200));

        // Client B tries to update with stale ETag
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

        // Client B should get 412 Precondition Failed
        expect(clientBResponse.statusCode, equals(412));

        // Verify Client A's update was preserved
        final finalUser = await repository.getById(testUser.id);
        expect(finalUser.name, equals('Updated by A'));
      });
    });

    group('contentHash strategy', () {
      test('generates different ETags for different content', () async {
        final contentHashResource = CrudResource<TestUser, dynamic>(
          path: '/users',
          repository: repository,
          serializers: {'application/json': TestUserSerializer()},
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
