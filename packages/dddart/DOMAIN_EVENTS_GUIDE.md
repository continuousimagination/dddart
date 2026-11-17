# Domain events and safe publication

A domain event describes a completed domain action. Extend `DomainEvent<I>` with
the aggregate's concrete identity type. The event's occurrence ID remains a UUID.
Keep event fields and context values immutable and avoid secrets in event payloads.
An aggregate raises events during business operations; raising does not persist or
publish them.

## Run a complete example

The [core quickstart](../../docs/quickstarts/core/README.md) includes the model,
manifest and finite program. The [core samples](example/README.md) cover multiple
listeners, event JSON, failures, logging and conditional writes. Distributed
HTTP polling and AppSync use the [shared transport contract](../../docs/DISTRIBUTED_EVENTS.md).

## Persistence and acknowledgment

Capture the pending batch **before the first await**, persist the aggregate, then
publish only that captured batch. Acknowledge an occurrence only after the
publisher accepts it. Events raised while persistence or publication is in flight
must remain pending for a later operation. A failed save must publish nothing;
a failed publication must retain its pending occurrence for retry.

Generated repositories and the in-memory repository accept an optional
`eventPublisher`. A custom basic repository can be wrapped in
[EventPublishingRepository](lib/src/event_publishing_repository.dart).
The separate core `saveWithEvents` helper applies the same captured-batch lifecycle. Do not wrap
a repository already configured to publish events, because two publication owners
can duplicate delivery. The wrapper exposes basic CRUD and does not automatically
forward an underlying repository's optional conditional capability.

For SQL repositories, publication associated with an outer transaction waits for
confirmed commit and runs after its locks are released. Rollback discards that
post-commit publication. Conditional operations own their commit; see
[transaction and uncertainty rules](../../docs/CONDITIONAL_WRITES.md).

`getUncommittedEvents()` is useful for inspection. Calling
`markEventsAsCommitted()` without a captured batch clears all current events and
is unsuitable after asynchronous work. Prefer the captured batch's
`acknowledge(event)`/`acknowledgeAll()` methods or pass the batch explicitly.

## Listener lifecycle and failures

`EventBus.on<EventType>()` returns a broadcast stream. Subscribe before publishing;
there is no replay for late subscribers. Keep subscription handles and cancel them
when their owner is disposed. Await `close()` when shutting down the bus.
`publish` returning does not mean asynchronous listeners completed; wait for an
application-owned completion signal when completion matters.

Handle failures inside asynchronous listeners. The bus is not a transaction
coordinator, retry queue or compensation engine. Model retries and compensating
actions in the application and make external side effects idempotent where needed.
Remote receipt uses `deliver`, which avoids the outbound `onPublished` stream;
republishing received events can create an echo loop.

## Serialization and remote delivery

Use the [JSON workflow](../../docs/quickstarts/json/README.md) for generated
serialization and the [distributed registry guide](../dddart_events_distributed/README.md#generate-event-serializers-and-registrations)
for generated event factories and stable wire keys. Identity codecs preserve
kind and scope; do not replace a typed ID with `toString()` at a storage boundary.

[Distributed events](../../docs/DISTRIBUTED_EVENTS.md) documents acceptance,
checkpoint catch-up, retention, authorization and bounded retries. Polling and
AppSync implement the shared transport interfaces. Persistence, event acceptance,
and durable consumer processing are separate steps.
