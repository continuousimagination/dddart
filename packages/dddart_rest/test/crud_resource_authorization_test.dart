import 'package:dddart/dddart.dart';
import 'package:dddart_rest/dddart_rest.dart';
import 'package:test/test.dart';

import 'authorization_test_support.dart';

void main() {
  late Documents repository;
  late Document document;
  late Verifier verifier;
  setUp(() async {
    repository = Documents();
    document = Document();
    verifier = Verifier();
    await repository.save(document);
    repository.resetCounters();
  });

  CrudResource<Document, UuidValue, Claims> resource({
    AccessPolicy<Document, UuidValue, Claims>? policy,
    bool withVerifier = false,
    Map<CrudOperation, AccessPolicy<Document, UuidValue, Claims>> overrides =
        const {},
    QueryHandler<Document, UuidValue, Claims>? collection,
  }) =>
      CrudResource(
        path: '/documents',
        repository: repository,
        serializer: DocumentSerializer(),
        authorizationSnapshot: cloneDocument,
        authenticationHandler: withVerifier ? verifier : null,
        defaultPolicy: policy,
        operationPolicies: overrides,
        collectionHandler: collection,
      );

  test('no security configuration keeps all CRUD operations public', () async {
    final api = resource(
      collection: (repo, filters, skip, take, authorization) async {
        expect(authorization.caller, isA<AnonymousCaller<Claims>>());
        expect(authorization.scope, isA<UnrestrictedQueryScope>());
        return QueryResult([document], totalCount: 1);
      },
    );
    expect(
      (await api.handleGetById(request('GET'), document.id.uuid)).statusCode,
      200,
    );
    expect((await api.handleQuery(request('GET'))).statusCode, 200);
    final fresh = Document();
    expect(
      (await api.handleCreate(request('POST', document: fresh))).statusCode,
      201,
    );
    expect(
      (await api.handleUpdate(
        request('PUT', document: document.copy(content: 'edit')),
        document.id.uuid,
      ))
          .statusCode,
      200,
    );
    expect(
      (await api.handleDelete(request('DELETE'), document.id.uuid)).statusCode,
      204,
    );
  });

  test(
      'required default rejects missing and invalid credentials before protected work',
      () async {
    var queries = 0;
    final api = resource(
      withVerifier: true,
      collection: (repo, filters, skip, take, authorization) async {
        queries++;
        return QueryResult([document]);
      },
    );
    for (final token in [null, 'invalid']) {
      final responses = await Future.wait([
        api.handleGetById(request('GET', token: token), document.id.uuid),
        api.handleQuery(request('GET', token: token)),
        api.handleCreate(request('POST', token: token, document: Document())),
        api.handleUpdate(
          request('PUT', token: token, document: document),
          document.id.uuid,
        ),
        api.handleDelete(request('DELETE', token: token), document.id.uuid),
      ]);
      expect(responses.map((r) => r.statusCode), everyElement(401));
    }
    expect(repository.reads, 0);
    expect(repository.writes, 0);
    expect(queries, 0);
    expect(
      (await api.handleGetById(
        request('GET', token: 'alice'),
        document.id.uuid,
      ))
          .statusCode,
      200,
    );
  });

  test('public item/list overrides work anonymously with protected writes',
      () async {
    final api = resource(
      withVerifier: true,
      overrides: {
        CrudOperation.read: const AccessPolicy.public(),
        CrudOperation.query: const AccessPolicy.public(),
      },
      collection: (repo, filters, skip, take, authorization) async =>
          QueryResult([document]),
    );
    expect(
      (await api.handleGetById(request('GET'), document.id.uuid)).statusCode,
      200,
    );
    expect((await api.handleQuery(request('GET'))).statusCode, 200);
    expect(verifier.calls, 0);
    expect(
      (await api.handleUpdate(
        request('PUT', document: document),
        document.id.uuid,
      ))
          .statusCode,
      401,
    );
    expect(
      (await api.handleGetById(
        request('GET', token: 'invalid'),
        document.id.uuid,
      ))
          .statusCode,
      401,
    );
    expect(repository.writes, 0);
  });

  test(
      'explicit public default verifies supplied credentials and retains typed claims',
      () async {
    Caller<Claims>? caller;
    final api = resource(
      withVerifier: true,
      policy: const AccessPolicy.public(),
      collection: (repo, filters, skip, take, authorization) async {
        caller = authorization.caller;
        return QueryResult([]);
      },
    );
    expect(
      (await api.handleQuery(request('GET', token: 'alice'))).statusCode,
      200,
    );
    expect(caller, isA<VerifiedCaller<Claims>>());
    expect(caller!.claims!.tenant, 'one');
    expect((await api.handleQuery(request('GET'))).statusCode, 200);
    expect(caller, isA<AnonymousCaller<Claims>>());
    expect(
      (await api.handleQuery(request('GET', headers: {'authorization': ''})))
          .statusCode,
      401,
    );
  });

  test('custom anonymous policy always executes and receives persisted state',
      () async {
    final policy = Policy(
      (context) => context is ReadContext<Document, UuidValue, Claims> &&
              context.current.isPublic
          ? const AuthorizationResult.allow()
          : const AuthorizationResult.deny(),
    );
    final api = resource(policy: AccessPolicy.custom(policy));
    expect(
      (await api.handleGetById(request('GET'), document.id.uuid)).statusCode,
      403,
    );
    await repository.save(document.copy(isPublic: true));
    expect(
      (await api.handleGetById(request('GET'), document.id.uuid)).statusCode,
      200,
    );
    expect(policy.contexts, hasLength(2));
    expect(policy.contexts.first.caller, isA<AnonymousCaller<Claims>>());
  });

  test('required custom policy cannot downgrade failed verification', () async {
    final policy = Policy((context) => const AuthorizationResult.allow());
    final api = resource(
      withVerifier: true,
      policy: AccessPolicy.custom(
        policy,
        authentication: AuthenticationRequirement.required,
      ),
    );
    expect(
      (await api.handleGetById(request('GET'), document.id.uuid)).statusCode,
      401,
    );
    expect(policy.contexts, isEmpty);
    expect(
      (await api.handleGetById(
        request('GET', token: 'alice'),
        document.id.uuid,
      ))
          .statusCode,
      200,
    );
    expect(policy.contexts.single.caller.claims!.user, 'alice');
  });

  test('verified denial and anonymous custom denial return 403 without an ETag',
      () async {
    final policy = Policy((context) => const AuthorizationResult.deny());
    final api =
        resource(withVerifier: true, policy: AccessPolicy.custom(policy));
    for (final token in [null, 'alice']) {
      final response = await api.handleGetById(
        request('GET', token: token),
        document.id.uuid,
      );
      expect(response.statusCode, 403);
      expect(response.headers['etag'], isNull);
      expect(await response.readAsString(), isNot(contains(document.content)));
    }
  });

  test('concealed denial matches missing-record response', () async {
    final api = resource(
      policy: AccessPolicy.custom(
        Policy(
          (context) => const AuthorizationResult.deny(conceal: true),
        ),
      ),
    );
    final denied = await api.handleGetById(request('GET'), document.id.uuid);
    final missing =
        await api.handleGetById(request('GET'), UuidValue.generate().uuid);
    expect(denied.statusCode, 404);
    expect(missing.statusCode, 404);
    expect(await denied.readAsString(), await missing.readAsString());
  });

  test('thrown policy details cannot leak and no operation follows failure',
      () async {
    final api = resource(
      policy: AccessPolicy.custom(
        Policy(
          (context) => throw const FormatException('private policy secret'),
        ),
      ),
    );
    final response =
        await api.handleCreate(request('POST', document: Document()));
    expect(response.statusCode, 500);
    expect(
      await response.readAsString(),
      isNot(contains('private policy secret')),
    );
    expect(repository.writes, 0);
  });

  test('query policy requires explicit scope before invoking application code',
      () async {
    var called = false;
    final api = resource(
      policy: AccessPolicy.custom(
        Policy((context) => const AuthorizationResult.allow()),
      ),
      collection: (repo, filters, skip, take, authorization) async {
        called = true;
        return QueryResult([]);
      },
    );
    expect((await api.handleQuery(request('GET'))).statusCode, 500);
    expect(called, isFalse);
  });

  test('custom query scope and concrete claims arrive at the handler',
      () async {
    final policy = Policy(
      (context) => AuthorizationResult.allow(
        scope: TenantScope(context.caller.claims!.tenant),
      ),
    );
    final api = resource(
      withVerifier: true,
      policy: AccessPolicy.custom(
        policy,
        authentication: AuthenticationRequirement.required,
      ),
      collection: (repo, filters, skip, take, authorization) async {
        // Compile-time proof that concrete claims survive the query boundary.
        // ignore: omit_local_variable_types
        final Claims claims = authorization.caller.claims!;
        expect(claims.user, 'alice');
        expect((authorization.scope as TenantScope).tenant, 'one');
        return QueryResult([]);
      },
    );
    expect(
      (await api.handleQuery(request('GET', token: 'alice'))).statusCode,
      200,
    );
  });

  test(
      'custom policies receive all anonymous mutation contexts after normalization',
      () async {
    final policy = Policy(
      (context) =>
          const AuthorizationResult.allow(scope: UnrestrictedQueryScope()),
    );
    final fresh = Document(owner: 'client');
    final api = CrudResource<Document, UuidValue, Claims>(
      path: '/documents',
      repository: repository,
      serializer: DocumentSerializer(),
      authorizationSnapshot: cloneDocument,
      defaultPolicy: AccessPolicy.custom(policy),
      preCreate: (value, caller) {
        expect(caller, isA<AnonymousCaller<Claims>>());
        return value.copy(owner: 'server-normalized');
      },
    );
    expect(
      (await api.handleCreate(request('POST', document: fresh))).statusCode,
      201,
    );
    expect(
      (policy.contexts.single as CreateContext<Document, UuidValue, Claims>)
          .proposed
          .owner,
      'server-normalized',
    );
    final proposed = document.copy(content: 'new');
    expect(
      (await api.handleUpdate(
        request('PUT', document: proposed),
        document.id.uuid,
      ))
          .statusCode,
      200,
    );
    final update =
        policy.contexts.last as UpdateContext<Document, UuidValue, Claims>;
    expect(update.current.content, document.content);
    expect(update.proposed.content, 'new');
    expect(identical(update.current, update.proposed), isFalse);
    expect(
      (await api.handleDelete(request('DELETE'), document.id.uuid)).statusCode,
      204,
    );
    expect(
      (policy.contexts.last as DeleteContext<Document, UuidValue, Claims>)
          .current
          .content,
      'new',
    );
    expect(
      policy.contexts.every((context) => !context.caller.isAuthenticated),
      isTrue,
    );
  });

  test('credential detector exceptions fail closed without leaking text',
      () async {
    final api = CrudResource<Document, UuidValue, Claims>(
      path: '/documents',
      repository: repository,
      serializer: DocumentSerializer(),
      authorizationSnapshot: cloneDocument,
      authenticationHandler: verifier,
      defaultPolicy: const AccessPolicy.public(),
      credentialsPresent: (_) =>
          throw const FormatException('private cookie detail'),
    );
    final response = await api.handleGetById(request('GET'), document.id.uuid);
    expect(response.statusCode, 500);
    expect(
      await response.readAsString(),
      isNot(contains('private cookie detail')),
    );
    expect(repository.reads, 0);
  });

  test(
      'custom aggregate policy requires an explicit complete snapshot strategy',
      () {
    expect(
      () => CrudResource<Document, UuidValue, Claims>(
        path: '/documents',
        repository: repository,
        serializer: DocumentSerializer(),
        defaultPolicy: AccessPolicy.custom(
          Policy((context) => const AuthorizationResult.allow()),
        ),
      ),
      throwsArgumentError,
    );
  });

  test('query-only policy needs no aggregate snapshot function', () async {
    final api = CrudResource<Document, UuidValue, Claims>(
      path: '/documents',
      repository: repository,
      serializer: DocumentSerializer(),
      operationPolicies: {
        CrudOperation.query: AccessPolicy.custom(
          Policy(
            (context) => const AuthorizationResult.allow(
              scope: UnrestrictedQueryScope(),
            ),
          ),
        ),
      },
      collectionHandler: (repo, filters, skip, take, authorization) async =>
          QueryResult([]),
    );
    expect((await api.handleQuery(request('GET'))).statusCode, 200);
  });

  test('invalid snapshot function fails closed before policy or mutation',
      () async {
    final handler = Policy((context) => const AuthorizationResult.allow());
    final api = CrudResource<Document, UuidValue, Claims>(
      path: '/documents',
      repository: repository,
      serializer: DocumentSerializer(),
      defaultPolicy: AccessPolicy.custom(handler),
      authorizationSnapshot: (value) => value,
    );
    expect(
      (await api.handleUpdate(
        request('PUT', document: document),
        document.id.uuid,
      ))
          .statusCode,
      500,
    );
    expect(handler.contexts, isEmpty);
    expect(repository.writes, 0);
  });

  test('incompatible required authentication fails at construction', () {
    expect(
      () => resource(policy: const AccessPolicy.authenticated()),
      throwsArgumentError,
    );
    expect(
      () => resource(
        overrides: {
          CrudOperation.delete: const AccessPolicy.authenticated(),
        },
      ),
      throwsArgumentError,
    );
    expect(
      () => VerifiedCaller(AuthenticationResult<Claims>.failure('no')),
      throwsArgumentError,
    );
  });
}
