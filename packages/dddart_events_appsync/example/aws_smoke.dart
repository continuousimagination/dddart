import 'dart:async';
import 'dart:io';

import 'package:dddart/dddart.dart';
import 'package:dddart_events_appsync/dddart_events_appsync.dart';
import 'package:dddart_events_distributed/dddart_events_distributed.dart';

import 'lib/example_domain.dart';

/// Explicitly opt in against an existing deployment; creates no AWS resources.
Future<void> main() async {
  final env = Platform.environment;
  if (env['DDDART_RUN_AWS_SMOKE'] != 'true') {
    throw StateError(
        'Set DDDART_RUN_AWS_SMOKE=true only for an existing configured deployment.');
  }
  String required(String key) =>
      env[key] ?? (throw StateError('$key is required'));
  final registry = exampleRegistry();
  final wire = AggregateEventWire(registry.identityCodecs);
  final control = HttpAggregateEventTransport(
      baseUrl: Uri.parse(required('DDDART_CONTROL_URL')),
      wire: wire,
      tokenProvider: () async => required('DDDART_TOKEN'));
  final transport = AppSyncEventTransport(
      httpEndpoint: Uri.parse(required('DDDART_EVENT_HTTP')),
      realtimeEndpoint: Uri.parse(required('DDDART_EVENT_REALTIME')),
      namespace: env['DDDART_NAMESPACE'] ?? 'aggregates',
      control: control,
      wire: wire,
      authorization: () async => {'Authorization': required('DDDART_TOKEN')});
  final kind = env['DDDART_AGGREGATE_KIND'] ?? 'game';
  final reference = AggregateReference(
      kind: kind, id: UuidValue.fromString(required('DDDART_AGGREGATE_ID')));
  final client = AggregateEventClient(
      transport: transport,
      registry: registry,
      aggregateKind: (_) => kind,
      interval: const Duration(minutes: 1));
  final event = ExampleChanged(
      aggregateId: reference.id, message: 'live-smoke-${UuidValue.generate()}');
  final watch = client.watch(reference);
  final delivered = Completer<void>();
  final subscription = watch.events.listen((received) {
    if (received.eventId == event.eventId && !delivered.isCompleted) {
      delivered.complete();
    }
  });
  try {
    await watch.ready.timeout(const Duration(seconds: 20));
    if (watch.status != EventWatchStatus.active) {
      throw StateError('Smoke aggregate is not authorized');
    }
    if (!await client.publisher.publish(event)) {
      throw StateError('Live publication failed');
    }
    await delivered.future.timeout(const Duration(seconds: 15));
    print(
        'Existing AWS deployment accepted and delivered the live occurrence.');
  } finally {
    await subscription.cancel();
    await watch.close();
    await client.close();
  }
}
