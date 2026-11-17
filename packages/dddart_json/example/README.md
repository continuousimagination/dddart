# dddart_json examples

Generate serializers and round-trip aggregate state and enums. See the [package guide](../README.md) for its API.

## Run from a checkout

Resolve the workspace, then run this lane from the repository root. It uses
the [example pubspec](pubspec.yaml) for dependencies and generation.

```sh
dart pub get
dart tool/validation/validate.dart example dddart_json_example --mode=ci
```

## Programs

| Program | How it runs | What it shows |
| --- | --- | --- |
| [enum_example_runner.dart](enum_example_runner.dart) | Local run | Finite generated enum round-trip demonstration. |
| [serialization_example.dart](serialization_example.dart) | Local run | Finite generated aggregate serialization demonstration. |
