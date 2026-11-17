# SQLite persistence

Use Dart **3.13.7**, the development SDK used for these checks. This is a verified
setup, not a claim about the minimum SDK on every platform (#98 tracks that).
The DDDart dependencies below use one immutable Git revision; they do not require
published DDDart packages. See [Git installation](https://github.com/continuousimagination/dddart/blob/main/docs/GIT_INSTALLATION.md)
for source overrides and [the support matrix](https://github.com/continuousimagination/dddart/blob/main/docs/CAPABILITIES.md) for platform limits.

This supplied SQLite adapter uses native FFI. Run on a native Dart VM with the
SQLite shared library available (macOS includes it; on Ubuntu install `libsqlite3-0`).
It does not run in a browser. The in-memory database is discarded when closed.

Create an empty directory **outside this repository**, then create the named files:

```sh
mkdir dddart_sqlite_quickstart
cd dddart_sqlite_quickstart
mkdir -p bin lib
```

Save as `pubspec.yaml` (the fixture uses `.txt` only to keep it out of the monorepo workspace):

<!-- dddart-source: docs/quickstarts/sqlite/pubspec.yaml.txt -->
```yaml
name: dddart_sqlite_quickstart
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
  dddart_repository_sqlite:
    git:
      url: https://github.com/continuousimagination/dddart.git
      ref: 56607ac8d3913b8e896ac03f8ecff58473d62ce2
      path: packages/dddart_repository_sqlite
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
  dddart_repository_sql:
    git:
      url: https://github.com/continuousimagination/dddart.git
      ref: 56607ac8d3913b8e896ac03f8ecff58473d62ce2
      path: packages/dddart_repository_sql
  dddart_repository_sqlite:
    git:
      url: https://github.com/continuousimagination/dddart.git
      ref: 56607ac8d3913b8e896ac03f8ecff58473d62ce2
      path: packages/dddart_repository_sqlite
  dddart_serialization:
    git:
      url: https://github.com/continuousimagination/dddart.git
      ref: 56607ac8d3913b8e896ac03f8ecff58473d62ce2
      path: packages/dddart_serialization
```
<!-- /dddart-source -->

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

Resolve dependencies, generate from clean build state, analyze, and run:

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
