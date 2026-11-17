# DynamoDB Local persistence

Use Dart **3.13.7**, the development SDK used for these checks. This is a verified
setup, not a claim about the minimum SDK on every platform (#98 tracks that).
The DDDart dependencies below use one immutable Git revision; they do not require
published DDDart packages. See [Git installation](https://github.com/continuousimagination/dddart/blob/main/docs/GIT_INSTALLATION.md)
for source overrides and [the support matrix](https://github.com/continuousimagination/dddart/blob/main/docs/CAPABILITIES.md) for platform limits.

DynamoDB Local on localhost:8000. No AWS account or live credentials are used. Use a fresh disposable instance: this demo creates and deletes its own `quickstart_notes` table. Docker must be installed and running.
Use these commands in another terminal; wait until the readiness command succeeds
(or DynamoDB Local reports it has started) before running Dart. A required service
being unavailable is a failure, not a skipped quickstart.

```sh
docker run --rm -d --name dddart-quickstart-dynamo -p 127.0.0.1:8000:8000 amazon/dynamodb-local:latest -jar DynamoDBLocal.jar -inMemory -sharedDb
docker logs dddart-quickstart-dynamo
```

Create an empty directory **outside this repository**, then create the named files:

```sh
mkdir dddart_dynamodb_quickstart
cd dddart_dynamodb_quickstart
mkdir -p bin lib
```

Save as `pubspec.yaml` (the fixture uses `.txt` only to keep it out of the monorepo workspace):

<!-- dddart-source: docs/quickstarts/dynamodb/pubspec.yaml.txt -->
```yaml
name: dddart_dynamodb_quickstart
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
  dddart_repository_dynamodb:
    git:
      url: https://github.com/continuousimagination/dddart.git
      ref: 56607ac8d3913b8e896ac03f8ecff58473d62ce2
      path: packages/dddart_repository_dynamodb
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
  dddart_repository_dynamodb:
    git:
      url: https://github.com/continuousimagination/dddart.git
      ref: 56607ac8d3913b8e896ac03f8ecff58473d62ce2
      path: packages/dddart_repository_dynamodb
  dddart_serialization:
    git:
      url: https://github.com/continuousimagination/dddart.git
      ref: 56607ac8d3913b8e896ac03f8ecff58473d62ce2
      path: packages/dddart_serialization
```
<!-- /dddart-source -->

Save as `bin/main.dart`:

<!-- dddart-source: docs/quickstarts/dynamodb/bin/main.dart -->
```dart
import 'package:dddart_repository_dynamodb/dddart_repository_dynamodb.dart';

import '../lib/note.dart';

Future<void> main() async {
  final connection = DynamoConnection.local();
  final repository = NoteDynamoRepository(connection);
  try {
    // This demo owns its table in a fresh, disposable DynamoDB Local instance.
    await repository.createTable();
    try {
      final note = Note(text: 'hello');
      await repository.save(note);
      final restored = await repository.getById(note.id);
      if (restored.id != note.id || restored.text != note.text) {
        throw StateError('The saved note did not round trip');
      }
      print('hello: persisted');
    } finally {
      await connection.client.deleteTable(tableName: 'quickstart_notes');
    }
  } finally {
    connection.dispose();
  }
}
```
<!-- /dddart-source -->

Save as `lib/note.dart`:

<!-- dddart-source: docs/quickstarts/dynamodb/lib/note.dart -->
```dart
import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_repository_dynamodb/dddart_repository_dynamodb.dart';

part 'note.g.dart';

@Serializable()
@GenerateDynamoRepository(tableName: 'quickstart_notes')
class Note extends AggregateRoot<UuidValue> {
  Note({required this.text, UuidValue? id, super.createdAt, super.updatedAt})
      : super(id: id ?? UuidValue.generate());
  final String text;
}
```
<!-- /dddart-source -->

Resolve dependencies, generate from clean build state, analyze, and run:

<!-- dddart-source: docs/quickstarts/dynamodb/commands.sh -->
```sh
dart pub get
dart run build_runner clean
dart run build_runner build --delete-conflicting-outputs
dart analyze --fatal-infos
dart run bin/main.dart
```
<!-- /dddart-source -->

Expected output:

<!-- dddart-source: docs/quickstarts/dynamodb/expected/main.txt -->
```text
hello: persisted
```
<!-- /dddart-source -->

The program finishes and closes its resources. Delete the temporary application directory when finished.
Stop the disposable service with `docker stop dddart-quickstart-dynamo`.
