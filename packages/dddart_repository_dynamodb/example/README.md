# dddart_repository_dynamodb_example examples

These are maintained application samples for [dddart_repository_dynamodb](../README.md).
For a fresh application outside the checkout, start with the
[standalone workflows](../../../docs/QUICKSTARTS.md). These repository examples use
the workspace's package resolution and are not hosted-installation evidence.

## Setup and validation

SDK and dependency constraints are declared in the [example pubspec](pubspec.yaml).
From the repository root, resolve workspace tooling with
`dart pub get`, then run the lane below. It resolves the example package,
regenerates its declared parts when required, analyzes with fatal infos, compiles
each program, runs eligible finite/service programs and cleans temporary outputs.

```sh
dart tool/validation/validate.dart example dddart_repository_dynamodb_example --mode=ci
```

Required local services must be available; CI mode fails when they are missing.
The [service setup](../../../scripts/README.md) and
[shared inventory](../../../tool/validation/inventory.json) specify host/port,
builders and verification boundaries. Tests using local services do not verify a
cloud deployment or application credentials.

## Programs

| Source | Coverage / runtime context |
| --- | --- |
| [basic_crud_example.dart](basic_crud_example.dart) | Compiled and run against the lane's required local database service. Finite CRUD demonstration backed by DynamoDB Local. |
| [custom_interface_example.dart](custom_interface_example.dart) | Compiled and run against the lane's required local database service. Finite generated custom repository demonstration backed by DynamoDB Local. |
| [error_handling_example.dart](error_handling_example.dart) | Compiled and run against the lane's required local database service. Finite repository error-mapping demonstration backed by DynamoDB Local. |
| [local_development_example.dart](local_development_example.dart) | Compiled and run against the lane's required local database service. Finite DynamoDB Local development demonstration. |
| [table_creation_example.dart](table_creation_example.dart) | Compiled and run against the lane's required local database service. Finite DynamoDB Local table creation demonstration. |

Each program contains its complete imports and application model/context. Inspect
its constants and prerequisites before running it manually from this directory.
Use disposable test databases and credentials. Do not treat sample users, signing
secrets, endpoints or authorization policies as production configuration.

Generated `.g.dart` parts belong to their handwritten model library. Run the
example lane after changing models; do not reuse old generated parts. Custom
repository implementation parts must share that library so generated private
helpers remain accessible. Follow the [supported contracts](../../../docs/CAPABILITIES.md)
for identity, persistence, conditional writes, optional auth and event publication.
