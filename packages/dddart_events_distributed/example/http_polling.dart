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
