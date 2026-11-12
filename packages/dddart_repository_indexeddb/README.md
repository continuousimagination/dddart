# dddart_repository_indexeddb

A small IndexedDB implementation of dddart's `Repository<T, I>` CRUD contract for
browser applications. It stores one detached, encoded aggregate snapshot per
concrete identity. Aggregate encoding, decoding, naming, and other domain rules stay with the
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
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:idb_shim/idb_client_native.dart';

// Register the application's concrete MyId codec. UUID is registered by default.
final identityCodecs = IdentityCodecRegistry()
  ..register<MyId>('my-id', myIdCodec);

final repository = IndexedDbRepository<MyAggregate, MyId>(
  factory: idbFactoryNative,
  databaseName: 'my-app-aggregates',
  storeName: 'aggregates',
  identityCodecs: identityCodecs,
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
are validated, including payload identity, receipt counts, and unique-claim
ownership, before the upgrade; their bytes are left intact. An interrupted
upgrade rolls back the marker and version change, so opening again can retry.
An incompatible codec, malformed legacy record, or unexpected store fails the
upgrade and preserves the old database for an explicit migration. Separate
contexts opening version 2 must agree on the codec version. Close old tabs that
still hold version-1 connections so the upgrade can proceed.

`save` is an upsert, as specified by `Repository<T, I>`. It waits for the
IndexedDB transaction to commit before returning. `getById` validates the
stored envelope, codec version, and decoded aggregate ID. Missing IDs map to
`RepositoryExceptionType.notFound`; invalid snapshots map to `constraint`;
storage failures carry their underlying cause. Reads never rewrite old or
malformed records. Basic `save` and `deleteById` validate the existing payload
and reject managed, malformed, or older-codec records rather than replacing
them. Encoding must produce a complete detached snapshot.

## Conditional transactions

`IndexedDbRepository<T, I>` also implements the optional, portable
`ConditionalRepository<T, I>` interface. A call to `commitConditional` checks all
expected revisions and desired unique values, changes every affected record,
and stores a receipt in one read-write IndexedDB transaction. It never treats a
successful request as a successful commit until the transaction completes.
Every put receives a fresh opaque revision, including after a delete and
recreation of the same aggregate ID. Two browser contexts writing from one
revision cannot both succeed.

```dart
final request = ConditionalCommit<MyAggregate, MyId>(
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

The native adapter temporarily suppresses `idb_shim` 2.10.1+1's transaction
`onerror` callback because it assumes a nullable browser error is present
during request-error bubbling. It still observes the final transaction abort
or completion and separately awaits each request. A native duplicate-key
regression test exercises this path. Remove the guard when the dependency is
fixed and retested.

## Cancellation, timeouts, and close

Dart `Future`s do not have an IndexedDB abort contract. Dropping a future,
wrapping it in `Future.timeout`, or cancelling a subscription **only stops the
caller waiting**; it does not cancel an operation. Observe the returned future
(or use a wrapper that observes late errors). Basic CRUD has no operation
receipts: after an independent timeout it cannot promise rollback or an
idempotent retry. Use conditional operations when reconciliation is required.

The concrete adapter adds an optional `IndexedDbCancellation` signal to
`commitConditional`; the portable core interface remains unchanged. Use one
signal per call and keep an immutable, detached request:

```dart
final cancellation = IndexedDbCancellation();
final digest = repository.digestFor(request); // retain before dispatch
final pending = repository.commitConditional(
  request,
  cancellation: cancellation,
);
// A caller-owned UI/lifecycle/deadline handler may call cancellation.cancel().
try {
  final result = await pending;
  if (result.decision == CommitDecision.uncertain) {
    final resolved = await repository.resolveOperation(
      result.operationId,
      result.payloadDigest,
    );
    // If still uncertain, retry the exact request with the same operation ID.
    // Do not mutate/re-encode it or use a new ID to guess that it rolled back.
  }
} on IndexedDbOperationCancelled catch (cancelled) {
  // This call never dispatched a transaction or wrote a receipt.
  // cancelled.operationId and cancelled.payloadDigest identify its request.
  // An earlier attempt with this same ID may still need reconciliation.
}
```

- **Before dispatch** (creation of the operation's IndexedDB transaction), a
  signalled cancellation throws `IndexedDbOperationCancelled`. The adapter still
  validates/encodes the request first. An already cancelled signal does not open
  storage. Cancellation during a pending database open is checked after that
  open/validation completes; it does not cancel or unblock the open itself.
  No operation mutations or receipt are issued. Prior committed data is intact.
- **After dispatch**, cancellation stops waiting and returns
  `CommitDecision.uncertain`, preserving the prepared operation ID and payload
  digest, with no revisions or rejection reason. It does **not** abort the
  transaction, even if cancellation happens before any write request. Aggregate,
  unique-claim, and receipt changes still commit or abort atomically. The adapter
  continues observing the late result/errors internally. If a confirmed outcome
  is observed before cancellation, that outcome wins; cancellation can also win
  after storage commits but before its acknowledgment is observed. Never label
  that race as rollback. An independent timeout needs the same reconciliation
  discipline; its `TimeoutException` alone contains no operation ID or digest.
- **`close()` is a dispatch barrier, not cancellation or a drain.** It immediately
  prevents new operation transactions, including calls waiting for opening, and
  requests closure of the connection after opening/validation finishes. Already
  created transactions keep running, and their futures retain their normal
  outcomes. `close()` does not wait for those futures; await them separately.
  Calls prevented from dispatching fail with a typed connection error
  (`resolveOperation` instead returns uncertain). The instance stays closed;
  use a new repository with the same database and codec to reconcile receipts.
  Closing a never-opened repository does not open storage. Pending/blocked schema
  opens are not forcibly cancelled; blocked upgrades remain a separate concern.

The signal is not a general transaction-abort API. A missing receipt is always
uncertain, not proof of rollback, and this contract adds no application policy
or browser dependencies to core.

## Typed identity and migration

The aggregate and repository use the same concrete identity type, just like core:
`AggregateRoot<MyId>`, `Repository<MyAggregate, MyId>` and
`ConditionalRepository<MyAggregate, MyId>`. Versioned snapshots and mutations
carry both type parameters; `CommitResult<MyId>.revisions` is keyed by `MyId`.
Operation IDs and generated revision tokens remain UUIDs independently of the
aggregate identity. Existing UUID consumers use `UuidAggregateRoot` and
`IndexedDbRepository<MyAggregate, UuidValue>`.

The adapter uses the application's registered `IdentityCodec<MyId>` canonical
key, never arbitrary `toString` or a UUID translation. Register it with the
instance-local `IdentityCodecRegistry` and share that registry with your
serializer if applicable. Browser dependencies remain here, not in core or the
portable conditional contract. `dddart_serialization` is a portable dependency;
it and core resolve as sibling paths in the same Git checkout without overrides.
If importing the registry directly, declare serialization at that same Git SHA.

Non-UUID physical keys encode the explicit stable codec registration key and
canonical identity key as a namespaced JSON/base64 tuple. This preserves scope,
case, punctuation and empty canonical strings while separating aggregate keys
from schema, receipt and uniqueness metadata. Malformed UTF-16 keys are rejected
before I/O instead of being silently replaced during UTF-8 conversion. Codecs
must be lossless, canonical and deterministic. Snapshot encoding must preserve
the same typed identity; decoded mismatches are constraint errors.

Existing UUID version-1 and version-2 record keys, unique ownership, receipts and
digests retain their reviewed format. The marker-only version-1 upgrade still
validates all legacy records atomically. This is not a conversion of existing
UUID records into a new identity kind. Use a dedicated database per aggregate
and concrete identity/codec, and an explicit application migration for a change
of identity kind, codec registration key, canonical key format or payload codec.
Increment `codecVersion` when changing the payload format; contexts must agree.

## Validation and limits

The workspace inventory registers this package and its portable dependency
closure. `dart test` runs both VM memory/failure tests and Chrome through
`dart_test.yaml`, so the shared package gate includes native-browser tests.
Use `dart test -p vm` for the memory/failure checks alone and
`dart test -p chrome` for browser checks. Chrome must be installed; set
`CHROME_EXECUTABLE` if it is not on the usual path. Native tests explicitly use
`idbFactoryNative` and cover UUID schema recovery plus scoped typed CRUD,
conditional writes, uniqueness, receipts and reopening.

The existing native conditional race uses separate connections in one browser
context; it is **not** a separate-tab isolation proof. Cancellation tests use
controlled open/acknowledgment barriers around real memory/native transactions,
not timing sleeps to guess the commit race. Native Chrome regressions cover
cancellation before and after commit, independent timeout, close during opening
and dispatched conditional/basic writes, late abort/error observation, aggregate
and unique-claim consistency, receipt counts, reconciliation and exact retry.
The memory fake closes shared handles immediately, so dispatched-close behavior
is asserted only against native IndexedDB. See the #74 work record in
`docs/worky/indexeddb-cancellation-work-record.md` for validation evidence.
Separate-tab isolation (#75), blocked schema upgrades (#76), and physical
iPhone/WebKit verification (#77) remain separate follow-ups; Chrome evidence
does not establish those guarantees. Public pub.dev publication is tracked
separately in #30.
