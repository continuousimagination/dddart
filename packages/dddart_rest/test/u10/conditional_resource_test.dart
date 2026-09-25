/// Conditional HTTP contract through the same public server/resource stack.
library;

import 'dart:convert';
import 'package:dddart/dddart.dart';
import 'package:dddart_rest/dddart_rest.dart';
import 'package:dddart_shared_model_fixture/versioned_model.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

VersionedRecord record({
  UuidValue? id,
  int revision = 0,
  String text = 'synthetic',
}) => VersionedRecord(
  id: id ?? UuidValue.generate(),
  revision: Revision(revision),
  text: text,
  tags: ['one'],
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

class RecordingConditional implements ConditionalRepository<VersionedRecord> {
  final codec = VersionedRecordJsonSerializer();
  late final inner = InMemoryConditionalRepository<VersionedRecord>(
    copyWithRevision: (value, revision) =>
        codec.fromJson({...codec.toJson(value), 'revision': revision.value}),
  );
  final List<String> calls = [];
  Future<VersionedRecord> Function(VersionedRecord, WritePrecondition)? onSave;
  @override
  Future<VersionedRecord> getById(UuidValue id) {
    calls.add('read');
    return inner.getById(id);
  }

  @override
  Future<VersionedRecord> save(
    VersionedRecord value, {
    required WritePrecondition precondition,
  }) {
    calls.add('save');
    return onSave?.call(value, precondition) ??
        inner.save(value, precondition: precondition);
  }

  @override
  Future<void> deleteById(
    UuidValue id, {
    required WritePrecondition precondition,
  }) {
    calls.add('delete');
    return inner.deleteById(id, precondition: precondition);
  }
}

class _Auth extends AuthenticationHandler<int> {
  bool allow = true;
  int calls = 0;
  @override
  Future<AuthenticationResult<int>> authenticate(Request request) async {
    calls++;
    return allow
        ? AuthenticationResult.success(userId: 'synthetic', claims: 1)
        : AuthenticationResult.failure('Denied');
  }
}

class _Policy extends AuthorizationHandler<VersionedRecord, int> {
  bool allow = true;
  final List<String> calls = [];
  AuthorizationResult decision(String name) {
    calls.add(name);
    return allow
        ? AuthorizationResult.allow()
        : AuthorizationResult.deny('Denied');
  }

  @override
  Future<AuthorizationResult> authorizeRead(
    UuidValue id,
    AuthenticationResult<int> auth,
  ) async => decision('read');
  @override
  Future<AuthorizationResult> authorizeCreate(
    VersionedRecord value,
    AuthenticationResult<int> auth,
  ) async => decision('create');
  @override
  Future<AuthorizationResult> authorizeUpdate(
    VersionedRecord value,
    AuthenticationResult<int> auth,
  ) async => decision('update');
  @override
  Future<AuthorizationResult> authorizeDelete(
    UuidValue id,
    AuthenticationResult<int> auth,
  ) async => decision('delete');
  @override
  Future<AuthorizationResult> authorizeQuery(
    Map<String, String> filters,
    AuthenticationResult<int> auth,
  ) async => decision('query');
}

void main() {
  final codec = VersionedRecordJsonSerializer();
  late RecordingConditional repository;
  late _Auth auth;
  late _Policy policy;
  late Handler handler;
  setUp(() {
    repository = RecordingConditional();
    auth = _Auth();
    policy = _Policy();
    final HttpResource resource = ConditionalCrudResource<VersionedRecord, int>(
      path: '/records',
      repository: repository,
      serializers: {'application/json': codec},
      authenticationHandler: auth,
      authorizationHandler: policy,
    );
    handler = (HttpServer()..registerResource(resource)).buildHandler();
  });
  Future<Response> invoke(
    String method,
    VersionedRecord value, {
    Map<String, String> headers = const {},
    String? body,
  }) async => handler(
    Request(
      method,
      Uri.parse('http://local/records/${value.id}'),
      headers: {'content-type': 'application/json', ...headers},
      body: body ?? (method == 'PUT' ? codec.serialize(value) : null),
    ),
  );
  for (final token in ['0.0', '0e0']) {
    test('conditional PUT normalizes whole create revision $token', () async {
      final value = record();
      final response = await invoke(
        'PUT',
        value,
        headers: {'if-none-match': '*'},
        body: codec
            .serialize(value)
            .replaceFirst('"revision":0', '"revision":$token'),
      );
      expect(response.statusCode, 201);
      expect(repository.calls, ['save']);
      expect(jsonDecode(await response.readAsString())['revision'], 1);
    });
  }
  for (final token in ['1.0', '1e0']) {
    test('conditional PUT normalizes whole update revision $token', () async {
      final value = record();
      await repository.inner.save(
        value,
        precondition: const WritePrecondition.absent(),
      );
      final response = await invoke(
        'PUT',
        value,
        headers: {'if-match': '"r1"'},
        body: codec
            .serialize(value)
            .replaceFirst('"revision":0', '"revision":$token'),
      );
      expect(response.statusCode, 200);
      expect(repository.calls, ['save']);
      expect(jsonDecode(await response.readAsString())['revision'], 2);
    });
  }
  test(
    'invalid decoded revision forms reject with zero storage operations',
    () async {
      for (final token in [
        '0.5',
        '1.5',
        '-1',
        '9007199254740992.0',
        '9007199254740993',
        '1e309',
        'true',
        '"1"',
        'null',
      ]) {
        final value = record();
        final response = await invoke(
          'PUT',
          value,
          headers: {'if-none-match': '*'},
          body: codec
              .serialize(value)
              .replaceFirst('"revision":0', '"revision":$token'),
        );
        expect(response.statusCode, 400, reason: token);
        expect(repository.calls, isEmpty);
      }
    },
  );
  test(
    'create201 update200 accepted body and GET strong validator use one save without reread',
    () async {
      final value = record();
      final created = await invoke(
        'PUT',
        value,
        headers: {'if-none-match': '*'},
      );
      expect(created.statusCode, 201);
      expect(created.headers['etag'], isNull);
      expect(created.headers['last-modified'], isNull);
      final accepted = codec.deserialize(await created.readAsString());
      expect(accepted.revision, Revision(1));
      expect(repository.calls, ['save']);
      expect(policy.calls, ['create']);
      final updated = await invoke(
        'PUT',
        accepted,
        headers: {'if-match': '"r1"'},
      );
      expect(updated.statusCode, 200);
      expect(updated.headers['etag'], isNull);
      expect(
        codec.deserialize(await updated.readAsString()).revision,
        Revision(2),
      );
      expect(repository.calls, ['save', 'save']);
      expect(policy.calls, ['create', 'update']);
      final read = await invoke('GET', accepted);
      expect(read.statusCode, 200);
      expect(read.headers['etag'], '"r2"');
      expect(
        codec.deserialize(await read.readAsString()).revision,
        Revision(2),
      );
    },
  );
  test(
    'missing/malformed/conflicting/body-mismatched conditions never reach repository',
    () async {
      final value = record();
      expect((await invoke('PUT', value)).statusCode, 428);
      for (final headers in [
        {'if-match': '*'},
        {'if-match': 'W/"r1"'},
        {'if-match': '"r1", "r2"'},
        {'if-none-match': '*', 'if-match': '"r1"'},
        {'if-match': '"r1"'},
        {'if-none-match': '*', 'range': 'bytes=0-1'},
      ]) {
        expect((await invoke('PUT', value, headers: headers)).statusCode, 400);
      }
      expect(repository.calls, isEmpty);
    },
  );
  test(
    'auth and policy denial precede protected I/O and preserve operation kind',
    () async {
      final value = record();
      auth.allow = false;
      expect((await invoke('GET', value)).statusCode, 401);
      expect(
        (await invoke(
          'PUT',
          value,
          headers: {'if-none-match': '*'},
        )).statusCode,
        401,
      );
      expect(policy.calls, isEmpty);
      expect(repository.calls, isEmpty);
      auth.allow = true;
      policy.allow = false;
      expect(
        (await invoke(
          'PUT',
          value,
          headers: {'if-none-match': '*'},
        )).statusCode,
        403,
      );
      expect(
        (await invoke(
          'PUT',
          record(id: value.id, revision: 1),
          headers: {'if-match': '"r1"'},
        )).statusCode,
        403,
      );
      expect(
        (await invoke(
          'DELETE',
          value,
          headers: {'if-match': '"r1"'},
        )).statusCode,
        403,
      );
      expect(repository.calls, isEmpty);
      expect(policy.calls, ['create', 'update', 'delete']);
    },
  );
  test('negotiation and identity checks precede save', () async {
    final value = record();
    expect(
      (await invoke(
        'PUT',
        value,
        headers: {'if-none-match': '*', 'accept': 'application/xml'},
      )).statusCode,
      406,
    );
    expect(
      (await invoke(
        'PUT',
        value,
        headers: {'if-none-match': '*'},
        body: codec.serialize(record()),
      )).statusCode,
      400,
    );
    expect(repository.calls, isEmpty);
  });
  test(
    'storage conflict maps412 and capacity maps413 stable code before I/O',
    () async {
      final value = record();
      await invoke('PUT', value, headers: {'if-none-match': '*'});
      expect(
        (await invoke(
          'PUT',
          value,
          headers: {'if-none-match': '*'},
        )).statusCode,
        412,
      );
      final before = repository.calls.length;
      final full = record(revision: Revision.maxValue);
      final response = await invoke(
        'PUT',
        full,
        headers: {'if-match': '"r${Revision.maxValue}"'},
      );
      expect(response.statusCode, 413);
      expect(
        jsonDecode(await response.readAsString())['code'],
        'capacityExceeded',
      );
      expect(repository.calls.length, before);
    },
  );
  test(
    'conditional DELETE retires and POST/query are explicitly unsupported',
    () async {
      final value = record();
      await invoke('PUT', value, headers: {'if-none-match': '*'});
      expect(
        (await invoke(
          'DELETE',
          value,
          headers: {'if-match': '"r1"'},
        )).statusCode,
        204,
      );
      expect((await invoke('GET', value)).statusCode, 404);
      expect(
        (await invoke(
          'PUT',
          value,
          headers: {'if-none-match': '*'},
        )).statusCode,
        412,
      );
      for (final method in ['POST', 'GET']) {
        expect(
          (await handler(
            Request(method, Uri.parse('http://local/records')),
          )).statusCode,
          501,
        );
      }
    },
  );
  test('invalid configuration cannot install a conditional resource', () {
    expect(
      () => ConditionalCrudResource<VersionedRecord, int>(
        path: '/records',
        repository: repository,
        serializers: {'application/json': codec, 'application/other': codec},
      ),
      throwsArgumentError,
    );
    expect(
      () => ConditionalCrudResource<VersionedRecord, int>(
        path: '/records',
        repository: repository,
        serializers: {'application/json': codec},
        authorizationHandler: policy,
      ),
      throwsArgumentError,
    );
  });
  test(
    'incomplete or malformed raw revision/timestamps are rejected before storage',
    () async {
      final value = record();
      final valid = codec.toJson(value);
      final bodies = <Map<String, dynamic>>[
        for (final field in ['revision', 'createdAt', 'updatedAt'])
          {...valid}..remove(field),
        for (final revision in [null, '0', false, -1, 1.5, 9007199254740992])
          {...valid, 'revision': revision},
        {...valid, 'createdAt': false},
        {...valid, 'updatedAt': 'not-a-time'},
      ];
      for (final body in bodies) {
        expect(
          (await invoke(
            'PUT',
            value,
            headers: {'if-none-match': '*'},
            body: jsonEncode(body),
          )).statusCode,
          400,
        );
      }
      expect(repository.calls, isEmpty);
    },
  );
  test(
    'DELETE requires a positive condition and has no request body',
    () async {
      final value = record();
      expect((await invoke('DELETE', value)).statusCode, 428);
      expect(
        (await invoke(
          'DELETE',
          value,
          headers: {'if-none-match': '*'},
        )).statusCode,
        400,
      );
      expect(
        (await invoke(
          'DELETE',
          value,
          headers: {'if-match': '"r1"'},
          body: 'unexpected',
        )).statusCode,
        400,
      );
      expect(repository.calls, isEmpty);
    },
  );
}
