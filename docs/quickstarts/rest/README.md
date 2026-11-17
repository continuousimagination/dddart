# Public HTTP endpoint

Run a public Shelf API and fetch an aggregate with a generated HTTP repository.

This server demo runs on the Dart VM. It binds an ephemeral loopback port and
makes one anonymous request. No authentication provider is installed: the route
is deliberately public. See the [public/protected example](https://github.com/continuousimagination/dddart/blob/main/packages/dddart_rest/example/public_leaderboard_example.dart)
for per-operation policy overrides.

## Set up the application

Create an empty directory **outside this repository**, then create the named files:

```sh
mkdir dddart_rest_quickstart
cd dddart_rest_quickstart
mkdir -p bin lib
```

Copy the [example pubspec](pubspec.yaml.txt) into the application as `pubspec.yaml`.

## Add the application files

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

## Run the example

<!-- dddart-source: docs/quickstarts/rest/commands.sh -->
```sh
dart pub get
dart run build_runner clean
dart run build_runner build --delete-conflicting-outputs
dart analyze --fatal-infos
dart run bin/main.dart
```
<!-- /dddart-source -->

Expected output:

<!-- dddart-source: docs/quickstarts/rest/expected/main.txt -->
```text
200: public hello
```
<!-- /dddart-source -->

The program finishes and closes its resources. Delete the temporary application directory when finished.
