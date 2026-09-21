/// Authorization and identity must be checked before protected repository calls.
library;

import 'dart:convert';
import 'package:dddart/dddart.dart';
import 'package:dddart_rest/dddart_rest.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

class _Record extends AggregateRoot {
  _Record({required super.id});
}

class _Codec implements Serializer<_Record> {
  @override
  String serialize(_Record value, [dynamic config]) =>
      jsonEncode({'id': value.id.uuid});
  @override
  _Record deserialize(String data, [dynamic config]) => _Record(
    id: UuidValue.fromString(
      (jsonDecode(data) as Map<String, dynamic>)['id'] as String,
    ),
  );
}

class _Repository implements QueryableRepository<_Record> {
  int reads = 0;
  int writes = 0;
  int queries = 0;
  Exception? error;
  @override
  Future<_Record> getById(UuidValue id) async {
    reads++;
    if (error != null) throw error!;
    return _Record(id: id);
  }

  @override
  Future<void> save(_Record value) async {
    writes++;
  }

  @override
  Future<void> deleteById(UuidValue id) async {}
  @override
  Future<List<_Record>> getAll() async {
    queries++;
    return [];
  }
}

class _Authentication implements AuthenticationHandler<String> {
  @override
  Future<AuthenticationResult<String>> authenticate(Request request) async =>
      AuthenticationResult.success(userId: 'test', claims: 'claims');
}

class _DeniedAuthentication implements AuthenticationHandler<String> {
  @override
  Future<AuthenticationResult<String>> authenticate(Request request) async =>
      AuthenticationResult.failure('Access denied');
}

class _Authorization extends AuthorizationHandler<_Record, String> {
  bool allowed = false;
  int reads = 0;
  int queries = 0;
  Future<AuthorizationResult> result() async => allowed
      ? AuthorizationResult.allow()
      : AuthorizationResult.deny('Access denied');
  @override
  Future<AuthorizationResult> authorizeRead(
    UuidValue id,
    AuthenticationResult<String> auth,
  ) {
    reads++;
    return result();
  }

  @override
  Future<AuthorizationResult> authorizeQuery(
    Map<String, String> query,
    AuthenticationResult<String> auth,
  ) {
    queries++;
    return result();
  }

  @override
  Future<AuthorizationResult> authorizeCreate(
    _Record value,
    AuthenticationResult<String> auth,
  ) => result();
  @override
  Future<AuthorizationResult> authorizeUpdate(
    _Record value,
    AuthenticationResult<String> auth,
  ) => result();
  @override
  Future<AuthorizationResult> authorizeDelete(
    UuidValue id,
    AuthenticationResult<String> auth,
  ) => result();
}

void main() {
  final id = UuidValue.fromString('00000000-0000-4000-8000-000000000001');
  late _Repository repo;
  late _Authorization auth;
  late CrudResource<_Record, String> resource;
  setUp(() {
    repo = _Repository();
    auth = _Authorization();
    resource = CrudResource(
      path: '/records',
      repository: repo,
      serializers: {'application/json': _Codec()},
      authenticationHandler: _Authentication(),
      authorizationHandler: auth,
    );
  });
  for (final method in ['POST', 'PUT']) {
    test('$method rejects bad Accept before any mutation', () async {
      auth.allowed = true;
      final request = Request(
        method,
        Uri.parse('https://example.invalid/records/${id.uuid}'),
        headers: {
          'content-type': 'application/json',
          'accept': 'application/xml',
        },
        body: jsonEncode({'id': id.uuid}),
      );
      final response = method == 'POST'
          ? await resource.handleCreate(request)
          : await resource.handleUpdate(request, id.uuid);
      expect(response.statusCode, 406);
      expect(repo.writes, 0);
      expect(repo.reads, 0);
    });
    test('$method keeps auth denial ahead of bad Accept', () async {
      Request request() => Request(
        method,
        Uri.parse('https://example.invalid/records/${id.uuid}'),
        headers: {
          'content-type': 'application/json',
          'accept': 'application/xml',
        },
        body: jsonEncode({'id': id.uuid}),
      );
      final denied = CrudResource<_Record, String>(
        path: '/records',
        repository: repo,
        serializers: {'application/json': _Codec()},
        authenticationHandler: _DeniedAuthentication(),
        authorizationHandler: auth,
      );
      final unauthenticated = method == 'POST'
          ? await denied.handleCreate(request())
          : await denied.handleUpdate(request(), id.uuid);
      expect(unauthenticated.statusCode, 401);
      final forbidden = method == 'POST'
          ? await resource.handleCreate(request())
          : await resource.handleUpdate(request(), id.uuid);
      expect(forbidden.statusCode, 403);
      expect(repo.writes, 0);
      expect(repo.reads, 0);
    });
  }
  test('PUT negotiates before optional If-Match repository read', () async {
    auth.allowed = true;
    final response = await resource.handleUpdate(
      Request(
        'PUT',
        Uri.parse('https://example.invalid/records/${id.uuid}'),
        headers: {
          'content-type': 'application/json',
          'accept': 'application/xml',
          'if-match': 'different',
        },
        body: jsonEncode({'id': id.uuid}),
      ),
      id.uuid,
    );
    expect(response.statusCode, 406);
    expect(repo.reads, 0);
    expect(repo.writes, 0);
  });
  test('denied item read touches no repository', () async {
    final response = await resource.handleGetById(
      Request('GET', Uri.parse('https://example.invalid/records/${id.uuid}')),
      id.uuid,
    );
    expect(response.statusCode, 403);
    expect(auth.reads, 1);
    expect(repo.reads, 0);
  });
  test('allowed read authenticates and authorizes before loading', () async {
    auth.allowed = true;
    expect(
      (await resource.handleGetById(
        Request('GET', Uri.parse('https://example.invalid/records/${id.uuid}')),
        id.uuid,
      )).statusCode,
      200,
    );
    expect(auth.reads, 1);
    expect(repo.reads, 1);
  });
  test('unfiltered and pagination-only queries are authorized', () async {
    for (final suffix in ['', '?skip=0&take=1']) {
      expect(
        (await resource.handleQuery(
          Request('GET', Uri.parse('https://example.invalid/records$suffix')),
        )).statusCode,
        403,
      );
    }
    expect(auth.queries, 2);
    expect(repo.queries, 0);
  });
  test('PUT rejects path/body identity disagreement without saving', () async {
    auth.allowed = true;
    final request = Request(
      'PUT',
      Uri.parse('https://example.invalid/records/${id.uuid}'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'id': '00000000-0000-4000-8000-000000000002'}),
    );
    expect((await resource.handleUpdate(request, id.uuid)).statusCode, 400);
    expect(repo.writes, 0);
  });
  test(
    'denied PUT with If-Match does not read storage or reveal a precondition',
    () async {
      final request = Request(
        'PUT',
        Uri.parse('https://example.invalid/records/${id.uuid}'),
        headers: {
          'content-type': 'application/json',
          'if-match': 'untrusted-etag',
        },
        body: jsonEncode({'id': id.uuid}),
      );
      expect((await resource.handleUpdate(request, id.uuid)).statusCode, 403);
      expect(repo.reads, 0);
      expect(repo.writes, 0);
    },
  );
  test(
    'authorization cannot be silently skipped when authentication is absent',
    () {
      expect(
        () => CrudResource<_Record, String>(
          path: '/records',
          repository: repo,
          serializers: {'application/json': _Codec()},
          authorizationHandler: auth,
        ),
        throwsArgumentError,
      );
      expect(
        () => CrudResource<_Record, String>(
          path: '/records',
          repository: repo,
          serializers: {'application/json': _Codec()},
        ),
        returnsNormally,
      );
    },
  );
  test(
    'provider and malformed decode values never reach response/logs',
    () async {
      const marker = 'restricted-synthetic-payload';
      final messages = <String>[];
      final old = Logger.root.level;
      Logger.root.level = Level.ALL;
      final subscription = Logger.root.onRecord.listen(
        (r) => messages.add('${r.message} ${r.error} ${r.stackTrace}'),
      );
      try {
        auth.allowed = true;
        repo.error = const RepositoryException(
          marker,
          type: RepositoryExceptionType.connection,
        );
        final get = await resource.handleGetById(
          Request(
            'GET',
            Uri.parse('https://example.invalid/records/${id.uuid}'),
          ),
          id.uuid,
        );
        expect(await get.readAsString(), isNot(contains(marker)));
        final put = await resource.handleUpdate(
          Request(
            'PUT',
            Uri.parse('https://example.invalid/records/${id.uuid}'),
            body: marker,
          ),
          id.uuid,
        );
        expect(await put.readAsString(), isNot(contains(marker)));
        expect(messages.join('\n'), isNot(contains(marker)));
        expect(repo.writes, 0);
      } finally {
        await subscription.cancel();
        Logger.root.level = old;
      }
    },
  );
}
