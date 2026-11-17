# dddart

Domain modeling primitives, typed repositories, and local events for Dart.

Start with the [core quickstart](../../docs/quickstarts/core/README.md). It shows
how an order records a domain action, saves through a repository, and publishes
an event. Import the [core library](lib/dddart.dart) as `package:dddart/dddart.dart`.

| Concept | When to use it |
| --- | --- |
| `Value` | Represent immutable domain data whose equality comes from its properties |
| `Entity<I>` and `AggregateRoot<I>` | Model an object with an explicit, stable [identity](IDENTITY_GUIDE.md); an aggregate owns a consistency boundary |
| `Repository<T, I>` | Load, save, and delete an aggregate; add application queries on a separate interface |
| `DomainEvent<I>` and `EventBus` | Record [domain events](DOMAIN_EVENTS_GUIDE.md) and notify in-process listeners |

Use an in-memory repository for a prototype or a test where retaining object
references is appropriate. To persist data or prevent lost updates, see the
[adapter guide](../../docs/CAPABILITIES.md) and
[conditional writes contract](../../docs/CONDITIONAL_WRITES.md).

The core library is usable without a database, server, or code generator.
`FileLogHandler` requires native filesystem access. Configure log levels and
listeners in the application, and close file sinks and event subscriptions.

Browse the [core examples](example/README.md) for identity, logging, publication,
and repositories, or the [documentation index](../../docs/README.md) to choose
another package.
