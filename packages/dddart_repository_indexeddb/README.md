# dddart_repository_indexeddb

Persist detached aggregate snapshots in native browser IndexedDB. The adapter
implements `Repository<T, I>` and the optional `ConditionalRepository<T, I>`
contract for atomic writes across records in one database.

## Set up a repository

1. Follow the [IndexedDB installation instructions](../../docs/GIT_INSTALLATION.md#core-and-indexeddb).
2. Choose a dedicated database for the aggregate and its concrete identity and
   codec. Pass `idbFactoryNative` from `package:idb_shim/idb_client_native.dart`;
   a fallback browser factory may use volatile memory if native storage is
   unavailable.
3. Supply encode/decode callbacks for a complete snapshot. For a custom ID, share
   an explicit `IdentityCodecRegistry` with the serializer and repository. The
   codec's canonical key must round-trip the typed ID, including its full scope.
   The decoder must restore that same ID.
4. Await saves and deletes. They finish when the transaction commits. Loading
   a missing ID raises a typed `RepositoryException` with type `notFound`.

The [browser CRUD example in the tests](test/browser_repository_test.dart)
shows setup, save, read, and reopen. See the [typed identity contract](test/typed_identity_contract.dart)
for a complete custom codec and a conditional write. Browser storage is scoped
to an origin and is subject to quota and eviction.

## Conditional transactions

Read the current revision with `getVersioned`. Use `commitConditional` to
check revisions and unique values, change records, and write a receipt in one
read/write transaction. Revisions are opaque and change on every put, including
after deleting and recreating an ID. Ordinary CRUD rejects records already
managed by conditional writes. Use the conditional workflow from the first
write for records that need it.

Supply the complete desired set of normalized unique values with each put.
Omitted claims are released. A stale revision or unique collision is a
confirmed rejection recorded in the receipt. Reusing an operation ID with
different encoded data or conditions is a constraint error.

Keep the detached request, its operation ID, and its payload digest until the
result is known. After a timeout or uncertain commit, use `resolveOperation`.
A missing receipt leaves the outcome uncertain. Retry only with the identical
ID, conditions, and encoded payload; re-encoding a modified aggregate changes
the digest. Receipts are retained until the database is removed or explicitly
compacted by the application. The
[conditional contract tests](test/conditional_browser_test.dart) demonstrate
replay and rejection, and the [adapter source](lib/src/indexeddb_repository.dart)
defines storage and transaction limits.

## Cancellation and close

A caller's timeout or cancelled subscription can stop it waiting while the
database operation continues. Basic CRUD has no operation receipts.

The concrete adapter accepts an `IndexedDbCancellation` signal for
`commitConditional`. Use a separate signal per request:

- Before transaction dispatch, cancellation raises `IndexedDbOperationCancelled`.
  It creates no operation receipt and makes no operation writes.
- After dispatch, cancellation can return `CommitDecision.uncertain` with the
  operation ID and digest. The transaction can still finish; resolve it like
  any other uncertain write. A result already observed by the adapter wins.
- `close()` prevents new transaction dispatch and permanently closes the
  repository. Already dispatched transactions retain their normal outcomes.
  Await them separately if needed. Create a new instance with the same database
  and codec to reconcile a receipt after closing.

The [cancellation tests](test/cancellation_contract.dart) show the distinctions.

## Schema changes across browser contexts

Use the same codec and schema in every tab, worker, or frame sharing the
database. The schema marker guards against incompatible snapshots. If your
application changes its identity or payload encoding, it owns that data
conversion. Reads never silently convert records.

An open blocked by another context raises `IndexedDbOpenBlockedException`
before dispatching a data transaction. Release the older connection and retry;
the abandoned native request must drain first. The adapter closes its own
connections on `versionchange` and invalidates the old repository. Reload
before constructing a compatible replacement. See the
[blocked-open tests](test/blocked_upgrade_browser_test.dart) for the lifecycle.

## Browser support

The [validation guide](../../scripts/README.md#browser-validation) explains how
to run the native Chrome suites and the separate-tab isolation check. The VM
memory backend is a test double. The [physical Safari run](https://github.com/continuousimagination/dddart/issues/77)
covers the browser-tab cases recorded in that issue. Installed PWA behavior,
storage eviction, and forced termination during a write require separate
verification in your application.
