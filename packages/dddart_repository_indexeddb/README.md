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

Use a dedicated database name for each object store. The adapter opens database
version 2 and writes a schema/codec marker in the same version-change
transaction. Existing version-1 aggregate, unique-index and receipt records
are checked before the upgrade; their bytes are left intact. An interrupted
upgrade rolls back the marker and version change, so opening again can retry.
An incompatible codec, malformed legacy record, or unexpected store fails the
upgrade and preserves the old database for an explicit migration. Separate
contexts opening version 2 must agree on the codec version. Close old tabs that
still hold version-1 connections so the upgrade can proceed.

`save` is an upsert, as specified by `Repository<T>`. It waits for the
IndexedDB transaction to commit before returning. `getById` validates the
stored envelope, codec version, and decoded aggregate ID. Missing IDs map to
`RepositoryExceptionType.notFound`; invalid snapshots map to `constraint`;
storage failures carry their underlying cause. Reads never rewrite old or
malformed records. Basic `save` and `deleteById` reject managed, malformed,
or older-codec records rather than replacing them. Encoding must produce a
complete detached snapshot.

## Conditional transactions

`IndexedDbRepository<T>` also implements the optional, portable
`ConditionalRepository<T>` interface. A call to `commitConditional` checks all
expected revisions and desired unique values, changes every affected record,
and stores a receipt in one read-write IndexedDB transaction. It never treats a
successful request as a successful commit until the transaction completes.
Every put receives a fresh opaque revision, including after a delete and
recreation of the same aggregate ID. Two browser contexts writing from one
revision cannot both succeed.

```dart
final request = ConditionalCommit<MyAggregate>(
  operationId: UuidValue.generate(),
  mutations: [
    ConditionalMutation.put(
      edited,
      expected: ExpectedRevision.match(previous.revision),
      uniqueValues: [UniqueValue('name', normalizedName)],
    ),
  ],
);
final digest = repository.digestFor(request);
final result = await repository.commitConditional(request);
if (result.decision == CommitDecision.uncertain) {
  final reconciled = await repository.resolveOperation(
    request.operationId,
    digest,
  );
  // If still uncertain, retain the exact request and retry with its same ID.
}
```

The caller supplies already-normalized unique values; name policy belongs to
the application. Each put supplies its *complete* desired unique-value set, so
omitted old claims are released. A rejected stale revision or unique collision
has a durable receipt. Reusing an operation ID with different encoded payload
or conditions is a constraint error. An absent receipt, including one queried
after a storage error, is **uncertain**, never proof that a write did not commit.
If a caller times out independently, it should retain the request, its ID, and
the precomputed digest for reconciliation. Re-encoding a mutable aggregate
after an uncertain result can change the digest; use detached immutable input.

The implementation keeps aggregate records, unique-claim records, and receipts
in the same object store to preserve atomicity without changing the initial
database schema. Basic `save` and `deleteById` reject aggregates already
managed by conditional transactions, preventing an unconditional overwrite.
Old basic-CRUD records have no revisions and cannot be conditionally updated
without an explicit migration. Reads do not silently migrate them.

One commit accepts 1–32 aggregates, at most 16 unique values per aggregate,
values of at most 256 characters, and snapshots of at most 1 MiB. Receipts are
retained for the database lifetime and are never silently pruned. The default
limit is 100,000 receipts per repository database; once reached, new operations
fail explicitly before mutation while existing receipts remain resolvable.
The application must plan a deliberate compaction/migration before reaching
that limit. Browser quota and origin-data eviction remain possible.

Version-1 to version-2 migration only adds the schema marker; it does not
transform aggregate payloads. A later codec change needs an explicit consumer
migration. Storage unavailability is a typed connection error. A quota failure
after a conditional write starts can yield `uncertain`; retain the exact
operation ID and digest, resolve it when storage returns, and retry the same
request if no receipt can be found. An absent receipt is never rollback proof.
The base CRUD API has not acquired conditional guarantees; callers that need
them must use `commitConditional`.

Run `dart test` for the in-memory IndexedDB contract and injected failure
checks. Run `dart test -p chrome test/browser_repository_test.dart
test/conditional_browser_test.dart` for real browser checks. Run both from this
package directory. Physical WebKit/device behavior is still a separate proof.
