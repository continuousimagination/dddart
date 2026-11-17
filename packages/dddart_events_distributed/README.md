# dddart_events_distributed

[Supported platforms and capability boundaries](../../docs/CAPABILITIES.md) ·
[Supported imports and extension APIs](../../docs/PUBLIC_API.md)


For complete setup, named source files, expected output and cleanup, follow the
[canonical quickstart](../../docs/QUICKSTARTS.md#browser-and-external-integrations). Other inline Dart snippets below are
**illustrative fragments** that assume application-specific models and surrounding
setup; they are not standalone programs. See the [quickstart inventory](../../docs/QUICKSTARTS.md)
for runnable, browser, service and credential-dependent coverage.


Aggregate-scoped domain events with one `AggregateEventClient` and one
`EventPublisher` contract. This package supplies `HttpAggregateEventTransport`
for HTTP publication and polling. Optional
[`dddart_events_appsync`](../dddart_events_appsync/) supplies `AppSyncEventTransport`
for live delivery through the same `AggregateEventTransport` interface, adding
`LiveAggregateEventTransport` subscriptions and HTTP history recovery.

Both configurations use explicit typed aggregate references, registered event
codecs, application access policy and ingestion checkpoints. Only servers need
history/channel repositories. In-memory implementations support local apps/tests;
[`dddart_events_dynamodb`](../dddart_events_dynamodb/) supplies durable shared
storage. No constructor provisions resources or starts a server.

## Run an HTTP-only publish/watch example

From this checkout, run:

```bash
dart pub get
dart run packages/dddart_events_distributed/example/http_polling.dart
```

Expected output: `HTTP polling accepted and delivered counter value 1.`
The program starts an ephemeral loopback server, waits for a fresh watch, publishes
one event, receives it by polling, and closes its resources. It needs `dddart`,
`dddart_events_distributed` and `shelf`; it neither depends on AppSync nor requires
AWS credentials or a database. The complete [source](example/http_polling.dart)
is below. Its fixed token and single-aggregate policy are local fixtures;
applications inject their existing verifier and authoritative membership rules.
Event-route policy remains separate from optional/public CRUD resource policies.

```dart
import 'dart:io';

import 'package:dddart/dddart.dart';
import 'package:dddart_events_distributed/dddart_events_distributed.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

/// Finite local HTTP example: no AppSync dependency, AWS account or database.
Future<void> main() async {
  final registry = EventRegistry()
    ..register<CounterChanged>(
      'counter.changed.v1',
      encode: (event) => event.toJson(),
      decode: CounterChanged.fromJson,
    );
  final reference =
      AggregateReference(kind: 'counter', id: UuidValue.generate());
  final service = AggregateEventService<String>(
    history: InMemoryAggregateEventRepository(),
    channels: InMemoryEventChannelRepository(),
    registry: registry,
    policy: DemoPolicy(reference),
  );
  final endpoints = AggregateEventHttpEndpoints(
    service: service,
    // Local fixture only. An application supplies its real token verifier.
    authenticate: (token) async => token == 'local-demo'
        ? EventPrincipal(userId: 'demo', claims: 'demo')
        : null,
  );
  final routes = <String, Handler>{
    'events/resolve': endpoints.resolve,
    'events/read': endpoints.read,
    'events/publish': endpoints.publish,
    'events/target': endpoints.target,
  };
  final server = await shelf_io.serve(
    (request) =>
        routes[request.url.path]?.call(request) ?? Response.notFound(''),
    InternetAddress.loopbackIPv4,
    0,
  );
  final AggregateEventTransport transport = HttpAggregateEventTransport(
    baseUrl: Uri.parse('http://127.0.0.1:${server.port}/events'),
    wire: AggregateEventWire(registry.identityCodecs),
    tokenProvider: () async => 'local-demo',
  );
  final client = AggregateEventClient(
    transport: transport,
    registry: registry,
    aggregateKind: (_) => 'counter',
    interval: const Duration(milliseconds: 50),
  );
  try {
    final watch = client.watch(reference);
    await watch.ready.timeout(const Duration(seconds: 5));
    if (watch.status != EventWatchStatus.active) {
      throw StateError('Demo watch was denied');
    }
    // A fresh watch starts at the current head; publish only after it is ready.
    final received = watch.events.first.timeout(const Duration(seconds: 5));
    final event = CounterChanged(aggregateId: reference.id, value: 1);
    final EventPublisher publisher = client.publisher;
    if (!await publisher.publish(event)) {
      throw StateError('Event publication was not accepted');
    }
    final delivered = await received as CounterChanged;
    if (delivered.eventId != event.eventId || delivered.value != 1) {
      throw StateError('Polling did not preserve the accepted event');
    }
    print(
      'HTTP polling accepted and delivered counter value ${delivered.value}.',
    );
    await watch.close();
  } finally {
    await client.close();
    await server.close(force: true);
  }
}

/// Demo-only access to this one aggregate; replace with application membership.
class DemoPolicy implements AggregateEventPolicy<String> {
  DemoPolicy(this.reference);
  final AggregateReference<UuidValue> reference;

  @override
  Future<bool> canSubscribe(
    EventPrincipal<String> principal,
    AggregateReference<Identity> aggregate,
  ) async =>
      principal.userId == 'demo' && aggregate == reference;

  @override
  Future<bool> canPublish(
    EventPrincipal<String> principal,
    EventEnvelope envelope,
  ) =>
      canSubscribe(principal, envelope.aggregate);
}

/// Handwritten codec keeps this example runnable without generated files.
/// Applications can also use @Serializable and @DistributedEvent registrations.
class CounterChanged extends DomainEvent<UuidValue> {
  CounterChanged({
    required super.aggregateId,
    required this.value,
    super.eventId,
    super.occurredAt,
    super.context,
  });
  final int value;

  Map<String, dynamic> toJson() => {
        'aggregateId': aggregateId.uuid,
        'eventId': eventId.uuid,
        'occurredAt': occurredAt.toIso8601String(),
        'context': context,
        'value': value,
      };

  static CounterChanged fromJson(Map<String, dynamic> json) => CounterChanged(
        aggregateId: UuidValue.fromString(json['aggregateId'] as String),
        eventId: UuidValue.fromString(json['eventId'] as String),
        occurredAt: DateTime.parse(json['occurredAt'] as String),
        context: Map<String, dynamic>.from(json['context'] as Map),
        value: json['value'] as int,
      );
}
```

## Configure AppSync with the same client

For an existing AppSync deployment, add `dddart_events_appsync` and replace the
transport construction. This factory uses your deployed endpoints and current
token provider; `AggregateEventClient`, `client.watch(reference)` and
`client.publisher` stay the same. A token provider can delegate to your existing
`AuthProvider.getIdToken`. The control endpoint is still required for access
resolution and retained-history recovery.

```dart
import 'package:dddart_events_appsync/dddart_events_appsync.dart';
import 'package:dddart_events_distributed/dddart_events_distributed.dart';

AggregateEventTransport appSyncTransport({
  required Uri controlUrl,
  required Uri eventHttpUrl,
  required Uri eventRealtimeUrl,
  required String namespace,
  required EventRegistry registry,
  required Future<String?> Function() tokenProvider,
}) {
  final wire = AggregateEventWire(registry.identityCodecs);
  return AppSyncEventTransport(
    httpEndpoint: eventHttpUrl,
    realtimeEndpoint: eventRealtimeUrl,
    namespace: namespace,
    wire: wire,
    control: HttpAggregateEventTransport(
      baseUrl: controlUrl,
      wire: wire,
      tokenProvider: tokenProvider,
    ),
    authorization: () async {
      final token = await tokenProvider();
      if (token == null || token.isEmpty) {
        throw const EventPublicationException('Authentication required');
      }
      return {'Authorization': token};
    },
  );
}
```

Reuse the existing [AppSync native invocation example](../dddart_events_appsync/example/native_invocation.dart)
for local server-handler validation and the opt-in
[AWS smoke program](../dddart_events_appsync/example/aws_smoke.dart) for an already
configured deployment. Local protocol fixtures exercise real serialized
WebSocket frames; they do not claim a live AWS acceptance test.

## Publication, recovery and lifecycle

For repository-driven publication configure `eventPublisher: client.publisher`
and await `repository.save(aggregate)`. Publication uses a separate event envelope;
aggregate REST JSON never carries pending events. The publisher retries bounded
transient failures with the same occurrence UUID. Rejected events remain pending.
Do not also publish that same pending batch through a local bus bridge.

A fresh watch starts at the server head. Save its opaque `watch.checkpoint` to
resume retained history for that aggregate. Recovery uses committed ingestion
positions, independent of occurrence timestamps. Retained retries deduplicate by
UUID/content; watch overlap deduplication is bounded, so handlers must tolerate
duplicates. There is no exactly-once processing or transactional outbox.

Unknown event types and malformed known payloads are logged/skipped while valid
history progress advances. `watch.signals` exposes `revoked` and `resyncRequired`;
expired history requires reloading application state and creating a fresh watch.
`client.pause()`, `resume()`, `watch.close()` and `client.close()` manage polling
and optional live subscriptions. The client owns its transport; an injected
`localEventBus` remains application-owned. Remote delivery uses `EventBus.deliver`,
so `onPublished` bridges see only intentional local publication.

## Identity and wire contracts

`DomainEvent<I>` has a concrete aggregate identity and a UUID occurrence ID.
`EventEnvelope` combines a stable aggregate kind/typed identity reference with
`StoredEvent<Identity>`. The stored record preserves occurrence UUID, time,
context, stable event key and serialized body. The body and envelope identities
must agree. `AggregateEventRepository` stores envelopes and adds atomic append,
head, paginated checkpoint reads and ingestion-time retention cleanup.

Tagged identities such as `{"type":"github.issue.node","value":"I_kwDO_native_id"}`
select an explicitly registered `IdentityCodec<I>`. Neither Dart runtime names
nor synthetic UUID mappings infer identity. 1.0 is the first compatibility baseline.

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
name is the wire key. Choose explicit stable keys before the first public release.
Duplicate keys, duplicate registrations and open/erased identity types fail.

For handwritten serializers, use
`events.registerSerializer<IssueOpened>('issue.opened.v1', serializer)`. Explicit
typed `register<E>(key, encode: ..., decode: ...)` callbacks are also supported.
They must preserve all metadata/context and application fields. There is no
implicit dynamic toJson fallback. Serialization/decoding failures are explicit.

## Custom stored records and validation

A concrete class can extend `StoredEvent<UuidValue>` (or another concrete identity)
and use `@Serializable` for independent application JSON. Its generated format and
the tagged `StoredEvent.toJson` wire format are distinct. The shared event endpoints
accept `EventEnvelope`; they do not promise arbitrary custom stored-subtype ingestion.
The [custom record example](example/custom_stored_event_json_example.dart) remains
an independently runnable serialization example.

The shared validation inventory runs both examples and checks generated public
consumers. HTTP integration tests cover typed/scoped identities, authentication,
publication retry/denial, cancellation and remote delivery without echo. Existing
watch/history, AppSync protocol/native-handler and DynamoDB suites cover retained
recovery, access changes, lifecycle and durable acceptance. See the
[distributed-events reference](../../docs/DISTRIBUTED_EVENTS.md) for complete
server composition, limits and explicit deployment instructions.
