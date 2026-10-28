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

## Evidence recorded before the final package gate

- The complete JSON suite passes all 114 tests; native inherited event IDs,
  occurrence UUID/time/context and malformed identity payload cases pass.
- Distributed runtime/regression checks pass all 87 tests before the final typed
  custom-ingestion case; that five-case focused identity suite also passes.
- Fresh outside-workspace event generation compiles and runs. Its negative cases
  reject wrong ID types, erased aggregate identities and duplicate wire keys.
- Both JSON and event archive-consumer lanes pass with declared local closures.
- A comprehensive outside-workspace consumer resolves 13 packages from immutable
  Git revision 81313391f7f8348ec5c4d4f17d594b72419581a7, with documented Git
  dependency overrides keeping the complete closure at that revision. One
  combined part contains JSON, SQLite, MySQL, MongoDB, DynamoDB, REST repositories
  and event registrations. It generates, analyzes and runs successfully.
- That immutable consumer proves structured configuration presence/null/list and
  three-provider masking; native/scoped case-sensitive CRUD, nullable identity
  updates and deletion isolation in SQLite, MySQL, MongoDB and DynamoDB Local;
  generated REST clients through registered server routes backed by real SQLite;
  and mixed native/scoped/UUID event envelope ingestion and reconstruction.
  The services use isolated probe databases/tables; Dynamo tables and the Mongo
  probe database are cleaned after success. No real AWS/OIDC services are used.

The following fixture-only commit 88b9c77 prevents embedded part directives from
being mistaken for package generation inputs; it does not change library code.
Logs are retained under /private/tmp/dddart-worky-implementation-20261028 and the
immutable fixture under /private/tmp/dddart-worky-integrated-consumer-8131339.

## Child completion gate

The final distributed package lane passes all 88 tests, required generation,
fatal-info analysis and formatting. The JSON package lane passes all 114 tests
and corresponding gates. The active concrete record example generates, compiles
and runs. Both archive-consumer lanes pass. Package publication dry runs are
exempt because these packages already declare publish_to: none.

The generation gate exposed an embedded `part` directive in the clean-consumer
fixture, which now uses the same placeholder approach as other package fixtures.
This is test-only and all required outputs are now verified against their owning
libraries. No generated file was edited manually. The final workspace/service
integration gate and independent feature review remain parent responsibilities.
