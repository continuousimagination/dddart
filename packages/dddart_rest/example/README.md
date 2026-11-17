# dddart_rest examples

Start with the finite public leaderboard and ETag examples. The server examples need a client or configured identity provider to exercise their routes. See the [package guide](../README.md) for its API.

## Run from a checkout

Resolve the workspace, then run this lane from the repository root. It uses
the [example pubspec](pubspec.yaml) for dependencies and generation.

```sh
dart pub get
dart tool/validation/validate.dart example dddart_rest_example --mode=ci
```

## Programs

| Program | How it runs | What it shows |
| --- | --- | --- |
| [authorization_example.dart](authorization_example.dart) | Compile only | Long-running HTTP server; compile validation avoids binding a shared port. |
| [custom_routes_example.dart](custom_routes_example.dart) | Compile only | Long-running HTTP server; compile validation avoids binding a shared port. |
| [etag_concurrency_example.dart](etag_concurrency_example.dart) | Local run | Self-contained HTTP concurrency regression uses an ephemeral loopback port and closes its server. |
| [main.dart](main.dart) | Compile only | Long-running HTTP server; compile validation avoids binding a shared port. |
| [oauth_auth_example.dart](oauth_auth_example.dart) | Compile only | Requires user-supplied OAuth/OIDC configuration and tokens. |
| [public_leaderboard_example.dart](public_leaderboard_example.dart) | Local run | Finite local HTTP demonstration of public leaderboard reads, protected writes, scoped private documents and unconfigured public CRUD; no external credentials. |
| [self_hosted_auth_example.dart](self_hosted_auth_example.dart) | Compile only | Long-running authenticated HTTP server; compile validation avoids binding a shared port. |

Compile-only programs need the configuration or running server indicated above.
