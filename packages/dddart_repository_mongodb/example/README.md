# dddart_repository_mongodb_example examples

These are maintained application samples for [dddart_repository_mongodb](../README.md).
For a fresh application outside the checkout, start with the
[standalone workflows](../../../docs/QUICKSTARTS.md). These repository examples use
the workspace's package resolution and are not hosted-installation evidence.

## Setup and validation

Use Dart 3.13.7 from the repository root. Resolve workspace tooling with
`dart pub get`, then run the lane below. It resolves the example package,
regenerates its declared parts when required, analyzes with fatal infos, compiles
each program, runs eligible finite/service programs and cleans temporary outputs.

```sh
dart tool/validation/validate.dart example dddart_repository_mongodb_example --mode=ci
```

Required local services must be available; CI mode fails when they are missing.
The [service setup](../../../scripts/README.md) and
[shared inventory](../../../tool/validation/inventory.json) specify host/port,
builders and verification boundaries. Tests using local services do not verify a
cloud deployment or application credentials.

## Programs

| Source | Coverage / runtime context |
| --- | --- |
| [basic_crud_example.dart](basic_crud_example.dart) | Compiled and run against the lane's required local database service. Finite CRUD demonstration backed by the policy-provisioned MongoDB service. |
| [config_integration_example.dart](config_integration_example.dart) | Compiled and run against the lane's required local database service. Finite configuration integration backed by MongoDB. |
| [custom_interface_example.dart](custom_interface_example.dart) | Compiled and run against the lane's required local database service. Finite generated custom repository demonstration backed by MongoDB. |
| [error_handling_example.dart](error_handling_example.dart) | Compiled and run against the lane's required local database service. Finite repository error-mapping demonstration backed by MongoDB. |
| [repository_swapping_example.dart](repository_swapping_example.dart) | Compiled and run against the lane's required local database service. Finite repository swapping demonstration backed by MongoDB. |

Each program contains its complete imports and application model/context. Inspect
its constants and prerequisites before running it manually from this directory.
Use disposable test databases and credentials. Do not treat sample users, signing
secrets, endpoints or authorization policies as production configuration.

Generated `.g.dart` parts belong to their handwritten model library. Run the
example lane after changing models; do not reuse old generated parts. Custom
repository implementation parts must share that library so generated private
helpers remain accessible. Follow the [supported contracts](../../../docs/CAPABILITIES.md)
for identity, persistence, conditional writes, optional auth and event publication.
