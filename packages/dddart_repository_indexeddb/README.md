# dddart_repository_indexeddb

A small IndexedDB implementation of dddart's `Repository<T>` CRUD contract for
browser applications. It stores one detached, encoded aggregate snapshot per
UUID. Aggregate encoding, decoding, naming, and other domain rules stay with the
consumer.

The package is Git-only. Pin both `dddart` and this package to the same tested
repository commit:

```yaml
dependencies:
  idb_shim: 2.10.1+1
  dddart:
    git:
      url: https://github.com/continuousimagination/dddart.git
      ref: <tested-commit-sha>
      path: packages/dddart
  dddart_repository_indexeddb:
    git:
      url: https://github.com/continuousimagination/dddart.git
      ref: <tested-commit-sha>
      path: packages/dddart_repository_indexeddb
```

Pass `idbFactoryNative` from `package:idb_shim/idb_client_native.dart` when
browser storage is required. `idbFactoryBrowser` may fall back to volatile
memory storage if native IndexedDB is unavailable.

```dart
import 'package:idb_shim/idb_client_native.dart';

final repository = IndexedDbRepository<MyAggregate>(
  factory: idbFactoryNative,
  databaseName: 'my-app-aggregates',
  storeName: 'aggregates',
  encode: encodeMyAggregate,
  decode: decodeMyAggregate,
);

try {
  await repository.save(aggregate);
  final restored = await repository.getById(aggregate.id);
  await repository.deleteById(restored.id);
} finally {
  await repository.close();
}
```

Use a dedicated database name for each object store with this initial schema.
The adapter creates its store at database version 1. Opening an existing
database at that version with a different, missing store reports a connection
failure; it does not change the schema or erase data.

`save` is an upsert, as specified by `Repository<T>`. It waits for the
IndexedDB transaction to commit before returning. `getById` validates the
stored envelope, codec version, and decoded aggregate ID. Missing IDs map to
`RepositoryExceptionType.notFound`; invalid snapshots map to `constraint`;
storage failures carry their underlying cause. Reads never rewrite old or
malformed records. Encoding must produce a complete detached snapshot.

This package does not provide conditional revisions, uniqueness rules, atomic
operations across records, operation receipts, migration, or recovery from
uncertain write outcomes. Those need a contract beyond `Repository<T>` before
local-first application state can depend on them.

Run `dart test test/repository_test.dart` for the in-memory IndexedDB contract
checks and `dart test -p chrome test/browser_repository_test.dart` for a real
browser check. Run both from this package directory.
