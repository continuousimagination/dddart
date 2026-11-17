# MySQL test suites

Use the [current test instructions](../TESTING.md) to regenerate and run the
package with its required local database. Test filenames and tags are discovered
by the [shared inventory](../../../tool/validation/inventory.json); new service
tags require an explicit policy. Do not infer current coverage from historical
counts or retired .skip examples.

The suites cover CRUD, graph persistence, collections, identities, transaction
coordination, custom interfaces and HTTP conditional races. Entity Set/Map
collections remain rejected. [SQL capability limits](../../../docs/CAPABILITIES.md)
and [conditional writes](../../../docs/CONDITIONAL_WRITES.md) define guarantees.
