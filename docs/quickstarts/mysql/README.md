# MySQL persistence

Generate MySQL persistence for a note and exercise it against a disposable database.

## Start MySQL

Start Docker and run the commands below. They create a disposable database on
localhost:3307. Wait for the readiness command to succeed before running Dart.

```sh
docker run --rm -d --name dddart-quickstart-mysql -p 127.0.0.1:3307:3306 -e MYSQL_ROOT_PASSWORD=test_password -e MYSQL_DATABASE=test_db mysql:8.0
docker exec dddart-quickstart-mysql mysqladmin ping -h 127.0.0.1 -ptest_password
```

## Set up the application

Create an empty directory **outside this repository**, then create the named files:

```sh
mkdir dddart_mysql_quickstart
cd dddart_mysql_quickstart
mkdir -p bin lib
```

Copy the [example pubspec](pubspec.yaml.txt) into the application as `pubspec.yaml`.

## Add the application files

Save as `bin/main.dart`:

<!-- dddart-source: docs/quickstarts/mysql/bin/main.dart -->
```dart
import 'package:dddart_repository_mysql/dddart_repository_mysql.dart';

import '../lib/note.dart';

Future<void> main() async {
  final connection = MysqlConnection(
      host: '127.0.0.1',
      port: 3307,
      database: 'test_db',
      user: 'root',
      password: 'test_password');
  await connection.open();
  try {
    final repository = NoteMysqlRepository(connection);
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

<!-- dddart-source: docs/quickstarts/mysql/lib/note.dart -->
```dart
import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_repository_mysql/dddart_repository_mysql.dart';

part 'note.g.dart';

@Serializable()
@GenerateMysqlRepository(tableName: 'quickstart_notes')
class Note extends AggregateRoot<UuidValue> {
  Note({required this.text, UuidValue? id, super.createdAt, super.updatedAt})
      : super(id: id ?? UuidValue.generate());
  final String text;
}
```
<!-- /dddart-source -->

## Run the example

<!-- dddart-source: docs/quickstarts/mysql/commands.sh -->
```sh
dart pub get
dart run build_runner clean
dart run build_runner build --delete-conflicting-outputs
dart analyze --fatal-infos
dart run bin/main.dart
```
<!-- /dddart-source -->

Expected output:

<!-- dddart-source: docs/quickstarts/mysql/expected/main.txt -->
```text
hello: persisted
```
<!-- /dddart-source -->

The program finishes and closes its resources. It removes the demo record. Delete the temporary application directory when finished.
Stop the disposable service with `docker stop dddart-quickstart-mysql`.
