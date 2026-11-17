# dddart_repository_rest examples

These client programs need a running REST API with the matching resources and query handlers. For a server and a client together, use the [HTTP quickstart](../../../docs/quickstarts/rest/README.md). See the [package guide](../README.md) for its API.

## Run from a checkout

Resolve the workspace, then run this lane from the repository root. It uses
the [example pubspec](pubspec.yaml) for dependencies and generation.

```sh
dart pub get
dart tool/validation/validate.dart example dddart_repository_rest_example --mode=ci
```

## Programs

| Program | How it runs | What it shows |
| --- | --- | --- |
| [authentication_example.dart](authentication_example.dart) | Compile only | Requires a separately running authenticated REST server. |
| [basic_crud_example.dart](basic_crud_example.dart) | Compile only | Requires the documented REST server fixture on localhost. |
| [custom_repository_example.dart](custom_repository_example.dart) | Compile only | Requires custom query routes on a separately running REST server. |
| [error_handling_example.dart](error_handling_example.dart) | Compile only | Requires a separately running REST server to exercise transport failures. |

Compile-only programs need the configuration or running server indicated above.
