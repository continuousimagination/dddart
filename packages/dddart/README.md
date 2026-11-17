# dddart

Core domain modeling, typed identities, repository contracts and local events.

[Capability boundaries](../../docs/CAPABILITIES.md) · [Supported imports](../../docs/PUBLIC_API.md)

## Installation and runnable setup

Follow the [complete core workflow](../../docs/quickstarts/core/README.md)
for the current Git manifest, named files, clean generation where required,
expected output and cleanup. Hosted release installation remains separate under
#30. The workflow links its example pubspec. 1.0 is the first compatibility baseline.

## Domain model and storage

`Identity` extends `Value`; application IDs can be UUIDs, native strings or scoped
keys. `Entity<I>` and `AggregateRoot<I>` require an explicit ID. Domain constructors
may generate a UUID. Equality properties must remain immutable. See the
[identity guide](IDENTITY_GUIDE.md) and [API reference](API_REFERENCE.md).

`Repository<T, I>` defines get/save/delete. The in-memory implementation retains
object references; mutating a returned object mutates that same stored object.
Its enumeration helpers do not add queries to the general repository contract.
Applications define bounded domain queries on custom repository interfaces.

## Events and concurrency

`DomainEvent<I>` carries a typed aggregate ID and independent UUID occurrence ID.
The local `EventBus` provides broadcast streams; publication and listener
completion are separate. Capture pending events before awaiting persistence,
publish only after confirmed save, and acknowledge accepted captured occurrences.
Use the optional repository `eventPublisher` or `EventPublishingRepository`.
See [safe publication](DOMAIN_EVENTS_GUIDE.md) and [remote transports](../../docs/DISTRIBUTED_EVENTS.md).

`ConditionalAggregateRepository` adds detached revision reads and atomic
single-aggregate conditions where supported. `ConditionalRepository` is the
separate stronger multi-record/receipt capability used by IndexedDB. A basic CRUD
repository does not acquire either guarantee by implementing `Repository`.
[Conditional writes](../../docs/CONDITIONAL_WRITES.md) explains uncertainty and
transaction ownership. [conditional_writes.dart](example/conditional_writes.dart)
is a finite executable example.

## Logging and platforms

DDDart uses the `logging` package. Logger names include `dddart.eventbus` and
`dddart.repository`. Configure levels/listeners in the application; library logs
do not replace listener error handling. Console, hierarchy and file logging have
[complete samples](example/README.md). Close file sinks and subscriptions.
Portable core paths run on VM and compile to JavaScript; `FileLogHandler` requires
native filesystem IO. The [support matrix](../../docs/CAPABILITIES.md) describes
composition limits.

[Documentation index](DOCUMENTATION_INDEX.md) links all current core guides.

## API and validation

The [public library](lib/dddart.dart) links the current API declarations. Detailed
contracts live with those declarations instead of duplicated signatures here.
[Repository examples](example/README.md) list their runtime/service requirements.
From the repository root, run the package and example commands in
[validation](../../scripts/README.md). Required service/browser lanes must be
available; compiling a configured sample does not prove a live deployment.
