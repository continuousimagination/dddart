# Unaddressed framework defects

Snapshot: 2026-08-10, after the authentication fixes and the
QueryableRepository/DynamoDB cleanup were merged.

This register contains the 4 implementation defects that remain. Resolved
entries are removed once their completion tests pass. It is not an exhaustive
issue tracker; source and executable tests remain authoritative.

Suggested priorities are provisional:

- **P1**: can cause incorrect data, authorization failures, or unsafe behavior;
- **P2**: breaks a supported workflow or makes an API materially misleading;
- **P3**: deferred or low-current-priority behavior, quality, or validation debt.

## Current disposition

### Save for later

- **EVENT-001** through **EVENT-004**: the distributed-events feature remains a
  work in progress.

## Summary

| ID | Priority | Area | Problem |
|---|---|---|---|
| EVENT-001 | P2 | Distributed events | Event-registry builder, output, imports, and annotation contract disagree. |
| EVENT-002 | P2 | Distributed events | POST ingestion ignores its server and cannot safely support a custom stored-event subtype. |
| EVENT-003 | P1 | Distributed events | `autoForward` can forward a remotely polled event back to the server. |
| EVENT-004 | P1 | Distributed events | Polling advances its cursor before an event is successfully reconstructed and published. |

## Confirmed generator and persistence defects

### EVENT-001 — event-registry generation has no coherent output contract

- **Evidence:** the factory uses `LibraryBuilder` and
  `.event_registry.g.dart`; `build.yaml` declares a cached
  `.event_registry.g.part` plus the combining builder. Generated standalone code
  references event classes without importing their library. The scan also
  requires `@Serializable` on `DomainEvent`, while the JSON generator rejects
  types that are not `AggregateRoot`, `Entity`, or `Value`.
- **Impact:** automatic registry generation cannot be relied on as an importable,
  compilable consumer workflow.
- **Done when:** the factory, `build.yaml`, part/import topology, and event
  serialization contract agree and a clean consumer fixture compiles and uses
  the generated registry.

## Distributed-event defects

### EVENT-002 — POST ingestion contradicts its generic/server surface

- **Evidence:** `EventHttpEndpoints<T>.handlePostEvent()` constructs a base
  `StoredEvent`, casts it to `T`, saves it, and never uses the supplied
  `EventBusServer<T>`.
- **Impact:** custom `StoredEvent` subtypes can fail at runtime, and POST does
  not produce the bidirectional EventBus behavior implied by the server
  parameter.
- **Done when:** the intended contract is chosen explicitly. For storage-only
  ingestion, remove the unused server and inject a `T` decoder/factory. For bus
  delivery, add the required domain-event reconstruction and prove publication
  with a behavioral test.

### EVENT-003 — `autoForward` permits an event echo loop

- **Evidence:** polling publishes reconstructed remote events onto the local
  `EventBus`; `autoForward` subscribes to every `DomainEvent` on that same bus and
  POSTs it to the server. There is no origin marker or suppression path.
- **Impact:** a remote event can be re-forwarded, duplicated, and repeatedly
  polled depending on server storage and timestamps.
- **Done when:** a test polls one remote event with `autoForward: true` and proves
  it is delivered locally without a corresponding POST, while a genuinely local
  event is still forwarded once.

### EVENT-004 — polling can permanently skip an unprocessed event

- **Evidence:** `_processEvent()` advances `_lastTimestamp` before registry
  lookup, event reconstruction, and local publication. Reconstruction failures
  are logged and swallowed after the cursor has moved.
- **Impact:** a transient factory failure permanently skips that event. Moving
  the cursor by one microsecond can also miss another event with the same
  timestamp.
- **Done when:** a failed event is retried from the same cursor, and multiple
  events sharing a timestamp are delivered exactly once. A compound
  timestamp/ID cursor or inclusive fetch plus deduplication may be required.

## Resolved concurrency regression

REST-004 was resolved by #91. REST validators now carry coherent storage
revisions and requested conditions execute through atomic repository operations.
The regression in `packages/dddart_repository_mysql/test/rest_concurrency_integration_test.dart`
uses two HTTP servers and independent MySQL connections: exactly one competing
If-Match write succeeds. REST and generated-client suites also cover absence,
recreation, unsupported capabilities and uncertain outcomes. Unconditional CRUD
remains optional by design; `requirePrecondition` enables mandatory conditions.

## Resolved optional authorization regressions

AUTH-002 and the proposed-owner mutation bypass were resolved by #92. Every item
and collection read now resolves an explicit policy. Anonymous public operations
remain supported on otherwise protected resources. Custom policies receive typed
callers, persisted/current/proposed snapshots and explicit application query scopes.
Custom mutations bind permission to a stored revision and POST is create-only.
Aggregate policies use an explicit complete domain snapshot function, so a lossy
public response projection cannot change the owner/permission state they inspect.

`packages/dddart_rest/test/read_authorization_test.dart`,
`mutation_authorization_test.dart`, and `optional_auth_http_test.dart` cover private
read denial, scoped rows/counts, public objects, forged fields, create/update bypass,
ownership races, event retention and the real HTTP caller/operation matrix.
`example/public_leaderboard_example.dart` runs all three intended use cases:
public leaderboard/protected writes, private documents with public objects, and
unconfigured public CRUD. Domain query scoping remains application-owned. Basic
repositories cannot provide atomic custom mutation enforcement and fail closed;
plain public CRUD retains its documented concurrent-creation limitation.
