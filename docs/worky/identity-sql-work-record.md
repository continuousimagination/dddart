# SQL identity work record — issue #42

Branch: issue/identity-sql-backends. Target: issue/37-extensible-identity.
Baseline: 3731932, after locally validated core, JSON and document adapters.
One owner handles shared SQL metadata, dialects, generators and all build caches.

## Frozen implementation boundary

Repositories keep the concrete AggregateRoot<I> identity in Repository<T, I>,
lookup/deletion, parent references and collection helpers. The optional named
identityCodecs registry is shared with JSON. Entity repositories are not added.

Identity columns use exact canonical key bytes: SQLite BLOB and MySQL
VARBINARY(1024). The adapter supports at most 1024 UTF-8 bytes per MySQL identity
key, reserving index space for parent/key combinations. Root keys are validated
before save transactions; malformed/oversized nested keys must roll back without
persisted changes even with non-strict SQL mode. Complete schema/index/row
constraints remain server-enforced; no prefix indexes or silent truncation.
MySQL validates declared identity column types/widths before repository use, so
an old padded BINARY(16) schema fails explicitly before writes in non-strict mode.
References: [binary comparison and padding](https://dev.mysql.com/doc/refman/8.0/en/binary-varbinary.html),
[InnoDB index limits](https://dev.mysql.com/doc/refman/8.0/en/innodb-limits.html).

UUID identity encoding also retains canonical UUID text bytes so case-sensitive
UuidValue equality survives SQL. Existing 16-byte UUID schemas/data require
explicit migration/recreation. Stock generation/validation and JSON remain.

Generated schema/type metadata must distinguish identities from embedded Value
objects, resolve inherited generic identity fields, and use the referenced
identity type for primary/foreign keys and collection parents. Structured codec
JSON stays atomic until typed key encoding. Reconstruction uses the same concrete
codec, with table/collection context, never a UUID-looking string or Id-name
heuristic. Identity map keys use canonical key text rather than structural JSON.
ColumnDefinition.jsonPath records structural leaf paths so identity payloads and
field names containing underscores remain atomic. Persistence serializers use
fixed Dart field names and include null fields so optional identity updates clear
stored values. Existing nullable collection containers still load as empty.

MySQL's driver exposes UTF-8 key data as strings. Conversion must honor column
metadata so numeric native keys such as "12" and "0012" remain strings. Canonical
UTF-8 input is validated and no arbitrary toString conversion becomes storage.

Existing collection/value/entity generation capabilities are inspected and tested
in place. Current unrelated persistence work (#29) is not silently declared done.
SQLite entity collections use junction tables; MySQL List<Entity> uses its
existing dedicated entity table, while primitive/value/identity collections use
the `_items` junction layout. MySQL Set/Map entity collections remain unsupported
and now fail generation explicitly instead of disappearing from persistence.

## Generation and behavioral completion gate

Generate each SQLite/MySQL package and example sequentially with its repository
builder plus dddart_json:json_serializable. Verify current combined parts against
owning handwritten libraries. No generated output is edited manually.

Focused embedded SQLite and provisioned MySQL tests must prove native/scoped and
stock UUID CRUD, exact case/whitespace/numeric keys, update/delete isolation,
nested entity/collection primary and foreign keys, and fail-fast unsupported key
encodings. Fresh custom-interface consumers must compile typed lookups. Then run
the workspace-derived package/example/archive-consumer gates and immutable Git
consumer proof. No final result is claimed yet.

Dedicated MySQL 8.0 container: dddart-worky-mysql-20261028, loopback port 3307,
test_db and the existing policy's test credentials. Existing stopped MySQL
containers/data are untouched. MongoDB/DynamoDB services remain available for
the final integrated gate.

## Evidence so far

- Shared SQL: 85 tests pass, including exact UTF-8 key limits/malformed bytes and
  inherited concrete identity resolution. Fatal-info analysis passes.
- SQLite: 93 tests pass before adding the clean-consumer fixture; its four new
  behavior cases cover exact native/scoped CRUD, inherited identity collections,
  identity map keys, nullable identity updates, embedded IDs, child foreign keys,
  UUID case preservation and rollback. Fresh generated custom-interface output
  also analyzes/compiles/runs and rejects unrelated lookup/deletion ID types.
- MySQL: all six focused identity/service cases pass, including rejection of an
  old BINARY(16) table in non-strict mode with zero rows written. A full run exposed old
  16-byte source expectations and UUID_TO_BIN manual fixtures, which are migrated.
  Real schema inspection replaces a former table-existence-only type assertion.
  Final regression, package/example and archive/Git consumer gates are in progress.

The SQLite illustrative example called a plain unannotated OrderItem an entity,
contrary to the public serialization/entity contracts. It now extends UuidEntity,
accepts named identity/timestamps and is annotated for its owning combined part.
Generation succeeds; no generated output was hand-edited.
