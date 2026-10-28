# dddart_events_distributed

Persist and distribute domain events through HTTP polling. This pre-release
package supports typed aggregate references, explicit event/identity codecs,
authentication and authorization filtering, retention, inclusive catch-up and
optional forwarding of locally published events.

## Identity and wire contracts

`DomainEvent<I>` references an aggregate with its concrete identity type I. The
event occurrence ID remains a `UuidValue`. `StoredEvent<I>` also uses that UUID
as its record ID; its `aggregateId` is separate. Heterogeneous stores intentionally
use `StoredEvent<Identity>`. Event repositories implement
`Repository<T, UuidValue>` plus explicit time-range operations.

An envelope carries a tagged aggregate reference:

```json
{"type":"github.issue.node","value":"I_kwDO_native_id"}
```

The stable tag selects an explicitly registered `IdentityCodec<I>`. It is never
inferred from `runtimeType`, `toString`, a UUID guess or a synthetic UUID mapping.
Old envelopes whose aggregateId is a bare UUID string require explicit migration
to `{"type":"uuid","value":"the-original-uuid"}`. Keep that original UUID text
and case. Concrete event body JSON uses its own typed serializer representation;
the restored body must agree with the envelope's event ID, time and aggregate ID.

## Generate event serializers and registrations

Add `dddart`, `dddart_json`, `dddart_serialization`, this package and
`build_runner` using the repository's documented Git installation approach.
One library owns both generated outputs:

```dart
import 'dart:convert';
import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_events_distributed/dddart_events_distributed.dart';

part 'issue_events.g.dart';

@Serializable()
@DistributedEvent('issue.opened.v1')
class IssueOpened extends DomainEvent<IssueId> {
  IssueOpened({
    required super.aggregateId,
    required this.title,
    super.eventId,
    super.occurredAt,
    super.context,
  });
  final String title;
}
```

`IssueId` is the application's immutable `Identity`; its codec defines JSON and
canonical key representations. See the core identity guide for native/scoped ID
examples. `DomainEvent<UuidValue>` uses the stock UUID codec. Every event must
expose the four named base metadata parameters shown above for reconstruction.

Run `dart run build_runner build --delete-conflicting-outputs` from the owning
package. `dddart_json:json_serializable` and
`dddart_events_distributed:event_registry` combine into `issue_events.g.dart`.
The registry builder uses generated serializer classes, not static fromJson
methods on event classes. It returns a fresh instance:

```dart
final identities = IdentityCodecRegistry()
  ..register<IssueId>('github.issue.node', IssueIdCodec());
final events = createGeneratedEventRegistry(identityCodecs: identities);
```

The identity registry is shared with every generated serializer. `@DistributedEvent`
freezes a wire key independently of a Dart rename. Without it, the declared class
name is the documented wire key; renaming the class then requires wire migration.
Duplicate keys, duplicate registrations and open/erased identity types fail.

For handwritten serializers, use
`events.registerSerializer<IssueOpened>('issue.opened.v1', serializer)`. Explicit
typed `register<E>(key, encode: ..., decode: ...)` callbacks are also supported.
They must preserve all metadata/context and application fields. There is no
implicit dynamic toJson fallback. Serialization/decoding failures are explicit.

## Server and client

```dart
final repository = InMemoryEventRepository();
final server = EventBusServer<StoredEvent<Identity>>(
  localEventBus: EventBus(),
  eventRepository: repository,
  storedEventFactory: (event) => StoredEvent<Identity>.fromDomainEvent(
    event, registry: events,
  ),
  retentionDuration: const Duration(days: 30),
);
final endpoints = EventHttpEndpoints<StoredEvent<Identity>>(
  eventRepository: repository,
  identityCodecs: identities,
);
```

Register `endpoints.handleGetEvents` at GET `/events` and a POST handler calling
`endpoints.handlePostEvent(request, server)` at `/events`. GET requires an ISO
8601 `since` parameter and returns authorized envelopes. POST validates tagged
aggregate identities before repository writes and returns 201 for valid records.
Authentication and authorization filtering remain explicitly injected callbacks.
The in-memory repository is an instance-local test/development fake; database
adapters must implement the time-range contract explicitly.

```dart
final client = EventBusClient(
  localEventBus: EventBus(),
  serverUrl: 'https://example.test',
  eventRegistry: events,
  autoForward: true,
);
client.on<IssueOpened>().listen((event) {
  print(event.aggregateId);
});
```

Polling sorts batches by time and uses an inclusive timestamp plus record IDs to
deduplicate tied events. Known events are decoded and checked before the cursor
advances. A malformed payload or missing identity codec stops that batch; repair
the payload/registration to make it retryable. Valid envelopes with unknown event
types retain the intentional skip policy. Request timeout, cancellation, credential
refresh, filtering and retention policies remain unchanged. Closing the client or
server closes its owned local event bus, as before.

## Custom stored records and limits

A concrete JSON-only record can extend `StoredEvent<UuidValue>` (or another
concrete I) and use `@Serializable`. Its generated serializer describes that
concrete class. The inherited manual `StoredEvent.toJson` method describes the
transport envelope with tagged identities; these are separate explicit formats.
For HTTP subtype ingestion, inject `storedEventFromJson` to reconstruct T with
the agreed wire format and shared identity codecs. The default decoder creates
`StoredEvent<Identity>`; it does not cast that base record into an arbitrary subtype.

The [active example](example/README.md) proves a custom record JSON round trip.
Focused tests and a fresh generated consumer separately prove the registry,
transport and typed identity boundary. Legacy server/client/range sketches remain
excluded under `example/legacy`; this change does not claim completion of their
unrelated EVENT-001 through EVENT-004 work or optional real AWS transports.

See [the work record](../../docs/worky/identity-events-work-record.md) for actual
local validation, generation ownership and unrun external-service checks.
