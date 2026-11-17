# dddart_events_appsync examples

Start with the finite native invocation example. Follow the [deployment guide](../DEPLOY.md) for the optional Lambda and live smoke programs. See the [package guide](../README.md) for its API.

## Run from a checkout

Resolve the workspace, then run this lane from the repository root. It uses
the [example pubspec](pubspec.yaml) for dependencies and generation.

```sh
dart pub get
dart tool/validation/validate.dart example dddart_events_appsync_example --mode=ci
```

## Programs

| Program | How it runs | What it shows |
| --- | --- | --- |
| [native_invocation.dart](native_invocation.dart) | Local run | Finite native invocation with explicit local test authentication. |
| [lambda.dart](lambda.dart) | Compile only | Complete custom runtime, requiring explicit AWS deployment. |
| [aws_smoke.dart](aws_smoke.dart) | Compile only | Explicit opt-in smoke against existing AWS resources. |

Compile-only programs need the configuration or running server indicated above.
