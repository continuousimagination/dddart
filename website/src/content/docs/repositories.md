---
title: Repositories, from memory to storage
description: Keep application code behind a typed repository contract, then add SQLite, server databases, or an HTTP adapter.
section: Connect the pieces
order: 10
---

Code outside an explicitly named complete workflow is an **illustrative fragment**
that assumes the surrounding application models and setup. Use the
[complete quickstarts](https://github.com/continuousimagination/dddart/blob/main/docs/QUICKSTARTS.md)
for copyable manifests, named files, generation commands, expected output and cleanup.


A repository gives application code a collection of aggregates without making it speak SQL, BSON, or HTTP. The useful abstraction is small: retrieve an aggregate, save it, and delete it. Start with that contract, then choose the implementation where the application is assembled.

## The contract you can share

`Repository<T, I>` ties an aggregate type to its identity type. For a `Note extends AggregateRoot<UuidValue>`, use `Repository<Note, UuidValue>`.

| Operation | Contract |
| --- | --- |
| `Future<T> getById(I id)` | Returns the aggregate or throws `RepositoryException` with type `notFound`. |
| `Future<void> save(T aggregate)` | Inserts a new aggregate or updates the existing aggregate with that identity. |
| `Future<void> deleteById(I id)` | Deletes it; a missing aggregate is a `notFound` error. |

The interface deliberately has no universal `getAll()`, query language, transaction scope, or conflict-resolution policy. Add the reads your domain needs through a custom interface. Backend guarantees remain part of your application's design.

## Start in memory

After [installing the core package](/dddart/docs/getting-started/), this is a complete Dart program:

<!-- dddart-source: docs/quickstarts/core/bin/repository.dart -->
```dart
import 'package:dddart/dddart.dart';

class Note extends AggregateRoot<UuidValue> {
  Note({required this.title, UuidValue? id})
      : super(id: id ?? UuidValue.generate());

  final String title;
}

Future<String> readTitle(
  Repository<Note, UuidValue> notes,
  UuidValue id,
) async {
  final note = await notes.getById(id);
  return note.title;
}

Future<void> main() async {
  final Repository<Note, UuidValue> notes =
      InMemoryRepository<Note, UuidValue>();
  final note = Note(title: 'Ship the first version');

  await notes.save(note);
  print(await readTitle(notes, note.id));
  await notes.deleteById(note.id);
}
```
<!-- /dddart-source -->

`readTitle` knows neither where the data lives nor how it travels. The same function can receive a database repository on a server or an HTTP-backed repository in a client.

The in-memory implementation stores object references. It is useful for tests and local development, but it does not simulate serialization, process restarts, database isolation, or network failures. Test the chosen adapter separately before relying on those behaviors.

## Generate a SQLite repository

Use Dart **3.13.7**, the development SDK used for these checks. This is a verified
setup, not a claim about the minimum SDK on every platform (#98 tracks that).
The DDDart dependencies below use one immutable Git revision; they do not require
published DDDart packages. See [Git installation](https://github.com/continuousimagination/dddart/blob/main/docs/GIT_INSTALLATION.md)
for source overrides and [the support matrix](https://continuousimagination.github.io/dddart/docs/contracts/) for platform limits.

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

## Give queries a domain name

Add a domain-specific interface when the application needs more than identity lookup. Using the `Note` model above:

```dart
abstract interface class NoteRepository
    implements Repository<Note, UuidValue> {
  Future<List<Note>> findByTitle(String title);
}
```

Pass `implements: NoteRepository` in `@GenerateSqliteRepository(...)` and regenerate. Because the interface has an additional method, the builder emits an abstract `NoteSqliteRepositoryBase`. Your concrete implementation extends it and implements `findByTitle`; the generator does not invent a query or infer what the business term means.

Generated underscore-prefixed members such as `_connection` and `_serializer` are **library-private**, not protected. A custom implementation that accesses them must be in the model library or a handwritten `part` of it. Alternatively, pass your own connection into an implementation in another library and use public APIs. Do not copy examples that access private members from an ordinary imported subclass.

Likewise, `InMemoryRepository<Note, UuidValue>` does not automatically implement your new `NoteRepository` interface. Supply a small fake or adapter that implements its extra query methods for tests.

## Choose the adapter at the application boundary

| Adapter | Typical placement | Storage behavior and setup |
| --- | --- | --- |
| `InMemoryRepository` | Unit tests, local prototypes | In-process object references; no durable storage. |
| `dddart_repository_sqlite` | Native local applications and native servers | Generated normalized tables; explicit connection lifecycle and `createTables()`. |
| `dddart_repository_mysql` | Server | Generated relational persistence using one MySQL connection, transactions, and InnoDB tables. |
| `dddart_repository_mongodb` | Server | Stores the serialized aggregate as a document; generated constructor receives `connection.database`. |
| `dddart_repository_dynamodb` | Server | Stores an aggregate as an item keyed by a canonical string identity; provision the table before serving requests. |
| `dddart_repository_rest` | HTTP clients | Generated `getById`, `save`, and `deleteById` over the API; compose authentication for the target platform. |
| `dddart_repository_sql` | Adapter infrastructure | Shared schema, dialect, query, and connection abstractions; not a standalone database driver. |

For MongoDB, open `MongoConnection` before constructing the generated repository and close it after use. For MySQL, use `MysqlConnection.open()` / `close()`; its deprecated `maxConnections` argument does not create a pool. For DynamoDB, construct `DynamoConnection`, provision a table with an `id` string partition key, and dispose the connection when finished. The generated `createTable()` helper is for provisioning, not something to call on every request.

### The HTTP contract

A generated REST repository uses these operations:

| Repository call | Request | Expected success |
| --- | --- | --- |
| `getById(id)` | `GET /notes/{encoded-id}` | `200` with a JSON object |
| `save(note)` | `PUT /notes/{encoded-id}` with JSON | `200` or `204` |
| `deleteById(id)` | `DELETE /notes/{encoded-id}` | `200` or `204` |

`save` expects the API's PUT endpoint to support the repository's upsert contract. The generated client checks that a fetched response has the identity it requested. It maps HTTP errors into repository exceptions, and `RestConnection.dispose()` closes its HTTP client. The [HTTP guide](/dddart/docs/http/) shows how to compose the corresponding resource and client.

## Share the contract, compose the runtime

Keep the domain, repository interfaces, and portable serialization in a shared package. Put database connections and server infrastructure at the server's composition boundary. Put the HTTP adapter and appropriate authentication/storage implementations at the client's boundary. This lets the same application service depend on `Repository<Note, UuidValue>` in both places.

Generated repositories are currently emitted into the annotated aggregate's Dart library. Adding a native database import and annotation to a shared model can therefore make that entire library unsuitable for a browser build. The compact SQLite example above is a native example, not a recommended universal shared-package layout. For a shared model used across runtime boundaries, keep native persistence implementations in a separate server library and implement or adapt the shared repository contract there. See [contracts and composition](/dddart/docs/contracts/).

Portability also does not make a database connection safe to expose in an untrusted client. Server database credentials and authorization decisions belong on the server. Client validation can improve the user experience while the server applies the authoritative rules.

## Know the boundaries

- **Identity:** generated repositories preserve the aggregate's concrete identity type. For custom identities, pass the same configured `IdentityCodecRegistry` to the repository and the serializers used at its boundaries. Stock UUID identities work with the default registry.
- **SQL keys:** current SQLite identities use UTF-8 bytes in BLOB columns; MySQL uses `VARBINARY(1024)` and rejects longer encoded identity keys. Existing binary-UUID schemas need an explicit migration. MySQL validates identity-column compatibility before use.
- **SQL collections:** use concrete element types. Nested collections, dynamic/Object collections, value-object map keys, and collections of aggregate roots are rejected. Reference another aggregate by identity. Nullable collection containers currently load as empty collections. MySQL entity collections currently require `List<Entity>` rather than sets or maps.
- **Database semantics:** the shared interface does not imply identical date precision, query capabilities, transactions, or consistency. The current MySQL date mapping has second precision. DynamoDB's generated reads use the service's default consistency; its upserts do not include a version condition.
- **Concurrency:** the generated CRUD implementations do not provide a universal compare-and-swap contract. The REST repository does not automatically retain ETags or send `If-Match`. Add the concurrency behavior your application needs explicitly.
- **Events:** generated repositories accept an optional `eventPublisher`. Publication follows successful persistence, and failed publication is distinct from failed persistence. This is not an atomic database-and-message transaction. Read the [events guide](/dddart/docs/events/) before deciding where events are published.

## Read the implementation

The examples and behavior on this page are grounded in the following source revision:

- [Repository contract](https://github.com/continuousimagination/dddart/blob/56607ac8d3913b8e896ac03f8ecff58473d62ce2/packages/dddart/lib/src/repository.dart)
- [SQLite CRUD example](https://github.com/continuousimagination/dddart/blob/56607ac8d3913b8e896ac03f8ecff58473d62ce2/packages/dddart_repository_sqlite/example/basic_crud_example.dart) and [generator](https://github.com/continuousimagination/dddart/blob/56607ac8d3913b8e896ac03f8ecff58473d62ce2/packages/dddart_repository_sqlite/lib/src/generators/sqlite_repository_generator.dart)
- [MySQL generator](https://github.com/continuousimagination/dddart/blob/56607ac8d3913b8e896ac03f8ecff58473d62ce2/packages/dddart_repository_mysql/lib/src/generators/mysql_repository_generator.dart)
- [MongoDB generator](https://github.com/continuousimagination/dddart/blob/56607ac8d3913b8e896ac03f8ecff58473d62ce2/packages/dddart_repository_mongodb/lib/src/generators/mongo_repository_generator.dart)
- [DynamoDB generator](https://github.com/continuousimagination/dddart/blob/56607ac8d3913b8e896ac03f8ecff58473d62ce2/packages/dddart_repository_dynamodb/lib/src/generators/dynamo_repository_generator.dart)
- [REST generator](https://github.com/continuousimagination/dddart/blob/56607ac8d3913b8e896ac03f8ecff58473d62ce2/packages/dddart_repository_rest/lib/src/generators/rest_repository_generator.dart)
