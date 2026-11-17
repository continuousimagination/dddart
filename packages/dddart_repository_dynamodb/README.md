# dddart_repository_dynamodb

Generated DynamoDB repositories for trusted services and disposable local development.

[Capability boundaries](../../docs/CAPABILITIES.md) · [Supported imports](../../docs/PUBLIC_API.md)

## Installation and runnable setup

Follow the [complete dynamodb workflow](../../docs/quickstarts/dynamodb/README.md)
for the current Git manifest, named files, clean generation where required,
expected output and cleanup. Hosted release installation remains separate under
#30. The workflow links its example pubspec. 1.0 is the first compatibility baseline.

## Models, keys and generation

Use `@GenerateDynamoRepository`, `@Serializable`, a concrete aggregate identity
and one owning generated part. The annotation accepts `tableName` and a custom
repository `implements` interface. Generated repositories support basic CRUD and
single-aggregate conditional operations; they do not provide automatic scans.

The table partition key is the string attribute `id`, containing a canonical
identity-codec key. Register non-UUID identity codecs explicitly and share that
registry with generated JSON. Custom query results should pass through generated
`fromItem` so structural identities and reserved revision metadata are handled.
Keys must contain 1–2048 valid UTF-8 bytes; case and trailing spaces matter.
A table owns one identity kind. Item limits and IAM permissions remain DynamoDB
responsibilities.

## Client and table lifecycle

[DynamoConnection](lib/src/connection/dynamo_connection.dart) lazily creates its
client. `local()` supplies dummy credentials and a localhost endpoint. For AWS,
supply credentials (including session token when required), region and deployment
configuration. With the currently pinned SDK, omitted credentials resolve from
environment/shared credential files; automatic EC2/ECS role discovery is not
promised by this wrapper. `dispose()` closes the current client; a subsequent
`client` access creates another client.

Generated `createTable()` provisions the basic table; static command/template
helpers return infrastructure text. Applications own indexes, capacity, IAM,
networking and deployment. The [table example](example/table_creation_example.dart)
uses DynamoDB Local. It does not deploy AWS infrastructure.

## Custom reads and conditional writes

Declare application reads on a custom interface, then implement the generated
abstract base in the same model library. The
[custom interface sample](example/custom_interface_example.dart) shows bounded
query methods and index prerequisites. A Query limit bounds evaluated items,
not necessarily returned matches; applications own continuation handling.

Generated single-item conditions are evaluated with the write, and identity reads
request strong consistency. A confirmed stale condition differs from a network
failure or uncertain response. See [conditional writes](../../docs/CONDITIONAL_WRITES.md).
These repositories do not provide multi-item receipts, cross-region coordination
or a transactional outbox. An optional publisher acknowledges captured events
only after confirmed persistence and acceptance.

## Errors and verification

`RepositoryException` classifies failures and retains causes where available.
Use [the example lane](example/README.md) with DynamoDB Local for generation,
table lifecycle, CRUD, errors and custom reads. Local tests do not certify AWS
IAM, Global Tables, LocalStack or a deployed service. DocumentDB is a different
protocol; the [MongoDB adapter](../dddart_repository_mongodb/README.md) has its
own explicit verification boundary.

## API and validation

The [public library](lib/dddart_repository_dynamodb.dart) links the current API declarations. Detailed
contracts live with those declarations instead of duplicated signatures here.
[Repository examples](example/README.md) list their runtime/service requirements.
From the repository root, run the package and example commands in
[validation](../../scripts/README.md). Required service/browser lanes must be
available; compiling a configured sample does not prove a live deployment.
