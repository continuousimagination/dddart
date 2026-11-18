---
title: Publish and watch events
description: Deliver events in one process or watch a typed aggregate across HTTP or AppSync.
section: Connect the pieces
order: 30
---

An event names something the domain has done, such as `ReservationConfirmed`.
Declare both identity types with `DomainEvent<A, E>`: `A` is the aggregate ID
and `E` is the event occurrence ID. The base constructor requires both IDs.
A concrete event can generate its own UUID or require an externally assigned ID.
The occurrence ID stays the same when restoring an event or retrying delivery.
Include the source in an external identity if its value is only unique within
that source. See the [reservation example](/dddart/docs/modeling/) for explicit
UUID generation and the [typed identity example](https://github.com/continuousimagination/dddart/blob/main/packages/dddart/IDENTITY_GUIDE.md#use-a-scoped-identity)
for an event with an external source and sequence number.

## Deliver locally

The [starter example](/dddart/docs/getting-started/) uses `EventBus` after a
save. Subscribe to the event type, await the work you need before shutdown,
and close the subscription and bus. A call to publish schedules delivery; it
does not wait for asynchronous listener work.

When saving through a publication hook, capture the pending batch before
awaiting persistence. Publish only after a confirmed save and acknowledge
only accepted occurrences from that batch. This leaves later and rejected
events pending. Read the
[local event contract](https://github.com/continuousimagination/dddart/blob/main/packages/dddart/DOMAIN_EVENTS_GUIDE.md)
for a complete save and acknowledgment example.

## Watch an aggregate remotely

Start with the
[HTTP polling example](https://github.com/continuousimagination/dddart/blob/main/packages/dddart_events_distributed/example/README.md).
It sends one envelope to a loopback server and receives it through the shared
`AggregateEventClient`. Choose a stable event key and use the same identity
codecs on both sides. The server authorizes publication and subscription
separately for the logical aggregate.

## Recover and handle duplicates

A fresh watch starts at the history head. Set it up before the initial
repository read and reconcile events that arrive during the read. Store its
checkpoint with local state. If history needed for recovery has expired, start
a fresh watch and reload the aggregate. Close the watch when it is no longer
needed and connect pause and resume to the application's lifecycle.

Delivery can repeat, especially during recovery. Make handlers idempotent when
effects must only happen once. A successful aggregate write, durable event
acceptance, and completed listener work are separate milestones. The
[distributed events guide](https://github.com/continuousimagination/dddart/blob/main/docs/DISTRIBUTED_EVENTS.md)
covers checkpoints, retries, and server policy in detail.

## Add live delivery with AppSync

Keep the same aggregate client. Supply an `AppSyncEventTransport` to receive
live messages over a WebSocket. Both transports use retained history for
catch-up. Follow the [AppSync guide](https://github.com/continuousimagination/dddart/blob/main/packages/dddart_events_appsync/README.md)
for token handling, a local handler example, and deployment instructions.

When multiple server processes need to share history and channel mappings, use
the [DynamoDB event store](https://github.com/continuousimagination/dddart/blob/main/packages/dddart_events_dynamodb/README.md).
Clients keep their watch checkpoints and connect through the event API.
