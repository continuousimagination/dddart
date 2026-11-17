# MySQL driver reference

The old mysql1 migration plan has been retired. The current adapter already uses
`mysql_client`; no pre-1.0 upgrade procedure or compatibility layer is required.
1.0 will be the first compatibility baseline.

Use the [MySQL quickstart](../../docs/quickstarts/mysql/README.md),
[current adapter guide](README.md) and [service test instructions](TESTING.md).
[MysqlConnection](lib/src/connection/mysql_connection.dart) owns one physical
connection, serializes overlapping operations and coordinates nested transaction
callbacks. It does not implement a connection pool; `maxConnections` is a legacy
no-op and should not be used to configure concurrency.

The checked service configuration uses MySQL 8 and fresh InnoDB tables. Claims
about mysql1 failures, future 2.0 packages, automatic data migration and parallel
driver compatibility in the former document do not describe the supported API.
