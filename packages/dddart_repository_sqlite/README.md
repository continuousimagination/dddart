# dddart_repository_sqlite

Generated native SQLite repositories for typed DDDart aggregates.

[Capability boundaries](../../docs/CAPABILITIES.md) · [Supported imports](../../docs/PUBLIC_API.md)

## Get started

Run the [SQLite quickstart](../../docs/quickstarts/sqlite/README.md) for a complete application.

## Model and generation

Use `@GenerateSqliteRepository`, `@Serializable`, a complete aggregate constructor
and the model's owning `.g.dart` part. JSON and repository builders run together.
Use the package's runtime library in your model. Its builder factory is a
separate [build-time entrypoint](../../docs/PUBLIC_API.md).

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
the [active-user query](example/lib/custom_user_repository_impl.dart) and its
[runnable example](example/custom_repository_example.dart).
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

Try the [order example](example/complex_aggregate_example.dart) to see a graph of related objects stored and reloaded together.
