# dddart_repository_sql

[Supported platforms and capability boundaries](../../docs/CAPABILITIES.md) ·
[Supported imports and extension APIs](../../docs/PUBLIC_API.md)


Shared SQL runtime contracts and build-time helpers for DDDart adapters. This
package is not itself a database repository. Start with the complete
[SQLite workflow](../../docs/quickstarts/sqlite/README.md) or
[MySQL workflow](../../docs/quickstarts/mysql/README.md), including their Git-only
setup, generation, expected output and cleanup.

The [support matrix](../../docs/CAPABILITIES.md) is authoritative for platforms and
capabilities. [PUBLIC_API.md](../../docs/PUBLIC_API.md) inventories the imports.

## Runtime extension API

Import `package:dddart_repository_sql/dddart_repository_sql.dart` for:

- `SqlConnection` and `SqlConnectionCoordinator`: transaction ownership,
  connection serialization and post-commit work. A concrete adapter owns IO.
- `SqlDialect`: SQL syntax, column types, exact identity-key conversion and DDL.
- `TableDefinition`, `ColumnDefinition`, `ForeignKeyDefinition` and cascade values:
  runtime schema descriptions consumed by dialect/query helpers.
- `QueryBuilder` and `JoinBuilder`: SQL generation from explicit schema metadata.
- `ObjectMapper`: `flattenValueObject(String, Map<String, dynamic>)` and
  `reconstructValueObject(String, Map<String, Object?>)`. These transform prefixed
  JSON maps; they do not discover arbitrary object fields or reconstruct domain
  classes through reflection. Field names containing underscores need an
  application-defined mapping if the prefix convention would be ambiguous.

Generated adapters own aggregate graph persistence/reconstruction. There is no
public GraphTraverser, serializeGraph or deserializeGraph placeholder.

## Build-time extension API

Import `package:dddart_repository_sql/generator.dart` in an adapter builder. It
re-exports the runtime contracts and adds:

- `IdentityTypeAnalysis`: resolved concrete/inherited identity and field types.
- `CollectionAnalyzer`: supported collection shapes and element/key types.
- `RelationshipAnalyzer`: referenced model types and dependency ordering.
- `TypeMapper`: Dart-type to dialect column mapping.
- `SchemaGenerator`: table/collection schema and DDL generation.

These helpers consume analyzer elements; their contract is coupled to the
package's analyzer dependency range. Do not import them into a runtime model.
Concrete generator classes remain internal; build.yaml invokes builder factories.
Use the [SQLite builder](../dddart_repository_sqlite/lib/src/generators/sqlite_repository_generator.dart)
and [MySQL builder](../dddart_repository_mysql/lib/src/generators/mysql_repository_generator.dart)
as repository implementation references, not as public subclassing APIs.

## Identity and storage contracts

Core uses `AggregateRoot<I>` and `Entity<I>` with explicit identities.
`dddart_serialization` provides `IdentityCodecRegistry`; each application identity
needs an explicit JSON/canonical-key codec. Identity values remain atomic leaves
when their codec JSON is structured. The registry is shared with generated JSON.

SQLite stores canonical UTF-8 identity keys in BLOB columns; MySQL uses
VARBINARY(1024) and validates the adapter byte budget. Stock UUIDs retain their
complete string bytes and case. SQL field mapping is fixed to Dart names and
includes nullable values when replacing stored state. Fresh schemas and fresh
generated parts are the pre-release workflow; 1.0 is the first compatibility
baseline.

| Value | SQLite | MySQL |
| --- | --- | --- |
| Identity | BLOB canonical key | VARBINARY(1024) canonical key |
| DateTime | ISO 8601 TEXT | native DATETIME |
| bool | INTEGER 0/1 | TINYINT(1) |
| Value object | Embedded columns | Embedded columns |
| Entity/list/collection | Generated tables and relationships for supported shapes | Generated tables and relationships; entity Set/Map shapes rejected |

See the concrete dialects and generators for exact mappings. There is no generic
promise that every collection graph, database version or third-party dialect is
supported. The supplied SQLite adapter is native FFI, not a Web/WASM adapter.

## Concurrency and verification

[CONDITIONAL_WRITES.md](../../docs/CONDITIONAL_WRITES.md) defines the narrow
single-aggregate capability, coherent versioned reads, commit ownership,
confirmed conflicts and uncertain results. Ordinary CRUD remains available.
Multi-record receipts and atomic outbox publication are not SQL adapter promises.

Run `dart tool/validation/validate.dart package dddart_repository_sql --mode=ci`
from the repository root. SQLite/MySQL gates additionally regenerate and compile
external custom-base consumers; MySQL's CI lane requires its database service.
The [validation inventory](../../tool/validation/inventory.json) defines these
lanes. Backend switching is an application data-mapping task, not an automatic
schema/data migration supplied by this package.
