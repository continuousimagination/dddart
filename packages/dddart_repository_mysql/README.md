# dddart_repository_mysql

Generated MySQL repositories for typed aggregates on trusted native servers.

[Capability boundaries](../../docs/CAPABILITIES.md) · [Supported imports](../../docs/PUBLIC_API.md)

## Installation and runnable setup

Follow the [complete mysql workflow](../../docs/quickstarts/mysql/README.md)
for the current Git manifest, named files, clean generation where required,
expected output and cleanup. Hosted release installation remains separate under
#30. Use the documented development SDK; 1.0 is the first compatibility baseline.

## Models and storage

Use `@GenerateMysqlRepository` with a concrete `AggregateRoot<I>`, complete
constructor and owning generated part. The standalone workflow includes JSON
serialization and both builders. Identity codecs map native/scoped identities to
canonical keys; UUID is the stock identity. MySQL keys use VARBINARY(1024), and
over-budget or malformed keys fail before I/O. DateTime uses DATETIME, booleans
TINYINT(1), and values use embedded columns. See [SQL mappings](../dddart_repository_sql/README.md).

Primitive/value List, Set and Map collections and entity Lists have generator
coverage. Entity Set/Map collections are rejected; they are not a supported
schema design. Use fresh InnoDB tables and regenerate parts. `createTables()`
does not upgrade an existing schema.

## Connections and custom queries

[MysqlConnection](lib/src/connection/mysql_connection.dart) uses `mysql_client`
and owns one physical connection. Configure host, port, database, user, password
and timeout; call `open()`/`close()`. `maxConnections` is an ignored legacy option,
not a pool. Do not infer TLS options from another driver's API: this wrapper's
constructor is the supported configuration boundary.

A shared connection serializes concurrent operations and coordinates nested
ordinary transactions. Each independent connection has its own coordinator.
Use application-owned lifecycle/dependency injection to share connections.

Declare bounded domain reads on a custom repository interface and implement the
generated abstract base in the model's owning library. The
[custom repository example](example/custom_repository_example.dart) includes
its handwritten query implementation. Use query parameters for values and trusted
schema identifiers; never concatenate untrusted input into SQL.

## Atomicity, errors and publication

Complete supported graphs commit atomically. Narrow conditional writes and
versioned reads use the root revision and database locks; conditional writes
must own the physical commit. Ordinary writes may join an outer transaction.
The optional publisher runs only after confirmed outer commit and lock release.
[Conditional writes](../../docs/CONDITIONAL_WRITES.md) explains conflicts,
uncertain results, permissions and retry boundaries. Storage errors are mapped
to `RepositoryException`; inspect its type and cause rather than message text.

The [service test guide](TESTING.md) uses MySQL 8. Other server versions and cloud
deployments require their own evidence. The [driver reference](MYSQL_DRIVER_MIGRATION.md)
replaces the obsolete mysql1 migration plan. No pre-1.0 upgrade bridge is required.

## API and validation

The [public library](lib/dddart_repository_mysql.dart) links the current API declarations. Detailed
contracts live with those declarations instead of duplicated signatures here.
[Repository examples](example/README.md) list their runtime/service requirements.
From the repository root, run the package and example commands in
[validation](../../scripts/README.md). Required service/browser lanes must be
available; compiling a configured sample does not prove a live deployment.
