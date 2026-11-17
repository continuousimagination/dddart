# dddart_repository_rest_example examples

These are maintained application samples for [dddart_repository_rest](../README.md).
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
dart tool/validation/validate.dart example dddart_repository_rest_example --mode=ci
```

Required local services must be available; CI mode fails when they are missing.
The [service setup](../../../scripts/README.md) and
[shared inventory](../../../tool/validation/inventory.json) specify host/port,
builders and verification boundaries. Tests using local services do not verify a
cloud deployment or application credentials.

## Programs

| Source | Coverage / runtime context |
| --- | --- |
| [authentication_example.dart](authentication_example.dart) | Compiled only; running requires application configuration or a long-running server. Requires a separately running authenticated REST server. |
| [basic_crud_example.dart](basic_crud_example.dart) | Compiled only; running requires application configuration or a long-running server. Requires the documented REST server fixture on localhost. |
| [custom_repository_example.dart](custom_repository_example.dart) | Compiled only; running requires application configuration or a long-running server. Requires custom query routes on a separately running REST server. |
| [error_handling_example.dart](error_handling_example.dart) | Compiled only; running requires application configuration or a long-running server. Requires a separately running REST server to exercise transport failures. |

Each program contains its complete imports and application model/context. Inspect
its constants and prerequisites before running it manually from this directory.
Use disposable test databases and credentials. Do not treat sample users, signing
secrets, endpoints or authorization policies as production configuration.

Generated `.g.dart` parts belong to their handwritten model library. Run the
example lane after changing models; do not reuse old generated parts. Custom
repository implementation parts must share that library so generated private
helpers remain accessible. Follow the [supported contracts](../../../docs/CAPABILITIES.md)
for identity, persistence, conditional writes, optional auth and event publication.
