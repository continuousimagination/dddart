# Publish and watch aggregate events

Use `AggregateEventClient` with an `AggregateEventTransport` to publish events
and follow changes to a typed aggregate. The
[HTTP polling example](../packages/dddart_events_distributed/README.md#run-an-http-only-publishwatch-example)
runs end to end on loopback. The [AppSync adapter](../packages/dddart_events_appsync/README.md)
adds live delivery using the same client and publisher interfaces. Neither
transport is required for the [local event bus](../packages/dddart/DOMAIN_EVENTS_GUIDE.md).

## Deliver locally

The [order quickstart](quickstarts/core/README.md) publishes through an
in-process event bus after saving. Subscribe before publishing and close the
bus at shutdown. The [local event guide](../packages/dddart/DOMAIN_EVENTS_GUIDE.md)
explains how to keep rejected or later occurrences pending.

## Prepare the event contract

- Identify a stream with an `AggregateReference<I>`: a stable aggregate kind
  such as `reservation` and the aggregate's concrete ID. Register a canonical
  codec for each custom identity so scope and type are preserved.
- Keep an `EventRegistry` on each participating client and server. Use a stable
  event-type key and preserve the event's occurrence ID, timestamp, and
  context. Follow [registry generation](../packages/dddart_events_distributed/README.md#generate-event-serializers-and-registrations)
  or see the [manual registry](../packages/dddart_events_distributed/example/http_polling.dart).
- Send an `EventEnvelope` containing the logical reference and a
  `StoredEvent<Identity, Identity>`. The event's aggregate ID must agree with the
  reference. This is a separate wire contract from aggregate CRUD JSON.

## Publish after persistence

Generated repositories accept an optional `eventPublisher: client.publisher`.
Use a single publication hook. Implementations that handle their own
persistence can use the [core save and publication contract](../packages/dddart/DOMAIN_EVENTS_GUIDE.md),
including capturing the pending batch before awaiting the save and
acknowledging only accepted occurrences.

A successful publish means the server accepted the event. It does not wait
for all consumers to finish. `RetryingEventPublisher` retries classified
transient failures within its configured budget, using the same occurrence ID.
HTTP network failures, 408, 429, and 5xx responses are retryable; authorization
and validation failures are not. A timeout bounds waiting; it does not prove
the server stopped. Failed publication after a successful save leaves the
occurrence pending. Persistence and publication do not form an atomic outbox.

<a id="recover-and-handle-duplicates"></a>

<a id="watch-an-aggregate-remotely"></a>

## Watch and resume

Run the [loopback HTTP example](../packages/dddart_events_distributed/example/README.md) to watch an aggregate locally.

1. Open a watch for the aggregate's logical reference. A fresh watch starts
   at the current history head. Inspect its status after `ready` for denial
   or expired history. For an initial state fetch, start the watch first and
   buffer events during the fetch so there is no gap.
2. Save the opaque checkpoint with the application's local state, scoped to
   that reference. Pass it back as `client.watch(reference, checkpoint: saved)`.
   Checkpoints record committed ingestion progress, independent of domain
   timestamps. Live frames do not advance that progress.
3. Handle `revoked` by ending access. If the watch signals `resyncRequired`,
   close it, open a fresh watch, and reload the aggregate from its repository.
   History can expire or be deleted before a client catches up.
4. Connect `pause()` and `resume()` to the application's lifecycle. Pause
   stops periodic work and live sockets. Resume uses current credentials and
   catches up. Cancel stream subscriptions and close each watch lease and the
   client when finished.

Leases for the same reference share one watch; conflicting checkpoints for an
already active reference are rejected. HTTP catch-up batches active references
and pages through their retained records. The
[client options](../packages/dddart_events_distributed/lib/src/aggregate_event_client.dart)
define poll intervals and bounds. Delayed or reordered live frames and events
outside the deduplication window can be delivered more than once. Consumers
that need idempotency must enforce it. Unknown event types and malformed
payloads are logged and skipped so valid history can progress. Foreground live
delivery does not provide background device notifications.

## Compose the event server

`AggregateEventService<C>` takes a registry, history and channel repositories,
and an `AggregateEventPolicy<C>`. Supply verified principals and check
`canSubscribe` and `canPublish` separately against authoritative application
state. For example, a document editor may watch its open documents, but the
server still checks each document's access policy. A shared channel's payload
must be appropriate for all its authorized subscribers.

Register the [HTTP event endpoints](../packages/dddart_events_distributed/lib/src/aggregate_event_transport.dart)
for resolve, read, publish, and publication target. The event routes require
Bearer authentication; this is independent of policies on ordinary CRUD
resources. Use the [public credential exports](PUBLIC_API.md#application-and-extension-contracts)
to share HTTP token verification with native handlers. The endpoints bound
request size, response size and per-reference work. Clients preserve
checkpoints for any deferred references.

A successful append commits the history record and its ingestion position
together. Use in-memory history for local tests or a single development
process. Use shared [DynamoDB history](../packages/dddart_events_dynamodb/README.md)
for durable history across processes or short-lived handlers. When publishing
on the server, await the service or repository call before returning. A retry
may re-invoke event processing even when the store deduplicates the durable
record.

## Add live delivery with AppSync

Supply an `AppSyncEventTransport` to the same aggregate client for live messages.
Retained history still provides catch-up. The [AppSync deployment guide](../packages/dddart_events_appsync/DEPLOY.md)
covers the optional live relay and native handlers.

## Event identity migration

`DomainEvent<A, E>` and `StoredEvent<A, E>` independently type the aggregate and
event identities. The event base constructor requires `eventId`; generation
belongs to the concrete event or its caller. Register codecs for both concrete
identity kinds. The generated registry rejects erased or open identity types.

Publication envelopes use version **2**. `event.id` is now a tagged identity
(`type` and `value`), matching the existing aggregate identity encoding.
Version 1 envelopes and stored records with bare UUID event IDs are rejected.
Upgrade producers and consumers together. Migrate retained records by wrapping
the existing event UUID as a tagged `uuid` identity and setting the envelope version
to 2; preserve the payload's event ID and all occurrence metadata. If history is
instead retired, clients must reload aggregate state and obtain fresh checkpoints.

The DynamoDB adapter also changes event lookup and rotation keys to include the
registered identity kind and canonical key. Migrate those keys and recompute
stored canonical-content digests alongside envelope records before resuming
traffic; changing only the envelope version is insufficient. Keep stream heads,
positions, recovery floors and current channel mappings consistent. Physical
channel IDs remain generated UUIDs and are independent of event IDs.
