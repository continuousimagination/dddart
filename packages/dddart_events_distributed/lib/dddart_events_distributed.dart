/// Distributed event system for DDDart.
///
/// One aggregate-scoped client/publisher API with an HTTP polling transport.
/// Add dddart_events_appsync for the optional live transport on the same interface.
library dddart_events_distributed;

export 'src/aggregate_event_client.dart';
export 'src/aggregate_event_repository.dart';
export 'src/aggregate_event_service.dart';
export 'src/aggregate_event_transport.dart';
export 'src/aggregate_reference.dart';
export 'src/event_envelope.dart';
export 'src/event_registry.dart';
export 'src/in_memory_aggregate_event_repository.dart';
export 'src/retrying_event_publisher.dart';
export 'src/stored_event.dart';
