import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_rest/dddart_rest.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'identity_test_support.dart';
import 'json_serializer_test_support.dart';

class _Serializer extends TestJsonSerializer<NativeIssue> {
  _Serializer(this.codecs);
  final IdentityCodecRegistry codecs;
  @override
  String serialize(NativeIssue issue, [dynamic config]) => jsonEncode({
        'id': codecs.toJson<NativeId>(issue.id),
        'title': issue.title,
      });
  @override
  NativeIssue deserialize(String data, [dynamic config]) {
    final json = jsonDecode(data) as Map<String, dynamic>;
    return NativeIssue(
      id: codecs.fromJson<NativeId>(json['id']),
      title: json['title'] as String,
    );
  }
}

class _Repository extends InMemoryRepository<NativeIssue, NativeId> {
  final List<NativeId> reads = [];
  final List<NativeId> deletes = [];
  @override
  Future<NativeIssue> getById(NativeId id) {
    reads.add(id);
    return super.getById(id);
  }

  @override
  Future<void> deleteById(NativeId id) {
    deletes.add(id);
    return super.deleteById(id);
  }
}

class _Auth implements AuthenticationHandler<String> {
  @override
  Future<AuthenticationResult<String>> authenticate(Request request) async =>
      const AuthenticationResult(isAuthenticated: true, claims: 'user');
}

class _Authorization
    extends AuthorizationHandler<NativeIssue, NativeId, String> {
  NativeId? deleted;
  @override
  Future<AuthorizationResult> authorizeCreate(
    NativeIssue aggregate,
    AuthenticationResult<String> authResult,
  ) async =>
      AuthorizationResult.allow();
  @override
  Future<AuthorizationResult> authorizeUpdate(
    NativeIssue aggregate,
    AuthenticationResult<String> authResult,
  ) async =>
      AuthorizationResult.allow();
  @override
  Future<AuthorizationResult> authorizeDelete(
    NativeId aggregateId,
    AuthenticationResult<String> authResult,
  ) async {
    deleted = aggregateId;
    return AuthorizationResult.allow();
  }

  @override
  Future<AuthorizationResult> authorizeQuery(
    Map<String, String> queryParams,
    AuthenticationResult<String> authResult,
  ) async =>
      AuthorizationResult.allow();
}

void main() {
  test('direct CRUD uses decoded native keys and typed delete authorization',
      () async {
    final codecs = issueIdentityCodecs();
    final serializer = _Serializer(codecs);
    final repository = _Repository();
    final authorization = _Authorization();
    final resource = CrudResource<NativeIssue, NativeId, String>(
      path: '/issues',
      repository: repository,
      serializer: serializer,
      identityCodecs: codecs,
      authenticationHandler: _Auth(),
      authorizationHandler: authorization,
    );
    const id = NativeId('Repo/IssueA %2F, café?x=# ');
    final issue = NativeIssue(id: id, title: 'original');
    await repository.save(issue);
    final found = await resource.handleGetById(
      Request('GET', Uri.parse('http://local/issues/id')),
      id.value,
    );
    expect(found.statusCode, 200);
    expect(repository.reads, [id]);
    expect(serializer.deserialize(await found.readAsString()).id, id);
    final update = await resource.handleUpdate(
      Request(
        'PUT',
        Uri.parse('http://local/issues/id'),
        headers: {'content-type': 'application/json'},
        body: serializer.serialize(NativeIssue(id: id, title: 'changed')),
      ),
      id.value,
    );
    expect(update.statusCode, 200);
    expect((await repository.getById(id)).title, 'changed');
    final mismatch = await resource.handleUpdate(
      Request(
        'PUT',
        Uri.parse('http://local/issues/id'),
        headers: {'content-type': 'application/json'},
        body: serializer.serialize(
          NativeIssue(id: const NativeId('other'), title: 'wrong'),
        ),
      ),
      id.value,
    );
    expect(mismatch.statusCode, 400);
    final deleted = await resource.handleDelete(
      Request('DELETE', Uri.parse('http://local/issues/id')),
      id.value,
    );
    expect(deleted.statusCode, 204);
    expect(repository.deletes, [id]);
    expect(authorization.deleted, id);
  });

  test('malformed keys fail before repository I/O; valid absent keys keep 404',
      () async {
    final codecs = issueIdentityCodecs();
    final repository = _Repository();
    final resource = CrudResource<NativeIssue, NativeId, void>(
      path: '/issues',
      repository: repository,
      serializer: _Serializer(codecs),
      identityCodecs: codecs,
    );
    for (final key in ['', '.', '..', String.fromCharCode(0xD800)]) {
      final malformed = await resource.handleGetById(
        Request('GET', Uri.parse('http://local/issues/id')),
        key,
      );
      expect(malformed.statusCode, 400);
      expect(await malformed.readAsString(), contains('identity key'));
    }
    expect(repository.reads, isEmpty);
    final absent = await resource.handleGetById(
      Request('GET', Uri.parse('http://local/issues/id')),
      'absent',
    );
    expect(absent.statusCode, 404);
    expect(repository.reads, [const NativeId('absent')]);
    expect(
      () => CrudResource<NativeIssue, NativeId, void>(
        path: '/issues',
        repository: repository,
        serializer: _Serializer(codecs),
      ),
      throwsArgumentError,
    );
  });

  test('registered HttpServer routes decode one URI segment exactly once',
      () async {
    final codecs = issueIdentityCodecs();
    final repository = _Repository();
    const id = NativeId('Repo/IssueA %2F, café?x=# ');
    await repository.save(NativeIssue(id: id, title: 'routed'));
    final server = HttpServer()
      ..registerResource(
        CrudResource<NativeIssue, NativeId, void>(
          path: '/issues',
          repository: repository,
          serializer: _Serializer(codecs),
          identityCodecs: codecs,
        ),
      );
    final handler = server.buildHandler();
    final response = await handler(
      Request(
        'GET',
        Uri.parse('http://local/issues/${Uri.encodeComponent(id.value)}'),
      ),
    );
    expect(response.statusCode, 200);
    expect(repository.reads, [id]);
  });
}
