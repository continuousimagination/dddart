# Unaddressed framework defects

Snapshot: 2026-09-24, integrating the authentication and
QueryableRepository/DynamoDB cleanup with the explicit conditional capability.

This register contains 5 deferred defects or legacy limitations. Resolved
entries retain their bounded test evidence below. It is not an exhaustive
issue tracker; source and executable tests remain authoritative.

Suggested priorities are provisional:

- **P1**: can cause incorrect data, authorization failures, or unsafe behavior;
- **P2**: breaks a supported workflow or makes an API materially misleading;
- **P3**: deferred or low-current-priority behavior, quality, or validation debt.

## Current disposition

### Save for later

- **EVENT-001** through **EVENT-004**: the distributed-events feature remains a
  work in progress.
- **REST-004**: legacy repositories remain unconditional. Legacy GET ETags are
  representation validators, not atomic write authority. Conditional mutation
  headers now refuse rather than using the former read/check/save sequence;
  only the separate opted-in conditional capability provides atomic writes.

## Summary

| ID | Priority | Area | Problem |
|---|---|---|---|
| EVENT-001 | P2 | Distributed events | Event-registry builder, output, imports, and annotation contract disagree. |
| EVENT-002 | P2 | Distributed events | POST ingestion ignores its server and cannot safely support a custom stored-event subtype. |
| EVENT-003 | P1 | Distributed events | `autoForward` can forward a remotely polled event back to the server. |
| EVENT-004 | P1 | Distributed events | Polling advances its cursor before an event is successfully reconstructed and published. |
| REST-004 | P3 | REST server | Legacy repositories and GET validators do not provide atomic writes. |

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

## REST, authentication, and authorization defects

### REST-004 — legacy validators do not provide atomic writes

- **Historical evidence:** the legacy ETag check used a separate read/check/save
  sequence. Concurrent writers could both pass and overwrite one another.
- **Current boundary:** `CrudResource` rejects conditional mutation headers with
  a capability error before repository access; ordinary non-versioned writes
  remain unconditional. Legacy GET validators do not turn these writes atomic.
- **Separate capability:** `ConditionalCrudResource` uses required explicit
  preconditions and versioned repositories. Its race tests prove one accepted
  mutation for competing preconditions. This does not add conditional support
  to MongoDB/MySQL/SQLite or the legacy repository interface.
- **Disposition:** preserve this legacy limitation; do not describe best-effort
  ETags as atomic protection or restore the unsafe sequential fallback.

## Resolved read-authorization defect

### AUTH-002 — item and collection reads authorize before storage

- **Resolution:** ordinary item GET invokes `authorizeRead`; filtered and
  unfiltered collections invoke `authorizeQuery` before their explicit handler.
  No repository enumeration fallback exists. Conditional item GET uses the same
  request-local authentication/authorization pipeline; collections are unsupported.
- **Evidence:** `packages/dddart_rest/test/u10/read_and_identity_contract_test.dart`
  asserts denial before repository access and before the explicit unfiltered
  collection handler. `test/u10/conditional_race_test.dart` in that package proves
  refreshed authoritative claims can deny a previously permitted read without
  another repository call, and overlapping requests keep their own principals.
- **Limit:** this resolves the missing read hooks, not every application policy,
  token revocation strategy, or the deferred event and legacy-write limitations.
