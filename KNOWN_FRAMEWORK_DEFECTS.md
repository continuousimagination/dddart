# Unaddressed framework defects

Snapshot: 2026-08-09, after the nine next framework defects were completed on
`fix/next-framework-defects`.

This register contains the 11 implementation defects that remain after the
next-fix branch. Resolved entries are removed once their completion tests pass.
It is not an exhaustive issue tracker; source and executable tests remain
authoritative.

Suggested priorities are provisional:

- **P1**: can cause incorrect data, authorization failures, or unsafe behavior;
- **P2**: breaks a supported workflow or makes an API materially misleading;
- **P3**: quality or validation debt that can conceal other failures.

## Current disposition

### Save for later

- **EVENT-001** through **EVENT-004**: the distributed-events feature remains a
  work in progress.
- **DYNAMO-002**: reconsider the intended role of `QueryableRepository` first.
- **REST-004**: decide the intended ETag and atomic-concurrency contract first.
- **AUTH-001**, **AUTH-002**, **AUTH-003**, **AUTH-005**, and **AUTH-006**:
  revisit the authentication and authorization contracts later.

## Summary

| ID | Priority | Area | Problem |
|---|---|---|---|
| EVENT-001 | P2 | Distributed events | Event-registry builder, output, imports, and annotation contract disagree. |
| EVENT-002 | P2 | Distributed events | POST ingestion ignores its server and cannot safely support a custom stored-event subtype. |
| EVENT-003 | P1 | Distributed events | `autoForward` can forward a remotely polled event back to the server. |
| EVENT-004 | P1 | Distributed events | Polling advances its cursor before an event is successfully reconstructed and published. |
| DYNAMO-002 | P2 | DynamoDB generation | Custom queryable interfaces can produce conflicting `getAll()` declarations. |
| REST-004 | P1 | REST server | ETag validation is a non-atomic read/check/save sequence. |
| AUTH-001 | P1 | Authentication | Refresh reconstructs custom claims from `sub` alone. |
| AUTH-002 | P1 | Authorization | Item GET and unfiltered collection GET bypass `AuthorizationHandler`. |
| AUTH-003 | P1 | Authentication | OAuth JWT authentication does not enforce `exp` or `nbf`. |
| AUTH-005 | P2 | Authentication | Generic refresh-token and device-code subtypes are created through unsafe base-type casts. |
| AUTH-006 | P1 | Authentication | Device grants are not client-bound or single-use. |

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

### DYNAMO-002 — custom queryable repository topology is contradictory

- **Evidence:** the generator's `baseRepositoryMethods` omits `getAll`. It emits
  a concrete `getAll()` but can also classify inherited `getAll()` from a custom
  `QueryableRepository<T>` interface as an abstract custom method. A generated
  custom class can therefore contain conflicting declarations; a custom
  interface that does not extend `QueryableRepository<T>` gets a callable
  method without the nominal capability.
- **Impact:** consumers cannot safely declare a custom DynamoDB repository as
  queryable.
- **Done when:** a generator fixture whose custom interface extends
  `QueryableRepository<T>` compiles with exactly one concrete `getAll()` and
  satisfies the interface at runtime.

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

### AUTH-001 — refresh cannot preserve arbitrary custom claims

- **Evidence:** `JwtAuthHandler.refresh()` calls the application's claims parser
  with only `{'sub': refreshToken.userId}` and then serializes the resulting
  claims into the new token.
- **Impact:** ordinary parsers can throw; parsers that default missing values can
  silently erase roles, tenant membership, email, or other authorization data.
- **Done when:** refresh rehydrates claims through an explicit trusted callback or
  stores sufficient validated claims, with a test proving required roles/profile
  claims survive refresh.

### AUTH-002 — authorization is not applied to two read paths

- **Evidence:** `AuthorizationHandler` is invoked for create, update, delete, and
  filtered queries. `GET /resource/<id>` and unfiltered collection GET do not
  invoke it.
- **Impact:** an authenticated caller can read objects or whole collections that
  operation-level policy would otherwise deny.
- **Done when:** read authorization hooks cover both paths, or the framework
  requires an explicit policy that disables those routes. Tests should prove a
  denied identity cannot read either form.

### AUTH-003 — OAuth authentication accepts expired/not-yet-valid JWTs

- **Evidence:** `OAuthJwtAuthHandler.authenticate()` verifies signature, issuer,
  and audience but does not enforce `exp` or `nbf` before returning success.
- **Impact:** a cryptographically valid expired token, or one not yet valid, can
  authenticate.
- **Done when:** JWKS-backed tests reject expired and future-`nbf` tokens while
  accepting a token inside a configured clock-skew window.

### AUTH-005 — generic token/device subtypes use unsafe casts

- **Evidence:** token issuance constructs a base `RefreshToken` and casts it to
  `TRefreshToken`; device-code creation similarly constructs the base type.
  `revoke()` and `approve()` return base objects that are cast back to generic
  subtypes.
- **Impact:** the advertised persistent/custom subtype extension path throws
  `TypeError` at runtime.
- **Done when:** subtype factories/copy contracts construct the requested type,
  and issuance, approval, refresh, and revocation pass with real subclasses.

### AUTH-006 — device grants are not client-bound or single-use

- **Evidence:** the token endpoint reads `client_id` but does not compare it with
  `DeviceCode.clientId`. Successful redemption leaves the device code approved,
  allowing subsequent redemptions.
- **Impact:** another client can redeem a captured code, and the same grant can
  issue tokens repeatedly.
- **Done when:** client mismatch returns `invalid_grant`, successful redemption
  atomically consumes the code, and a second redemption fails.
