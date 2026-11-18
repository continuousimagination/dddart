---
title: Choose a repository
description: Start with in-memory CRUD, then choose storage that matches where your Dart application runs.
section: Connect the pieces
order: 10
---

A `Repository<T, I>` loads, saves, and deletes aggregates of a concrete
identity type. Choose the implementation where you construct the application.

## Start in memory

In the application from [Getting started](/dddart/docs/getting-started/),
save the following as `bin/repository.dart` and run
`dart run bin/repository.dart`:

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

The function reads through the same interface regardless of storage. The
in-memory implementation retains references, which works for a simple test
or prototype. It does not simulate database isolation or durable storage.

## Generate a SQLite repository

The [SQLite quickstart](https://github.com/continuousimagination/dddart/blob/main/docs/quickstarts/sqlite/README.md)
creates a generated repository for a note. It includes the native library
prerequisite, model annotations, build commands, schema setup, and the complete
program. Use the SQLite adapter in a native Dart or Flutter process.

The generator implements CRUD. For a domain query, define an interface with
the method you need, then implement the method on the generated base. The
[custom repository example](https://github.com/continuousimagination/dddart/blob/main/packages/dddart_repository_sqlite/example/lib/custom_user_repository_impl.dart)
shows the handwritten query and how it shares the model's Dart library and
generated part. Use parameters for input values, and define ordering and
bounds as part of the application query.

## Choose storage for the runtime

- Use [native IndexedDB](https://github.com/continuousimagination/dddart/blob/main/packages/dddart_repository_indexeddb/README.md)
  for browser persistence. Supply the browser factory and your codecs.
- Use [a server database](https://github.com/continuousimagination/dddart/blob/main/docs/CAPABILITIES.md#store-and-retrieve-aggregates)
  when trusted services own persistence. The adapter guide compares relational
  and document options, supported shapes, and connection requirements.
- Use [an HTTP repository](/dddart/docs/http/) to call a compatible server from
  a client. Keep database credentials and authoritative access rules on the server.

## Prevent overwrites when it matters

Ordinary saves are unconditional. Use a versioned read and a conditional save
when the operation must fail if another writer changed the record. The database
adapters that implement this capability check the condition in the same write.
An HTTP client depends on a server with that capability. IndexedDB also
offers atomic changes across multiple records and operation receipts.
Read the [conditional writes guide](https://github.com/continuousimagination/dddart/blob/main/docs/CONDITIONAL_WRITES.md)
for the distinction between a confirmed conflict and an unknown outcome.

For publication after a save, see [Events](/dddart/docs/events/). Storage
and publication have separate failure behavior.
