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
consumer proof. These child completion gates passed as recorded below.

Dedicated MySQL 8.0 container: dddart-worky-mysql-20261028, loopback port 3307,
test_db and the existing policy's test credentials. Existing stopped MySQL
containers/data are untouched. MongoDB/DynamoDB services remain available for
the final integrated gate.

## Validation evidence

- Shared SQL: all 85 tests pass, including exact UTF-8 key limits/malformed
  bytes and inherited concrete identity resolution.
- SQLite: all 94 tests pass. Four focused cases cover exact native/scoped CRUD,
  inherited identity collections, identity map keys, nullable identity updates,
  embedded IDs, child foreign keys, UUID case preservation and rollback.
- MySQL: all 191 tests pass against the provisioned MySQL 8.0 service. Six focused
  cases also cover oversized keys and old BINARY(16) schemas in non-strict mode;
  rejection leaves zero rows written. Real schema inspection verifies column
  types and widths.
- Fresh generated custom-interface consumers for both adapters analyze, compile
  and run. Negative analyzer cases reject unrelated lookup/deletion ID types.
- The workspace-derived package lanes pass for all three packages, including
  sequential required generation, handwritten formatting, fatal-info analysis,
  tests and zero-warning publication dry runs. All three archive-consumer lanes
  pass. SQLite and MySQL example lanes generate, analyze and run successfully.
- A separate outside-workspace consumer resolves all six packages from immutable
  pushed revision 2d3d10cd14c537014d4a52c748ac5dc3ea946a4c, using documented Git
  overrides for the shared dependencies. Its combined JSON/SQLite/MySQL part
  generates and compiles. Real SQLite and MySQL CRUD preserves distinct scoped
  identities with URI-sensitive punctuation/Unicode, nullable identity references
  and deletion isolation. MySQL uses the separate worky_git_sql_probe database.
  The following commit 81eb6be changes only a test's required trailing comma.

The SQLite illustrative example called a plain unannotated OrderItem an entity,
contrary to the public serialization/entity contracts. It now extends UuidEntity,
accepts named identity/timestamps and is annotated for its owning combined part.
No generated output was hand-edited. The illustrative complex example remains
compile-only under the existing validation inventory; runnable examples pass.

Commands: `dart run tool/validation/validate.dart package NAME --mode=local`
(shared SQL and SQLite), the MySQL package lane with `--mode=ci`, each of the
three `consumer NAME` lanes, and both `example NAME` lanes (MySQL in CI mode).
Logs and the immutable consumer fixture are retained under
/private/tmp/dddart-worky-implementation-20261028 and
/private/tmp/dddart-worky-sql-consumer-2d3d10c.

No SQL external-service tests remain skipped in this child. The final integrated
workspace gate and independent feature review remain parent responsibilities.
This child does not publish packages or merge main.
