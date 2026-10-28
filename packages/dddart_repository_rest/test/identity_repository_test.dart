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
  test('generated native client encodes once and shares key/body codecs',
      () async {
    final codecs = issueIdentityCodecs();
    const id = NativeId('Repo/IssueA %2F, café?x=# ');
    final serializer = NativeIssueJsonSerializer.withIdentityCodecs(codecs);
    final requests = <http.Request>[];
    final connection = RestConnection(
      baseUrl: 'https://api.example.com/v1',
      httpClient: MockClient((request) async {
        requests.add(request);
        expect(request.url.pathSegments, ['v1', 'native-issues', id.value]);
        expect(request.url.query, isEmpty);
        expect(request.url.fragment, isEmpty);
        expect(
          request.url.toString(),
          'https://api.example.com/v1/native-issues/${Uri.encodeComponent(id.value)}',
        );
        if (request.method == 'GET') {
          return http.Response(
            serializer.serialize(NativeIssue(id: id, title: 'found')),
            200,
          );
        }
        if (request.method == 'PUT') {
          expect(serializer.deserialize(request.body).id, id);
        }
        return http.Response('', request.method == 'DELETE' ? 204 : 200);
      }),
    );
    addTearDown(connection.dispose);
    final repository =
        NativeIssueRestRepository(connection, identityCodecs: codecs);
    expect(
      (await repository.lookup(id, label: 'custom named argument')).id,
      id,
    );
    await repository.save(NativeIssue(id: id, title: 'saved'));
    await repository.deleteById(id);
    expect(requests.map((request) => request.method), ['GET', 'PUT', 'DELETE']);
  });

  test('generated client rejects misidentified responses and malformed keys',
      () async {
    final codecs = issueIdentityCodecs();
    final serializer = NativeIssueJsonSerializer.withIdentityCodecs(codecs);
    var calls = 0;
    final connection = RestConnection(
      baseUrl: 'https://api.example.com',
      httpClient: MockClient((request) async {
        calls++;
        return http.Response(
          serializer.serialize(
            NativeIssue(id: const NativeId('other'), title: 'wrong'),
          ),
          200,
        );
      }),
    );
    addTearDown(connection.dispose);
    final repository =
        NativeIssueRestRepository(connection, identityCodecs: codecs);
    final constraint = isA<RepositoryException>().having(
      (error) => error.type,
      'type',
      RepositoryExceptionType.constraint,
    );
    await expectLater(
      repository.getById(const NativeId('expected')),
      throwsA(constraint),
    );
    expect(calls, 1);
    for (final key in ['', '.', '..', String.fromCharCode(0xD800)]) {
      await expectLater(repository.getById(NativeId(key)), throwsA(constraint));
      await expectLater(
        repository.deleteById(NativeId(key)),
        throwsA(constraint),
      );
      await expectLater(
        repository.save(NativeIssue(id: NativeId(key), title: 'invalid')),
        throwsA(constraint),
      );
    }
    expect(calls, 1);
  });

  test('malformed server identity errors map to client constraints', () async {
    final codecs = issueIdentityCodecs();
    final connection = RestConnection(
      baseUrl: 'https://api.example.com',
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode({'detail': 'Invalid or noncanonical identity key'}),
          400,
        ),
      ),
    );
    addTearDown(connection.dispose);
    final repository =
        ScopedIssueRestRepository(connection, identityCodecs: codecs);
    await expectLater(
      repository.getById(const ScopedId('repo', 12)),
      throwsA(
        isA<RepositoryException>()
            .having(
              (error) => error.type,
              'type',
              RepositoryExceptionType.constraint,
            )
            .having(
              (error) => error.message,
              'message',
              contains('noncanonical'),
            ),
      ),
    );
  });

  test(
      'generated clients and registered server preserve native/scoped/UUID CRUD',
      () async {
    final codecs = issueIdentityCodecs();
    final native = InMemoryRepository<NativeIssue, NativeId>();
    final scoped = InMemoryRepository<ScopedIssue, ScopedId>();
    final uuid = InMemoryRepository<TestUser, UuidValue>();
    final server = HttpServer()
      ..registerResource(
        CrudResource<NativeIssue, NativeId, void>(
          path: '/native-issues',
          repository: native,
          serializer: NativeIssueJsonSerializer.withIdentityCodecs(codecs),
          identityCodecs: codecs,
        ),
      )
      ..registerResource(
        CrudResource<ScopedIssue, ScopedId, void>(
          path: '/scoped-issues',
          repository: scoped,
          serializer: ScopedIssueJsonSerializer.withIdentityCodecs(codecs),
          identityCodecs: codecs,
        ),
      )
      ..registerResource(
        CrudResource<TestUser, UuidValue, void>(
          path: '/users',
          repository: uuid,
          serializer: TestUserJsonSerializer(),
        ),
      );
    final handler = server.buildHandler();
    final connection = RestConnection(
      baseUrl: 'http://local',
      httpClient: MockClient((request) async {
        final response = await handler(
          shelf.Request(
            request.method,
            request.url,
            headers: request.headers,
            body: request.body,
          ),
        );
        return http.Response(
          await response.readAsString(),
          response.statusCode,
          headers: response.headers,
        );
      }),
    );
    addTearDown(connection.dispose);
    final nativeClient =
        NativeIssueRestRepository(connection, identityCodecs: codecs);
    const upper = NativeId('Repo/IssueA %2F, café?x=#');
    const lower = NativeId('Repo/issuea %2F, café?x=#');
    await native.save(NativeIssue(id: upper, title: 'upper'));
    await native.save(NativeIssue(id: lower, title: 'lower'));
    expect((await nativeClient.getById(upper)).title, 'upper');
    await nativeClient.save(NativeIssue(id: upper, title: 'changed'));
    expect((await nativeClient.getById(upper)).title, 'changed');
    await nativeClient.deleteById(upper);
    expect((await nativeClient.getById(lower)).title, 'lower');
    final scopedClient =
        ScopedIssueRestRepository(connection, identityCodecs: codecs);
    const first = ScopedId('org/Repo %2F, café', 12);
    const second = ScopedId('org/repo %2F, café', 12);
    await scoped.save(ScopedIssue(id: first, title: 'first'));
    await scoped.save(ScopedIssue(id: second, title: 'second'));
    expect((await scopedClient.getById(first)).id, first);
    await scopedClient.save(ScopedIssue(id: first, title: 'updated'));
    expect((await scopedClient.getById(first)).title, 'updated');
    await scopedClient.deleteById(first);
    expect((await scopedClient.getById(second)).id, second);
    await expectLater(
      scopedClient.getById(first),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.type,
          'type',
          RepositoryExceptionType.notFound,
        ),
      ),
    );
    final user = TestUser(name: 'UUID', email: 'uuid@example.com');
    await uuid.save(user);
    final uuidClient = TestUserRestRepository(connection);
    expect((await uuidClient.getById(user.id)).id, user.id);
    await uuidClient.deleteById(user.id);
    expect(uuid.getAllSync(), isEmpty);
  });
}
