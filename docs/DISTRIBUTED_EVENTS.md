# Aggregate events and AppSync implementation

This guide records the approved design and the functionality available so far.
The implementation is tracked by [#54](https://github.com/continuousimagination/dddart/issues/54)
and its linked issues. DDDart remains pre-release; contract changes are allowed.
Coherent public contracts and client/server symmetry take priority over reducing
the number of requests.

## Implementation status

| Area | Available in this change | Remaining work |
| --- | --- | --- |
| Aggregate saves | Optional publisher in InMemory and generated DynamoDB, MongoDB, REST, SQLite and MySQL repositories; safe captured batches | Further cross-transport integration tests in #64 |
| Publication | Awaitable publisher, shared bounded retries and named logging; legacy HTTP client publisher | AppSync transport in #60 |
| Remote delivery | Origin-aware local bus prevents automatic forwarding of received events | Aggregate watch orchestration in #59 and #60 |
| Retained history | Logical aggregate references, separate event envelopes, ingestion checkpoints, paginated InMemory history | Durable DynamoDB history and shared channel metadata in #57 |
| Access and lifecycle | Approved contracts below | Shared authentication #58, watches #59, authorization and rotation #61 |
| Deployment | No AWS resources created | CloudFormation template in #62 |

The existing timestamp HTTP polling API remains available. It has **not** been
migrated to the new history/watch protocol yet. In particular, it does not gain
aggregate watches, retention-gap recovery, background pause/resume, or the new
malformed-payload skip policy simply by using these foundation types. The
AppSync package and its deployment template are not available yet.

## Saving aggregates and publishing events

Domain code raises events through `aggregate.raiseEvent(event)`. An event-enabled
repository captures the pending batch before awaiting persistence, saves the
aggregate, then awaits attempts to publish that batch. Failed CRUD propagates
without publishing or acknowledging any captured events.

```dart
final orders = OrderRestRepository(
  restConnection,
  eventPublisher: eventClient.publisher,
);
await orders.save(order);
```

`OrderRestRepository` represents an application-generated repository.
`eventClient` can currently be an `EventBusClient`; its `publisher` sends a
separate event POST and returns only after acceptance or bounded failure. A
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
The legacy HTTP publisher retries network failures, HTTP 408, 429 and 5xx.

Retries preserve the same occurrence UUID. A timeout bounds the caller's wait;
it does not prove a remote operation was cancelled. Stores must handle uncertain
acceptance idempotently. Final failure is logged with the occurrence ID and leaves
the event pending, but an already successful aggregate save still succeeds.
Aggregate persistence and event acceptance are separate operations. There is no
transactional outbox or guarantee for an event never durably accepted, including
when a short-lived server terminates before acceptance.

Lambda handlers should await `repository.save` or `publisher.publish` before
returning. Legacy `EventBus.publish` and auto-forward listeners are asynchronous
local notifications and do not provide that serverless lifecycle guarantee.

## Safe pending-event acknowledgment

`getUncommittedEvents()` returns a read-only snapshot. Infrastructure doing
asynchronous work should capture a `PendingEventBatch` before the first await:

```dart
final batch = order.captureUncommittedEvents();
await persistOrder(order);
for (final event in batch.events) {
  if (await publisher.publish(event)) batch.acknowledge(event);
}
```

Prefer `saveWithEvents` in repository implementations; it also catches and logs
unexpected publisher exceptions after persistence. Acknowledgment removes only
the captured raise of the exact event instance. Failed events and events raised
while saving remain pending, even if an event object or UUID is reused. Overlapping
captures may publish duplicates, so infrastructure must still deduplicate by
occurrence ID. Acknowledgment does not mutate event payloads.

`markEventsAsCommitted(batch: batch)` acknowledges a complete captured batch.
The legacy no-argument form immediately clears the current queue; do not use it
after an await, where it could erase newly raised events.

## Local delivery and logging

`EventBus.publish(event)` originates a local event. `EventBus.deliver(event)` is
for transport adapters delivering an event already received or accepted elsewhere.
Application subscribers use `on<E>()` for both. Forwarding/persistence bridges use
`onPublished<E>()` and only observe local publication. Origin is per delivery and
never inferred from the event UUID or added to the event's domain payload.

`EventBus(logger: logger)`, `EventBusClient(logger: logger)` and
`RetryingEventPublisher(logger: logger)` accept application loggers. Their public
`logger` properties expose the configured logger; defaults are named loggers
`dddart.eventbus`, `dddart.events.client` and `dddart.events.publisher`. Configure
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
bounded paginated `read` and ingestion-time cleanup. The current
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
contract. The planned SDK warns and skips unknown types, logs and skips malformed
known payloads, and advances the valid transport checkpoint. Applications are
responsible for keeping clients updated.

## Approved watch, authorization and rotation design

Both transports will use explicit watches on logical aggregates. Access and
current interest are separate: two players watch their own Game; a document user
watches the documents currently open rather than every document they can access;
all players can watch the same daily Puzzle. Payloads on a shared channel must
be appropriate for every authorized subscriber to that aggregate.

A shared verified-principal and aggregate policy will authorize subscribe and
publish separately. Subscription resolution, HTTP catch-up and AppSync handlers
must use the same policy, denying unauthorized logical references, wildcards and
stale physical channels. Clients keep existing dddart JWT authentication or use
optional Cognito/OIDC; Cognito, Amplify and client-held AWS credentials are not
mandatory. Credential verification will be extracted from the Shelf request
adapter so Lambda invocations can use it directly.

AppSync adapters will accept app-owned repositories and policies. Direct Lambda
authorization/subscription invocations do not require a Dart HTTP listener.
Optional authenticated HTTP handlers can be added to an application-owned server.
Library initialization will not start a server or deploy AWS resources implicitly.

Applications register access-change events such as `PlayerRemoved` to trigger
rotation. On processing that event the server assigns a fresh random channel UUID
and persists the shared mapping. Versions do not increment. Later publications
resolve the new mapping, preventing the removed player's old subscription from
receiving later aggregate payloads. The logical watch remains stable.

Authorized clients receive a refresh control hint, resolve and reauthorize the
watch, subscribe to the replacement channel and catch up. A denied watch emits
an access-revoked result and stops only that watch. Reconnection and occasional
batched reconciliation recover missed hints. Access-change processing is initially
best effort: losing the trigger event can delay revocation. Immediate atomic
revocation and automatic permission-field fingerprinting are deferred.

Clients will pause subscriptions while backgrounded through platform-neutral
pause/resume APIs, then reconnect, reauthorize and catch up on resume. APNs/FCM
background notification support is outside this first implementation.

## Deployment and migration work still to complete

The initial production history and channel-metadata adapter will use DynamoDB;
other database event stores are deferred. Clients retain watches/checkpoints and
do not need their own event database. CloudFormation will describe AppSync Events,
DynamoDB retention, Lambda integration/permissions and authentication configuration.
It will not assume an AWS-managed Dart Lambda runtime or deploy automatically.

The existing timestamp `EventRepository` and the new `AggregateEventRepository`
are distinct APIs during this implementation. Existing subscriptions do not
automatically acquire logical kind information. Migration must define those
kinds explicitly, preserve occurrence UUIDs and registered identity/event tags,
and establish fresh watches deliberately. The aggregate watch protocol, AppSync
transport, credentials refactor, deployment examples and final migration guide
remain tracked in #57–#64.
