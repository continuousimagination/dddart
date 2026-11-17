# SQL collection verification boundaries

The SQLite and MySQL adapters share schema helpers, but support must be established
per adapter. It is not correct to promise that every collection graph transfers
between them unchanged. In particular, MySQL rejects entity Set/Map collections.

Use [MySQL testing](../TESTING.md) and [SQLite testing](../../dddart_repository_sqlite/TESTING.md)
with current generated fixtures. [SQL mappings](../../dddart_repository_sql/README.md)
record canonical identity keys (SQLite BLOB, MySQL VARBINARY(1024)), DateTime
mapping (SQLite ISO 8601 TEXT, MySQL DATETIME) and boolean mapping. The former
BINARY(16), integer-timestamp and universal collection-support claims are retired.

A passing primitive/value collection test does not prove entity collection,
nullable element, nested graph or cloud behavior. Refer to the actual tests and
[capability matrix](../../../docs/CAPABILITIES.md) for each composition.
