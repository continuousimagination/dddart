# DynamoDB Local persistence

Generate a note repository and run it against DynamoDB Local.

## Start DynamoDB Local

Start Docker and run the commands below. The demo creates and deletes a
`quickstart_notes` table on localhost:8000. Wait for DynamoDB Local to start
before running Dart. You do not need an AWS account.

```sh
docker run --rm -d --name dddart-quickstart-dynamo -p 127.0.0.1:8000:8000 amazon/dynamodb-local:latest -jar DynamoDBLocal.jar -inMemory -sharedDb
docker logs dddart-quickstart-dynamo
```

## Set up the application

Create an empty directory **outside this repository**, then create the named files:

```sh
mkdir dddart_dynamodb_quickstart
cd dddart_dynamodb_quickstart
mkdir -p bin lib
```

Copy the [example pubspec](pubspec.yaml.txt) into the application as `pubspec.yaml`.

## Add the application files

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

## Run the example

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
