# DDDart core API reference

The maintained API declarations and Dart documentation live with the source.
This index links those declarations instead of duplicating signatures that can
silently drift. Import the [public library](lib/dddart.dart); the repository-wide
[supported export inventory](../../docs/PUBLIC_API.md) defines its boundary.

| Area | API source and contract |
| --- | --- |
| Value equality | [Value](lib/src/value.dart): runtime type and structural `props`; keep equality properties immutable |
| Identity | [Identity](lib/src/identity.dart), [UuidValue](lib/src/uuid_value.dart): application-defined kinds and explicit UUID creation |
| Entities | [Entity](lib/src/entity.dart), [AggregateRoot](lib/src/aggregate_root.dart): explicit typed ID, timestamps and pending event batches |
| Events | [DomainEvent](lib/src/domain_event.dart), [EventBus](lib/src/event_bus.dart): aggregate identity is typed; occurrence ID is a UUID; local delivery is asynchronous |
| Publication | [EventPublisher](lib/src/event_publisher.dart), [EventPublishingRepository](lib/src/event_publishing_repository.dart): save first, acknowledge only accepted captured events |
| Basic repositories | [Repository](lib/src/repository.dart), [InMemoryRepository](lib/src/in_memory_repository.dart): get/save/delete; collection queries are application-specific |
| Failures | [RepositoryException](lib/src/repository_exception.dart): typed storage errors, preserving underlying causes where available |
| Single-aggregate concurrency | [ConditionalAggregateRepository](lib/src/conditional_aggregate_repository.dart), [in-memory implementation](lib/src/in_memory_conditional_repository.dart) |
| Multi-record conditional capability | [ConditionalRepository](lib/src/conditional_repository.dart): atomic mutations and operation receipts, supplied by the IndexedDB adapter |
| Logging | [FileLogHandler](lib/src/file_log_handler.dart): native filesystem sink; console logging uses the logging package |

Use [complete quickstarts](../../docs/QUICKSTARTS.md) for runnable usage and
[the capability matrix](../../docs/CAPABILITIES.md) for platform and durability
limits. Core does not own JSON serialization: see the
[serialization contract](../../docs/SERIALIZATION.md).

`getUncommittedEvents()` returns an inspection snapshot. Infrastructure that
awaits persistence or publication must capture a `PendingEventBatch` before its
first await and acknowledge that batch, rather than clearing all current events.
See the [event lifecycle guide](DOMAIN_EVENTS_GUIDE.md).
