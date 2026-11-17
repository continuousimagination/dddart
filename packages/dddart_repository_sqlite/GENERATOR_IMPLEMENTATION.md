# SQLite repository generation

Start with the [complete SQLite workflow](../../docs/quickstarts/sqlite/README.md).
Its model imports core, serialization, JSON and the SQLite runtime library,
declares its owning generated part, and uses the repository and JSON builders.
Generate from clean inputs; do not copy or hand-edit generated implementations.

The [builder entrypoint](lib/builder.dart) exposes the builder factory. The
[generator implementation](lib/src/generators/sqlite_repository_generator.dart)
is internal. Shared analyzer/schema extension contracts are available through
`package:dddart_repository_sql/generator.dart`; runtime code imports the normal
SQL library. See the [supported export inventory](../../docs/PUBLIC_API.md).

Generated repositories implement typed aggregate CRUD and the narrow conditional
capability. Concrete identity codecs preserve exact key equality. Supported
aggregate graphs, collections and nested entities are stored/reconstructed by
generated code within the connection's transaction coordinator. Values are
embedded using prefixed columns; the generator is not a reflection-based runtime
object mapper. The [SQL guide](../dddart_repository_sql/README.md) records mappings:
identity keys use canonical UTF-8 BLOBs, DateTime uses ISO 8601 TEXT, and booleans
use INTEGER values. The earlier integer-timestamp/UUID-only description is obsolete.

A custom repository interface with additional methods produces an abstract base;
implement its application queries in the same owning library/part. The maintained
[custom repository example](example/custom_repository_example.dart) shows this
layout. `createTables()` provisions fresh schema and does not migrate an existing
schema. The [conditional contract](../../docs/CONDITIONAL_WRITES.md) defines
revision ownership, nested transaction limits, confirmed conflicts and uncertainty.

[Tests and consumers](TESTING.md) regenerate models and verify persistence,
collections, identities, atomicity, supported imports and custom bases. SQLite
uses native FFI; this adapter has no browser/WASM implementation.
