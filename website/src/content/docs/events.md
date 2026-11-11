---
title: Events that speak your domain
description: Raise meaningful facts, publish after persistence, and watch aggregates through HTTP or an optional live transport.
section: Connect the pieces
order: 30
---

An event records something meaningful that happened: an order was placed, a player joined, a document was approved. Those names should work in a product conversation as well as in a Dart class.

DDDart separates three concerns: raising a fact inside an aggregate, accepting its publication, and delivering it to interested consumers. The domain event stays the same across those boundaries. Their timing and guarantees do not.

## Define a fact

An occurrence has its own UUID, a typed aggregate identity, a timestamp, and context. Preserve those values when the event crosses a serialization boundary.

```dart
import 'package:dddart/dddart.dart';

class OrderPlaced extends DomainEvent<UuidValue> {
  OrderPlaced({
    required super.aggregateId,
    required this.customer,
    super.eventId,
    super.occurredAt,
    super.context,
  });

  final String customer;
}
```

An aggregate can call `raiseEvent(OrderPlaced(...))` from a domain method after its rules have passed. Raising an event adds it to the pending queue; it does not immediately send a network request.

## Deliver locally

This function publishes the event to a local bus and waits for one listener to receive it:

```dart
Future<void> localExample() async {
  final bus = EventBus();
  final received = bus.on<OrderPlaced>().first;

  bus.publish(OrderPlaced(
    aggregateId: UuidValue.generate(),
    customer: 'Acme',
  ));

  final event = await received;
  print('Order placed for ${event.customer}');
  await bus.close();
}
```

`publish` originates a local event. Transport adapters use `deliver` for events received elsewhere. Application listeners use `on<E>()` to see both; forwarding bridges use `onPublished<E>()` so received events do not echo back onto the network. The distinction belongs to the delivery, not to an extra flag inside the domain payload.

## Publish after a save

Generated event-enabled repositories accept an optional `EventPublisher`. For example, once your application has a generated `OrderRestRepository`, a REST connection, and an `AggregateEventClient`:

```dart
final orders = OrderRestRepository(
  connection,
  eventPublisher: eventClient.publisher,
);
await orders.save(order);
```

The repository captures the pending batch before awaiting persistence, saves the aggregate, and then awaits publication attempts. It acknowledges only the accepted captured occurrences. A failed save publishes nothing. Events raised while the save is waiting remain pending for a later operation.

Custom repositories can use the core `saveWithEvents` helper. `EventPublishingRepository<T, I>` can wrap a basic CRUD implementation. Configure one hook for a save; wrapping an already event-enabled repository or also forwarding its pending events through a bus duplicates publication.

An accepted publication means the event store accepted the occurrence. It does not mean all listeners finished. A final publication failure is logged and leaves the event pending, while an already successful aggregate save still succeeds. The pending queue is in memory: a process exiting before durable event acceptance can lose that unpublished event. There is no transactional outbox joining database persistence and event acceptance.

## Give the wire contract a stable name

`EventRegistry` explicitly maps event types to stable, versioned names. It is shared by clients and servers. With the `OrderPlaced` class above, the following complete registration preserves its base metadata:

```dart
import 'package:dddart_events_distributed/dddart_events_distributed.dart';

EventRegistry orderEvents() => EventRegistry()
  ..register<OrderPlaced>(
    'order.placed.v1',
    encode: (event) => {
      'aggregateId': event.aggregateId.uuid,
      'eventId': event.eventId.uuid,
      'occurredAt': event.occurredAt.toIso8601String(),
      'context': event.context,
      'customer': event.customer,
    },
    decode: (json) => OrderPlaced(
      aggregateId: UuidValue.fromString(json['aggregateId'] as String),
      eventId: UuidValue.fromString(json['eventId'] as String),
      occurredAt: DateTime.parse(json['occurredAt'] as String),
      context: Map<String, dynamic>.from(json['context'] as Map),
      customer: json['customer'] as String,
    ),
  );
```

Generated JSON serializers can be registered with `registerSerializer` instead. The generator also supports `@DistributedEvent('order.placed.v1')` to keep the wire key independent of a Dart class rename. See the [event registry guide](https://github.com/continuousimagination/dddart/blob/b4aacf0671873e729a1a390dc2bb609b80c723e5/packages/dddart_events_distributed/README.md) for generated registration setup.

For application-defined aggregate identities, supply the same `IdentityCodecRegistry` used by your serializers and repositories. Unknown identity kinds do not receive an implicit runtime-name encoding.

## Watch one logical aggregate

An `AggregateReference` combines a stable kind, such as `order`, with a concrete identity. It expresses interest in that aggregate, independently of an HTTP route or a physical WebSocket channel.

The function below is complete once placed beside `OrderPlaced` and `orderEvents()`. The application supplies its API URL, current-token callback, order identity, and UI/domain callbacks. It returns the client so the application can own its lifecycle.

```dart
AggregateEventClient watchOrder({
  required Uri eventsUrl,
  required UuidValue orderId,
  required Future<String?> Function() currentToken,
  required void Function(OrderPlaced) onPlaced,
  required void Function(EventWatchStatus) onStatus,
}) {
  final registry = orderEvents();
  final transport = HttpAggregateEventTransport(
    baseUrl: eventsUrl,
    wire: AggregateEventWire(registry.identityCodecs),
    tokenProvider: currentToken,
  );
  final client = AggregateEventClient(
    transport: transport,
    registry: registry,
    aggregateKind: (event) {
      if (event is OrderPlaced) return 'order';
      throw ArgumentError('Unregistered aggregate kind');
    },
  );
  final watch = client.watch(AggregateReference(kind: 'order', id: orderId));
  watch.events.where((event) => event is OrderPlaced).cast<OrderPlaced>()
      .listen(onPlaced);
  watch.signals.listen(onStatus);
  return client;
}
```

For individual view lifecycles, retain the `AggregateEventWatch` and its stream subscriptions yourself, cancel the listeners, and call `watch.close()` when the view closes. Multiple leases for the same reference share one underlying watch. `client.close()` closes all of its watches and transport resources.

HTTP-only clients poll every five seconds by default using one batched synchronization operation. An optional AppSync transport adds live delivery and changes the default reconciliation interval to one minute. Both use the same watch contract and retained history.

## Initial state, reconnects, and lifecycle

A fresh watch starts at the current server head; it does not replay the aggregate's entire past. Establish the watch, await `watch.ready`, inspect `watch.status`, then load initial state through a repository. Buffer or reconcile events that arrive during the initial fetch. Fetching first and watching afterward leaves a gap where a change can be missed.

Save `watch.checkpoint` with the application's corresponding local state. To resume later, pass that opaque token to `client.watch(reference, checkpoint: savedCheckpoint)`. Keep a checkpoint per logical aggregate; it is server progress, not an authorization credential.

Handle the two signals that need application decisions:

| Signal | Application action |
| --- | --- |
| `revoked` | Stop using this watch; access is no longer allowed. |
| `resyncRequired` | Required retained history expired or was deleted. Close the old watch, establish a fresh watch, and explicitly reload/reconcile aggregate state. |

`ready` completes for an initial bounded synchronization, including denial or expiration. It does not promise that a large retained backlog has all arrived. Later checkpoints continue to advance as additional pages are processed.

Connect these methods to the platform lifecycle:

```dart
await client.pause();  // Background: stops periodic work and live subscriptions.
await client.resume(); // Foreground: refresh credentials and recover history.
await client.close(); // Final disposal.
```

Flutter lifecycle hooks and browser visibility events belong to the application. A foreground WebSocket connection does not provide APNs or FCM background notifications.

## Compose the server

`AggregateEventService<C>` combines an event registry, retained-history repository, channel repository, and your `AggregateEventPolicy<C>`. Its policy separately checks subscription and publication rights against authoritative domain state. A client-supplied user ID or a known channel ID is not proof of access.

In-memory history and channels are useful for tests and a single local process. Concurrent or short-lived server instances need shared durable implementations, such as the [DynamoDB event repositories](/dddart/docs/integrations/).

After constructing `service` and an `authenticate` callback returning a verified `EventPrincipal<C>`, register the shared endpoints:

```dart
final endpoints = AggregateEventHttpEndpoints(
  service: service,
  authenticate: authenticate,
);
final server = HttpServer()
  ..addRoute('POST', '/events/resolve', endpoints.resolve)
  ..addRoute('POST', '/events/read', endpoints.read)
  ..addRoute('POST', '/events/target', endpoints.target)
  ..addRoute('POST', '/events/publish', endpoints.publish);
```

These types come from `dddart_events_distributed` and `dddart_rest`. All four routes require Bearer authentication. The target route checks publication rights separately from subscription rights. An application that can submit an event need not be allowed to subscribe to the entire aggregate stream.

The same service can be injected into [native AppSync/Lambda handlers](/dddart/docs/integrations/). No second event model is required, and constructing a service starts no listener or infrastructure deployment.

## Delivery guarantees to design around

- Retained history uses committed ingestion positions, not client clocks. Pages are ordered by those positions; live delivery may reorder events.
- Equivalent retries reuse the occurrence UUID and are idempotently accepted within the retention window. Conflicting reuse of that UUID is rejected.
- Client overlap deduplication is bounded. Handlers should tolerate duplicates; there is no exactly-once delivery or consumer-processing acknowledgment.
- The default retry policy makes up to three attempts with backoff and jitter, with a six-second total waiting budget. Only classified transient failures retry.
- Retention defaults to seven days in the supplied history stores. Expired history requires an application resynchronization; it is not an event-sourcing archive.
- New aggregate watches skip unknown or malformed event payloads with logging and advance valid transport progress. Keep clients and event contracts compatible.

The older timestamp-based `EventBusClient` / `EventBusServer` APIs remain available. They are a separate flow with different recovery behavior. Use `AggregateEventClient` for new per-aggregate watches.

For complete server composition, access rotation, budgets, and migration steps, read the [detailed distributed-events reference](https://github.com/continuousimagination/dddart/blob/b4aacf0671873e729a1a390dc2bb609b80c723e5/docs/DISTRIBUTED_EVENTS.md). The [native invocation example](https://github.com/continuousimagination/dddart/blob/b4aacf0671873e729a1a390dc2bb609b80c723e5/packages/dddart_events_appsync/example/native_invocation.dart) runs locally without deploying AWS resources.
