/// Shared-resource races retain request-local authority and atomic persistence.
library;

import 'dart:async';
import 'dart:convert';
import 'package:dddart/dddart.dart';
import 'package:dddart_rest/dddart_rest.dart';
import 'package:dddart_shared_model_fixture/versioned_model.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'conditional_resource_test.dart' show RecordingConditional, record;

class _Authentication extends AuthenticationHandler<String> {
  final firstAuthenticated = Completer<void>();
  @override
  Future<AuthenticationResult<String>> authenticate(Request request) async {
    final value = request.headers['authorization']!;
    if (value == 'first' && !firstAuthenticated.isCompleted) {
      firstAuthenticated.complete();
    }
    return AuthenticationResult.success(userId: value, claims: value);
  }
}

class _Policy extends AuthorizationHandler<VersionedRecord, String> {
  final seen = <(String, String)>[];
  @override
  Future<AuthorizationResult> authorizeUpdate(
    VersionedRecord value,
    AuthenticationResult<String> auth,
  ) async {
    seen.add((value.text, auth.claims!));
    return value.text == auth.claims
        ? AuthorizationResult.allow()
        : AuthorizationResult.deny('Wrong request authority');
  }

  @override
  Future<AuthorizationResult> authorizeCreate(
    VersionedRecord value,
    AuthenticationResult<String> auth,
  ) async => AuthorizationResult.allow();
  @override
  Future<AuthorizationResult> authorizeRead(
    UuidValue id,
    AuthenticationResult<String> auth,
  ) async => AuthorizationResult.allow();
  @override
  Future<AuthorizationResult> authorizeDelete(
    UuidValue id,
    AuthenticationResult<String> auth,
  ) async => AuthorizationResult.allow();
  @override
  Future<AuthorizationResult> authorizeQuery(
    Map<String, String> filters,
    AuthenticationResult<String> auth,
  ) async => AuthorizationResult.deny('Unsupported');
}

class _RefreshedReadPolicy extends _Policy {
  @override
  Future<AuthorizationResult> authorizeRead(
    UuidValue id,
    AuthenticationResult<String> auth,
  ) async => auth.claims == 'reader'
      ? AuthorizationResult.allow()
      : AuthorizationResult.deny('Read denied');
}

void main() {
  final codec = VersionedRecordJsonSerializer();
  test(
    'refreshed authoritative claims deny reads before repository access',
    () async {
      String? currentRole = 'reader';
      final auth = JwtAuthHandler<String, RefreshToken>(
        secret: 'synthetic-refresh-read-test-key',
        refreshTokenRepository: InMemoryRefreshTokenRepository<RefreshToken>(),
        refreshTokenLifecycle: const StandardRefreshTokenLifecycle(),
        claimsLoader: (_) async => currentRole,
        claimsToJson: (claims) => {'role': claims},
        parseClaimsFromJson: (json) => json['role'] as String,
      );
      final repository = RecordingConditional();
      final initial = record();
      await repository.inner.save(
        initial,
        precondition: const WritePrecondition.absent(),
      );
      final resource = ConditionalCrudResource<VersionedRecord, String>(
        path: '/records',
        repository: repository,
        serializers: {'application/json': codec},
        authenticationHandler: auth,
        authorizationHandler: _RefreshedReadPolicy(),
      );
      Future<Response> read(String token) => resource.handleGetById(
        Request(
          'GET',
          Uri.parse('http://local/records/${initial.id}'),
          headers: {'authorization': 'Bearer $token'},
        ),
        initial.id.uuid,
      );
      final issued = await auth.issueTokens('synthetic-user');
      expect((await read(issued.accessToken)).statusCode, 200);
      currentRole = 'blocked';
      final refreshed = await auth.refresh(issued.refreshToken);
      expect((await read(refreshed.accessToken)).statusCode, 403);
      expect(repository.calls, ['read']);
      currentRole = null;
      await expectLater(auth.refresh(issued.refreshToken), throwsException);
      expect(repository.calls, ['read']);
    },
  );
  test(
    'concurrent create requests produce exactly one accepted mutation',
    () async {
      final repository = RecordingConditional();
      final resource = ConditionalCrudResource<VersionedRecord, void>(
        path: '/records',
        repository: repository,
        serializers: {'application/json': codec},
      );
      final value = record();
      Future<Response> create(String text) => resource.handleUpdate(
        Request(
          'PUT',
          Uri.parse('http://local/records/${value.id}'),
          headers: {'content-type': 'application/json', 'if-none-match': '*'},
          body: codec.serialize(record(id: value.id, text: text)),
        ),
        value.id.uuid,
      );
      final responses = await Future.wait([create('A'), create('B')]);
      expect(
        responses.map((response) => response.statusCode).toList()..sort(),
        [201, 412],
      );
      final winner = codec.deserialize(
        await responses
            .firstWhere((response) => response.statusCode == 201)
            .readAsString(),
      );
      final observed = await repository.inner.getById(value.id);
      expect(observed.revision, Revision(1));
      expect(observed.text, winner.text);
      expect(repository.calls, ['save', 'save']);
    },
  );
  test(
    'overlapping request bodies never exchange authenticated claims',
    () async {
      final repository = RecordingConditional();
      final initial = record();
      await repository.inner.save(
        initial,
        precondition: const WritePrecondition.absent(),
      );
      final auth = _Authentication();
      final policy = _Policy();
      final resource = ConditionalCrudResource<VersionedRecord, String>(
        path: '/records',
        repository: repository,
        serializers: {'application/json': codec},
        authenticationHandler: auth,
        authorizationHandler: policy,
      );
      final body = StreamController<List<int>>();
      final first = resource.handleUpdate(
        Request(
          'PUT',
          Uri.parse('http://local/records/${initial.id}'),
          headers: {
            'authorization': 'first',
            'content-type': 'application/json',
            'if-match': '"r1"',
          },
          body: body.stream,
        ),
        initial.id.uuid,
      );
      await auth.firstAuthenticated.future;
      final second = await resource.handleUpdate(
        Request(
          'PUT',
          Uri.parse('http://local/records/${initial.id}'),
          headers: {
            'authorization': 'second',
            'content-type': 'application/json',
            'if-match': '"r1"',
          },
          body: codec.serialize(
            record(id: initial.id, revision: 1, text: 'second'),
          ),
        ),
        initial.id.uuid,
      );
      body.add(
        utf8.encode(
          codec.serialize(record(id: initial.id, revision: 1, text: 'first')),
        ),
      );
      await body.close();
      expect(second.statusCode, 200);
      expect((await first).statusCode, 412);
      expect(policy.seen, [('second', 'second'), ('first', 'first')]);
      expect((await repository.inner.getById(initial.id)).text, 'second');
    },
  );
  test(
    'corrupt returned state after persistence is500 rather than rejected input',
    () async {
      final repository = RecordingConditional();
      repository.onSave = (value, condition) async {
        final accepted = await repository.inner.save(
          value,
          precondition: condition,
        );
        accepted.updatedAt = DateTime.utc(1900);
        return accepted;
      };
      final resource = ConditionalCrudResource<VersionedRecord, void>(
        path: '/records',
        repository: repository,
        serializers: {'application/json': codec},
      );
      final value = record();
      final response = await resource.handleUpdate(
        Request(
          'PUT',
          Uri.parse('http://local/records/${value.id}'),
          headers: {'if-none-match': '*'},
          body: codec.serialize(value),
        ),
        value.id.uuid,
      );
      expect(response.statusCode, 500);
      expect(await response.readAsString(), isNot(contains('1900')));
      expect(repository.calls, ['save']);
      expect(
        (await repository.inner.getById(value.id)).updatedAt,
        value.updatedAt,
      );
    },
  );
  test(
    'foreign or inconsistent accepted copies cannot acknowledge persisted state',
    () async {
      for (final mutation in <void Function(Map<String, dynamic>)>[
        (wire) => wire['id'] = UuidValue.generate().uuid,
        (wire) => wire['revision'] = 2,
        (wire) => wire['text'] = 'incorrect',
      ]) {
        final repository = RecordingConditional();
        repository.onSave = (value, condition) async {
          final accepted = await repository.inner.save(
            value,
            precondition: condition,
          );
          final wire = codec.toJson(accepted);
          mutation(wire);
          return codec.fromJson(wire);
        };
        final resource = ConditionalCrudResource<VersionedRecord, void>(
          path: '/records',
          repository: repository,
          serializers: {'application/json': codec},
        );
        final value = record();
        final response = await resource.handleUpdate(
          Request(
            'PUT',
            Uri.parse('http://local/records/${value.id}'),
            headers: {'if-none-match': '*'},
            body: codec.serialize(value),
          ),
          value.id.uuid,
        );
        expect(response.statusCode, 500);
        expect(repository.calls, ['save']);
        final stored = await repository.inner.getById(value.id);
        expect(stored.id, value.id);
        expect(stored.revision, Revision(1));
        expect(stored.text, value.text);
      }
    },
  );
  test(
    'throwing response codec and unclassified post-dispatch errors remain500',
    () async {
      for (final failingResponse in [false, true]) {
        final repository = RecordingConditional();
        if (!failingResponse) {
          repository.onSave = (value, condition) async {
            await repository.inner.save(value, precondition: condition);
            throw const FormatException('restricted-after-write');
          };
        }
        final resource = ConditionalCrudResource<VersionedRecord, void>(
          path: '/records',
          repository: repository,
          serializers: {
            'application/json': failingResponse
                ? _ThrowingResponseCodec()
                : codec,
          },
        );
        final value = record();
        final response = await resource.handleUpdate(
          Request(
            'PUT',
            Uri.parse('http://local/records/${value.id}'),
            headers: {'if-none-match': '*'},
            body: codec.serialize(value),
          ),
          value.id.uuid,
        );
        expect(response.statusCode, 500);
        expect(await response.readAsString(), isNot(contains('restricted')));
        expect(repository.calls, ['save']);
        expect(
          (await repository.inner.getById(value.id)).revision,
          Revision(1),
        );
      }
    },
  );
}

class _ThrowingResponseCodec extends VersionedRecordJsonSerializer {
  @override
  String serialize(VersionedRecord value, [dynamic config]) =>
      throw const FormatException('restricted-response-codec');
}
