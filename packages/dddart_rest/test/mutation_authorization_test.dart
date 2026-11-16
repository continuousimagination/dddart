import 'dart:async';

import 'package:dddart/dddart.dart';
import 'package:dddart_rest/dddart_rest.dart';
import 'package:test/test.dart';

import 'authorization_test_support.dart';

void main() {
  late Documents repository;
  late Document original;
  late RecordingPublisher publisher;
  late EventSerializer serializer;
  late Policy policy;
  late CrudResource<Document, UuidValue, Claims> api;
  setUp(() async {
    publisher = RecordingPublisher();
    repository = Documents(eventPublisher: publisher);
    original = Document();
    await repository.save(original);
    repository.resetCounters();
    serializer = EventSerializer();
    policy = Policy(ownershipPolicy);
    api = CrudResource(
      path: '/documents',
      repository: repository,
      serializer: serializer,
      authenticationHandler: Verifier(),
      defaultPolicy: AccessPolicy.custom(
        policy,
        authentication: AuthenticationRequirement.required,
      ),
    );
  });

  test('forged owner, tenant, role and publicity cannot grant write access',
      () async {
    for (final attempt in [
      ('bob', original.copy(owner: 'bob', tenant: 'two', content: 'stolen')),
      ('bob', original.copy(role: 'admin', isPublic: true)),
      ('alice', original.copy(owner: 'bob')),
      ('alice', original.copy(tenant: 'two')),
      ('alice', original.copy(role: 'admin')),
      ('alice', original.copy(isPublic: true)),
    ]) {
      serializer.candidates.clear();
      final response = await api.handleUpdate(
        request('PUT', token: attempt.$1, document: attempt.$2),
        original.id.uuid,
      );
      expect(response.statusCode, 403);
      expect(repository.writes, 0);
      expect(publisher.events, isEmpty);
      expect(serializer.candidates.first.getUncommittedEvents(), hasLength(1));
      final stored = await repository.getById(original.id);
      expect(
        DocumentSerializer().serialize(stored),
        DocumentSerializer().serialize(original),
      );
      final context =
          policy.contexts.last as UpdateContext<Document, UuidValue, Claims>;
      expect(context.current.owner, 'alice');
      expect(context.current.tenant, 'one');
      expect(identical(context.current, context.proposed), isFalse);
    }
  });

  test(
      'legitimate owner edit binds permission to its revision and acknowledges once',
      () async {
    final response = await api.handleUpdate(
      request(
        'PUT',
        token: 'alice',
        document: original.copy(content: 'edited'),
      ),
      original.id.uuid,
    );
    expect(response.statusCode, 200);
    expect(response.headers['etag'], isNotNull);
    expect((await repository.getById(original.id)).content, 'edited');
    expect(repository.writes, 1);
    expect(publisher.events, hasLength(1));
    expect(serializer.candidates.first.getUncommittedEvents(), isEmpty);
  });

  test('application policy can explicitly transfer ownership and tenant',
      () async {
    final transferred = original.copy(
      owner: 'bob',
      tenant: 'two',
      role: 'moderator',
      isPublic: true,
    );
    expect(
      (await api.handleUpdate(
        request('PUT', token: 'admin', document: transferred),
        original.id.uuid,
      ))
          .statusCode,
      200,
    );
    expect(
      (await api.handleUpdate(
        request(
          'PUT',
          token: 'alice',
          document: transferred.copy(content: 'old owner'),
        ),
        original.id.uuid,
      ))
          .statusCode,
      403,
    );
    expect(
      (await api.handleUpdate(
        request(
          'PUT',
          token: 'bob',
          document: transferred.copy(content: 'new owner'),
        ),
        original.id.uuid,
      ))
          .statusCode,
      200,
    );
    expect((await repository.getById(original.id)).content, 'new owner');
  });

  test('POST cannot overwrite a protected identity through a create policy',
      () async {
    final forged =
        original.copy(owner: 'bob', tenant: 'two', content: 'stolen');
    final revision = (await repository.getVersioned(original.id)).revision;
    for (final headers in <Map<String, String>>[
      {},
      {'if-none-match': '*'},
      {'if-match': RevisionETag.encode(revision)},
    ]) {
      final response = await api.handleCreate(
        request('POST', token: 'bob', document: forged, headers: headers),
      );
      expect(
        response.statusCode,
        headers.isEmpty
            ? 409
            : headers.containsKey('if-match')
                ? 501
                : 412,
      );
      expect((await repository.getById(original.id)).owner, 'alice');
      expect(publisher.events, isEmpty);
    }
    expect(
      (await api.handleUpdate(
        request('PUT', token: 'bob', document: forged),
        original.id.uuid,
      ))
          .statusCode,
      403,
    );
  });

  test('DELETE supplies persisted state and rejects another owner', () async {
    expect(
      (await api.handleDelete(
        request('DELETE', token: 'bob'),
        original.id.uuid,
      ))
          .statusCode,
      403,
    );
    expect(repository.writes, 0);
    final context =
        policy.contexts.single as DeleteContext<Document, UuidValue, Claims>;
    expect(context.current.owner, 'alice');
    expect(
      (await api.handleDelete(
        request('DELETE', token: 'alice'),
        original.id.uuid,
      ))
          .statusCode,
      204,
    );
    expect(
      (await api.handleDelete(
        request('DELETE', token: 'alice'),
        original.id.uuid,
      ))
          .statusCode,
      404,
    );
  });

  test(
      'create policy sees normalized owner and typed caller before persistence',
      () async {
    final order = <String>[];
    final normalizationPolicy = Policy((context) {
      order.add('policy');
      final create = context as CreateContext<Document, UuidValue, Claims>;
      expect(create.proposed.owner, 'alice');
      expect(create.caller.claims!.user, 'alice');
      return ownershipPolicy(context);
    });
    final normalized = CrudResource<Document, UuidValue, Claims>(
      path: '/documents',
      repository: repository,
      serializer: serializer,
      authenticationHandler: Verifier(),
      defaultPolicy: AccessPolicy.custom(
        normalizationPolicy,
        authentication: AuthenticationRequirement.required,
      ),
      preCreate: (value, caller) {
        order.add('normalize');
        return value.copy(
          owner: caller.claims!.user,
          tenant: caller.claims!.tenant,
        );
      },
    );
    final proposed = Document(owner: 'attacker', tenant: 'untrusted');
    final response = await normalized
        .handleCreate(request('POST', token: 'alice', document: proposed));
    expect(response.statusCode, 201);
    expect(order, ['normalize', 'policy']);
    expect((await repository.getById(proposed.id)).owner, 'alice');
  });

  test('a missing PUT must also pass create policy and cannot forge an owner',
      () async {
    final proposed = Document();
    expect(
      (await api.handleUpdate(
        request('PUT', token: 'bob', document: proposed),
        proposed.id.uuid,
      ))
          .statusCode,
      403,
    );
    expect(repository.writes, 0);
    expect(
      (await api.handleUpdate(
        request('PUT', token: 'alice', document: proposed),
        proposed.id.uuid,
      ))
          .statusCode,
      201,
    );
    expect(
      policy.contexts.last,
      isA<CreateContext<Document, UuidValue, Claims>>(),
    );
  });

  test(
      'public PUT cannot bypass required create permission for a missing identity',
      () async {
    final restrictedCreate = CrudResource<Document, UuidValue, Claims>(
      path: '/documents',
      repository: repository,
      serializer: serializer,
      authenticationHandler: Verifier(),
      defaultPolicy: const AccessPolicy.public(),
      operationPolicies: {
        CrudOperation.create: const AccessPolicy.authenticated(),
      },
    );
    final proposed = Document();
    expect(
      (await restrictedCreate.handleUpdate(
        request('PUT', document: proposed),
        proposed.id.uuid,
      ))
          .statusCode,
      401,
    );
    expect(repository.writes, 0);
    expect(
      (await restrictedCreate.handleUpdate(
        request('PUT', token: 'alice', document: proposed),
        proposed.id.uuid,
      ))
          .statusCode,
      201,
    );
  });

  for (final explicit in [false, true]) {
    test(
        'ownership change after policy rejects stale ${explicit ? 'explicit' : 'implicit'} write without retry',
        () async {
      final revision = (await repository.getVersioned(original.id)).revision;
      var raced = false;
      repository.beforeConditionalSave = () async {
        if (raced) throw StateError('must not retry');
        raced = true;
        await repository.save(original.copy(owner: 'bob', tenant: 'two'));
      };
      final response = await api.handleUpdate(
        request(
          'PUT',
          token: 'alice',
          document: original.copy(content: 'stale permission'),
          headers: explicit ? {'if-match': RevisionETag.encode(revision)} : {},
        ),
        original.id.uuid,
      );
      expect(response.statusCode, explicit ? 412 : 409);
      expect(policy.contexts, hasLength(1));
      expect((await repository.getById(original.id)).owner, 'bob');
      expect((await repository.getById(original.id)).content, original.content);
      expect(publisher.events, isEmpty);
      expect(serializer.candidates.first.getUncommittedEvents(), hasLength(1));
      repository.beforeConditionalSave = null;
      final reloaded = await repository.getById(original.id);
      expect(
        (await api.handleUpdate(
          request(
            'PUT',
            token: 'alice',
            document: reloaded.copy(content: 'retry'),
          ),
          original.id.uuid,
        ))
            .statusCode,
        403,
      );
    });
  }

  test('DELETE permission cannot survive a concurrent ownership change',
      () async {
    repository.beforeConditionalDelete =
        () => repository.save(original.copy(owner: 'bob', tenant: 'two'));
    final response = await api.handleDelete(
      request('DELETE', token: 'alice'),
      original.id.uuid,
    );
    expect(response.statusCode, 409);
    expect((await repository.getById(original.id)).owner, 'bob');
    expect(policy.contexts, hasLength(1));
  });

  test('policy exception retains pending events and leaves storage unchanged',
      () async {
    final broken = CrudResource<Document, UuidValue, Claims>(
      path: '/documents',
      repository: repository,
      serializer: serializer,
      defaultPolicy: AccessPolicy.custom(
        Policy((context) => throw StateError('private policy state')),
      ),
    );
    final response = await broken.handleUpdate(
      request('PUT', document: original.copy(content: 'failed')),
      original.id.uuid,
    );
    expect(response.statusCode, 500);
    expect(
      await response.readAsString(),
      isNot(contains('private policy state')),
    );
    expect(repository.writes, 0);
    expect(publisher.events, isEmpty);
    expect(serializer.candidates.first.getUncommittedEvents(), hasLength(1));
  });

  test('custom anonymous mutations run without fabricated credentials',
      () async {
    final anonymousPolicy = Policy((context) {
      expect(context.caller, isA<AnonymousCaller<Claims>>());
      return const AuthorizationResult.allow();
    });
    final anonymous = CrudResource<Document, UuidValue, Claims>(
      path: '/documents',
      repository: repository,
      serializer: serializer,
      defaultPolicy: AccessPolicy.custom(anonymousPolicy),
    );
    final proposed = Document();
    expect(
      (await anonymous.handleCreate(request('POST', document: proposed)))
          .statusCode,
      201,
    );
    expect(
      (await anonymous.handleUpdate(
        request(
          'PUT',
          document: proposed.copy(content: 'anonymous edit'),
        ),
        proposed.id.uuid,
      ))
          .statusCode,
      200,
    );
    expect(
      (await anonymous.handleDelete(request('DELETE'), proposed.id.uuid))
          .statusCode,
      204,
    );
    expect(anonymousPolicy.contexts, hasLength(3));
  });

  test('two authorized POST creates cannot replace each other', () async {
    final otherSerializer = EventSerializer();
    final other = CrudResource<Document, UuidValue, Claims>(
      path: '/documents',
      repository: repository,
      serializer: otherSerializer,
      authenticationHandler: Verifier(),
      defaultPolicy: AccessPolicy.custom(
        Policy(ownershipPolicy),
        authentication: AuthenticationRequirement.required,
      ),
    );
    var arrived = 0;
    final release = Completer<void>();
    repository.beforeConditionalSave = () async {
      if (++arrived == 2) release.complete();
      await release.future;
    };
    final id = UuidValue.generate();
    final results = await Future.wait([
      api.handleCreate(
        request('POST', token: 'alice', document: Document(id: id)),
      ),
      other.handleCreate(
        request(
          'POST',
          token: 'bob',
          document: Document(id: id, owner: 'bob', tenant: 'two'),
        ),
      ),
    ]);
    expect(
      results.map((result) => result.statusCode),
      unorderedEquals([201, 409]),
    );
    expect(
      (await repository.getById(id)).owner,
      results.first.statusCode == 201 ? 'alice' : 'bob',
    );
    expect(publisher.events, hasLength(1));
    expect(
      [
        serializer.candidates.first.getUncommittedEvents().length,
        otherSerializer.candidates.first.getUncommittedEvents().length,
      ],
      unorderedEquals([0, 1]),
    );
  });

  test('mutable policy snapshots cannot mutate storage or the actual proposal',
      () async {
    final detached = CrudResource<Document, UuidValue, Claims>(
      path: '/documents',
      repository: repository,
      serializer: serializer,
      defaultPolicy: AccessPolicy.custom(
        Policy((context) {
          final update = context as UpdateContext<Document, UuidValue, Claims>;
          update.current.tags.add('mutated current');
          update.proposed.tags.add('mutated proposed');
          return const AuthorizationResult.deny();
        }),
      ),
    );
    final response = await detached.handleUpdate(
      request('PUT', document: original.copy(content: 'proposal')),
      original.id.uuid,
    );
    expect(response.statusCode, 403);
    expect((await repository.getById(original.id)).tags, isEmpty);
    expect(serializer.candidates.first.tags, isEmpty);
    expect(repository.writes, 0);
    expect(publisher.events, isEmpty);
  });

  test('custom mutation on an incapable repository fails closed', () async {
    final basic = InMemoryRepository<Document, UuidValue>();
    await basic.save(original);
    final incapable = CrudResource<Document, UuidValue, Claims>(
      path: '/documents',
      repository: basic,
      serializer: serializer,
      defaultPolicy: AccessPolicy.custom(
        Policy((context) => const AuthorizationResult.allow()),
      ),
    );
    expect(
      (await incapable.handleUpdate(
        request('PUT', document: original.copy(content: 'unsafe')),
        original.id.uuid,
      ))
          .statusCode,
      501,
    );
    expect(
      (await incapable.handleDelete(request('DELETE'), original.id.uuid))
          .statusCode,
      501,
    );
    expect(
      (await incapable.handleCreate(request('POST', document: Document())))
          .statusCode,
      501,
    );
    expect((await basic.getById(original.id)).content, original.content);
  });
}
