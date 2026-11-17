# dddart_repository_sqlite

Generated native SQLite repositories for typed DDDart aggregates.

[Capability boundaries](../../docs/CAPABILITIES.md) · [Supported imports](../../docs/PUBLIC_API.md)

## Installation and runnable setup

Follow the [complete sqlite workflow](../../docs/quickstarts/sqlite/README.md)
for the current Git manifest, named files, clean generation where required,
expected output and cleanup. Hosted release installation remains separate under
#30. Use the documented development SDK; 1.0 is the first compatibility baseline.

## Model and generation

Use `@GenerateSqliteRepository`, `@Serializable`, a complete aggregate constructor
and the model's owning `.g.dart` part. JSON and repository builders run together.
The [generation guide](GENERATOR_IMPLEMENTATION.md) describes the supported
runtime/build-time imports; concrete generator classes are internal.

Supported aggregate graphs, nested entities and collections are persisted by
generated code. Value objects use prefixed columns; DateTime uses ISO 8601 TEXT,
booleans use INTEGER, and identity keys use canonical UTF-8 BLOBs. Supply an
`IdentityCodecRegistry` for non-UUID identities. The same registry reaches nested
serializers. [SQL mappings](../dddart_repository_sql/README.md) describe limits.

## Connections and queries

`SqliteConnection.file` and `SqliteConnection.memory` require `open()` and
`close()`. This is a native FFI adapter with no browser/WASM implementation.
`createTables()` provisions fresh tables; it is not a schema migration tool.

Custom repository methods belong to an application interface. Generated abstract
bases and the handwritten subclass share the model library via parts. See
[custom_repository_example.dart](example/custom_repository_example.dart).
Declare explicit selection, ordering and bounds; CRUD does not imply getAll.

## Transactions and conditions

A save writes the complete supported graph in a database transaction. A shared
connection serializes overlapping operations; nested ordinary transactions join
the outer one. Narrow conditional writes must own their physical commit and
reject nesting. Versioned reads are coherent; stale revisions fail explicitly.
A failed or uncertain commit must not be treated as successful publication.
[Conditional writes](../../docs/CONDITIONAL_WRITES.md) defines the exact contract.

An optional `eventPublisher` publishes the captured pending batch after confirmed
commit, including an outer transaction's commit. Rollback retains pending events.
This does not implement a transactional outbox.

[Testing](TESTING.md) and [examples](example/README.md) cover persistence,
generation, custom bases, collection limits and independent-connection races.

## API and validation

The [public library](lib/dddart_repository_sqlite.dart) links the current API declarations. Detailed
contracts live with those declarations instead of duplicated signatures here.
[Repository examples](example/README.md) list their runtime/service requirements.
From the repository root, run the package and example commands in
[validation](../../scripts/README.md). Required service/browser lanes must be
available; compiling a configured sample does not prove a live deployment.
