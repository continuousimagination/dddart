# dddart_events_distributed

Publish typed aggregate events and watch them over HTTP polling. Use the same
`AggregateEventClient` and `AggregateEventTransport` contracts with
[AppSync](../dddart_events_appsync/README.md) when you need live delivery.

## Run an HTTP-only publish/watch example

Follow the [example instructions](example/README.md) and run
[http_polling.dart](example/http_polling.dart). It starts a local server, opens a
watch, publishes one event, checks delivery, and closes the resources. The
sample has a local test credential and policy. Supply your own credential
verifier and access policy when deploying.

The [distributed events guide](../../docs/DISTRIBUTED_EVENTS.md) explains
publication, checkpoints, recovery and server composition.

## Generate event serializers and registrations

Add direct dependencies on core, serialization, JSON, this package, and
`build_runner` as a dev dependency. Use the
[Git installation guide](../../docs/GIT_INSTALLATION.md) and the
[clean consumer generation test](test/clean_consumer_generation_test.dart)
for a complete manifest and event library.

1. Define a concrete `@Serializable()` event extending `DomainEvent<I>`.
   Expose the base constructor parameters `aggregateId`, `eventId`,
   `occurredAt`, and `context` by name so the serializer can reconstruct it.
2. Import the public libraries for core, serialization, JSON, and distributed
   events into the owning library. Declare its `.g.dart` part.
3. Use `@DistributedEvent('issue.opened.v1')` to give the event a stable wire
   key. Without the annotation, the Dart class name is its key.
4. Run `dart run build_runner build --delete-conflicting-outputs` in the
   owning package. The JSON and registry builders share the generated part.
5. Call `createGeneratedEventRegistry(identityCodecs: identities)`. Use the
   same identity registry on the sending and receiving sides. Register custom
   [identity codecs](../../docs/SERIALIZATION.md#defaults-and-composition)
   when the event uses a non-UUID identity.

Alternatively, use `events.registerSerializer<E>(key, serializer)` for a
handwritten serializer, or set typed encode/decode callbacks with
`events.register<E>`. Preserve base metadata and application fields.

## Store custom event records

An application can extend `StoredEvent<I>` and generate JSON for that concrete
class. That JSON is independent of the tagged event record used by the
transport. Shared event endpoints accept `EventEnvelope`. See the
[custom record example](example/custom_stored_event_json_example.dart) for
round-tripping an application record.
