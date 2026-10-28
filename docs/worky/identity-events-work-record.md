# Distributed identity work record — issue #44

Branch: issue/identity-distributed-events. Target: issue/37-extensible-identity.
Baseline 9e48b06 includes validated REST and persistence prerequisites.

## Frozen boundary

StoredEvent<I extends Identity> keeps its UUID record identity while retaining I
for the aggregate reference. A heterogeneous store intentionally uses
StoredEvent<Identity>. Stored JSON carries the explicit identity registry tag
(type plus structural value); old bare UUID aggregateId records require explicit
migration. Concrete StoredEvent subtypes specialize I for generated JSON.

EventRegistry explicitly registers stable event keys with typed JSON encoders
and factories, or a JsonSerializer<E>. Local runtime types only select a declared
registration; runtimeType/toString never supplies a wire discriminator or payload.
Identity codecs are instance-local and shared with serializers. Missing codecs,
unknown event registrations and malformed/tag-mismatched payloads fail clearly.
The generator creates registrations using generated serializers in the owning
combined part; class names are the documented default stable keys, with an
explicit annotation available to freeze a key independently of a Dart rename.

Server persistence keeps the injected stored-event factory. HTTP ingestion and
polling receive the identity registry explicitly. Custom stored-record decoding
uses an injected typed factory instead of an unchecked base-to-subtype cast.
Polling validates an envelope and its registered event before advancing its
inclusive timestamp/ID cursor. A decode failure stops that batch and leaves the
failed event retryable. Unknown event types with valid envelopes keep the existing
intentional skip policy; they do not pretend to reconstruct an identity kind.
Catch-up, tied timestamps, deduplication, authentication/filtering, retention and
experimental transport policies remain unchanged in scope.

Source inspection found the prior registry advertised @Serializable DomainEvent
inputs while dddart_json rejected DomainEvent. This child adds a distinct event
serialization path with concrete inherited ID resolution and named reconstruction
of eventId, occurredAt, aggregateId and context. Focused JSON tests prove this
path before the generated event-registry consumer; it adds no entity timestamps.

One owner controls event-registry plus JSON generation and each owning part/cache.
Focused fake-transport/registry cases precede the routed integration and package,
example, archive-consumer and immutable Git gates. Real AWS resources remain
optional and unrun unless explicitly configured; no production hardening is added.
