/// Distributed event system for DDDart.
///
/// Extends DDDart's local EventBus to enable domain events to be published
/// and subscribed across network boundaries using HTTP polling.
library dddart_events_distributed;

export 'src/event_bus_client.dart';
export 'src/event_bus_server.dart';
export 'src/event_http_endpoints.dart';
export 'src/event_repository.dart';
export 'src/generators/event_registry_generator.dart';
export 'src/in_memory_event_repository.dart';
export 'src/stored_event.dart';
