# dddart_webhooks examples

Each program starts a Shelf server. Supply a local sender with the request format and verifier configuration shown in that program. See the [package guide](../README.md) for its API.

## Run from a checkout

Resolve the workspace, then run this lane from the repository root. It uses
the [example pubspec](pubspec.yaml) for dependencies and generation.

```sh
dart pub get
dart tool/validation/validate.dart example dddart_webhooks_example --mode=ci
```

## Programs

| Program | How it runs | What it shows |
| --- | --- | --- |
| [custom_verifier_example.dart](custom_verifier_example.dart) | Compile only | Long-running webhook server; compile validation avoids binding a shared port. |
| [form_encoded_example.dart](form_encoded_example.dart) | Compile only | Long-running webhook server; compile validation avoids binding a shared port. |
| [raw_json_example.dart](raw_json_example.dart) | Compile only | Long-running webhook server; compile validation avoids binding a shared port. |

Compile-only programs need the configuration or running server indicated above.
