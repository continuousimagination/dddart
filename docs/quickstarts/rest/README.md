# Public HTTP endpoint

Run a public Shelf API and fetch an aggregate with a generated HTTP repository.

The server binds to a temporary loopback port on the Dart VM. Both a plain
HTTP client and the generated repository can read the same public note.

## Set up the application

Create an empty directory **outside this repository**, then create the named files:

```sh
mkdir dddart_rest_quickstart
cd dddart_rest_quickstart
mkdir -p bin lib
```

Copy the [example pubspec](pubspec.yaml.txt) into the application as `pubspec.yaml`.

## Add the application files

Start with the note the application will serve. Save as `lib/note.dart`:

<!-- dddart-source: docs/quickstarts/rest/lib/note.dart -->
```dart
import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_repository_rest/dddart_repository_rest.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

part 'note.g.dart';

@Serializable()
@GenerateRestRepository(resourcePath: '/notes')
class Note extends AggregateRoot<UuidValue> {
  Note({required this.text, UuidValue? id, super.createdAt, super.updatedAt})
      : super(id: id ?? UuidValue.generate());
  final String text;
}
```
<!-- /dddart-source -->

Save as `bin/main.dart`:

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

<a id="run-a-public-server-and-client"></a>

## Run the example

<!-- dddart-source: docs/quickstarts/rest/commands.sh -->
```sh
dart pub get
dart run build_runner build --delete-conflicting-outputs
dart run bin/main.dart
```
<!-- /dddart-source -->

Expected output:

<!-- dddart-source: docs/quickstarts/rest/expected/main.txt -->
```text
200: public hello
```
<!-- /dddart-source -->

Both requests read the same note without a token. To share an existing
listener, compose `HttpServer.buildHandler()` into that host.

## Public and protected operations

To allow anonymous reads and
protect writes on the same resource, run the [public leaderboard example](../../../packages/dddart_rest/example/README.md).

For collection queries, apply the authorized scope to rows and counts before
paging. The [REST policy guide](../../../packages/dddart_rest/README.md#optional-access-policies)
covers revision checks and authorization for writes.

## Prevent lost updates

Use versioned reads and explicit conditional calls when one writer must
detect another's change. A strong ETag carries the stored revision. A stale
condition needs a reload and an application decision about whether to reapply
the update. Ordinary `save` uses unconditional PUT where the resource allows
it. The [conditional writes guide](../../CONDITIONAL_WRITES.md)
describes the required storage capability and how to handle an unknown result.

## Authentication providers and platforms

On the server, choose a credential verifier and resource policies. On the
client, supply a token provider only for calls that need authentication. The
[REST client guide](../../../packages/dddart_rest_client/README.md)
describes device flow, Cognito/OIDC callbacks, and credential storage. Supply
storage and callback handling appropriate to your browser or mobile
application.
