# Silly Sentence Game: AppSync Events migration handoff

Prepared 6 November 2026 for the Codex project already working on Silly Sentence
Game. The app uses dddart's polling events today. Its source, deployment and exact
domain types have **not** been inspected in this dddart task; confirm those in the
app project rather than treating the illustrative names below as existing code.

## Objective and starting point

Use Silly Sentence Game as the first real application acceptance test of dddart's
new distributed events. Migrate a development event flow, exercise it against real
AWS, and turn integration failures or awkward APIs into framework improvements
and repeatable regression tests. The owner explicitly proposed this approach.

- Repository: <https://github.com/continuousimagination/dddart>
- Branch: `codex/appsync-events`
- PR: <https://github.com/continuousimagination/dddart/pull/65>
- Tested implementation commit: `11f4754fb77f875d6d3e44239e58e0950d90f658`.
  This handoff is a documentation follow-up; later framework fixes may advance
  the branch. Record the actual revision used for each app test.
- Issues #54–#64 contain the accepted scope and completed implementation
  checklists. All carry `appsync`; the shared PR closes them on merge.
- Main API/deployment/migration guide: [DISTRIBUTED_EVENTS.md](DISTRIBUTED_EVENTS.md).

The framework implementation passed the complete local service-backed gate.
**No real AWS deployment or live AppSync smoke test has been performed.** Native
protocol fixtures and schema validation are evidence for the implementation,
not evidence that an application deployment works on AWS.

## Decisions to preserve

These were settled with the owner, rather than left for the app migration to
redesign:

- Coherent public contracts and client/server symmetry take priority over
  efficiency. Aggregate REST JSON contains only public aggregate state. Never
  attach the private pending-event collection to its body or headers.
- DDDart is pre-release. The owner accepts justified contract-breaking changes;
  compatibility alone should not preserve an incoherent API.
- Clients and servers can originate events. An event-enabled repository saves
  the aggregate, then awaits a separate shared publisher. Do not force all
  client-originated events into a new command-only architecture.
- Common publisher code owns bounded retries/logging. Exhausted event publication
  leaves events pending and logs an error; it does not fail already committed CRUD.
- Keep safe captured pending batches and selective acknowledgment. Do not clear
  the whole pending queue after an await or duplicate retry loops in repositories.
- Watches identify a concrete logical aggregate: explicit stable kind plus typed,
  possibly scoped identity. Permission and current interest are separate.
- Built-in dddart authentication remains supported. Cognito/OIDC are optional;
  no mandatory Amplify, replacement login flow or mobile AWS access keys.
- Server history and channel metadata use DynamoDB. InMemory is for local/tests.
  Clients store per-watch checkpoints, not their own event database.
- Access-change events rotate physical channels to fresh random UUIDs. Revocation
  is initially best effort and effective after processing the trigger. Atomic
  membership/rotation, automatic permission fingerprinting and outbox delivery
  were explicitly deferred.
- Default history retention is seven days, configurable. Expiration requires an
  explicit application reload. No strict live ordering, exactly-once delivery or
  consumer-processing acknowledgment is promised.
- Unknown event types warn/skip; malformed known payloads error/skip and history
  recovery continues. Clients are expected to be updated.
- App lifecycle hooks call pause/resume. APNs/FCM are outside this implementation.

## First inspect the app

Find the existing dddart revision, event registry/serializers, event bus wiring,
poller/server endpoints, authentication provider, aggregate repositories and
deployment entrypoints. Useful search terms include `EventBusClient`,
`EventBusServer`, `EventRepository`, `raiseEvent`, `getUncommittedEvents`,
`markEventsAsCommitted`, `eventPublisher` and `getIdToken`.

Identify the actual game/match/room identity and membership rules, which events
originate on each side, and how events update or invalidate app state. Establish
a working two-session polling baseline before changing transport.

Inspect payload visibility carefully. Every subscriber on one aggregate channel
can receive the same payload. If the game's events contain player-private state,
choose appropriate narrower logical references or an authorized public payload.
Client-side filtering cannot make a shared-channel payload private. Surface any
model mismatch instead of silently broadcasting the aggregate's entire state.

Preserve the app's existing aggregate database unless another change is needed.
The new DynamoDB requirement is for **event history/channel metadata**; it does
not require moving all game aggregates to DynamoDB.

## Packages, versions and source map

Pin all dddart packages used by the app to one consistent revision. Do not mix
core/serialization from `main` with event packages from this PR. Regenerate
application code when upgrading the repository generators and serializers.

Follow the app's existing Git/path installation pattern and
[GIT_INSTALLATION.md](GIT_INSTALLATION.md). These packages are not published on
pub.dev. Some manifests retain hosted internal references, so the external app
may need root `dependency_overrides` for sibling packages. Record a minimal
reproducer if dependency resolution is a blocker; the isolated archive consumer
checks do not substitute for resolving this actual app's Git dependencies.

| Area | Public APIs / source |
| --- | --- |
| Core save/publication | `EventPublisher`, `saveWithEvents`, `EventPublishingRepository`, `PendingEventBatch`; optional `eventPublisher:` in InMemory and generated REST/DynamoDB/MongoDB/SQLite/MySQL repositories |
| Shared protocol/server | [`aggregate_event_service.dart`](../packages/dddart_events_distributed/lib/src/aggregate_event_service.dart): references to verified principals/policy, service, envelope publisher, channel repository and wire encoding |
| HTTP transport/routes | [`aggregate_event_transport.dart`](../packages/dddart_events_distributed/lib/src/aggregate_event_transport.dart): `AggregateEventHttpEndpoints`, `HttpAggregateEventTransport`, statuses and transport interfaces |
| Watch SDK | [`aggregate_event_client.dart`](../packages/dddart_events_distributed/lib/src/aggregate_event_client.dart): `AggregateEventClient`, `AggregateEventWatch` |
| Durable server storage | [`dynamo_event_repository.dart`](../packages/dddart_events_dynamodb/lib/src/dynamo_event_repository.dart): `DynamoAggregateEventRepository`, `DynamoEventChannelRepository` |
| AppSync socket | [`appsync_event_transport.dart`](../packages/dddart_events_appsync/lib/src/appsync_event_transport.dart): `AppSyncEventTransport` |
| Native Lambda adapters | [`appsync_event_handlers.dart`](../packages/dddart_events_appsync/lib/src/appsync_event_handlers.dart): `AppSyncEventHandlers`, optional authenticated `AppSyncHttpBridge` |
| Backend live relay | [`appsync_http_publisher.dart`](../packages/dddart_events_appsync/lib/src/appsync_http_publisher.dart): `AppSyncHttpPublisher`, `AppSyncIamAuthorization` |
| Shared authentication | `package:dddart_rest/credentials.dart`: `CredentialVerifier`, `JwtCredentialVerifier`, `TokenAuthenticationHandler`, `OAuthJwtAuthHandler` |

Clients need `dddart_events_distributed` and `dddart_events_appsync` alongside
their existing core/serialization packages. They do not need the DynamoDB event
adapter or the full REST server. Servers add `dddart_events_dynamodb` and reuse
`DynamoConnection.client` from `dddart_repository_dynamodb`.

## Suggested migration sequence

### 1. Wire one common server pipeline

Compose `AggregateEventService<AppClaims>` with the app's registry, authoritative
`AggregateEventPolicy<AppClaims>`, durable history and shared channel repository.
Implement `canSubscribe(principal, reference)` and `canPublish(principal, envelope)`
separately. Deny unrelated/unknown game access using verified identity and actual
membership, not a user ID supplied in the event payload.

Both HTTP and native AppSync handlers must use this service/policy. Register these
application-owned routes through `HttpServer.addRoute` and `buildHandler`:

| POST route | Handler |
| --- | --- |
| `/events/resolve` | `endpoints.resolve` |
| `/events/read` | `endpoints.read` |
| `/events/target` | `endpoints.target` |
| `/events/publish` | `endpoints.publish` |

`endpoints` is an `AggregateEventHttpEndpoints` with the same service and an
`EventAuthenticator<AppClaims>` backed by shared credential verification. These
routes remain necessary with AppSync for membership resolution, publication
targeting and retained recovery. Library construction opens no HTTP listener.

For server-originated events, use an `EnvelopeEventPublisher` that awaits
`service.accept(serverPrincipal, envelope)`, and inject it into the repository's
publication hook. Choose an explicit trusted server principal permitted by the
policy. Await saves/publication before returning from Lambda.

Use the service's `onEvent` for application processing that must be awaited;
handlers must tolerate retries. `localEventBus` delivery alone is an asynchronous
notification, not an awaited subscriber-processing guarantee.

### 2. Integrate the existing authentication and AWS deployment

Reuse the app's current token provider. HTTP verification and custom AppSync
authorization can call the same `verifyCredential` implementation. Custom JWTs
use the AWS Lambda authorizer; existing Cognito/OIDC can use native AWS identity
claims with matching backend verifier configuration.

Start from these concrete artifacts:

- [CloudFormation](../packages/dddart_events_appsync/deploy/cloudformation.yaml)
- [Dockerfile](../packages/dddart_events_appsync/deploy/Dockerfile)
- [Complete Dart Lambda Runtime API example](../packages/dddart_events_appsync/example/lambda.dart)
- [Finite native invocation example](../packages/dddart_events_appsync/example/native_invocation.dart)

The supplied image/entrypoint is a **reference app** registering `ExampleChanged`
and reading sample DynamoDB ACL rows. It is not already connected to Silly
Sentence Game. Adapt the registry, membership policy, domain processing and build
entrypoint to the app. Do not deploy the sample unchanged and expect it to accept
the app's event types or read its membership repositories.

The event table requires string `pk`/`sk` keys and numeric `expiresAt` TTL; an
existing aggregate table with a different schema is not interchangeable. Current
heads/channels survive payload expiration. Match IAM permissions to the actual
repositories used by the adapted policy; the sample authorizer role grants only
`GetItem` on the configured event table.

Record the chosen development account/region, stack/image revision, event HTTP
and realtime endpoints, control URL, namespace, table, auth mode, issuer/audience
and provider configuration. Use existing app deployment conventions for resource
creation and secret handling. Template/deploy/update/cleanup details are in the
main guide; new event tables are retained when the stack is deleted.

`AppSyncEventHandlers` has distinct authorizer, DIRECT subscribe and per-item
publish contracts. Its native identity/context is trusted only when AWS supplies
it. Do not expose a public HTTP route accepting arbitrary native invocation JSON.
The optional HTTP bridge requires its documented backend-only HMAC authentication.
The backend relay must allow only the configured trusted IAM role.

### 3. Add the new watch client, then switch its transport

First prove the new aggregate-watch HTTP path if helpful, then wrap its control
transport in AppSync. Keep a development transport selection for comparison.
Construct a fresh owned transport/client when switching modes; closing the client
also closes its transport and, for AppSync, its HTTP control transport.

The following is composition pseudocode using app-owned values, not a standalone
program:

```dart
final wire = AggregateEventWire(registry.identityCodecs);
final control = HttpAggregateEventTransport(
  baseUrl: controlUrl,
  wire: wire,
  tokenProvider: authProvider.getIdToken,
);
final AggregateEventTransport transport = useAppSync
    ? AppSyncEventTransport(
        httpEndpoint: eventHttpUrl,
        realtimeEndpoint: eventRealtimeUrl,
        namespace: namespace,
        control: control,
        wire: wire,
        authorization: () async => {
          'Authorization': (await authProvider.getIdToken())!,
        },
      )
    : control;
final client = AggregateEventClient(
  transport: transport,
  registry: registry,
  aggregateKind: kindForEvent, // Explicit stable application mapping.
);
final watch = client.watch(AggregateReference(kind: 'game', id: gameId));
final events = watch.events.listen(applyEvent);
await watch.ready;
// Inspect watch.status; ready also completes for denial/expiration.
```

Use one state-update path: direct watch listeners or the optional local bus, so
the app does not apply each delivery twice. Existing bus forwarding must not
re-publish received events. Choose one publication hook per save; do not retain
the old auto-forwarder alongside `eventPublisher: client.publisher` for the same
events. Explicit publication is `await client.publisher.publish(event)`.

The legacy timestamp `EventBusClient` is a separate API, not the HTTP variant of
this SDK. Old timestamp cursors cannot become new ingestion checkpoints. Define
stable kinds and preserve actual typed IDs, occurrence UUIDs and event type keys.

### 4. Connect state, membership changes and lifecycle

- A fresh watch starts at the server head. Establish it before an initial state
  fetch and buffer/reconcile events arriving during that fetch.
- Resume with the checkpoint belonging to that exact logical reference. Persist
  checkpoint and corresponding app state consistently; do not reuse a different
  game's cursor. Live events alone do not advance the history checkpoint.
- Handle `revoked` by stopping access to that game. Handle `resyncRequired` by
  closing the old lease, establishing a fresh watch and explicitly reloading
  aggregate state. The SDK does not replace application state for the app.
- Watch only the current game/other actively used aggregates. Dispose event/status
  stream subscriptions and watch leases on navigation; leases for the same
  reference share transport work without closing each other.
- Hook backgrounding to `client.pause()` and foregrounding to `client.resume()`.
  Dispose the client when its application/session scope ends.
- Update authoritative membership first, then publish an actual access-change
  event registered by `rotatesAccess`. Configure `broadcast`/`refresh` using the
  trusted backend relay. Do not copy the example's message-string discriminator
  instead of using the app's real event types.

## Acceptance tests on the actual app and AWS

Use at least two authorized sessions in one game plus an unrelated account/game.
Keep event UUIDs, logical references, source of delivery and redacted request/log
evidence so unexpected behavior can be reproduced.

| Scenario | Evidence to collect |
| --- | --- |
| Client-originated event | Normal repository save succeeds; separate event is durably accepted and the other session updates |
| Server-originated event | A short-lived invocation awaits acceptance; connected clients update even across different server instances |
| Actual push | Marker arrives through a WebSocket data frame; distinguish it from HTTP recovery, including automatic reconnect recovery |
| Authorization | Unrelated account/game receives no payload; subscribe and publish checks are independent; forged/wildcard/stale channels fail |
| Membership removal | Fresh random channel UUID, stable logical watch for remaining players, removed player revoked; retired channel receives only a generic hint after the processed rotation |
| Lost refresh hint | Authorized watch eventually resolves/rejoins through reconciliation or reconnect; the removed account remains denied |
| Offline/reconnect | Previously established checkpoint recovers accepted missed events; overlap does not multiply app side effects |
| Fresh watch | Existing history is not replayed as new activity; initial state fetch still yields correct game state |
| Expired history | Typed resync signal and deliberate state reload; use an aged test checkpoint or a suitably configured test backend rather than waiting seven days |
| Credential refresh | New HTTP/connection/subscribe/publish operations use current credentials; rejection does not leak another game's data |
| Background/navigation | Event subscriptions, timers and requests stop on pause/last-lease disposal; resume catches up; repeated navigation does not accumulate listeners |
| Publication failure | Already committed CRUD still succeeds, bounded failure is logged, unsuccessful/new pending events remain, and retries preserve the UUID |
| Unknown/malformed event | Controlled fixtures or differing client/server codec versions log/skip a valid envelope's undecodable payload and allow later events/checkpoints to progress |
| Idle network traffic | Compare equivalent active watch sets with old polling/new HTTP/AppSync; separate control reconciliation, WebSocket keepalives, app CRUD and recovery traffic |

Default HTTP-only polling is five seconds; AppSync reconciliation is one minute.
AppSync does not eliminate HTTP entirely. The SDK's UUID deduplication is bounded
(4,096 IDs per watch by default), and live delivery can be reordered. Do not turn
those explicit limits into exactly-once or ordering assertions.

Use ingestion/rotation milestones when assessing revocation: already in-flight
deliveries cannot be recalled, and loss of the trigger can delay rotation.

The [AWS smoke program](../packages/dddart_events_appsync/example/aws_smoke.dart)
requires `DDDART_RUN_AWS_SMOKE=true` and configured existing endpoints/token/game.
It publishes `ExampleChanged`, so use it with the reference deployment or adapt
its registry/event to this app. It creates no AWS infrastructure. A green smoke
result alone does not prove membership rotation or all failure paths, and delivery
must be attributed to live frames versus recovery when assessing push.

## Validation already performed, and how to repeat it

At implementation commit `11f4754`:

- `./scripts/test-all.sh --with-services` passed locally for all 17 public
  packages, 17 isolated archive consumers and 15 example projects. This includes
  required generation, fatal-info analysis, formatting and service-backed tests.
- Distributed-events tests: 117 passed. AppSync tests: 15 passed. DynamoDB event
  tests: eight passed, including six real DynamoDB Local scenarios.
- Existing JWT/OAuth regressions passed. Real local MongoDB/MySQL/DynamoDB
  repository suites and service examples passed.
- `cfn-lint` and deployment-contract fixtures passed. The complete Lambda runtime
  compiled to an AOT executable; native and opt-in AWS smoke entrypoints compiled.
- Native protocol/security tests use fixtures/local sockets, not live AWS.
- The full gate used a clean temporary Git snapshot because Pub checks clean
  tracked sources; hashes matched all 787 implementation source files.

GitHub Actions is disabled for dddart. Run checks locally rather than waiting for
CI. From the dddart workspace root:

```bash
dart pub get
./scripts/test-all.sh --with-services
```

The service-enabled command expects local MongoDB at 27017, DynamoDB Local at
8000, and MySQL `test_db` at 3307 (root / `test_password`). The temporary services
from the implementation run were stopped; do not assume they are still running.
Plain `./scripts/test-all.sh` follows the documented local exclusions for external
services. Follow the app project's own validation instructions for its changes.

## Feedback loop and completion evidence

Fix application wiring in the app and reusable behavior in dddart. For a framework
defect, capture a minimal reproducer and add a meaningful regression test near
the affected public API. Record the app/framework revisions, identity/event types,
expected and actual behavior, whether delivery was live or recovery, and relevant
sanitized AWS errors/logs. If the framework checkout is unavailable, leave an
actionable issue/reproduction instead of hiding the defect behind an app patch.

Keep fixes associated with dddart PR #65/the `appsync` work while that PR remains
open, coordinating any additional commits through the app project's available
repository workflow. Re-pin all dddart dependencies consistently after a fix.
Preserve the agreed contracts above; bring newly discovered contract questions
back to the owner rather than silently adding stronger or incompatible behavior.

The useful handback is an app migration diff plus reproducible deployment/test
instructions, the exact tested revisions/configuration, observed live AWS results,
framework regressions/fixes, idle traffic observations and any remaining gaps.
