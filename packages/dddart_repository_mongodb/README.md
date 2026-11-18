# dddart_repository_mongodb

Generated MongoDB repositories with explicit typed identities and application queries.

[Capability boundaries](../../docs/CAPABILITIES.md) · [Supported imports](../../docs/PUBLIC_API.md)

## Get started

Run the [MongoDB quickstart](../../docs/quickstarts/mongodb/README.md) for a complete application.

## Models and identity

Use `@GenerateMongoRepository`, `@Serializable` and the owning generated part.
The annotation accepts `collectionName` and a custom repository `implements`
interface. The generator derives a default name; set an explicit collection name
when it is part of the application's storage contract.

Pass the same `IdentityCodecRegistry` through the generated repository and JSON
serializers. `_id` stores canonical identity-key UTF-8 bytes as BSON binary, while
the document retains structural JSON identity. Custom reads should call the
generated `fromDocument` helper; removing `_id` and calling an unrelated serializer
can bypass the repository's identity/revision conversion. A collection owns one
concrete identity kind; malformed key Unicode fails before I/O.

## Connections and custom repositories

[MongoConnection](lib/src/connection/mongo_connection.dart) supports constructor
parameters or `fromUri`, exposes its database after `open()`, and releases it via
`close()`. Reuse the connection according to the application's lifecycle.
The underlying driver owns connection pooling.

Custom interfaces define domain reads; generated bases leave those methods to
the application. The [custom example](example/custom_interface_example.dart)
contains the complete interface/model/part layout. Define query bounds and
ordering explicitly. A basic in-memory repository does not implement arbitrary
custom methods merely because it implements CRUD.

## Conditions and errors

Generated repositories implement single-document conditional operations and
coherent revision reads. Custom mutations must use the appropriate capability;
a read followed by an ordinary save is not compare-and-swap. Writes request the
acknowledgment documented in [conditional writes](../../docs/CONDITIONAL_WRITES.md).
An uncertain response is not proof of rollback. No multi-document commit or
operation receipt is promised. Successful saves may publish captured events;
publication is a separate step, not an atomic outbox.

`RepositoryException` separates missing records, duplicates, connectivity,
timeouts and other failures. Inspect causes for diagnostics and avoid retrying
uncertain writes blindly. Provision fresh pre-release collections.

## Deployment boundary

Use MongoDB for the [local examples](example/README.md). If the deployment uses
Amazon DocumentDB, verify the operations, topology, and trusted certificates
against that service. A compatible connection URI alone cannot establish support.

See the [public library](lib/dddart_repository_mongodb.dart).
