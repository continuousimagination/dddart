# dddart_repository_mongodb

Generated MongoDB repositories with explicit typed identities and application queries.

[Capability boundaries](../../docs/CAPABILITIES.md) · [Supported imports](../../docs/PUBLIC_API.md)

## Installation and runnable setup

Follow the [complete mongodb workflow](../../docs/quickstarts/mongodb/README.md)
for the current Git manifest, named files, clean generation where required,
expected output and cleanup. Hosted release installation remains separate under
#30. The workflow links its example pubspec. 1.0 is the first compatibility baseline.

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

The service tests run MongoDB. A DocumentDB-style URI is not proof of DocumentDB
feature, TLS or topology compatibility. Verify the actual deployment and trusted
certificate configuration; do not disable certificate checking as a default.
Use [testing instructions](TESTING.md) for the required local service lane.

## API and validation

The [public library](lib/dddart_repository_mongodb.dart) links the current API declarations. Detailed
contracts live with those declarations instead of duplicated signatures here.
[Repository examples](example/README.md) list their runtime/service requirements.
From the repository root, run the package and example commands in
[validation](../../scripts/README.md). Required service/browser lanes must be
available; compiling a configured sample does not prove a live deployment.
