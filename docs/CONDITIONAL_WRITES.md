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
