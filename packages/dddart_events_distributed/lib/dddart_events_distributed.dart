/// Distributed event system for DDDart.
///
/// Extends DDDart's local EventBus to enable domain events to be published
/// and subscribed across network boundaries using HTTP polling.
library dddart_events_distributed;

export 'src/aggregate_event_client.dart';
export 'src/aggregate_event_repository.dart';
export 'src/aggregate_event_service.dart';
export 'src/aggregate_event_transport.dart';
export 'src/aggregate_reference.dart';
export 'src/event_bus_client.dart';
export 'src/event_bus_server.dart';
export 'src/event_envelope.dart';
export 'src/event_http_endpoints.dart';
export 'src/event_registry.dart';
export 'src/event_repository.dart';
export 'src/in_memory_aggregate_event_repository.dart';
export 'src/in_memory_event_repository.dart';
export 'src/retrying_event_publisher.dart';
export 'src/stored_event.dart';
