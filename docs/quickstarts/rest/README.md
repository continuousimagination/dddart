# Public HTTP endpoint

Use Dart **3.13.7**, the development SDK used for these checks. This is a verified
setup, not a claim about the minimum SDK on every platform (#98 tracks that).
The DDDart dependencies below use one immutable Git revision; they do not require
published DDDart packages. See [Git installation](https://github.com/continuousimagination/dddart/blob/main/docs/GIT_INSTALLATION.md)
for source overrides and [the support matrix](https://github.com/continuousimagination/dddart/blob/main/docs/CAPABILITIES.md) for platform limits.

This server demo runs on the Dart VM. It binds an ephemeral loopback port and
makes one anonymous request. No authentication provider is installed: the route
is deliberately public. See the [public/protected example](https://github.com/continuousimagination/dddart/blob/main/packages/dddart_rest/example/public_leaderboard_example.dart)
for per-operation policy overrides.

Create an empty directory **outside this repository**, then create the named files:

```sh
mkdir dddart_rest_quickstart
cd dddart_rest_quickstart
mkdir -p bin lib
```

Save as `pubspec.yaml` (the fixture uses `.txt` only to keep it out of the monorepo workspace):

<!-- dddart-source: docs/quickstarts/rest/pubspec.yaml.txt -->
```yaml
name: dddart_rest_quickstart
publish_to: none
environment:
  sdk: '>=3.13.7 <4.0.0'
dependencies:
  dddart:
    git:
      url: https://github.com/continuousimagination/dddart.git
      ref: 56607ac8d3913b8e896ac03f8ecff58473d62ce2
      path: packages/dddart
  dddart_json:
    git:
      url: https://github.com/continuousimagination/dddart.git
      ref: 56607ac8d3913b8e896ac03f8ecff58473d62ce2
      path: packages/dddart_json
  dddart_serialization:
    git:
      url: https://github.com/continuousimagination/dddart.git
      ref: 56607ac8d3913b8e896ac03f8ecff58473d62ce2
      path: packages/dddart_serialization
  dddart_rest:
    git:
      url: https://github.com/continuousimagination/dddart.git
      ref: 56607ac8d3913b8e896ac03f8ecff58473d62ce2
      path: packages/dddart_rest
  dddart_repository_rest:
    git:
      url: https://github.com/continuousimagination/dddart.git
      ref: 56607ac8d3913b8e896ac03f8ecff58473d62ce2
      path: packages/dddart_repository_rest
  http: ^1.2.0
  shelf: ^1.4.0
dev_dependencies:
  build_runner: ^2.4.0
dependency_overrides:
  dddart:
    git:
      url: https://github.com/continuousimagination/dddart.git
      ref: 56607ac8d3913b8e896ac03f8ecff58473d62ce2
      path: packages/dddart
  dddart_json:
    git:
      url: https://github.com/continuousimagination/dddart.git
      ref: 56607ac8d3913b8e896ac03f8ecff58473d62ce2
      path: packages/dddart_json
  dddart_repository_rest:
    git:
      url: https://github.com/continuousimagination/dddart.git
      ref: 56607ac8d3913b8e896ac03f8ecff58473d62ce2
      path: packages/dddart_repository_rest
  dddart_rest:
    git:
      url: https://github.com/continuousimagination/dddart.git
      ref: 56607ac8d3913b8e896ac03f8ecff58473d62ce2
      path: packages/dddart_rest
  dddart_rest_client:
    git:
      url: https://github.com/continuousimagination/dddart.git
      ref: 56607ac8d3913b8e896ac03f8ecff58473d62ce2
      path: packages/dddart_rest_client
  dddart_serialization:
    git:
      url: https://github.com/continuousimagination/dddart.git
      ref: 56607ac8d3913b8e896ac03f8ecff58473d62ce2
      path: packages/dddart_serialization
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

Save as `lib/note.dart`:

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

Resolve dependencies, generate from clean build state, analyze, and run:

```sh
dart pub get
dart run build_runner clean
dart run build_runner build --delete-conflicting-outputs
dart analyze --fatal-infos
dart run bin/main.dart
```

Expected output:

```text
200: public hello
```

The program finishes and closes its resources. Delete the temporary application directory when finished.
