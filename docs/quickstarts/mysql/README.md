# MySQL persistence

The example manifest uses one immutable Git revision; it does not require
published DDDart packages. See [Git installation](https://github.com/continuousimagination/dddart/blob/main/docs/GIT_INSTALLATION.md)
for source overrides and [the support matrix](https://github.com/continuousimagination/dddart/blob/main/docs/CAPABILITIES.md) for platform limits.

MySQL 8 on localhost:3307, database `test_db`, root password `test_password`. Docker must be installed and running.
Use these commands in another terminal; wait until the readiness command succeeds
(or DynamoDB Local reports it has started) before running Dart. A required service
being unavailable is a failure, not a skipped quickstart.

```sh
docker run --rm -d --name dddart-quickstart-mysql -p 127.0.0.1:3307:3306 -e MYSQL_ROOT_PASSWORD=test_password -e MYSQL_DATABASE=test_db mysql:8.0
docker exec dddart-quickstart-mysql mysqladmin ping -h 127.0.0.1 -ptest_password
```

Create an empty directory **outside this repository**, then create the named files:

```sh
mkdir dddart_mysql_quickstart
cd dddart_mysql_quickstart
mkdir -p bin lib
```

Copy the [example pubspec](pubspec.yaml.txt) into the application as `pubspec.yaml`.
It declares the SDK requirement and all dependency constraints.

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

Resolve dependencies, generate from clean build state, analyze, and run:

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
