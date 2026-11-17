import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_rest/dddart_rest.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'authorization_test_support.dart';

// Exposes response encoding separately from domain snapshot conversion.
class EncodingSpy extends DocumentSerializer {
  int responses = 0;
  @override
  Map<String, dynamic> toJson(Document value, [SerializationConfig? config]) =>
      {
        'id': value.id.uuid,
        'owner': value.owner,
        'tenant': value.tenant,
        'role': value.role,
        'isPublic': value.isPublic,
        'content': value.content,
      };
  @override
  Document fromJson(dynamic value, [SerializationConfig? config]) => Document(
        id: UuidValue.fromString(value['id'] as String),
        owner: value['owner'] as String,
        tenant: value['tenant'] as String,
        role: value['role'] as String,
        isPublic: value['isPublic'] as bool,
        content: value['content'] as String,
      );
  @override
  String serialize(Document value, [SerializationConfig? config]) {
    responses++;
    return jsonEncode(toJson(value));
  }
}

// A response projection intentionally omits ownership. It must never become
// the source of trusted permission state.
class ProjectedSerializer extends EncodingSpy {
  @override
  Map<String, dynamic> toJson(Document value, [SerializationConfig? config]) =>
      super.toJson(value, config)..remove('owner');
  @override
  Document fromJson(dynamic value, [SerializationConfig? config]) => super
      .fromJson({...value as Map<String, dynamic>, 'owner': 'bob'}, config);
}

void main() {
  late Documents repository;
  late Document alice;
  late Document bob;
  late Document public;
  late EncodingSpy serializer;
  setUp(() async {
    repository = Documents();
    alice = Document(content: 'Alice confidential');
    bob = Document(owner: 'bob', tenant: 'two', content: 'Bob confidential');
    public = Document(
      owner: 'bob',
      tenant: 'two',
      isPublic: true,
      content: 'Public score',
    );
    for (final value in [
      alice,
      bob,
      public,
      Document(content: 'Alice second'),
    ]) {
      await repository.save(value);
    }
    serializer = EncodingSpy();
  });

  test('item policy receives stored ownership before response encoding or ETag',
      () async {
    final policy = Policy((context) {
      final read = context as ReadContext<Document, UuidValue, Claims>;
      expect(read.current.id, alice.id);
      expect(read.current.owner, 'alice');
      expect(serializer.responses, 0);
      return read.current.owner == read.caller.claims?.user
          ? const AuthorizationResult.allow()
          : const AuthorizationResult.deny();
    });
    final api = CrudResource<Document, UuidValue, Claims>(
      path: '/documents',
      repository: repository,
      serializer: serializer,
      authorizationSnapshot: cloneDocument,
      authenticationHandler: Verifier(),
      defaultPolicy: AccessPolicy.custom(
        policy,
        authentication: AuthenticationRequirement.required,
      ),
    );
    final denied =
        await api.handleGetById(request('GET', token: 'bob'), alice.id.uuid);
    expect(denied.statusCode, 403);
    expect(serializer.responses, 0);
    expect(denied.headers['etag'], isNull);
    expect(await denied.readAsString(), isNot(contains('Alice confidential')));
    final allowed =
        await api.handleGetById(request('GET', token: 'alice'), alice.id.uuid);
    expect(allowed.statusCode, 200);
    expect(serializer.responses, 1);
    expect(allowed.headers['etag'], isNotNull);
    expect(
      jsonDecode(await allowed.readAsString())['content'],
      'Alice confidential',
    );
  });

  for (final path in [
    '/documents',
    '/documents?tenant=two',
    '/documents?skip=1&take=1',
  ]) {
    for (final throwsPolicy in [false, true]) {
      test('collection policy gates handler for $path, throws=$throwsPolicy',
          () async {
        var handlerCalls = 0;
        final policy = Policy((context) {
          expect(context, isA<QueryContext<Document, UuidValue, Claims>>());
          if (throwsPolicy) {
            throw const FormatException('secret global count: 999');
          }
          return const AuthorizationResult.deny();
        });
        Future<QueryResult<Document>> query(
          Repository<Document, UuidValue> repo,
          Map<String, String> filters,
          int skip,
          int take,
          AuthorizedQuery<Claims> authorization,
        ) async {
          handlerCalls++;
          return QueryResult([alice, bob], totalCount: 999);
        }

        final api = CrudResource<Document, UuidValue, Claims>(
          path: '/documents',
          repository: repository,
          serializer: serializer,
          authorizationSnapshot: cloneDocument,
          defaultPolicy: AccessPolicy.custom(policy),
          collectionHandler: query,
          queryHandlers: {'tenant': query},
        );
        final response = await api.handleQuery(request('GET', path: path));
        expect(response.statusCode, throwsPolicy ? 500 : 403);
        expect(policy.contexts, hasLength(1));
        expect(handlerCalls, 0);
        expect(response.headers['x-total-count'], isNull);
        final body = await response.readAsString();
        expect(body, isNot(contains('confidential')));
        expect(body, isNot(contains('999')));
      });
    }
  }

  test('verified tenant scope restricts rows AND count before pagination',
      () async {
    final policy = Policy(
      (context) => AuthorizationResult.allow(
        scope: TenantScope(context.caller.claims!.tenant),
      ),
    );
    Future<QueryResult<Document>> query(
      Repository<Document, UuidValue> repo,
      Map<String, String> filters,
      int skip,
      int take,
      AuthorizedQuery<Claims> authorization,
    ) async {
      final tenant = (authorization.scope as TenantScope).tenant;
      final visible = (await repository.all())
          .where((value) => value.tenant == tenant)
          .where(
            (value) =>
                !filters.containsKey('tenant') ||
                value.tenant == filters['tenant'],
          )
          .toList()
        ..sort((one, two) => one.content.compareTo(two.content));
      return QueryResult(
        visible.skip(skip).take(take).toList(),
        totalCount: visible.length,
      );
    }

    final api = CrudResource<Document, UuidValue, Claims>(
      path: '/documents',
      repository: repository,
      serializer: serializer,
      authorizationSnapshot: cloneDocument,
      authenticationHandler: Verifier(),
      defaultPolicy: AccessPolicy.custom(
        policy,
        authentication: AuthenticationRequirement.required,
      ),
      collectionHandler: query,
      queryHandlers: {'tenant': query},
    );
    for (final parameters in [
      '',
      '?skip=1&take=1',
      '?skip=10&take=1',
      '?tenant=two',
      '?tenant=one&take=0',
    ]) {
      final response = await api.handleQuery(
        request('GET', path: '/documents$parameters', token: 'alice'),
      );
      expect(response.statusCode, 200);
      final rows = jsonDecode(await response.readAsString()) as List;
      expect(rows.every((dynamic value) => value['tenant'] == 'one'), isTrue);
      expect(
        response.headers['x-total-count'],
        parameters == '?tenant=two' ? '0' : '2',
      );
      if (parameters.contains('skip=10') ||
          parameters.contains('tenant=two') ||
          parameters.contains('take=0')) {
        expect(rows, isEmpty);
      } else {
        expect(rows.length, parameters.isEmpty ? 2 : 1);
      }
    }
  });

  test(
      'anonymous stored-public policy reveals public objects and hides private ones',
      () async {
    final policy = Policy((context) {
      final read = context as ReadContext<Document, UuidValue, Claims>;
      return read.current.isPublic ||
              read.current.owner == read.caller.claims?.user
          ? const AuthorizationResult.allow()
          : const AuthorizationResult.deny(conceal: true);
    });
    final api = CrudResource<Document, UuidValue, Claims>(
      path: '/documents',
      repository: repository,
      serializer: serializer,
      authorizationSnapshot: cloneDocument,
      authenticationHandler: Verifier(),
      defaultPolicy: const AccessPolicy.authenticated(),
      operationPolicies: {CrudOperation.read: AccessPolicy.custom(policy)},
    );
    expect(
      (await api.handleGetById(request('GET'), public.id.uuid)).statusCode,
      200,
    );
    final private = await api.handleGetById(request('GET'), bob.id.uuid);
    final missing =
        await api.handleGetById(request('GET'), UuidValue.generate().uuid);
    expect(private.statusCode, 404);
    expect(private.headers['etag'], isNull);
    expect(await private.readAsString(), await missing.readAsString());
    expect(
      (await api.handleUpdate(
        request('PUT', document: public),
        public.id.uuid,
      ))
          .statusCode,
      401,
    );
  });

  test('response projection cannot rewrite the stored owner seen by policy',
      () async {
    final api = CrudResource<Document, UuidValue, Claims>(
      path: '/documents',
      repository: repository,
      serializer: ProjectedSerializer(),
      authorizationSnapshot: cloneDocument,
      authenticationHandler: Verifier(),
      defaultPolicy: AccessPolicy.custom(
        Policy(
          (context) => (context as ReadContext<Document, UuidValue, Claims>)
                      .current
                      .owner ==
                  context.caller.claims?.user
              ? const AuthorizationResult.allow()
              : const AuthorizationResult.deny(),
        ),
        authentication: AuthenticationRequirement.required,
      ),
    );
    final response =
        await api.handleGetById(request('GET', token: 'bob'), alice.id.uuid);
    expect(response.statusCode, 403);
    expect(
      await response.readAsString(),
      isNot(contains('Alice confidential')),
    );
  });

  test('query handler can impose stricter access than the resource policy',
      () async {
    final api = CrudResource<Document, UuidValue, Claims>(
      path: '/documents',
      repository: repository,
      serializer: serializer,
      authorizationSnapshot: cloneDocument,
      collectionHandler: (repo, filters, skip, take, authorization) async =>
          throw const AccessDeniedException(),
    );
    expect((await api.handleQuery(request('GET'))).statusCode, 403);
  });

  test('exception mappers cannot turn a configured policy failure into success',
      () async {
    final api = CrudResource<Document, UuidValue, Claims>(
      path: '/documents',
      repository: repository,
      serializer: serializer,
      authorizationSnapshot: cloneDocument,
      defaultPolicy: AccessPolicy.custom(
        Policy((context) => const AuthorizationResult.deny()),
      ),
      customExceptionHandlers: {
        AccessDeniedException: (_) => Response.ok('private data'),
      },
    );
    final response = await api.handleGetById(request('GET'), alice.id.uuid);
    expect(response.statusCode, 403);
    expect(await response.readAsString(), isNot(contains('private data')));
  });
}
