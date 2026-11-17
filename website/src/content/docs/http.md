---
title: HTTP without a second domain model
description: Expose a repository through a JSON API, then use the same repository contract from a Dart or Flutter client.
section: Connect the pieces
order: 20
---

A server exposes a typed repository through Shelf handlers; a generated HTTP
repository calls those handlers from a client. Both share domain identities and
JSON contracts. Authentication stays optional: a public leaderboard can be read
without logging in while writes require explicit permissions.

## Run a public server and client

The [complete HTTP workflow](https://github.com/continuousimagination/dddart/blob/main/docs/quickstarts/rest/README.md)
supplies the Git manifest, model, part directive, builders and expected output.
After creating those named files, its `bin/main.dart` runs a finite local server
and an anonymous generated client, then closes both:

<!-- dddart-source: docs/quickstarts/rest/bin/main.dart -->
```dart
import 'dart:io' as io;

import 'package:dddart/dddart.dart';
import 'package:dddart_rest/dddart_rest.dart';
import 'package:dddart_repository_rest/dddart_repository_rest.dart';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf_io.dart' as shelf_io;

import '../lib/note.dart';

Future<void> main() async {
  final serializer = NoteJsonSerializer();
  final repository = InMemoryRepository<Note, UuidValue>();
  final note = Note(text: 'public hello');
  await repository.save(note);
  final app = HttpServer()
    ..registerResource(
      CrudResource<Note, UuidValue, Object>(
        path: '/notes', repository: repository, serializer: serializer,
        // No authentication handler: this resource is public by default.
      ),
    );
  final server = await shelf_io.serve(
      app.buildHandler(), io.InternetAddress.loopbackIPv4, 0);
  final client = http.Client();
  final connection = RestConnection(baseUrl: 'http://127.0.0.1:${server.port}');
  try {
    final response = await client.get(
        Uri.parse('http://127.0.0.1:${server.port}/notes/${note.id.uuid}'));
    if (response.statusCode != 200 ||
        serializer.deserialize(response.body).text != note.text) {
      throw StateError(
          'Public read failed: ${response.statusCode} ${response.body}');
    }
    final remote = NoteRestRepository(connection);
    if ((await remote.getById(note.id)).text != note.text) {
      throw StateError('Generated REST repository read failed');
    }
    print('200: public hello');
  } finally {
    connection.dispose();
    client.close();
    await server.close(force: true);
  }
}
```
<!-- /dddart-source -->

This workflow needs no token or auth provider. Use `HttpServer.buildHandler()`
instead of `start()` when the application's host already owns the HTTP listener.
Register additional Shelf handlers with `addRoute`; custom handlers own their
explicit auth and request validation.

## Public and protected operations

An unconfigured `CrudResource` is public. Supplying an authentication handler
makes its default policy authenticated, while explicit public operation policies
still permit anonymous access. Item and collection reads both resolve policy.

The [public/protected example](https://github.com/continuousimagination/dddart/blob/main/packages/dddart_rest/example/public_leaderboard_example.dart)
executes public leaderboard reads with protected writes, private records with
public objects, and ordinary unconfigured public CRUD. The
[REST policy guide](https://github.com/continuousimagination/dddart/blob/main/packages/dddart_rest/README.md)
describes `ResourceAccessPolicy`, typed callers, stored/current/proposed snapshots
and query scopes. Authorization uses authoritative domain snapshots, not a lossy
public JSON projection or client-submitted ownership fields.

Custom mutations require a suitable atomic conditional repository, binding the
permission decision to the stored revision. They fail closed on an unsupported
backend. Plain public CRUD retains its explicitly documented creation-race limit.

## Make collection reads explicit

Provide `collectionHandler` for unfiltered/pagination-only requests and named
`queryHandlers` for application filters. A basic repository has no implicit scan.
Handlers receive `AuthorizedQuery<TClaims>` and must apply its scope to both rows
and total count before paging; client filters may narrow that scope, never widen it.

Unsupported or combined filters, and unfiltered requests without a collection
handler, return a client error. The default page is skip 0/take 50, with maximum
100. Apply selection, ordering and bounds in the datastore query. Return
`QueryResult(items, totalCount: count)`; items form the JSON response array and the
optional count uses `X-Total-Count`.

## Identity and conditional writes

Use a concrete identity and one shared `IdentityCodecRegistry` through the model
serializer, resource and generated repository. Canonical identity keys are escaped
as one URI segment. Do not split composite IDs or guess a lossy URL encoding.
The route identity must agree with the submitted aggregate identity.

Generated ordinary `save` uses PUT. Strong ETags represent coherent persisted
revisions. Versioned reads and explicit conditional client methods carry the
server's atomic conditions; ordinary save does not silently become compare-and-swap.
`requirePrecondition` can make conditions mandatory for configured resources.
An incapable backend cannot emulate this with a read followed by an ordinary save.

A stale condition yields a conflict response without private current content.
Storage failure or uncertain commit is distinct from a conflict. Reload and
recompute deliberately; the libraries do not retry with a fresh revision.
The [two-writer example](https://github.com/continuousimagination/dddart/blob/main/packages/dddart_rest/example/etag_concurrency_example.dart)
and [conditional-write contract](https://github.com/continuousimagination/dddart/blob/main/docs/CONDITIONAL_WRITES.md)
show the actual transaction and uncertainty boundaries.

## Authentication providers and platforms

`AuthenticationHandler<TClaims>` verifies HTTP requests. `CredentialVerifier<TClaims>`
allows native handlers to reuse token verification. Self-hosted JwtAuthHandler
owns issuance/refresh with explicit claim and storage callbacks; OAuthJwtAuthHandler
uses configured JWKS, issuer, audience and claim validation. Authentication does
not substitute for resource authorization.

Client auth providers are optional. RestClient obtains the provider's ID-token
method before sending; a non-OIDC implementation returns its suitable token.
Cognito uses authorization code with PKCE, while the self-hosted provider uses
device flow. See the [client guide](https://github.com/continuousimagination/dddart/blob/main/packages/dddart_rest_client/README.md).
Built-in file credentials are not encrypted/keychain storage. Browser/mobile
callback, navigation and storage integrations remain application-owned.

The server is native IO. Browser clients additionally need appropriate CORS
allow/expose headers, including conditional headers and ETags when used. Consult
the [server source](https://github.com/continuousimagination/dddart/blob/main/packages/dddart_rest/lib/src/http_server.dart)
for the built-in helper's exact behavior.

Aggregate JSON carries public state, not pending events. Repository publication
uses the separate [event contract](/dddart/docs/events/).
