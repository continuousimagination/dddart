# Atomic aggregate writes

`Repository<T, I>` retains ordinary unconditional CRUD. A repository implementing
`ConditionalAggregateRepository<T, I>` additionally supplies `getVersioned`,
`saveConditional` and `deleteConditional`. Use
`requireConditionalAggregateRepository(repository)` when an operation requires
this capability: unsupported repositories fail explicitly rather than falling
back to a read/check/unconditional save.

Read a detached `VersionedAggregate<T, I>`, change its domain data, and save with
`ExpectedRevision.match(snapshot.revision)`. The returned string is the committed
revision. The datastore compares the condition and commits the complete aggregate
graph and new revision together. Two writers using the same revision cannot both
commit. Every successful ordinary or conditional save changes the revision, even
when the payload is identical. Delete/recreate never revives an earlier revision.
Revisions are infrastructure metadata; domain identity and timestamps remain
independent. Treat tokens as opaque and scoped to the repository/aggregate.

`ExpectedRevision.absent()` means create-if-absent for saves. A matching condition
on a missing record is a confirmed conflict. Conditional delete with an absent
condition is a successful no-op when missing and a conflict when present.
Ordinary `deleteById` still reports notFound for missing records. Empty, oversized,
whitespace or control-character tokens are invalid before dispatch; other unknown
tokens are stale conditions. A versioned read of a missing aggregate is notFound.

`RevisionConflictException<I>` is a confirmed rejection: the losing request
changed no data and published/acknowledged no pending events. Reload and deliberately
reapply or abandon the application change. Connection failures and timeouts are
not revision conflicts. `ConditionalWriteUncertainException` means persistence may
have succeeded but its acknowledgment is unknown. Do not blindly retry or report
confirmed failure/success; reconcile using application state or a stronger receipt
capability. A revision-only capability does not provide operation receipts.

`ConditionalRepository<T, I>` remains the stronger IndexedDB contract: atomic
multi-record commits, unique claims, operation/payload binding, durable receipts
and uncertain-outcome resolution. Both capabilities share `VersionedRepository`,
`VersionedAggregate` and `ExpectedRevision`; they do not claim interchangeable
write guarantees. IndexedDB's prohibition on ordinary CRUD overwriting
conditionally managed records remains intact. Its conditional delete requires a
matching token. Use its full commit/receipt workflow for that stronger contract.

The executable example is `packages/dddart/example/conditional_writes.dart`.
`InMemoryConditionalRepository` is a single-isolate reference implementation. Supply
an explicit deep-copy/codec function; a map of shared mutable domain objects is
not a detached-snapshot implementation. Multiple repository handles can share an
`InMemoryConditionalStore` for conformance tests. It is not durable storage.

Publication uses captured pending-event batches only after confirmed persistence.
Failed/rejected writes retain their events; uncertain writes must not acknowledge
or publish as though confirmed. Successful saves may still have publication
failure under the existing bounded retry policy; no transactional outbox is implied.

## SQL adapters

Generated SQLite and MySQL repositories implement the single-aggregate capability
for UUID, native, and scoped identities, including custom repository base classes.
The root table owns a reserved `__dddart_revision` column. Every ordinary or
conditional save replaces its token; child rows and collections commit in the
same transaction. Domain JSON does not contain this metadata.

SQLite acquires a write reservation with `BEGIN IMMEDIATE`; independent connections
wait asynchronously for up to five seconds while acquiring it. User callbacks and
commits are never retried. MySQL locks the root row with `SELECT ... FOR UPDATE`;
create-if-absent uses an insert constrained by the primary key. Versioned reads
hold the same transaction through reconstruction of the complete graph. This
favors coherent reads over concurrent reads of the same aggregate.

A conditional save/delete must start outside an existing transaction on its
connection. It owns the physical commit and returns only after confirmation;
nested conditional calls fail before writing. Ordinary saves can join an outer
transaction. Their event publication waits until that outer commit, runs after
its locks are released, and is discarded on rollback. A failed COMMIT is reported
as `ConditionalWriteUncertainException`, never as a stale revision. Lock acquisition
and storage errors also remain distinct from confirmed revision conflicts.

Provision fresh schemas using the updated generators. SQLite needs write access
to the database file and directory. MySQL requires InnoDB tables, `CREATE` and
`REFERENCES` permissions for schema creation, and `SELECT`, `INSERT`, `UPDATE`,
and `DELETE` for repository operations. 1.0 is the first schema
compatibility baseline; these changes do not provide upgrades for prerelease
root tables that lack the revision column.
