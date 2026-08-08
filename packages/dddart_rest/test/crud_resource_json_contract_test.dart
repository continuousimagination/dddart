import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_rest/src/authentication_handler.dart';
import 'package:dddart_rest/src/authentication_result.dart';
import 'package:dddart_rest/src/authorization_handler.dart';
import 'package:dddart_rest/src/authorization_result.dart';
import 'package:dddart_rest/src/crud_resource.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'json_serializer_test_support.dart';

class _TestUser extends AggregateRoot {
  _TestUser({required this.name, super.id, super.createdAt, super.updatedAt});

  final String name;
}

class _TestUserSerializer extends TestJsonSerializer<_TestUser> {
  @override
  String serialize(_TestUser user, [dynamic config]) {
    return jsonEncode({
      'id': user.id.toString(),
      'name': user.name,
      'createdAt': user.createdAt.toIso8601String(),
      'updatedAt': user.updatedAt.toIso8601String(),
    });
  }

  @override
  _TestUser deserialize(String data, [dynamic config]) {
    final json = jsonDecode(data) as Map<String, dynamic>;
    return _TestUser(
      id: UuidValue.fromString(json['id'] as String),
      name: json['name'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

class _CountingRepository implements QueryableRepository<_TestUser> {
  _CountingRepository([Iterable<_TestUser> initial = const []])
      : _items = {for (final item in initial) item.id: item};

  final Map<UuidValue, _TestUser> _items;
  int getByIdCalls = 0;
  int getAllCalls = 0;
  int saveCalls = 0;
  int deleteCalls = 0;

  @override
  Future<_TestUser> getById(UuidValue id) async {
    getByIdCalls++;
    final item = _items[id];
    if (item == null) {
      throw const RepositoryException(
        'Not found',
        type: RepositoryExceptionType.notFound,
      );
    }
    return item;
  }

  @override
  Future<List<_TestUser>> getAll() async {
    getAllCalls++;
    return _items.values.toList();
  }

  @override
  Future<void> save(_TestUser aggregate) async {
    saveCalls++;
    _items[aggregate.id] = aggregate;
  }

  @override
  Future<void> deleteById(UuidValue id) async {
    deleteCalls++;
    _items.remove(id);
  }
}

class _CountingAuthenticationHandler implements AuthenticationHandler<String> {
  int calls = 0;

  @override
  Future<AuthenticationResult<String>> authenticate(Request request) async {
    calls++;
    return const AuthenticationResult(isAuthenticated: true, claims: 'claims');
  }
}

class _CountingAuthorizationHandler
    implements AuthorizationHandler<_TestUser, String> {
  int calls = 0;

  @override
  Future<AuthorizationResult> authorizeCreate(
    _TestUser aggregate,
    AuthenticationResult<String> authResult,
  ) async {
    calls++;
    return AuthorizationResult.allow();
  }

  @override
  Future<AuthorizationResult> authorizeDelete(
    UuidValue aggregateId,
    AuthenticationResult<String> authResult,
  ) async {
    calls++;
    return AuthorizationResult.allow();
  }

  @override
  Future<AuthorizationResult> authorizeQuery(
    Map<String, String> queryParams,
    AuthenticationResult<String> authResult,
  ) async {
    calls++;
    return AuthorizationResult.allow();
  }

  @override
  Future<AuthorizationResult> authorizeUpdate(
    _TestUser aggregate,
    AuthenticationResult<String> authResult,
  ) async {
    calls++;
    return AuthorizationResult.allow();
  }
}

Request _request(
  String method,
  String path, {
  Map<String, String>? headers,
  String? body,
}) {
  return Request(
    method,
    Uri.parse('http://localhost$path'),
    headers: headers,
    body: body,
  );
}

void main() {
  final id = UuidValue.fromString('123e4567-e89b-12d3-a456-426614174000');
  final timestamp = DateTime.utc(2026);
  late _TestUser user;
  late _TestUserSerializer serializer;

  setUp(() {
    user = _TestUser(
      id: id,
      name: 'Ada',
      createdAt: timestamp,
      updatedAt: timestamp,
    );
    serializer = _TestUserSerializer();
  });

  test('missing, wildcard, JSON, and positive JSON ranges select JSON',
      () async {
    final acceptHeaders = <String?>[
      null,
      '*/*',
      'application/*',
      'application/json',
      'application/xml, application/json;q=0.25',
      'application/*;q=0, application/json;q=0.25',
    ];

    for (final accept in acceptHeaders) {
      final repository = _CountingRepository([user]);
      final resource = CrudResource<_TestUser, void>(
        path: '/users',
        repository: repository,
        serializer: serializer,
      );
      final response = await resource.handleGetById(
        _request(
          'GET',
          '/users/$id',
          headers: accept == null ? null : {'accept': accept},
        ),
        id.toString(),
      );

      expect(response.statusCode, 200, reason: 'Accept: $accept');
      expect(response.headers['Content-Type'], 'application/json');
      expect(jsonDecode(await response.readAsString()), isA<Map>());
    }
  });

  test('unsupported or excluded JSON returns 406 before every CRUD effect',
      () async {
    final cases = <(String, String)>[
      ('unsupported', 'application/xml'),
      ('zero quality', 'application/json;q=0'),
      ('specific exclusion', 'application/json;q=0, */*;q=1'),
    ];

    for (final (description, accept) in cases) {
      for (final operation in ['get', 'query', 'create', 'update', 'delete']) {
        final repository = _CountingRepository([user]);
        final authentication = _CountingAuthenticationHandler();
        final resource = CrudResource<_TestUser, String>(
          path: '/users',
          repository: repository,
          serializer: serializer,
          authenticationHandler: authentication,
        );

        late Response response;
        switch (operation) {
          case 'get':
            response = await resource.handleGetById(
              _request('GET', '/users/$id', headers: {'accept': accept}),
              id.toString(),
            );
          case 'query':
            response = await resource.handleQuery(
              _request('GET', '/users', headers: {'accept': accept}),
            );
          case 'create':
            response = await resource.handleCreate(
              _request(
                'POST',
                '/users',
                headers: {
                  'accept': accept,
                  'content-type': 'application/json',
                },
                body: serializer.serialize(user),
              ),
            );
          case 'update':
            response = await resource.handleUpdate(
              _request(
                'PUT',
                '/users/$id',
                headers: {
                  'accept': accept,
                  'content-type': 'application/json',
                  'if-match': '"stale"',
                },
                body: serializer.serialize(user),
              ),
              id.toString(),
            );
          case 'delete':
            response = await resource.handleDelete(
              _request('DELETE', '/users/$id', headers: {'accept': accept}),
              id.toString(),
            );
        }

        expect(
          response.statusCode,
          406,
          reason: '$description Accept on $operation',
        );
        expect(response.headers['Content-Type'], 'application/problem+json');
        expect(authentication.calls, 0);
        expect(repository.getByIdCalls, 0);
        expect(repository.getAllCalls, 0);
        expect(repository.saveCalls, 0);
        expect(repository.deleteCalls, 0);
      }
    }
  });

  test('missing or non-JSON POST/PUT Content-Type returns 415 first', () async {
    for (final operation in ['create', 'update']) {
      for (final contentType in <String?>[null, 'application/yaml']) {
        final repository = _CountingRepository([user]);
        final authentication = _CountingAuthenticationHandler();
        final resource = CrudResource<_TestUser, String>(
          path: '/users',
          repository: repository,
          serializer: serializer,
          authenticationHandler: authentication,
        );
        final headers = <String, String>{'if-match': '"stale"'};
        if (contentType != null) headers['content-type'] = contentType;
        final request = _request(
          operation == 'create' ? 'POST' : 'PUT',
          operation == 'create' ? '/users' : '/users/$id',
          headers: headers,
          body: serializer.serialize(user),
        );
        final response = operation == 'create'
            ? await resource.handleCreate(request)
            : await resource.handleUpdate(request, id.toString());

        expect(response.statusCode, 415, reason: '$operation: $contentType');
        expect(response.headers['Content-Type'], 'application/problem+json');
        expect(authentication.calls, 0);
        expect(repository.getByIdCalls, 0);
        expect(repository.saveCalls, 0);
      }
    }
  });

  test('application/json parameters are allowed for request bodies', () async {
    final repository = _CountingRepository();
    final resource = CrudResource<_TestUser, void>(
      path: '/users',
      repository: repository,
      serializer: serializer,
    );
    final response = await resource.handleCreate(
      _request(
        'POST',
        '/users',
        headers: {'content-type': 'Application/JSON; charset=utf-8'},
        body: serializer.serialize(user),
      ),
    );

    expect(response.statusCode, 201);
    expect(repository.saveCalls, 1);
    expect(response.headers['Content-Type'], 'application/json');
  });

  test('PUT rejects a route/body ID mismatch before downstream effects',
      () async {
    final bodyId = UuidValue.fromString('987fcdeb-51a2-43f7-b123-456789abcdef');
    final bodyUser = _TestUser(
      id: bodyId,
      name: 'Wrong identity',
      createdAt: timestamp,
      updatedAt: timestamp,
    );
    final repository = _CountingRepository([user]);
    final authentication = _CountingAuthenticationHandler();
    final authorization = _CountingAuthorizationHandler();
    final resource = CrudResource<_TestUser, String>(
      path: '/users',
      repository: repository,
      serializer: serializer,
      authenticationHandler: authentication,
      authorizationHandler: authorization,
    );

    final response = await resource.handleUpdate(
      _request(
        'PUT',
        '/users/$id',
        headers: {
          'accept': 'application/json',
          'content-type': 'application/json',
          'if-match': '"stale"',
        },
        body: serializer.serialize(bodyUser),
      ),
      id.toString(),
    );

    expect(response.statusCode, 400);
    expect(response.headers['Content-Type'], 'application/problem+json');
    final problem = jsonDecode(await response.readAsString()) as Map;
    expect(problem['title'], 'Bad Request');
    expect(problem['detail'], contains(id.toString()));
    expect(problem['detail'], contains(bodyId.toString()));
    expect(authentication.calls, 1);
    expect(authorization.calls, 0);
    expect(repository.getByIdCalls, 0);
    expect(repository.getAllCalls, 0);
    expect(repository.saveCalls, 0);
    expect(repository.deleteCalls, 0);
  });

  test('PUT with matching route and body IDs still updates', () async {
    final updatedUser = _TestUser(
      id: id,
      name: 'Updated identity',
      createdAt: timestamp,
      updatedAt: timestamp,
    );
    final repository = _CountingRepository([user]);
    final authentication = _CountingAuthenticationHandler();
    final authorization = _CountingAuthorizationHandler();
    final resource = CrudResource<_TestUser, String>(
      path: '/users',
      repository: repository,
      serializer: serializer,
      authenticationHandler: authentication,
      authorizationHandler: authorization,
    );

    final response = await resource.handleUpdate(
      _request(
        'PUT',
        '/users/$id',
        headers: {'content-type': 'application/json'},
        body: serializer.serialize(updatedUser),
      ),
      id.toString(),
    );

    expect(response.statusCode, 200);
    expect(authentication.calls, 1);
    expect(authorization.calls, 1);
    expect(repository.getByIdCalls, 0);
    expect(repository.saveCalls, 1);
    final responseBody = jsonDecode(await response.readAsString()) as Map;
    expect(responseBody['id'], id.toString());
    expect(responseBody['name'], 'Updated identity');
  });

  test('collection responses are valid JSON arrays', () async {
    for (final items in <List<_TestUser>>[
      [],
      [user],
    ]) {
      final resource = CrudResource<_TestUser, void>(
        path: '/users',
        repository: _CountingRepository(items),
        serializer: serializer,
      );
      final response = await resource.handleQuery(
        _request('GET', '/users'),
      );

      expect(response.statusCode, 200);
      final body = jsonDecode(await response.readAsString());
      expect(body, isA<List>());
      expect((body as List).length, items.length);
    }
  });
}
