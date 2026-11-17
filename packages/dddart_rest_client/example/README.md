# dddart_rest_client examples

Use the CLI with a configured device-flow server. Match its URL and client ID to your server, and provide the routes the commands call. See the [public HTTP quickstart](../../../docs/quickstarts/rest/README.md) for an anonymous example. See the [package guide](../README.md) for its API.

## Run from a checkout

Resolve the workspace, then run this lane from the repository root. It uses
the [example pubspec](pubspec.yaml) for dependencies and generation.

```sh
dart pub get
dart tool/validation/validate.dart example dddart_rest_client_example --mode=ci
```

## Programs

| Program | How it runs | What it shows |
| --- | --- | --- |
| [cli_tool_example.dart](cli_tool_example.dart) | Compile only | Requires a separately configured authenticated dddart_rest server; validation compiles it without accessing credentials or the network. |

Compile-only programs need the configuration or running server indicated above.
