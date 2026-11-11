---
title: Repositories, from memory to storage
description: Keep application code behind a typed repository contract, then add SQLite, server databases, or an HTTP adapter.
section: Connect the pieces
order: 10
---

A repository gives application code a collection of aggregates without making it speak SQL, BSON, or HTTP. The useful abstraction is small: retrieve an aggregate, save it, and delete it. Start with that contract, then choose the implementation where the application is assembled.

## The contract you can share

`Repository<T, I>` ties an aggregate type to its identity type. For a `Note extends UuidAggregateRoot`, use `Repository<Note, UuidValue>`.

| Operation | Contract |
| --- | --- |
| `Future<T> getById(I id)` | Returns the aggregate or throws `RepositoryException` with type `notFound`. |
| `Future<void> save(T aggregate)` | Inserts a new aggregate or updates the existing aggregate with that identity. |
| `Future<void> deleteById(I id)` | Deletes it; a missing aggregate is a `notFound` error. |

The interface deliberately has no universal `getAll()`, query language, transaction scope, or conflict-resolution policy. Add the reads your domain needs through a custom interface. Backend guarantees remain part of your application's design.

## Start in memory

After [installing the core package](/dddart/docs/getting-started/), this is a complete Dart program:

```dart
import 'package:dddart/dddart.dart';

class Note extends UuidAggregateRoot {
  Note({required this.title, super.id});

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

`readTitle` knows neither where the data lives nor how it travels. The same function can receive a database repository on a server or an HTTP-backed repository in a client.

The in-memory implementation stores object references. It is useful for tests and local development, but it does not simulate serialization, process restarts, database isolation, or network failures. Test the chosen adapter separately before relying on those behaviors.

## Generate a SQLite repository

This example targets a native Dart application with SQLite available. The current adapter uses the native `sqlite3` API; it is not a browser SQLite adapter.

### 1. Prepare the dependencies

The packages are currently installed from Git. Add these four direct dependencies at the same full commit: `dddart`, `dddart_serialization`, `dddart_json`, and `dddart_repository_sqlite`. Add `build_runner: ^2.4.0` under `dev_dependencies`.

Because the SQLite adapter still declares hosted sibling dependencies, the application must also override `dddart`, `dddart_serialization`, `dddart_json`, and `dddart_repository_sql` to the same Git revision. The [Git installation guide](https://github.com/continuousimagination/dddart/blob/b4aacf0671873e729a1a390dc2bb609b80c723e5/docs/GIT_INSTALLATION.md) explains the source setup. An override entry has this form; repeat it for the other three package names and paths:

```yaml
dependency_overrides:
  dddart_repository_sql:
    git:
      url: https://github.com/continuousimagination/dddart.git
      ref: b4aacf0671873e729a1a390dc2bb609b80c723e5
      path: packages/dddart_repository_sql
```

To try an already configured example instead of creating a new application, clone the repository and run its SQLite example:

```bash
git clone https://github.com/continuousimagination/dddart.git
cd dddart
git checkout b4aacf0671873e729a1a390dc2bb609b80c723e5
dart pub get
cd packages/dddart_repository_sqlite/example
dart run build_runner build --delete-conflicting-outputs
dart run basic_crud_example.dart
```

### 2. Define the model

In your own application, create `lib/note.dart`. The JSON and SQLite builders contribute to the same generated part. `dart:convert` and the JSON/serialization imports are used by that generated code, even when the handwritten model looks as though it does not need them.

```dart
import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_repository_sqlite/dddart_repository_sqlite.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

part 'note.g.dart';

@Serializable()
@GenerateSqliteRepository(tableName: 'notes')
class Note extends UuidAggregateRoot {
  Note({
    required this.title,
    super.id,
    super.createdAt,
    super.updatedAt,
  });

  final String title;
}
```

Exposing the identity and timestamps in the constructor lets deserialization restore the saved aggregate instead of creating a new identity on every read.

Run generation from the application's root:

```bash
dart pub get
dart run build_runner build --delete-conflicting-outputs
```

This produces `NoteJsonSerializer` and `NoteSqliteRepository` in `note.g.dart`. Do not edit that file by hand.

### 3. Save, load, and delete

Create `bin/main.dart`. The relative import keeps this example independent of your application's package name.

```dart
import 'package:dddart/dddart.dart';
import 'package:dddart_repository_sqlite/dddart_repository_sqlite.dart';

import '../lib/note.dart';

Future<void> main() async {
  final connection = SqliteConnection.memory();
  // For persistence across runs:
  // final connection = SqliteConnection.file('notes.db');
  await connection.open();

  try {
    final sqlite = NoteSqliteRepository(connection);
    await sqlite.createTables();

    final Repository<Note, UuidValue> notes = sqlite;
    final note = Note(title: 'Ship the first version');
    await notes.save(note);

    final loaded = await notes.getById(note.id);
    print(loaded.title);

    await notes.save(Note(
      id: loaded.id,
      title: 'Ship the next version',
      createdAt: loaded.createdAt,
      updatedAt: DateTime.now(),
    ));

    await notes.deleteById(note.id);
  } finally {
    await connection.close();
  }
}
```

Run it with `dart run bin/main.dart`. Only the composition code knows about SQLite. Functions accepting `Repository<Note, UuidValue>` keep the same shape as the in-memory version.

### What the generated adapter does

SQLite saves an aggregate and its supported child collections inside a database transaction. Value objects are embedded into columns; collections use related tables. Foreign keys are enabled when the connection opens, and collection rows are removed with their parent.

`createTables()` uses `CREATE TABLE IF NOT EXISTS`. It creates a fresh schema; it does **not** migrate an existing schema when your model changes. Plan migrations separately. The current generator replaces aggregate data on save and does not supply optimistic version checks.

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

- [Repository contract](https://github.com/continuousimagination/dddart/blob/b4aacf0671873e729a1a390dc2bb609b80c723e5/packages/dddart/lib/src/repository.dart)
- [SQLite CRUD example](https://github.com/continuousimagination/dddart/blob/b4aacf0671873e729a1a390dc2bb609b80c723e5/packages/dddart_repository_sqlite/example/basic_crud_example.dart) and [generator](https://github.com/continuousimagination/dddart/blob/b4aacf0671873e729a1a390dc2bb609b80c723e5/packages/dddart_repository_sqlite/lib/src/generators/sqlite_repository_generator.dart)
- [MySQL generator](https://github.com/continuousimagination/dddart/blob/b4aacf0671873e729a1a390dc2bb609b80c723e5/packages/dddart_repository_mysql/lib/src/generators/mysql_repository_generator.dart)
- [MongoDB generator](https://github.com/continuousimagination/dddart/blob/b4aacf0671873e729a1a390dc2bb609b80c723e5/packages/dddart_repository_mongodb/lib/src/generators/mongo_repository_generator.dart)
- [DynamoDB generator](https://github.com/continuousimagination/dddart/blob/b4aacf0671873e729a1a390dc2bb609b80c723e5/packages/dddart_repository_dynamodb/lib/src/generators/dynamo_repository_generator.dart)
- [REST generator](https://github.com/continuousimagination/dddart/blob/b4aacf0671873e729a1a390dc2bb609b80c723e5/packages/dddart_repository_rest/lib/src/generators/rest_repository_generator.dart)
