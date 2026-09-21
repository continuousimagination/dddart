/// Explicit conditional HTTP requests and safe post-dispatch uncertainty.
library;

import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_repository_rest/dddart_repository_rest.dart';
import 'package:dddart_rest_client/dddart_rest_client_core.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_shared_model_fixture/versioned_model.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import '../test_models.dart' as legacy;
import 'conditional_binding.dart';

VersionedRecord _record({int revision = 0, UuidValue? id}) => VersionedRecord(
  text: 'synthetic',
  tags: ['one'],
  id: id ?? UuidValue.generate(),
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  revision: Revision(revision),
);
void main() {
  test(
    'denied authenticated write obtains one token and never refreshes or retries',
    () async {
      final auth = _Auth();
      var sends = 0;
      final repo = ConditionalProbeRestRepository(
        RestConnection(
          baseUrl: 'https://example.invalid',
          authProvider: auth,
          httpClient: MockClient((request) async {
            sends++;
            expect(request.headers['authorization'], 'Bearer synthetic-auth');
            return http.Response('', 401);
          }),
        ),
      );
      await expectLater(
        repo.save(_record(), precondition: const WritePrecondition.absent()),
        throwsA(
          isA<WriteOutcomeUnknownException>()
              .having(
                (e) => e.observedFailure,
                'classification',
                RepositoryExceptionType.unauthorized,
              )
              .having((e) => e.accessUnavailable, 'access', true),
        ),
      );
      expect(auth.tokens, 1);
      expect(auth.otherCalls, 0);
      expect(sends, 1);
    },
  );

  test(
    'actual legacy generated adapter rejects a widened versioned subtype before I/O',
    () async {
      var sends = 0;
      final repo = legacy.TestUserRestRepository(
        RestConnection(
          baseUrl: 'https://example.invalid',
          httpClient: MockClient((_) async {
            sends++;
            return http.Response('', 200);
          }),
        ),
      );
      await expectLater(
        repo.save(_WidenedVersioned()),
        throwsA(isA<RepositoryCapabilityException>()),
      );
      expect(sends, 0);
    },
  );

  final codec = VersionedRecordJsonSerializer();
  test(
    'create and update explicitly send expected revision and accept complete next state',
    () async {
      for (final previous in [0, 4]) {
        final proposed = _record(revision: previous);
        var calls = 0;
        final repo = ConditionalProbeRestRepository(
          RestConnection(
            baseUrl: 'https://example.invalid',
            httpClient: MockClient((request) async {
              calls++;
              expect(request.method, 'PUT');
              expect(request.url.path, '/VersionedRecord/${proposed.id}');
              expect(request.followRedirects, isFalse);
              expect(
                request.headers[previous == 0 ? 'if-none-match' : 'if-match'],
                previous == 0 ? '*' : '"r4"',
              );
              final wire = jsonDecode(request.body) as Map<String, dynamic>;
              expect(wire['revision'], previous);
              return http.Response(
                jsonEncode({...wire, 'revision': previous + 1}),
                previous == 0 ? 201 : 200,
                headers: {'content-type': 'application/json'},
              );
            }),
          ),
        );
        final result = await repo.save(
          proposed,
          precondition: previous == 0
              ? const WritePrecondition.absent()
              : WritePrecondition.atRevision(Revision(previous)),
        );
        expect(calls, 1);
        expect(result.revision, Revision(previous + 1));
        expect(proposed.revision, Revision(previous));
        proposed.tags.add('caller');
        expect(result.tags, ['one']);
      }
    },
  );
  test(
    'GET requires matching strong ETag and positive body revision',
    () async {
      final value = _record(revision: 2);
      var calls = 0;
      final repo = ConditionalProbeRestRepository(
        RestConnection(
          baseUrl: 'https://example.invalid',
          httpClient: MockClient((request) async {
            calls++;
            expect(request.followRedirects, isFalse);
            return http.Response(
              codec.serialize(value),
              200,
              headers: {'content-type': 'application/json', 'etag': '"r2"'},
            );
          }),
        ),
      );
      expect((await repo.getById(value.id)).revision, Revision(2));
      expect(calls, 1);
    },
  );
  test(
    'post-dispatch denial, conflict, malformed success and transport failures stay uncertain',
    () async {
      final value = _record(revision: 1);
      for (final (reply, expectedFailure, unavailable)
          in <
            (
              Future<http.Response> Function(http.Request),
              RepositoryExceptionType,
              bool,
            )
          >[
            (
              (_) async => http.Response('restricted-response', 401),
              RepositoryExceptionType.unauthorized,
              true,
            ),
            (
              (_) async => http.Response('restricted-response', 403),
              RepositoryExceptionType.forbidden,
              true,
            ),
            (
              (_) async => http.Response('restricted-response', 412),
              RepositoryExceptionType.constraint,
              false,
            ),
            (
              (_) async => http.Response('', 204),
              RepositoryExceptionType.unknown,
              false,
            ),
            (
              (_) async => http.Response(
                '{}',
                200,
                headers: {'content-type': 'application/json'},
              ),
              RepositoryExceptionType.unknown,
              false,
            ),
            (
              (_) async => throw http.ClientException('restricted-transport'),
              RepositoryExceptionType.connection,
              false,
            ),
          ]) {
        var calls = 0;
        final repo = ConditionalProbeRestRepository(
          RestConnection(
            baseUrl: 'https://example.invalid',
            httpClient: MockClient((request) {
              calls++;
              return reply(request);
            }),
          ),
        );
        try {
          await repo.save(
            value,
            precondition: WritePrecondition.atRevision(Revision(1)),
          );
          fail('Must not acknowledge invalid or failed outcome');
        } on WriteOutcomeUnknownException catch (error) {
          expect(error.cause, isNull);
          expect(error.toString(), isNot(contains('restricted')));
          expect(error.type, RepositoryExceptionType.unknown);
          expect(error.observedFailure, expectedFailure);
          expect(error.accessUnavailable, unavailable);
        }
        expect(calls, 1);
      }
    },
  );
  test(
    'strict successful response rejects wrong identity, revision, content and validators',
    () async {
      final value = _record(revision: 3);
      final valid = {...codec.toJson(value), 'revision': 4};
      for (final wire in [
        {...valid, 'id': UuidValue.generate().uuid},
        {...valid, 'revision': 3},
        {...valid, 'revision': 5},
        {...valid, 'text': 'changed'},
        {...valid, 'extra': true},
      ]) {
        final repo = ConditionalProbeRestRepository(
          RestConnection(
            baseUrl: 'https://example.invalid',
            httpClient: MockClient(
              (_) async => http.Response(
                jsonEncode(wire),
                200,
                headers: {'content-type': 'application/json'},
              ),
            ),
          ),
        );
        await expectLater(
          repo.save(
            value,
            precondition: WritePrecondition.atRevision(Revision(3)),
          ),
          throwsA(isA<WriteOutcomeUnknownException>()),
        );
      }
    },
  );
  test(
    'invalid local preconditions and capacity dispatch zero requests',
    () async {
      var calls = 0;
      final repo = ConditionalProbeRestRepository(
        RestConnection(
          baseUrl: 'https://example.invalid',
          httpClient: MockClient((_) async {
            calls++;
            return http.Response('', 500);
          }),
        ),
      );
      await expectLater(
        repo.save(
          _record(revision: 1),
          precondition: const WritePrecondition.absent(),
        ),
        throwsArgumentError,
      );
      await expectLater(
        repo.save(
          _record(revision: Revision.maxValue),
          precondition: WritePrecondition.atRevision(
            Revision(Revision.maxValue),
          ),
        ),
        throwsA(isA<RevisionCapacityException>()),
      );
      await expectLater(
        repo.deleteById(
          UuidValue.generate(),
          precondition: const WritePrecondition.absent(),
        ),
        throwsArgumentError,
      );
      expect(calls, 0);
    },
  );
  test(
    'GET rejects missing or inconsistent validators and malformed complete bodies',
    () async {
      final value = _record(revision: 2);
      final wire = codec.toJson(value);
      final replies = <http.Response>[
        for (final tag in [null, 'W/"r2"', '"r3"', '"r2", "r2"'])
          http.Response(
            jsonEncode(wire),
            200,
            headers: {
              'content-type': 'application/json',
              if (tag != null) 'etag': tag,
            },
          ),
        for (final invalid in [
          {...wire, 'id': UuidValue.generate().uuid},
          {...wire, 'revision': 0},
          {...wire, 'unknown': true},
        ])
          http.Response(
            jsonEncode(invalid),
            200,
            headers: {'content-type': 'application/json', 'etag': '"r2"'},
          ),
        http.Response.bytes(
          [255],
          200,
          headers: {'content-type': 'application/json', 'etag': '"r2"'},
        ),
      ];
      for (final reply in replies) {
        var calls = 0;
        final repo = ConditionalProbeRestRepository(
          RestConnection(
            baseUrl: 'https://example.invalid',
            httpClient: MockClient((_) async {
              calls++;
              return reply;
            }),
          ),
        );
        await expectLater(
          repo.getById(value.id),
          throwsA(isA<RepositoryException>()),
        );
        expect(calls, 1);
      }
    },
  );

  test(
    'PUT transformed success cannot carry validators or an incorrect success status',
    () async {
      final value = _record(revision: 1);
      final accepted = jsonEncode({...codec.toJson(value), 'revision': 2});
      for (final reply in [
        http.Response(
          accepted,
          200,
          headers: {'content-type': 'application/json', 'etag': '"r2"'},
        ),
        http.Response(
          accepted,
          200,
          headers: {
            'content-type': 'application/json',
            'last-modified': 'today',
          },
        ),
        http.Response(
          accepted,
          201,
          headers: {'content-type': 'application/json'},
        ),
        http.Response(
          accepted,
          200,
          headers: {'content-type': 'application/xml'},
        ),
      ]) {
        final repo = ConditionalProbeRestRepository(
          RestConnection(
            baseUrl: 'https://example.invalid',
            httpClient: MockClient((_) async => reply),
          ),
        );
        await expectLater(
          repo.save(
            value,
            precondition: WritePrecondition.atRevision(value.revision),
          ),
          throwsA(isA<WriteOutcomeUnknownException>()),
        );
      }
    },
  );

  test(
    'delete uses an explicit positive precondition and preserves failed-outcome uncertainty',
    () async {
      final id = UuidValue.generate();
      var calls = 0;
      final repo = ConditionalProbeRestRepository(
        RestConnection(
          baseUrl: 'https://example.invalid',
          httpClient: MockClient((request) async {
            calls++;
            expect(request.method, 'DELETE');
            expect(request.followRedirects, isFalse);
            expect(request.headers['if-match'], '"r4"');
            return http.Response('', calls == 1 ? 204 : 412);
          }),
        ),
      );
      await repo.deleteById(
        id,
        precondition: WritePrecondition.atRevision(Revision(4)),
      );
      await expectLater(
        repo.deleteById(
          id,
          precondition: WritePrecondition.atRevision(Revision(4)),
        ),
        throwsA(isA<WriteOutcomeUnknownException>()),
      );
      await expectLater(
        repo.deleteById(
          id,
          precondition: WritePrecondition.atRevision(
            Revision(Revision.maxValue),
          ),
        ),
        throwsA(isA<RevisionCapacityException>()),
      );
      expect(calls, 2);
    },
  );

  test(
    'unusable local codec rejects before dispatch instead of discovering it after write',
    () async {
      var calls = 0;
      final repo = RestConditionalRepository<VersionedRecord>(
        RestConnection(
          baseUrl: 'https://example.invalid',
          httpClient: MockClient((request) async {
            calls++;
            return http.Response(
              request.body,
              201,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
        resourcePath: '/records',
        serializer: _BrokenCodec(),
      );
      await expectLater(
        repo.save(_record(), precondition: const WritePrecondition.absent()),
        throwsA(isA<RepositoryCapabilityException>()),
      );
      expect(calls, 0);
    },
  );
}

class _BrokenCodec extends VersionedRecordJsonSerializer {
  @override
  VersionedRecord fromJson(dynamic json, [SerializationConfig? config]) =>
      throw StateError('restricted-local-codec');
}

class _WidenedVersioned extends legacy.TestUser
    implements VersionedAggregateRoot {
  _WidenedVersioned() : super(name: 'synthetic', email: 'synthetic');
  @override
  Revision get revision => const Revision.zero();
}

class _Auth extends AuthProvider {
  int tokens = 0;
  int otherCalls = 0;
  @override
  Future<String> getIdToken() async {
    tokens++;
    return 'synthetic-auth';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    otherCalls++;
    throw StateError('Unexpected authentication operation');
  }
}
