# Aggregate events, HTTP polling and AppSync Events

DDDart supports explicit aggregate watches through independent HTTP polling or
AWS AppSync Events. Both use the same publication envelope, retained history,
authorization policy and client lifecycle. Aggregate CRUD carries only public
state; pending events use a separate public event contract.

| Package | Responsibility |
| --- | --- |
| `dddart` | Pending event capture, repository publication hooks, local bus |
| `dddart_events_distributed` | References/codecs, history contracts, InMemory history/channels, HTTP endpoints and transport, shared watch SDK and retrying publisher |
| `dddart_events_dynamodb` | Server-side durable history and shared random channel mappings, using the existing DynamoDB connection |
| `dddart_events_appsync` | Optional live transport, native Lambda handlers, trusted backend relay, CloudFormation and custom-runtime example |
| `dddart_rest` | Existing built-in/OAuth token verification shared with native handlers |

Only servers need the DynamoDB event repository. Clients retain watch checkpoints
and use their existing authentication provider. InMemory history/channel stores
are instance-local test backends. Production Lambda invocations share DynamoDB;
constructing an adapter starts no listener, worker or infrastructure deployment.

Both transports implement `AggregateEventTransport` and use `AggregateEventClient`.
The [finite HTTP-only example](../packages/dddart_events_distributed/example/http_polling.dart)
starts a local server, publishes an event, receives it by polling and closes its
resources. Run it with `dart run packages/dddart_events_distributed/example/http_polling.dart`.
It requires neither the AppSync package nor AWS setup.

## Saving aggregates and publishing events

Domain code raises events through `aggregate.raiseEvent(event)`. An event-enabled
repository captures the pending batch before awaiting persistence, saves the
aggregate, then awaits attempts to publish that batch. Failed CRUD propagates
without publishing or acknowledging any captured events.

The [repository publication example](../packages/dddart/example/event_publication.dart) exercises persistence, acceptance and retained pending events. Generated repository constructors accept `eventPublisher: eventClient.publisher`.

`eventClient` is an `AggregateEventClient`; its `publisher` sends a separate
publication and returns only after acceptance or bounded failure. A
database repository accepts the same optional `eventPublisher` constructor
argument. Custom subclasses of generated repository bases must forward that
argument if they expose publication configuration.

REST aggregate requests contain only their public serialized representation.
Pending events are transient infrastructure bookkeeping, never aggregate JSON,
hidden headers, or fields added to an aggregate's public contract. A server
deserializing the posted aggregate therefore does not inherit the client's
private event queue. Server domain logic can raise and publish its own events.

Custom repositories can call the core `saveWithEvents` helper around their actual
persistence operation, preserving custom query interfaces. A basic CRUD repository
can instead use `EventPublishingRepository<T, I>`. Configure one publication hook
for a save; do not wrap an already event-enabled repository or also send the same
event through an auto-forwarding bus.

`EventPublisher.publish` returns `true` for acceptance and `false` for a logged
failure. Distributed implementations must acknowledge durable acceptance, not
successful processing by subscribers. The shared `RetryingEventPublisher` owns
retry policy: three attempts by default, exponential backoff with 20% jitter,
100 ms initial delay, one-second maximum delay, two-second attempt timeout and
six-second total waiting budget. The policy is configurable. Only classified
transient failures retry; authentication, validation and programming errors stop.
The shared HTTP publisher retries network failures, HTTP 408, 429 and 5xx.

Retries preserve the same occurrence UUID. A timeout bounds the caller's wait;
it does not prove a remote operation was cancelled. Stores must handle uncertain
acceptance idempotently. Final failure is logged with the occurrence ID and leaves
the event pending, but an already successful aggregate save still succeeds.
Aggregate persistence and event acceptance are separate operations. There is no
transactional outbox or guarantee for an event never durably accepted, including
when a short-lived server terminates before acceptance.

Lambda handlers should await `repository.save` or `publisher.publish` before
returning. `EventBus.publish` and application-owned listeners are asynchronous
local notifications and do not provide that serverless lifecycle guarantee.

## Safe pending-event acknowledgment

`getUncommittedEvents()` returns a read-only snapshot. Infrastructure doing
asynchronous work should capture a `PendingEventBatch` before the first await:

The [core event guide](../packages/dddart/DOMAIN_EVENTS_GUIDE.md) explains capture and acknowledgment. The [publication example](../packages/dddart/example/event_publication.dart) and [helper implementation](../packages/dddart/lib/src/save_with_events.dart) show the complete behavior.

Prefer `saveWithEvents` in repository implementations; it also catches and logs
unexpected publisher exceptions after persistence. Acknowledgment removes only
the captured raise of the exact event instance. Failed events and events raised
while saving remain pending, even if an event object or UUID is reused. Overlapping
captures may publish duplicates, so infrastructure must still deduplicate by
occurrence ID. Acknowledgment does not mutate event payloads.

`markEventsAsCommitted(batch: batch)` acknowledges a complete captured batch.
The no-argument form immediately clears the current queue; do not use it
after an await, where it could erase newly raised events.

## Local delivery and logging

`EventBus.publish(event)` originates a local event. `EventBus.deliver(event)` is
for transport adapters delivering an event already received or accepted elsewhere.
Application subscribers use `on<E>()` for both. Forwarding/persistence bridges use
`onPublished<E>()` and only observe local publication. Origin is per delivery and
never inferred from the event UUID or added to the event's domain payload.

`EventBus(logger: logger)`, `AggregateEventClient(logger: logger)` and
`RetryingEventPublisher(logger: logger)` accept application loggers. Their public
`logger` properties expose the configured logger; defaults are named loggers
`dddart.eventbus`, `dddart.events.watches` and `dddart.events.publisher`. Configure
the standard `logging` package's level and sinks to collect records.

## Logical references and retained history

`AggregateReference<I>` identifies one stream with an explicit stable aggregate
kind and its typed scoped identity. The kind is a public discriminator such as
`game`, independent of a Dart class name. The identity uses the same explicit
`IdentityCodecRegistry` as the existing serializers. Canonical logical keys encode
the aggregate kind, registered identity tag and canonical identity key separately;
case and application scope are preserved. Adapters must respect backend limits
without truncating or otherwise collapsing distinct logical references.

`EventEnvelope` version 1 combines this reference with `StoredEvent<Identity>`.
The stored record keeps the event's UUID, occurrence time, stable event-type key
and serialized payload. Its aggregate identity must agree with the reference.
This publication envelope is a separate contract from aggregate CRUD JSON.

`AggregateEventRepository` implements ordinary
`Repository<EventEnvelope, UuidValue>` operations and adds `append`, `head`,
bounded paginated `read` and ingestion-time cleanup.
`InMemoryAggregateEventRepository` implements it for tests and local apps. It
supports injected time and defaults to seven-day retention. It is instance-local
and unsuitable for sharing history between serverless invocations.

`append` returns a `RecordedEvent` with server ingestion time and a committed
position within the logical stream. The head and record become visible together;
a reserved counter followed by a delayed insertion would allow a consumer to
skip that insertion and does not satisfy the contract. Retained duplicate UUIDs
with equivalent JSON content return the original record. Conflicting reuse is
rejected. Retry identity is guaranteed within retained history; expiration is not
a permanent deduplication ledger.

A fresh watch obtains `head` and starts there, without replaying prior history.
A reconnect uses its saved per-aggregate `EventCheckpoint`. Checkpoints describe
server progress and are opaque when encoded for transport. They never grant
permission; the server must authorize the logical aggregate separately.
`read` returns ingestion-ordered pages, a checkpoint and `hasMore`. Occurrence
timestamps do not determine progress. Recovery anchors renew only after complete
catch-up, so paging cannot conceal expiration of still-unread records.

Expired or deliberately deleted required history produces `EventHistoryExpired`.
The application must reload state through its repository and establish a fresh
watch. The SDK must not silently replace application state. Live delivery may
duplicate or reorder events; there is no exactly-once or handler acknowledgment
contract. The SDK warns and skips unknown types, logs and skips malformed
known payloads, and advances the valid transport checkpoint. Applications are
responsible for keeping clients updated.

## Watches and application lifecycle

Supply an `EventRegistry` with stable event keys and explicit identity codecs.
The [distributed package README](../packages/dddart_events_distributed/README.md)
shows generated serializers/registrations; the
[example wire contract](../packages/dddart_events_appsync/example/lib/example_domain.dart)
shows equivalent manual registration.

The [complete HTTP client/server program](../packages/dddart_events_distributed/example/http_polling.dart) builds the registry, transport, watch and publication and checks the delivered event.

Applications own the registry, credential callback, identities, policies and handlers.
`ready` means the initial bounded synchronization finished; inspect `status` for
denial/expiration and use later checkpoints if a long backlog needs more pages.
Keep a checkpoint **per logical reference**, store it with the application's
local state, and pass it back as `client.watch(game, checkpoint: saved)` to resume.

Establish a fresh watch before fetching initial state through a repository, and
buffer/reconcile events arriving during that fetch. This avoids a gap between an
initial fetch and watch establishment; application state/event merging remains
application logic. After `resyncRequired`, close the old lease, establish a fresh
watch and reload the aggregate explicitly. Never silently discard local state.

Multiple calls for the same reference share one underlying watch. Closing one
lease does not close another. A conflicting checkpoint for an active reference
is rejected. `revoked` and `resyncRequired` stop that watch independently; close
its lease before establishing a new watch. Dispose application stream listeners
as well as watch leases:

Await `client.pause()` on backgrounding and `client.resume()` on return. Cancel each stream subscription, await `watch.close()` for a lease, and finally await `client.close()`.

There is one single-flight batched HTTP operation for active references, rather
than one timer per aggregate. HTTP-only clients poll every five seconds by
default; live clients reconcile once per minute. Both intervals are configurable.
Pause/resume is platform-neutral; the application connects Flutter or other
lifecycle hooks. Foreground push does not imply APNs/FCM background notifications.

Examples of interest versus access:

For a two-player game, watch that match reference; for a document editor, watch only the currently open documents; for a daily puzzle, many authorized players may watch the same puzzle reference.

The server policy checks game participants, document ACLs or puzzle availability
using authoritative domain repositories. A shared channel's payload must be
appropriate for every authorized subscriber; interest does not grant permission.

## Shared server and credential verification

Implement `AggregateEventPolicy<C>.canSubscribe(principal, reference)` and
`canPublish(principal, envelope)` separately. Clients that can publish need not
have subscribe rights. Recheck current access on resolution, catch-up, native
subscription and publication. Never authorize from a client-supplied user ID.

`CredentialVerifier<C>.verifyCredential(token)` returns the same typed
`AuthenticationResult<C>` used by HTTP authentication. `JwtAuthHandler` and
`OAuthJwtAuthHandler` expose it through `TokenAuthenticationHandler`, preserving
HTTP authentication and issuance/refresh APIs. A native handler can use the
standalone `JwtCredentialVerifier` without creating a refresh-token repository:

The [native reference bootstrap](../packages/dddart_events_appsync/example/lambda.dart) configures the credential verifier and converts verified authentication results into event principals.

Use `OAuthJwtAuthHandler` with the existing provider's issuer, audience and JWKS
URI for Cognito/OIDC. Signature, issuer, audience, expiry and subject validation
remain mandatory in configured production examples. Narrow
`package:dddart_rest/credentials.dart` and `package:dddart_rest/http.dart` exports
allow standalone runtimes to avoid unrelated generated token-model libraries.

Compose `AggregateEventService<C>` with history, shared channels, registry and
policy. `accept` validates the typed event, durably appends it, awaits registered
rotation and `onEvent` processing, delivers to the optional local bus, and relays
live data. A retry can re-invoke `onEvent`/local subscribers; handlers needing
idempotence must enforce it themselves. Durable UUID deduplication is not a
consumer-processing acknowledgment. Await service/repository publication before
returning from Lambda.

`EnvelopeEventPublisher(registry: registry, aggregateKind: kindForEvent,
send: (envelope) async { await service.accept(serverPrincipal, envelope); })`
provides the server's matching `EventPublisher`. Use an explicit trusted server
principal and policy; do not bypass authorization through client-provided claims.

For an existing application-owned server:

The [finite HTTP program](../packages/dddart_events_distributed/example/http_polling.dart) registers all four handlers. In a DDDart `HttpServer`, use `addRoute` for each POST path and `buildHandler()` to let an existing host own the listener.

Resolve/read batch references and checkpoints; publish accepts the separate
versioned envelope; target checks publish rights before giving a current physical
channel. Bearer authentication is required on every route. Default budgets are
100 watches, 10 events per aggregate/page, 200 events and 4 MiB per response, and
1 MiB per request. Remaining watches are deferred with their original checkpoints.
The SDK prioritizes deferred watches and processes at most 10 pages per sync;
later intervals continue recovery. Canonical publication envelopes are limited
to 230 KiB, leaving room for the transport wrapper. Large identities must still
fit backend/request budgets; no identity is silently truncated.

## AppSync transport and native handlers

The [complete AppSync smoke client](../packages/dddart_events_appsync/example/aws_smoke.dart) constructs the live transport and HTTP control transport with one registry and current-token callback. Its run requires the explicit deployment setup below.

One `aws-appsync-event-ws` connection multiplexes watches, waits for connection
and subscription acknowledgments, monitors keepalive deadlines and reconnects
with bounded backoff/jitter. Each connection, subscription and publication asks
for current authorization. It reconnects before AWS's 24-hour connection limit.
Live delivery never advances the retained-history checkpoint, so reordered frames
cannot skip recovery. Each watch keeps at most 4,096 UUIDs for overlap deduplication
by default; duplicates outside that window remain possible. Receipt uses local
`deliver`, so it cannot echo through a publication bridge.

Physical paths are `/<namespace>/<random-uuid>`. Full typed logical references
live in the server mapping rather than squeezing scoped IDs into AWS channel
segments. Only exact current IDs are allowed; wildcards, unknown IDs and retired
channels fail authorization. The namespace follows AWS's 1–50 alphanumeric/hyphen
constraint, with alphanumeric ends.

`AppSyncEventHandlers<C>` implements three distinct native contracts:

| Method | AWS input and result |
| --- | --- |
| `authorize` | Raw custom token plus EVENT_CONNECT/SUBSCRIBE/PUBLISH context; returns `isAuthorized`, flat verified `handlerContext`, `ttlOverride: 0` |
| `onSubscribe` | DIRECT SUBSCRIBE invocation and verified identity; returns `null` on success or an error |
| `onPublish` | DIRECT PUBLISH invocation, current channel and up to five stringified event items; returns per-item accepted payloads/errors |

Native Cognito/OIDC modes use AWS-verified claims and enforce configured issuer,
audience, expiry and subject constraints. Custom tokens use the shared verifier.
AppSync handler context is trusted only on native invocations, never as claims
submitted through a public HTTP body. `AppSyncHttpPublisher` relays committed
records/refresh hints using `AppSyncIamAuthorization` and fresh backend SigV4
credentials; the handler's injected `trustedRelay` must allow only that backend
IAM identity. Normal clients cannot fabricate committed records or control hints.

The optional `AppSyncHttpBridge` is for an application-owned backend integration,
not a mobile endpoint. It requires a private secret of at least 32 characters,
`x-dddart-appsync-time` (Unix seconds)/`x-dddart-appsync-signature` HMAC-SHA256 over timestamp, request path
and exact body, and a 30-second freshness window. See its API/tests for the exact
signing format. Configure TLS and keep the secret in backend deployment storage.
Direct Lambda integration needs neither this bridge nor an HTTP listener.

## Access changes and random channel rotation

Register `rotatesAccess: (event) => event is PlayerRemoved` (and other application
access-change types) on the service. Update authoritative membership first, then
publish the trigger. Handling it assigns a fresh random UUID and persists the
mapping/trigger result; repeated triggers do not increment or rotate it again
within the deduplication retention window. Later publication resolves the current
mapping. The retired channel receives only a generic refresh hint, including when
the triggering event was published on that channel. Its domain payload is routed
to the new channel. Logical history and checkpoints do not change.

The SDK receives the hint, resolves/reauthorizes, joins the replacement channel,
and merges retained catch-up behind the existing watch stream. A removed player
gets `revoked`; other watches continue. Reconnection, resume and periodic batch
reconciliation recover missed hints. Old physical subscriptions may remain open;
they do not authorize access to the replacement channel.

Revocation is **best effort and event-driven**. Losing the trigger can delay it;
membership changes and rotation are not atomic, and already in-flight deliveries
cannot be recalled. Immediate revocation, automatic permission fingerprinting,
strict live ordering and transactional outbox delivery are deferred.

## DynamoDB schema and retention

Inject `DynamoAggregateEventRepository` and `DynamoEventChannelRepository` using
`DynamoConnection.client`, the table name and the same identity registry. The
table has string `pk`/`sk` keys and numeric `expiresAt` TTL. No index is required:

| Partition / sort key | Content |
| --- | --- |
| `s#<sha256(logical)>` / `head` | Durable committed head, full logical key and recovery floor |
| Same stream partition / `p#<20-digit-position>` | Envelope, digest, ingestion time/position, TTL |
| `e#<occurrence-uuid>` / `id` | Retained global UUID lookup and canonical content digest |
| `m#s#<sha256(logical)>` / `state` | Durable current channel mapping |
| `c#<channel-uuid>` / `current` | Reverse current-channel lookup |
| `r#<trigger-uuid>` / `rotation` | Idempotent previous/current rotation result and TTL |

Append atomically updates the head and writes both record/UUID lookup with
conditional transactions. Uncertain successful requests can be retried safely;
conflicting UUID content is rejected. Reads use consistent aggregate-partition
queries and preserve progress at DynamoDB byte/page boundaries. The stored full
logical key detects digest collisions. Normal reads/appends/resolution do not
scan the table. Explicit `deleteOlderThan` is an administrative maintenance scan;
deletion advances a durable recovery floor.

History and rotation deduplication each default to seven days and are configurable.
Reads enforce expiry despite delayed physical TTL deletion. Heads/current mappings
do not expire. Replaying an old trigger after its retained deduplication window
may cause another safe random rotation; UUID history is not a permanent ledger.

## Build and deploy the reference application

The [CloudFormation template](../packages/dddart_events_appsync/deploy/cloudformation.yaml)
uses AppSync **Events**, DIRECT REQUEST_RESPONSE Lambda handlers and optional
custom/Cognito/OIDC authentication. The complete
[custom runtime](../packages/dddart_events_appsync/example/lambda.dart) awaits
invocation processing and adapts Function URL requests to the same Shelf routes.
It uses a DynamoDB-backed **example** ACL policy; replace that policy with domain
repositories for a production application. Constructors never deploy resources.

The following are explicit operator deployment steps, not actions performed by
package initialization or local tests. Use a chosen AWS account/region, an existing
ECR repository and current AWS CLI/Docker credentials. For built-in JWTs, first
create an existing Secrets Manager JSON secret containing a `jwtSecret` string
matching the application's issuer. Supply the ARN without printing the secret.

```bash
# From the workspace root. IMAGE_URI points at an ECR repository:unique-tag.
aws ecr get-login-password --region "$AWS_REGION" | \
  docker login --username AWS --password-stdin "$ECR_REGISTRY"
docker buildx build --platform linux/amd64 --push -t "$IMAGE_URI" \
  -f packages/dddart_events_appsync/deploy/Dockerfile .
aws cloudformation deploy --region "$AWS_REGION" \
  --stack-name dddart-events \
  --template-file packages/dddart_events_appsync/deploy/cloudformation.yaml \
  --capabilities CAPABILITY_IAM \
  --parameter-overrides ImageUri="$IMAGE_URI" AuthMode=AWS_LAMBDA \
    JwtSecretArn="$JWT_SECRET_ARN" TokenIssuer="$TOKEN_ISSUER" \
    TokenAudience="$TOKEN_AUDIENCE" AllowedOrigins="$APP_ORIGIN"
aws cloudformation describe-stacks --region "$AWS_REGION" \
  --stack-name dddart-events --query 'Stacks[0].Outputs'
```

The image uses Dart AOT and Lambda's provided AL2023 base, rather than assuming an
AWS-managed Dart runtime. Update with a fresh image tag through the same deploy
command. A secret-value update also needs a Lambda configuration/stack update to
refresh the resolved environment value; publishing into Secrets Manager alone
does not replace a warm runtime's environment.

Set `AuthMode=AMAZON_COGNITO_USER_POOLS`, `CognitoUserPoolId`, `CognitoRegion`,
`TokenIssuer`, `TokenAudience`, and `NativeJwksUri` for an existing Cognito pool.
For OIDC, set `AuthMode=OPENID_CONNECT` with issuer, audience and JWKS URI. No pool
is created. Clients use the same appropriate ID token for HTTP and AppSync.

Optional `ExistingTableName` must match the schema/TTL above. Default
`RetentionDays=7` configures both payload and rotation retention. Default
`CreateControlUrl=true` creates a Function URL whose routes require application
Bearer authentication. Set it to false and supply `ExistingControlBaseUrl` when
registering the routes on your own server. Outputs include event HTTP/realtime
endpoints, namespace, table, control URL, handler ARN and backend relay role;
signing secrets are never outputs.

To authorize the reference application's smoke aggregate, an operator writes an
ACL item in the output table: `pk = 'acl#' + reference.toKey(registry.identityCodecs)`,
`sk = 'acl'`, `subscribers` and `publishers` are DynamoDB String Sets of verified
token subject IDs. The full example is deny-by-default. Compute that key with the
public `AggregateReference.toKey` API, never a hand-invented UUID encoding.
Update ACLs before publishing `ExampleChanged(message: 'access-changed', ...)` to
exercise the example's registered rotation trigger. Regular events use another
message value. This ACL schema is application example data, not a core contract.

After configuring an existing deployment/ACL/token, explicitly opt in to the
finite [AWS smoke program](../packages/dddart_events_appsync/example/aws_smoke.dart):

```bash
export DDDART_RUN_AWS_SMOKE=true
# Set DDDART_CONTROL_URL, DDDART_EVENT_HTTP, DDDART_EVENT_REALTIME,
# DDDART_TOKEN, DDDART_AGGREGATE_ID, and optionally DDDART_NAMESPACE /
# DDDART_AGGREGATE_KIND (defaults: aggregates / game).
dart run packages/dddart_events_appsync/example/aws_smoke.dart
```

It watches an authorized aggregate, publishes one occurrence, waits for live
delivery, then closes resources. It creates no AWS infrastructure. Do not point
it at an aggregate where that example event would be inappropriate.

Delete the stack with `aws cloudformation delete-stack --stack-name dddart-events`
in the chosen region. **New event tables are retained** on deletion/replacement;
record their output names beforehand and explicitly remove retained tables/data
only when no longer needed. Existing tables, signing secrets, Cognito/OIDC
providers and ECR repositories/images remain operator-owned. Removing the stack
does not automatically remove them.

## Validation and limits

Local checks include real serialized WebSocket protocol fixtures, native Lambda
authorization/handler fixtures, shared real JWT verification, HMAC bridge/SigV4
tests, and isolated DynamoDB Local transactions/concurrency/TTL tests. Protocol
fakes are not a live AWS service test. The template is checked with `cfn-lint`
and schema-contract tests; the runtime and opt-in smoke programs are compiled.
No live AWS deployment or smoke pass is claimed by these local checks.

Run `dart pub get` at the workspace root. `./scripts/test-all.sh --with-services`
enables the full local service-backed gate with MongoDB at 27017, DynamoDB Local
at 8000 and MySQL test_db at 3307 (root/test_password). It covers all packages,
generation, analyzer/formatter, tests, isolated archive consumers and examples.
The plain command excludes documented external service tests. GitHub Actions
is optional; this work is validated locally. Service tests use isolated resources.

Both supported transports use ingestion checkpoints and the shared watch API.
Watches warn/skip unknown types and error/skip malformed known payloads while
advancing valid history progress. Other persistent event backends, APNs/FCM,
atomic revocation/outbox delivery, strict live ordering and consumer acknowledgments
remain outside this first release. 1.0 is the first compatibility baseline; no
historical timestamp-cursor conversion or prerelease migration layer is supplied.
