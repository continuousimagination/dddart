import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_repository_rest/dddart_repository_rest.dart';
import 'package:dddart_rest/dddart_rest.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:test/test.dart';

import 'test_models.dart';

void main() {
  test('generated REST save publishes separately after successful public CRUD',
      () async {
    final user = TestUser(name: 'Alice', email: 'alice@example.com');
    final first = _Changed(user.id);
    final later = _Changed(user.id);
    user.raiseEvent(first);
    final operations = <String>[];
    final serverRepository = InMemoryRepository<TestUser, UuidValue>();
    await serverRepository.save(
      TestUser(name: 'Before', email: user.email, id: user.id),
    );
    final server = HttpServer()
      ..registerResource(
        CrudResource<TestUser, UuidValue, void>(
          path: '/users',
          repository: serverRepository,
          serializer: TestUserJsonSerializer(),
        ),
      );
    final handler = server.buildHandler();
    final connection = RestConnection(
      baseUrl: 'https://example.com',
      httpClient: MockClient((request) async {
        operations.add(request.method);
        final json = jsonDecode(request.body) as Map<String, dynamic>;
        expect(
          json.keys.toSet(),
          {'id', 'createdAt', 'updatedAt', 'name', 'email'},
        );
        expect(
          TestUserJsonSerializer().fromJson(json).getUncommittedEvents(),
          isEmpty,
        );
        expect(request.headers.keys, isNot(contains('pendingEvents')));
        final response = await handler(
          shelf.Request(
            request.method,
            request.url,
            headers: request.headers,
            body: request.body,
          ),
        );
        // Events raised during the asynchronous save belong to the next save.
        user.raiseEvent(later);
        return http.Response(
          await response.readAsString(),
          response.statusCode,
          headers: response.headers,
        );
      }),
    );
    addTearDown(connection.dispose);
    final published = <DomainEvent<Identity>>[];
    final repository = TestUserRestRepository(
      connection,
      eventPublisher: _Publisher((event) async {
        final saved = await serverRepository.getById(user.id);
        expect(saved.name, 'Alice');
        expect(saved.getUncommittedEvents(), isEmpty);
        operations.add('publish');
        published.add(event);
        return true;
      }),
    );

    await repository.save(user);

    expect(operations, ['PUT', 'publish']);
    expect(published, [first]);
    expect(user.getUncommittedEvents(), [later]);
  });

  test('failed generated REST CRUD does not publish or acknowledge events',
      () async {
    final user = TestUser(name: 'Alice', email: 'alice@example.com');
    final event = _Changed(user.id);
    user.raiseEvent(event);
    var publications = 0;
    final connection = RestConnection(
      baseUrl: 'https://example.com',
      httpClient: MockClient((_) async => http.Response('', 500)),
    );
    addTearDown(connection.dispose);
    final repository = TestUserRestRepository(
      connection,
      eventPublisher: _Publisher((_) async {
        publications++;
        return true;
      }),
    );

    await expectLater(
      repository.save(user),
      throwsA(isA<RepositoryException>()),
    );
    expect(publications, 0);
    expect(user.getUncommittedEvents(), [event]);
  });
}

class _Changed extends DomainEvent<UuidValue> {
  _Changed(UuidValue id) : super(aggregateId: id);
}

class _Publisher implements EventPublisher {
  _Publisher(this.callback);
  final Future<bool> Function(DomainEvent<Identity>) callback;
  @override
  Future<bool> publish(DomainEvent<Identity> event) => callback(event);
}
