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
contexts opening version 2 must agree on the codec version.

### Blocked upgrades and connection lifecycle

If an older tab, iframe or worker holds a version-1 connection open, the browser
cannot begin the version-2 upgrade. On its native `blocked` event, operations
waiting for that open fail promptly with `IndexedDbOpenBlockedException` (a
`RepositoryException` with type `connection` and a `databaseName`). No data
transaction has been dispatched: neither schema version/marker nor aggregates,
unique claims or receipts are changed. This is an explicit failure, not a timeout
or an `uncertain` conditional-commit result. `resolveOperation` retains its
existing contract: connection failures yield `uncertain`, not rollback proof.

```dart
try {
  await repository.save(aggregate);
} on IndexedDbOpenBlockedException catch (error) {
  // Ask the user to close/reload older contexts using error.databaseName.
  // After those connections are released, retry this operation.
}
```

IndexedDB cannot cancel a queued open request. The adapter abandons that request,
observes its eventual completion/error, aborts its eventual upgrade **before any
schema or record changes**, and closes any late connection. While it is still
queued/draining, repeated calls fail with the same blocked error rather than
silently queuing behind it. After it drains, retry on the same repository starts
a fresh atomic upgrade. Close/reload the older contexts first; retry can still
report blocked while their connection release is being processed. The adapter
never deletes the database or forces another context to close. An external
legacy connection must handle `versionchange` itself or be closed by its owner.

Connections opened by this adapter automatically close on `versionchange`,
including database deletion requests. Existing transactions may finish; the
repository is permanently invalidated and new operations fail with a connection
error explaining the version change. Reload the application before constructing
a replacement with the compatible schema/codec; the old instance never silently
reopens against a different schema. `close()` is also permanent and can abandon
a queued open without waiting indefinitely for another context to release it.

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

The blocked-upgrade regression holds a native version-1 connection in a separate
same-origin iframe and requests version 2 from the parent context. It checks the
entire old store while blocked and after abandonment, then verifies a fresh
atomic upgrade, payload/unique-claim/receipt preservation, and schema/codec
fences. Native tests also cover closing a queued open and automatic release on
version change. These Chrome tests are not a physical WebKit verification.

### Separate-tab isolation harness

From the repository root, with `dart pub get` completed:

```sh
dart packages/dddart_repository_indexeddb/tool/verify_cross_tab.dart > cross-tab-results.json
# Optional positive argument selects the number of race rounds (default: 10).
```

The harness compiles a generic sample participant with Dart, serves it on an
ephemeral loopback origin, and launches an isolated temporary Chrome profile.
Chrome DevTools Protocol creates two **top-level pages**, each independently
loading the compiled Dart program and opening `idbFactoryNative`. These are
same-origin tabs in one storage partition, not two connections in one Dart
context, iframes, memory factories, or isolated incognito partitions. A prepare
barrier stages both requests before dispatching either commit; no application
lock serializes them. Native IndexedDB provides transaction serialization.

Each round asserts one committed writer and one durable stale-revision rejection,
then races a shared unique value and checks both tabs' records and ownership.
A tab retaining an old revision also attempts a write after the other tab deletes
and recreates that ID. Both pages are then destroyed and independently reopened.
Every original operation is resolved and retried with its original ID, payload,
and digest, including a unique-conflict rejection whose competing owner has now
been deleted. Receipts, records, unique owners, and revisions must stay unchanged.
Changed-payload operation-ID reuse and resolution with its changed digest must
still fail with `constraint`.

A failed assertion, command timeout, or persistent cleanup failure exits nonzero.
Profile deletion retries transient filesystem failures at most five times; all
teardown steps run and cleanup diagnostics never replace a verification error.
Only after successful cleanup does a passing run write a JSON report to stdout
containing the browser version, base Git SHA, working-tree status, source hashes
(to identify uncommitted harness changes honestly), page
and Dart-context IDs, and original/replayed outcomes. Compilation diagnostics go
to stderr. `CHROME_EXECUTABLE` selects Chrome (default: `google-chrome` on Linux,
standard application path on macOS). Chrome's sandbox stays enabled. The temporary
browser, profile, server, and database are test-owned.
The adapter CI lane runs this harness after the package tests and retains its JSON
report; `scripts/test-all.sh` runs the same check locally. The [issue #75 work record](../../docs/worky/indexeddb-cross-tab-work-record.md)
records the local verification and independent-review boundary. This harness can
also provide independently loaded participants for later lifecycle tests; it does
not currently exercise blocked upgrades or cancellation.

Cancellation of in-flight operations (#74) and physical iPhone/WebKit
verification (#77) remain separate follow-ups. Chromium results are not physical
WebKit evidence. Public pub.dev publication is tracked
separately in #30.
