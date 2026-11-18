import 'dart:async';
import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_rest/dddart_rest.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'json_serializer_test_support.dart';

// Test aggregate root
class TestUser extends AggregateRoot<UuidValue> {
  TestUser({
    required this.name,
    required this.email,
    UuidValue? id,
    super.createdAt,
    super.updatedAt,
  }) : super(id: id ?? UuidValue.generate());

  final String name;
  final String email;
}

// Test serializer
class TestUserSerializer extends TestJsonSerializer<TestUser> {
  @override
  String serialize(TestUser user, [SerializationConfig? config]) {
    return jsonEncode({
      'id': user.id.toString(),
      'name': user.name,
      'email': user.email,
      'createdAt': user.createdAt.toIso8601String(),
      'updatedAt': user.updatedAt.toIso8601String(),
    });
  }

  @override
  TestUser deserialize(String data, [SerializationConfig? config]) {
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

TestUser copy(TestUser value) =>
    TestUserSerializer().deserialize(TestUserSerializer().serialize(value));
TestUser user(String name, [UuidValue? id]) =>
    TestUser(name: name, email: 'a@example.com', id: id);
Request put(TestUser value, Map<String, String> headers) => Request(
      'PUT',
      Uri.parse('http://localhost/users/${value.id}'),
      headers: {'content-type': 'application/json', ...headers},
      body: TestUserSerializer().serialize(value),
    );

class TestRepository
    extends InMemoryConditionalRepository<TestUser, UuidValue> {
  TestRepository({super.store, super.eventPublisher}) : super(clone: copy);
  Future<void> Function()? barrier;
  Exception? failure;
  @override
  Future<String> saveConditional(
    TestUser aggregate, {
    required ExpectedRevision expected,
  }) async {
    await barrier?.call();
    if (failure != null) throw failure!;
    return super.saveConditional(aggregate, expected: expected);
  }
}

class Changed extends DomainEvent<UuidValue, UuidValue> {
  Changed(UuidValue id) : super(eventId: UuidValue.generate(), aggregateId: id);
}

class RaisingSerializer extends TestUserSerializer {
  final candidates = <TestUser>[];
  @override
  TestUser deserialize(String data, [SerializationConfig? config]) {
    final value = super.deserialize(data, config)
      ..raiseEvent(Changed(UuidValue.generate()));
    candidates.add(value);
    return value;
  }
}

class Publisher implements EventPublisher {
  final events = <DomainEvent<Identity, Identity>>[];
  @override
  Future<bool> publish(DomainEvent<Identity, Identity> event) async {
    events.add(event);
    return true;
  }
}

void main() {
  late TestRepository repository;
  late CrudResource<TestUser, UuidValue, void> resource;
  late TestUser original;
  late String etag;
  setUp(() async {
    repository = TestRepository();
    resource = CrudResource(
      path: '/users',
      repository: repository,
      serializer: TestUserSerializer(),
    );
    original = user('original');
    await repository.save(original);
    final response = await resource.handleGetById(
      Request('GET', Uri.parse('http://localhost/users/${original.id}')),
      original.id.uuid,
    );
    etag = response.headers['etag']!;
    expect(
      RevisionETag.tryDecode(etag),
      (await repository.getVersioned(original.id)).revision,
    );
  });

  test('POST honors explicit conditions without downgrading to ordinary save',
      () async {
    Request post(TestUser value, String condition) => Request(
          'POST',
          Uri.parse('http://localhost/users'),
          headers: {
            'content-type': 'application/json',
            'if-none-match': condition,
          },
          body: TestUserSerializer().serialize(value),
        );
    expect(
      (await resource.handleCreate(post(user('overwrite', original.id), '*')))
          .statusCode,
      412,
    );
    expect((await repository.getById(original.id)).name, 'original');
    final fresh = user('created');
    final response = await resource.handleCreate(post(fresh, '*'));
    expect(response.statusCode, 201);
    expect(
      RevisionETag.tryDecode(response.headers['etag']!),
      (await repository.getVersioned(fresh.id)).revision,
    );
  });

  test('two independent handlers at one revision commit exactly one candidate',
      () async {
    final store = InMemoryConditionalStore<TestUser, UuidValue>();
    final publisher = Publisher();
    final first = TestRepository(store: store, eventPublisher: publisher);
    final second = TestRepository(store: store, eventPublisher: publisher);
    await first.save(original);
    final revision = (await first.getVersioned(original.id)).revision;
    final serializer = RaisingSerializer();
    final one = CrudResource<TestUser, UuidValue, void>(
      path: '/users',
      repository: first,
      serializer: serializer,
    );
    final two = CrudResource<TestUser, UuidValue, void>(
      path: '/users',
      repository: second,
      serializer: serializer,
    );
    var entered = 0;
    final release = Completer<void>();
    Future<void> barrier() async {
      if (++entered == 2) release.complete();
      await release.future;
    }

    first.barrier = barrier;
    second.barrier = barrier;
    final tag = RevisionETag.encode(revision);
    final responses = await Future.wait([
      one.handleUpdate(
        put(user('one', original.id), {'if-match': tag}),
        original.id.uuid,
      ),
      two.handleUpdate(
        put(user('two', original.id), {'if-match': tag}),
        original.id.uuid,
      ),
    ]);
    expect(responses.map((r) => r.statusCode), unorderedEquals([200, 412]));
    final winner = responses.singleWhere((r) => r.statusCode == 200);
    final snapshot = await first.getVersioned(original.id);
    expect(
      TestUserSerializer().deserialize(await winner.readAsString()).name,
      snapshot.aggregate.name,
    );
    expect(RevisionETag.tryDecode(winner.headers['etag']!), snapshot.revision);
    expect(publisher.events, hasLength(1));
    expect(
      serializer.candidates.map((a) => a.getUncommittedEvents().length),
      unorderedEquals([0, 1]),
    );
    final loser = responses.singleWhere((r) => r.statusCode == 412);
    expect(loser.headers['etag'], isNull);
    expect(jsonDecode(await loser.readAsString())['status'], 412);
  });

  for (final shape in ['single', 'list', 'mixed weak', 'empty members']) {
    test('strong $shape condition reaches an atomic write', () async {
      final header = switch (shape) {
        'list' => '${RevisionETag.encode('other')}, $etag',
        'mixed weak' => 'W/"anything", $etag',
        'empty members' => ', ,$etag,,',
        _ => etag,
      };
      final response = await resource.handleUpdate(
        put(user('next', original.id), {'if-match': header}),
        original.id.uuid,
      );
      expect(response.statusCode, 200);
      expect(response.headers['etag'], isNot(etag));
    });
  }
  for (final entry in <String, int>{
    '"unknown"': 412,
    'W/"unknown"': 412,
    '*': 501,
    '': 400,
    'unquoted': 400,
    '"unterminated': 400,
    '"a" "b"': 400,
    '*, "a"': 400,
    'w/"a"': 400,
    '"a b"': 400,
    ',,': 400,
  }.entries) {
    test('If-Match ${entry.key} fails closed with ${entry.value}', () async {
      final response = await resource.handleUpdate(
        put(user('rejected', original.id), {'if-match': entry.key}),
        original.id.uuid,
      );
      expect(response.statusCode, entry.value);
      expect((await repository.getById(original.id)).name, 'original');
    });
  }
  test('weak version of the actual validator never matches', () async {
    final response = await resource.handleUpdate(
      put(user('rejected', original.id), {'if-match': 'W/$etag'}),
      original.id.uuid,
    );
    expect(response.statusCode, 412);
  });
  test('ordinary updates invalidate old tokens and return no speculative ETag',
      () async {
    final response = await resource.handleUpdate(
      put(user('ordinary', original.id), {}),
      original.id.uuid,
    );
    expect(response.statusCode, 200);
    expect(response.headers['etag'], isNull);
    final stale = await resource.handleUpdate(
      put(user('stale', original.id), {'if-match': etag}),
      original.id.uuid,
    );
    expect(stale.statusCode, 412);
  });
  test('matching deleted and recreated resources cannot pass an old condition',
      () async {
    await repository.deleteById(original.id);
    expect(
      (await resource.handleUpdate(
        put(original, {'if-match': etag}),
        original.id.uuid,
      ))
          .statusCode,
      412,
    );
    await repository.save(user('recreated', original.id));
    expect(
      (await resource.handleUpdate(
        put(original, {'if-match': etag}),
        original.id.uuid,
      ))
          .statusCode,
      412,
    );
    expect((await repository.getById(original.id)).name, 'recreated');
  });
  test(
      'create-if-absent and conditional delete use the same repository contract',
      () async {
    final created = user('new');
    final response = await resource.handleUpdate(
      put(created, {'if-none-match': '*'}),
      created.id.uuid,
    );
    expect(response.statusCode, 201);
    expect(
      (await resource.handleUpdate(
        put(created, {'if-none-match': '*'}),
        created.id.uuid,
      ))
          .statusCode,
      412,
    );
    final deleted = await resource.handleDelete(
      Request(
        'DELETE',
        Uri.parse('http://localhost/users/${created.id}'),
        headers: {'if-match': response.headers['etag']!},
      ),
      created.id.uuid,
    );
    expect(deleted.statusCode, 204);
    final absent = await resource.handleDelete(
      Request(
        'DELETE',
        Uri.parse('http://localhost/users/${created.id}'),
        headers: {'if-none-match': '*'},
      ),
      created.id.uuid,
    );
    expect(absent.statusCode, 204);
  });
  test('conflicting or unsupported precondition headers do not write',
      () async {
    expect(
      (await resource.handleUpdate(
        put(original, {'if-match': etag, 'if-none-match': '*'}),
        original.id.uuid,
      ))
          .statusCode,
      400,
    );
    expect(
      (await resource.handleUpdate(
        put(original, {'if-none-match': etag}),
        original.id.uuid,
      ))
          .statusCode,
      501,
    );
  });
  test('required preconditions reject missing conditions on update and delete',
      () async {
    resource = CrudResource(
      path: '/users',
      repository: repository,
      serializer: TestUserSerializer(),
      requirePrecondition: true,
    );
    expect(
      (await resource.handleUpdate(put(original, {}), original.id.uuid))
          .statusCode,
      428,
    );
    expect(
      (await resource.handleDelete(
        Request(
          'DELETE',
          Uri.parse('http://localhost/users/${original.id}'),
        ),
        original.id.uuid,
      ))
          .statusCode,
      428,
    );
    expect((await repository.getById(original.id)).name, 'original');
  });
  test(
      'plain repositories support CRUD but never pretend to enforce a condition',
      () async {
    final plain = InMemoryRepository<TestUser, UuidValue>();
    await plain.save(original);
    final public = CrudResource<TestUser, UuidValue, void>(
      path: '/users',
      repository: plain,
      serializer: TestUserSerializer(),
    );
    final get = await public.handleGetById(
      Request('GET', Uri.parse('http://localhost/users/${original.id}')),
      original.id.uuid,
    );
    expect(get.statusCode, 200);
    expect(get.headers['etag'], isNull);
    expect(
      (await public.handleUpdate(
        put(user('rejected', original.id), {'if-match': etag}),
        original.id.uuid,
      ))
          .statusCode,
      501,
    );
    expect((await plain.getById(original.id)).name, 'original');
    expect(
      () => CrudResource<TestUser, UuidValue, void>(
        path: '/users',
        repository: plain,
        serializer: TestUserSerializer(),
        requirePrecondition: true,
      ),
      throwsArgumentError,
    );
  });
  for (final failure in [
    const RepositoryException(
      'offline',
      type: RepositoryExceptionType.connection,
    ),
    const ConditionalWriteUncertainException(),
  ]) {
    test('storage failure ${failure.type} is not a stale conflict or success',
        () async {
      repository.failure = failure;
      final response = await resource.handleUpdate(
        put(user('rejected', original.id), {'if-match': etag}),
        original.id.uuid,
      );
      expect(response.statusCode, 500);
      expect((await repository.getById(original.id)).name, 'original');
    });
  }
  test('identity and media validation happen before conditional persistence',
      () async {
    expect(
      (await resource.handleUpdate(
        put(user('wrong'), {'if-match': etag}),
        original.id.uuid,
      ))
          .statusCode,
      400,
    );
    final request = Request(
      'PUT',
      Uri.parse('http://localhost/users/${original.id}'),
      headers: {'if-match': etag, 'content-type': 'text/plain'},
      body: '{}',
    );
    expect(
      (await resource.handleUpdate(request, original.id.uuid)).statusCode,
      415,
    );
    expect((await repository.getById(original.id)).name, 'original');
  });
}
