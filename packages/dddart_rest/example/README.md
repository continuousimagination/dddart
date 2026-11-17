# dddart_rest_example examples

These are maintained application samples for [dddart_rest](../README.md).
For a fresh application outside the checkout, start with the
[standalone workflows](../../../docs/QUICKSTARTS.md). These repository examples use
the workspace's package resolution and are not hosted-installation evidence.

## Setup and validation

Use Dart 3.13.7 from the repository root. Resolve workspace tooling with
`dart pub get`, then run the lane below. It resolves the example package,
regenerates its declared parts when required, analyzes with fatal infos, compiles
each program, runs eligible finite/service programs and cleans temporary outputs.

```sh
dart tool/validation/validate.dart example dddart_rest_example --mode=ci
```

Required local services must be available; CI mode fails when they are missing.
The [service setup](../../../scripts/README.md) and
[shared inventory](../../../tool/validation/inventory.json) specify host/port,
builders and verification boundaries. Tests using local services do not verify a
cloud deployment or application credentials.

## Programs

| Source | Coverage / runtime context |
| --- | --- |
| [authorization_example.dart](authorization_example.dart) | Compiled only; running requires application configuration or a long-running server. Long-running HTTP server; compile validation avoids binding a shared port. |
| [custom_routes_example.dart](custom_routes_example.dart) | Compiled only; running requires application configuration or a long-running server. Long-running HTTP server; compile validation avoids binding a shared port. |
| [etag_concurrency_example.dart](etag_concurrency_example.dart) | Compiled and run; finite local demonstration. Self-contained HTTP concurrency regression uses an ephemeral loopback port and closes its server. |
| [main.dart](main.dart) | Compiled only; running requires application configuration or a long-running server. Long-running HTTP server; compile validation avoids binding a shared port. |
| [oauth_auth_example.dart](oauth_auth_example.dart) | Compiled only; running requires application configuration or a long-running server. Requires user-supplied OAuth/OIDC configuration and tokens. |
| [public_leaderboard_example.dart](public_leaderboard_example.dart) | Compiled and run; finite local demonstration. Finite local HTTP demonstration of public leaderboard reads, protected writes, scoped private documents and unconfigured public CRUD; no external credentials. |
| [self_hosted_auth_example.dart](self_hosted_auth_example.dart) | Compiled only; running requires application configuration or a long-running server. Long-running authenticated HTTP server; compile validation avoids binding a shared port. |

Each program contains its complete imports and application model/context. Inspect
its constants and prerequisites before running it manually from this directory.
Use disposable test databases and credentials. Do not treat sample users, signing
secrets, endpoints or authorization policies as production configuration.

Generated `.g.dart` parts belong to their handwritten model library. Run the
example lane after changing models; do not reuse old generated parts. Custom
repository implementation parts must share that library so generated private
helpers remain accessible. Follow the [supported contracts](../../../docs/CAPABILITIES.md)
for identity, persistence, conditional writes, optional auth and event publication.
