// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io' as io;

import 'package:dddart/dddart.dart';
import 'package:dddart_rest/dddart_rest.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import 'lib/versioned_user.dart';

/// Runs an executable atomic-concurrency demonstration on ephemeral loopback.
///
/// This synthetic example deliberately has no authentication. Production
/// resources must configure their own authentication and authorization policy.
/// Run from this directory with `dart run etag_concurrency_example.dart`.
Future<void> main() async {
  final codec = VersionedUserJsonSerializer();
  final repository = InMemoryConditionalRepository<VersionedUser>(
    copyWithRevision: (value, revision) =>
        codec.fromJson({...codec.toJson(value), 'revision': revision.value}),
  );
  final resource = ConditionalCrudResource<VersionedUser, void>(
    path: '/users',
    repository: repository,
    serializers: {'application/json': codec},
  );
  final router = HttpServer()..registerResource(resource);
  final server = await shelf_io.serve(
    router.buildHandler(),
    io.InternetAddress.loopbackIPv4,
    0,
  );
  final client = io.HttpClient();
  final id = UuidValue.fromString('123e4567-e89b-42d3-a456-426614174000');
  final time = DateTime.utc(2026);
  final uri = Uri.parse('http://127.0.0.1:${server.port}/users/${id.uuid}');
  Future<({int status, String? etag, String body})> send(
    String method, {
    VersionedUser? value,
    Map<String, String> headers = const {},
  }) async {
    final request = await client.openUrl(method, uri);
    request.followRedirects = false;
    headers.forEach(request.headers.set);
    if (value != null) {
      request.headers.contentType = io.ContentType.json;
      request.write(codec.serialize(value));
    }
    final response = await request.close();
    return (
      status: response.statusCode,
      etag: response.headers.value('etag'),
      body: await utf8.decoder.bind(response).join(),
    );
  }

  VersionedUser proposal(VersionedUser basis, String name) => VersionedUser(
    id: basis.id,
    createdAt: basis.createdAt,
    updatedAt: basis.updatedAt,
    revision: basis.revision,
    name: name,
  );
  void require(String message, {required bool condition}) {
    if (!condition) throw StateError(message);
  }

  try {
    final initial = VersionedUser(
      id: id,
      createdAt: time,
      updatedAt: time,
      name: 'Initial',
    );
    final missing = await send('PUT', value: initial);
    require(
      'Every write needs an explicit condition',
      condition: missing.status == 428,
    );
    final created = await send(
      'PUT',
      value: initial,
      headers: {'if-none-match': '*'},
    );
    require(
      'Create must acknowledge revision1',
      condition: created.status == 201,
    );
    require(
      'Revision1',
      condition: codec.deserialize(created.body).revision == Revision(1),
    );
    require(
      'Transformed PUT must not emit a validator',
      condition: created.etag == null,
    );

    final a = await send('GET');
    final b = await send('GET');
    require(
      'Strong GET validator',
      condition: a.status == 200 && a.etag == '"r1"',
    );
    require(
      'Both drafts start at the same revision',
      condition: b.etag == a.etag,
    );
    final draftA = proposal(codec.deserialize(a.body), 'Alice');
    final draftB = proposal(codec.deserialize(b.body), 'Bob');
    final acceptedA = await send(
      'PUT',
      value: draftA,
      headers: {'if-match': a.etag!},
    );
    require(
      'Accepted update',
      condition: acceptedA.status == 200 && acceptedA.etag == null,
    );
    require(
      'Revision2',
      condition: codec.deserialize(acceptedA.body).revision == Revision(2),
    );
    final rejectedB = await send(
      'PUT',
      value: draftB,
      headers: {'if-match': b.etag!},
    );
    require(
      'The stale draft cannot overwrite Alice',
      condition: rejectedB.status == 412,
    );
    require(
      'Conflict is not a current-state receipt',
      condition: rejectedB.etag == null,
    );

    final observation = await send('GET');
    final latest = codec.deserialize(observation.body);
    require(
      'The winning state is preserved',
      condition: latest.name == 'Alice',
    );
    // This is a new, explicit example business decision, not a retry loop or
    // automatic rebasing of Bob's old draft. A real UI asks its owner to choose.
    final merged = proposal(latest, 'Alice and Bob');
    final acceptedMerge = await send(
      'PUT',
      value: merged,
      headers: {'if-match': observation.etag!},
    );
    require(
      'Explicit reconciled proposal accepted',
      condition: acceptedMerge.status == 200,
    );
    require(
      'Revision3',
      condition: codec.deserialize(acceptedMerge.body).revision == Revision(3),
    );
    require(
      'Accepted body carries the next revision',
      condition: acceptedMerge.etag == null,
    );

    final deleted = await send('DELETE', headers: {'if-match': '"r3"'});
    require(
      'Conditional retirement succeeds',
      condition: deleted.status == 204,
    );
    final recreated = await send(
      'PUT',
      value: initial,
      headers: {'if-none-match': '*'},
    );
    require(
      'Retired identity cannot be recreated',
      condition: recreated.status == 412,
    );
    require(
      'Retired record is not readable',
      condition: (await send('GET')).status == 404,
    );
    print(
      jsonEncode({
        'pass': true,
        'create': 201,
        'acceptedRevisions': [1, 2, 3],
        'missingPrecondition': 428,
        'staleWrite': 412,
        'retiredRecreate': 412,
        'putValidators': false,
      }),
    );
  } finally {
    client.close(force: true);
    await server.close(force: true);
  }
}
