# Getting started with DDDart

Start with the [complete core quickstart](../../docs/quickstarts/core/README.md).
It supplies a Git-pinned manifest, a named Dart program, exact output and cleanup.
Create the application outside this monorepo using its example pubspec.
DDDart's first compatibility baseline will be 1.0; hosted installation is
part of the separate release process, not a prerequisite for this guide.

The program defines an aggregate and an event, persists the aggregate through a
repository, publishes its captured events, awaits a listener and closes the bus.
For generated JSON, follow the [JSON quickstart](../../docs/quickstarts/json/README.md),
including the imports, part directive and clean build_runner commands.

## Choose the next step

| Task | Current instructions |
| --- | --- |
| Native or composite identifiers | [Identity guide](IDENTITY_GUIDE.md) |
| Safe save and event publication | [Domain events](DOMAIN_EVENTS_GUIDE.md) |
| Database persistence | [All quickstarts](../../docs/QUICKSTARTS.md) |
| Public HTTP reads and optional authentication | [REST guide](../dddart_rest/README.md) |
| Prevent concurrent updates from overwriting each other | [Conditional writes](../../docs/CONDITIONAL_WRITES.md) |
| Look up a public type or method | [API reference](API_REFERENCE.md) |
| Run the repository's samples | [Example instructions](example/README.md) |

InMemoryRepository stores object references and is intended for local tests and
simple in-process use. Use a durable adapter when persistence is required. The
local event bus does not provide durable delivery, an atomic outbox or completion
of asynchronous listeners when `publish` returns.
