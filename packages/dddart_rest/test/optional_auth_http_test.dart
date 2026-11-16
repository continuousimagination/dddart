import 'dart:convert';
import 'dart:io' as io;

import 'package:dddart/dddart.dart';
import 'package:dddart_rest/dddart_rest.dart';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';

import 'authorization_test_support.dart';

class ThrowingVerifier extends Verifier {
  @override
  Future<AuthenticationResult<Claims>> authenticate(Request request) async =>
      throw const FormatException('PRIVATE-VERIFIER');
}

void main() {
  late Documents repository;
  late Documents leaderboard;
  late Document private;
  late Document public;
  late Document score;
  late RecordingPublisher publisher;
  late EventSerializer serializer;
  late http.Client client;
  late io.HttpServer server;
  late Uri base;
  var queries = 0;
  setUp(() async {
    queries = 0;
    publisher = RecordingPublisher();
    repository = Documents(eventPublisher: publisher);
    leaderboard = Documents();
    private = Document(content: 'PRIVATE-ALICE');
    public = Document(
      owner: 'bob',
      tenant: 'two',
      isPublic: true,
      content: 'PUBLIC-RECORD',
    );
    score = Document(isPublic: true, content: 'PUBLIC-SCORE');
    await repository.save(private);
    await repository.save(public);
    await leaderboard.save(score);
    repository.resetCounters();
    serializer = EventSerializer();
    final verifier = Verifier();
    final privatePolicy = Policy((context) {
      if (context is QueryContext<Document, UuidValue, Claims> &&
          context.caller.claims?.tenant != 'one') {
        return const AuthorizationResult.deny();
      }
      return ownershipPolicy(context);
    });
    Future<QueryResult<Document>> privateQuery(
      Repository<Document, UuidValue> repo,
      Map<String, String> filters,
      int skip,
      int take,
      AuthorizedQuery<Claims> authorization,
    ) async {
      queries++;
      final tenant = (authorization.scope as TenantScope).tenant;
      final rows = (await repository.all())
          .where((value) => value.tenant == tenant)
          .where(
            (value) =>
                !filters.containsKey('tenant') ||
                value.tenant == filters['tenant'],
          )
          .toList();
      return QueryResult(
        rows.skip(skip).take(take).toList(),
        totalCount: rows.length,
      );
    }

    final privateApi = CrudResource<Document, UuidValue, Claims>(
      path: '/private',
      repository: repository,
      serializer: serializer,
      authenticationHandler: verifier,
      defaultPolicy: AccessPolicy.custom(
        privatePolicy,
        authentication: AuthenticationRequirement.required,
      ),
      collectionHandler: privateQuery,
      queryHandlers: {'tenant': privateQuery},
    );
    final scorePolicy = Policy((context) {
      final allowed = switch (context) {
        CreateContext<Document, UuidValue, Claims>() =>
          context.proposed.owner == context.caller.claims?.user,
        UpdateContext<Document, UuidValue, Claims>() =>
          context.caller.claims?.admin ?? false,
        DeleteContext<Document, UuidValue, Claims>() =>
          context.caller.claims?.admin ?? false,
        ReadContext<Document, UuidValue, Claims>() => true,
        QueryContext<Document, UuidValue, Claims>() => true,
      };
      return allowed
          ? const AuthorizationResult.allow(scope: UnrestrictedQueryScope())
          : const AuthorizationResult.deny();
    });
    final board = CrudResource<Document, UuidValue, Claims>(
      path: '/leaderboard',
      repository: leaderboard,
      serializer: DocumentSerializer(),
      authenticationHandler: verifier,
      defaultPolicy: AccessPolicy.custom(
        scorePolicy,
        authentication: AuthenticationRequirement.required,
      ),
      operationPolicies: {
        CrudOperation.read: const AccessPolicy.public(),
        CrudOperation.query: const AccessPolicy.public(),
      },
      collectionHandler: (repo, filters, skip, take, authorization) async {
        final rows = await leaderboard.all();
        return QueryResult(
          rows.skip(skip).take(take).toList(),
          totalCount: rows.length,
        );
      },
    );
    final publicObjects = CrudResource<Document, UuidValue, Claims>(
      path: '/visible',
      repository: repository,
      serializer: DocumentSerializer(),
      authenticationHandler: verifier,
      defaultPolicy: AccessPolicy.custom(
        Policy(ownershipPolicy),
        authentication: AuthenticationRequirement.required,
      ),
      operationPolicies: {
        CrudOperation.read: AccessPolicy.custom(
          Policy((context) {
            final read = context as ReadContext<Document, UuidValue, Claims>;
            return read.current.isPublic ||
                    read.current.owner == read.caller.claims?.user
                ? const AuthorizationResult.allow()
                : const AuthorizationResult.deny(conceal: true);
          }),
        ),
        CrudOperation.query: AccessPolicy.custom(
          Policy(
            (context) => AuthorizationResult.allow(
              scope: TenantScope(context.caller.claims?.tenant ?? ''),
            ),
          ),
        ),
      },
      collectionHandler: (repo, filters, skip, take, authorization) async {
        final tenant = (authorization.scope as TenantScope).tenant;
        final rows = (await repository.all())
            .where((value) => value.isPublic || value.tenant == tenant)
            .toList();
        return QueryResult(
          rows.skip(skip).take(take).toList(),
          totalCount: rows.length,
        );
      },
    );
    final broken = CrudResource<Document, UuidValue, Claims>(
      path: '/broken',
      repository: repository,
      serializer: serializer,
      defaultPolicy: AccessPolicy.custom(
        Policy(
          (context) => throw const FormatException('PRIVATE-EXCEPTION'),
        ),
      ),
      collectionHandler: (repo, filters, skip, take, authorization) async {
        queries++;
        return QueryResult([private], totalCount: 999);
      },
    );
    final brokenVerifier = CrudResource<Document, UuidValue, Claims>(
      path: '/broken-verifier',
      repository: repository,
      serializer: serializer,
      authenticationHandler: ThrowingVerifier(),
    );
    final openStore = InMemoryRepository<Document, UuidValue>();
    final open = CrudResource<Document, UuidValue, void>(
      path: '/open',
      repository: openStore,
      serializer: DocumentSerializer(),
      collectionHandler: (repo, filters, skip, take, authorization) async =>
          QueryResult(
        openStore.getAllSync().skip(skip).take(take).toList(),
        totalCount: openStore.getAllSync().length,
      ),
    );
    final app = HttpServer()
      ..registerResource(privateApi)
      ..registerResource(board)
      ..registerResource(publicObjects)
      ..registerResource(broken)
      ..registerResource(brokenVerifier)
      ..registerResource(open);
    server = await shelf_io.serve(
      app.buildHandler(),
      io.InternetAddress.loopbackIPv4,
      0,
    );
    base = Uri.parse('http://127.0.0.1:${server.port}');
    client = http.Client();
  });
  tearDown(() async {
    client.close();
    await server.close(force: true);
  });

  Future<http.Response> send(
    String method,
    String path, {
    String? token,
    Document? body,
    Map<String, String> headers = const {},
  }) async {
    final outgoing = http.Request(method, base.resolve(path))
      ..headers.addAll({
        if (token != null) 'authorization': 'Bearer $token',
        if (body != null) 'content-type': 'application/json',
        ...headers,
      });
    if (body != null) outgoing.body = DocumentSerializer().serialize(body);
    return http.Response.fromStream(await client.send(outgoing));
  }

  for (final operation in [
    'item',
    'collection',
    'filtered',
    'pagination',
    'POST',
    'PUT',
    'DELETE',
  ]) {
    for (final token in <String?>[null, 'alice', 'bob', 'invalid']) {
      test('private HTTP $operation caller=$token', () async {
        final (method, path, body) = switch (operation) {
          'item' => ('GET', '/private/${private.id}', null),
          'collection' => ('GET', '/private', null),
          'filtered' => ('GET', '/private?tenant=one', null),
          'pagination' => ('GET', '/private?skip=1&take=1', null),
          'POST' => ('POST', '/private', Document()),
          'PUT' => (
              'PUT',
              '/private/${private.id}',
              private.copy(content: 'approved edit')
            ),
          _ => ('DELETE', '/private/${private.id}', null),
        };
        final response = await send(method, path, token: token, body: body);
        final expected = token == 'alice'
            ? switch (operation) { 'POST' => 201, 'DELETE' => 204, _ => 200 }
            : token == 'bob'
                ? 403
                : 401;
        expect(response.statusCode, expected, reason: response.body);
        if (expected >= 400) {
          expect(response.body, isNot(contains('PRIVATE-ALICE')));
          expect(response.headers['etag'], isNull);
          expect(response.headers['x-total-count'], isNull);
          expect(repository.writes, 0);
          expect(publisher.events, isEmpty);
          expect(queries, 0);
          if (serializer.candidates.isNotEmpty) {
            expect(
              serializer.candidates.first.getUncommittedEvents(),
              hasLength(1),
            );
          }
        } else {
          if (operation == 'pagination') {
            expect(response.body, '[]');
            expect(response.headers['x-total-count'], '1');
          }
          if (method == 'GET') {
            expect(
              response.headers['content-type'],
              contains('application/json'),
            );
          }
        }
      });
    }
  }

  for (final token in <String?>[null, 'alice', 'bob', 'invalid']) {
    test('leaderboard public reads with protected writes, caller=$token',
        () async {
      final readStatus = token == 'invalid' ? 401 : 200;
      expect(
        (await send('GET', '/leaderboard/${score.id}', token: token))
            .statusCode,
        readStatus,
      );
      expect(
        (await send('GET', '/leaderboard?skip=0&take=1', token: token))
            .statusCode,
        readStatus,
      );
      final expectedWrite = token == null || token == 'invalid' ? 401 : 403;
      expect(
        (await send(
          'PUT',
          '/leaderboard/${score.id}',
          token: token,
          body: score.copy(content: 'changed'),
        ))
            .statusCode,
        expectedWrite,
      );
      expect(
        (await send('DELETE', '/leaderboard/${score.id}', token: token))
            .statusCode,
        expectedWrite,
      );
    });
  }

  test(
      'leaderboard submissions validate identity; only moderator can correct/delete',
      () async {
    final proposed = Document(isPublic: true, content: 'SUBMISSION');
    expect(
      (await send('POST', '/leaderboard', token: 'bob', body: proposed))
          .statusCode,
      403,
    );
    expect(
      (await send('POST', '/leaderboard', token: 'alice', body: proposed))
          .statusCode,
      201,
    );
    final snapshot = await send('GET', '/leaderboard/${proposed.id}');
    expect(snapshot.statusCode, 200);
    expect(
      (await send(
        'PUT',
        '/leaderboard/${proposed.id}',
        token: 'admin',
        body: proposed.copy(content: 'CORRECTED'),
        headers: {'if-match': snapshot.headers['etag']!},
      ))
          .statusCode,
      200,
    );
    expect(
      (await send('DELETE', '/leaderboard/${proposed.id}', token: 'admin'))
          .statusCode,
      204,
    );
  });

  test('optional custom public objects expose only visible rows and counts',
      () async {
    final hidden = await send('GET', '/visible/${private.id}');
    final missing = await send('GET', '/visible/${UuidValue.generate()}');
    expect(hidden.statusCode, 404);
    expect(hidden.body, missing.body);
    expect(hidden.headers['etag'], isNull);
    expect((await send('GET', '/visible/${public.id}')).statusCode, 200);
    final page = await send('GET', '/visible?skip=1&take=1');
    expect(page.statusCode, 200);
    expect(page.body, '[]');
    expect(page.headers['x-total-count'], '1');
    final own = await send('GET', '/visible', token: 'alice');
    expect((jsonDecode(own.body) as List).length, 2);
    expect(own.headers['x-total-count'], '2');
  });

  test('forged body and POST existing ID fail through real routing', () async {
    final forged = private.copy(owner: 'bob', tenant: 'two', content: 'stolen');
    expect(
      (await send(
        'PUT',
        '/private/${private.id}',
        token: 'bob',
        body: forged,
      ))
          .statusCode,
      403,
    );
    expect(
      (await send('POST', '/private', token: 'bob', body: forged)).statusCode,
      409,
    );
    expect((await repository.getById(private.id)).owner, 'alice');
    expect(publisher.events, isEmpty);
  });

  test('thrown policy never leaks body/count/ETag or executes query/write',
      () async {
    for (final operation in ['item', 'query', 'POST', 'PUT', 'DELETE']) {
      final method =
          operation == 'item' || operation == 'query' ? 'GET' : operation;
      final path = operation == 'POST' || operation == 'query'
          ? '/broken'
          : '/broken/${private.id}';
      final response = await send(
        method,
        path,
        body: method == 'POST' || method == 'PUT' ? private : null,
      );
      expect(response.statusCode, 500);
      expect(response.body, isNot(contains('PRIVATE')));
      expect(response.headers['etag'], isNull);
      expect(response.headers['x-total-count'], isNull);
    }
    expect(repository.writes, 0);
    expect(publisher.events, isEmpty);
    expect(queries, 0);
  });

  test('verifier exceptions fail before lookup without leaking their text',
      () async {
    final response =
        await send('GET', '/broken-verifier/${private.id}', token: 'alice');
    expect(response.statusCode, 500);
    expect(response.body, isNot(contains('PRIVATE-VERIFIER')));
    expect(response.headers['etag'], isNull);
    expect(repository.reads, 0);
    expect(repository.writes, 0);
  });

  test('HTTP tenant filter cannot widen the verified scope', () async {
    final response = await send('GET', '/private?tenant=two', token: 'alice');
    expect(response.statusCode, 200);
    expect(response.body, '[]');
    expect(response.headers['x-total-count'], '0');
  });

  test('unconfigured public CRUD works over HTTP without any verifier',
      () async {
    final value = Document();
    expect((await send('POST', '/open', body: value)).statusCode, 201);
    expect((await send('GET', '/open/${value.id}')).statusCode, 200);
    expect((await send('GET', '/open?skip=0&take=1')).statusCode, 200);
    expect(
      (await send(
        'PUT',
        '/open/${value.id}',
        body: value.copy(content: 'open edit'),
      ))
          .statusCode,
      200,
    );
    expect((await send('DELETE', '/open/${value.id}')).statusCode, 204);
  });
}
