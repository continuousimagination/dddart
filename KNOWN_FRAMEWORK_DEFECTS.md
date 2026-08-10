# Unaddressed framework defects

Snapshot: 2026-08-09, after the accepted authentication defects AUTH-001,
AUTH-003, AUTH-005, and AUTH-006 were completed on
`fix/auth-framework-defects`.

This register contains the 6 implementation defects that remain. Resolved
entries are removed once their completion tests pass. It is not an exhaustive
issue tracker; source and executable tests remain authoritative.

Suggested priorities are provisional:

- **P1**: can cause incorrect data, authorization failures, or unsafe behavior;
- **P2**: breaks a supported workflow or makes an API materially misleading;
- **P3**: quality or validation debt that can conceal other failures.

## Current disposition

### Save for later

- **EVENT-001** through **EVENT-004**: the distributed-events feature remains a
  work in progress.
- **REST-004**: decide the intended ETag and atomic-concurrency contract first.
- **AUTH-002**: revisit the authorization contract later.

## Summary

| ID | Priority | Area | Problem |
|---|---|---|---|
| EVENT-001 | P2 | Distributed events | Event-registry builder, output, imports, and annotation contract disagree. |
| EVENT-002 | P2 | Distributed events | POST ingestion ignores its server and cannot safely support a custom stored-event subtype. |
| EVENT-003 | P1 | Distributed events | `autoForward` can forward a remotely polled event back to the server. |
| EVENT-004 | P1 | Distributed events | Polling advances its cursor before an event is successfully reconstructed and published. |
| REST-004 | P1 | REST server | ETag validation is a non-atomic read/check/save sequence. |
| AUTH-002 | P1 | Authorization | Item GET and unfiltered collection GET bypass `AuthorizationHandler`. |

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

### REST-004 — ETag checks are not atomic writes

- **Evidence:** `handleUpdate()` loads the current aggregate, compares the ETag,
  and later calls ordinary `repository.save()` as a separate operation.
- **Impact:** two concurrent writers can both pass the comparison and overwrite
  one another. `If-Match` is also optional, so unconditional updates remain
  possible by design.
- **Done when:** a repository-level conditional write/version contract makes the
  compare-and-save atomic and a concurrency test proves only one stale writer
  succeeds. If ETags remain advisory, the API and naming should say so plainly.

### AUTH-002 — authorization is not applied to two read paths

- **Evidence:** `AuthorizationHandler` is invoked for create, update, delete, and
  filtered queries. `GET /resource/<id>` and unfiltered collection GET do not
  invoke it.
- **Impact:** an authenticated caller can read objects or whole collections that
  operation-level policy would otherwise deny.
- **Done when:** read authorization hooks cover both paths, or the framework
  requires an explicit policy that disables those routes. Tests should prove a
  denied identity cannot read either form.
