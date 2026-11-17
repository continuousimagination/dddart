# SQLite persistence

Generate a note repository and store it in an in-memory SQLite database.

This supplied SQLite adapter uses native FFI. Run on a native Dart VM with the
SQLite shared library available (macOS includes it; on Ubuntu install `libsqlite3-0`).
It does not run in a browser. The in-memory database is discarded when closed.

## Set up the application

Create an empty directory **outside this repository**, then create the named files:

```sh
mkdir dddart_sqlite_quickstart
cd dddart_sqlite_quickstart
mkdir -p bin lib
```

Copy the [example pubspec](pubspec.yaml.txt) into the application as `pubspec.yaml`.

## Add the application files

Save as `bin/main.dart`:

<!-- dddart-source: docs/quickstarts/sqlite/bin/main.dart -->
```dart
import 'package:dddart_repository_sqlite/dddart_repository_sqlite.dart';

import '../lib/note.dart';

Future<void> main() async {
  final connection = SqliteConnection.memory();
  await connection.open();
  try {
    final repository = NoteSqliteRepository(connection);
    await repository.createTables();
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

<!-- dddart-source: docs/quickstarts/sqlite/lib/note.dart -->
```dart
import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_repository_sqlite/dddart_repository_sqlite.dart';

part 'note.g.dart';

@Serializable()
@GenerateSqliteRepository(tableName: 'quickstart_notes')
class Note extends AggregateRoot<UuidValue> {
  Note({required this.text, UuidValue? id, super.createdAt, super.updatedAt})
      : super(id: id ?? UuidValue.generate());
  final String text;
}
```
<!-- /dddart-source -->

## Run the example

<!-- dddart-source: docs/quickstarts/sqlite/commands.sh -->
```sh
dart pub get
dart run build_runner clean
dart run build_runner build --delete-conflicting-outputs
dart analyze --fatal-infos
dart run bin/main.dart
```
<!-- /dddart-source -->

Expected output:

<!-- dddart-source: docs/quickstarts/sqlite/expected/main.txt -->
```text
hello: persisted
```
<!-- /dddart-source -->

The program finishes and closes its resources. Delete the temporary application directory when finished.
