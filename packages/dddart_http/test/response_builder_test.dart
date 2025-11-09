import 'dart:convert';
import 'package:test/test.dart';
import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_http/src/response_builder.dart';

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

void main() {
  late ResponseBuilder<TestUser> responseBuilder;
  late TestUserSerializer serializer;
  late TestUser testUser;

  setUp(() {
    responseBuilder = ResponseBuilder<TestUser>();
    serializer = TestUserSerializer();
    testUser = TestUser(
      id: UuidValue.fromString('123e4567-e89b-12d3-a456-426614174000'),
      name: 'John Doe',
      email: 'john@example.com',
      createdAt: DateTime.parse('2024-01-15T10:30:00Z'),
      updatedAt: DateTime.parse('2024-01-15T10:30:00Z'),
    );
  });

  group('ResponseBuilder - Single aggregate responses', () {
    test('ok() method returns 200 with serialized body', () async {
      // Act
      final response = responseBuilder.ok(
        testUser,
        serializer,
        'application/json',
      );

      // Assert
      expect(response.statusCode, equals(200));
      expect(response.headers['Content-Type'], equals('application/json'));

      final bodyString = await response.readAsString();
      final body = jsonDecode(bodyString);
      expect(body['id'], equals('123e4567-e89b-12d3-a456-426614174000'));
      expect(body['name'], equals('John Doe'));
      expect(body['email'], equals('john@example.com'));
      expect(body['createdAt'], equals('2024-01-15T10:30:00.000Z'));
      expect(body['updatedAt'], equals('2024-01-15T10:30:00.000Z'));
    });

    test('created() method returns 201 with serialized body', () async {
      // Act
      final response = responseBuilder.created(
        testUser,
        serializer,
        'application/json',
      );

      // Assert
      expect(response.statusCode, equals(201));
      expect(response.headers['Content-Type'], equals('application/json'));

      final bodyString = await response.readAsString();
      final body = jsonDecode(bodyString);
      expect(body['id'], equals('123e4567-e89b-12d3-a456-426614174000'));
      expect(body['name'], equals('John Doe'));
      expect(body['email'], equals('john@example.com'));
    });

    test('Content-Type header is set correctly for different formats', () async {
      // Act - JSON
      final jsonResponse = responseBuilder.ok(
        testUser,
        serializer,
        'application/json',
      );

      // Assert - JSON
      expect(jsonResponse.headers['Content-Type'], equals('application/json'));

      // Act - YAML (hypothetical)
      final yamlResponse = responseBuilder.ok(
        testUser,
        serializer,
        'application/yaml',
      );

      // Assert - YAML
      expect(yamlResponse.headers['Content-Type'], equals('application/yaml'));
    });
  });

  group('ResponseBuilder - Aggregate list responses', () {
    test('okList() method returns 200 with serialized array', () async {
      // Arrange
      final user2 = TestUser(
        id: UuidValue.fromString('987fcdeb-51a2-43f7-b123-456789abcdef'),
        name: 'Jane Smith',
        email: 'jane@example.com',
        createdAt: DateTime.parse('2024-01-16T11:00:00Z'),
        updatedAt: DateTime.parse('2024-01-16T11:00:00Z'),
      );
      final users = [testUser, user2];

      // Act
      final response = responseBuilder.okList(
        users,
        serializer,
        'application/json',
      );

      // Assert
      expect(response.statusCode, equals(200));
      expect(response.headers['Content-Type'], equals('application/json'));

      final bodyString = await response.readAsString();
      final body = jsonDecode(bodyString) as List;
      expect(body.length, equals(2));
      expect(body[0]['id'], equals('123e4567-e89b-12d3-a456-426614174000'));
      expect(body[0]['name'], equals('John Doe'));
      expect(body[1]['id'], equals('987fcdeb-51a2-43f7-b123-456789abcdef'));
      expect(body[1]['name'], equals('Jane Smith'));
    });

    test('X-Total-Count header is included when totalCount provided', () async {
      // Arrange
      final users = [testUser];

      // Act
      final response = responseBuilder.okList(
        users,
        serializer,
        'application/json',
        totalCount: 150,
      );

      // Assert
      expect(response.statusCode, equals(200));
      expect(response.headers['X-Total-Count'], equals('150'));
    });

    test('X-Total-Count header is omitted when totalCount is null', () async {
      // Arrange
      final users = [testUser];

      // Act
      final response = responseBuilder.okList(
        users,
        serializer,
        'application/json',
      );

      // Assert
      expect(response.statusCode, equals(200));
      expect(response.headers.containsKey('X-Total-Count'), isFalse);
    });

    test('Content-Type header is set correctly for list responses', () async {
      // Arrange
      final users = [testUser];

      // Act
      final response = responseBuilder.okList(
        users,
        serializer,
        'application/json',
        totalCount: 1,
      );

      // Assert
      expect(response.headers['Content-Type'], equals('application/json'));
    });

    test('okList() returns empty array when no items', () async {
      // Arrange
      final users = <TestUser>[];

      // Act
      final response = responseBuilder.okList(
        users,
        serializer,
        'application/json',
        totalCount: 0,
      );

      // Assert
      expect(response.statusCode, equals(200));
      final bodyString = await response.readAsString();
      final body = jsonDecode(bodyString) as List;
      expect(body.length, equals(0));
      expect(response.headers['X-Total-Count'], equals('0'));
    });
  });

  group('ResponseBuilder - Empty and error responses', () {
    test('noContent() method returns 204 with empty body', () async {
      // Act
      final response = responseBuilder.noContent();

      // Assert
      expect(response.statusCode, equals(204));
      final bodyString = await response.readAsString();
      expect(bodyString, isEmpty);
    });

    test('badRequest() method returns 400 with RFC 7807 format', () async {
      // Act
      final response = responseBuilder.badRequest(
        'Cannot combine multiple query parameters',
      );

      // Assert
      expect(response.statusCode, equals(400));
      expect(response.headers['Content-Type'], equals('application/problem+json'));

      final bodyString = await response.readAsString();
      final body = jsonDecode(bodyString);
      expect(body['type'], equals('about:blank'));
      expect(body['title'], equals('Bad Request'));
      expect(body['status'], equals(400));
      expect(body['detail'], equals('Cannot combine multiple query parameters'));
    });

    test('notFound() method returns 404 with RFC 7807 format', () async {
      // Act
      final response = responseBuilder.notFound(
        'User with ID 123e4567-e89b-12d3-a456-426614174000 not found',
      );

      // Assert
      expect(response.statusCode, equals(404));
      expect(response.headers['Content-Type'], equals('application/problem+json'));

      final bodyString = await response.readAsString();
      final body = jsonDecode(bodyString);
      expect(body['type'], equals('about:blank'));
      expect(body['title'], equals('Not Found'));
      expect(body['status'], equals(404));
      expect(body['detail'], equals('User with ID 123e4567-e89b-12d3-a456-426614174000 not found'));
    });

    test('error responses include all required RFC 7807 fields', () async {
      // Act - badRequest
      final badRequestResponse = responseBuilder.badRequest('Test message');
      final badRequestBody = jsonDecode(await badRequestResponse.readAsString());

      // Assert - badRequest has all required fields
      expect(badRequestBody.containsKey('type'), isTrue);
      expect(badRequestBody.containsKey('title'), isTrue);
      expect(badRequestBody.containsKey('status'), isTrue);
      expect(badRequestBody.containsKey('detail'), isTrue);

      // Act - notFound
      final notFoundResponse = responseBuilder.notFound('Test message');
      final notFoundBody = jsonDecode(await notFoundResponse.readAsString());

      // Assert - notFound has all required fields
      expect(notFoundBody.containsKey('type'), isTrue);
      expect(notFoundBody.containsKey('title'), isTrue);
      expect(notFoundBody.containsKey('status'), isTrue);
      expect(notFoundBody.containsKey('detail'), isTrue);
    });
  });
}
