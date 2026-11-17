# MongoDB persistence

Generate a note repository and store it in a disposable MongoDB collection.

## Start MongoDB

Start Docker and run the commands below. The demo uses the
`dddart_quickstart` database on localhost:27017. Wait for the readiness
command to succeed before running Dart.

```sh
docker run --rm -d --name dddart-quickstart-mongo -p 127.0.0.1:27017:27017 mongo:latest
docker exec dddart-quickstart-mongo mongosh --quiet --eval 'db.runCommand({ping: 1})'
```

## Set up the application

Create an empty directory **outside this repository**, then create the named files:

```sh
mkdir dddart_mongodb_quickstart
cd dddart_mongodb_quickstart
mkdir -p bin lib
```

Copy the [example pubspec](pubspec.yaml.txt) into the application as `pubspec.yaml`.

## Add the application files

Save as `bin/main.dart`:

<!-- dddart-source: docs/quickstarts/mongodb/bin/main.dart -->
```dart
import 'package:dddart_repository_mongodb/dddart_repository_mongodb.dart';

import '../lib/note.dart';

Future<void> main() async {
  final connection = MongoConnection(
      host: '127.0.0.1', port: 27017, databaseName: 'dddart_quickstart');
  await connection.open();
  try {
    final repository = NoteMongoRepository(connection.database);
    final note = Note(text: 'hello');
    await repository.save(note);
    final restored = await repository.getById(note.id);
    if (restored.id != note.id || restored.text != note.text) {
      throw StateError('The saved note did not round trip');
    }
    print('hello: persisted');
    await repository.deleteById(note.id);
  } finally {
    await connection.close();
  }
}
```
<!-- /dddart-source -->

Save as `lib/note.dart`:

<!-- dddart-source: docs/quickstarts/mongodb/lib/note.dart -->
```dart
import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_repository_mongodb/dddart_repository_mongodb.dart';
import 'package:mongo_dart/mongo_dart.dart';

part 'note.g.dart';

@Serializable()
@GenerateMongoRepository(collectionName: 'quickstart_notes')
class Note extends AggregateRoot<UuidValue> {
  Note({required this.text, UuidValue? id, super.createdAt, super.updatedAt})
      : super(id: id ?? UuidValue.generate());
  final String text;
}
```
<!-- /dddart-source -->

## Run the example

<!-- dddart-source: docs/quickstarts/mongodb/commands.sh -->
```sh
dart pub get
dart run build_runner clean
dart run build_runner build --delete-conflicting-outputs
dart analyze --fatal-infos
dart run bin/main.dart
```
<!-- /dddart-source -->

Expected output:

<!-- dddart-source: docs/quickstarts/mongodb/expected/main.txt -->
```text
hello: persisted
```
<!-- /dddart-source -->

The program finishes and closes its resources. It removes the demo record. Delete the temporary application directory when finished.
Stop the disposable service with `docker stop dddart-quickstart-mongo`.
