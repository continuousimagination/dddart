# dddart_config examples

Load and validate settings from YAML, an environment map, or a custom provider. See the [package guide](../README.md) for its API.

## Run from a checkout

Resolve the workspace, then run this lane from the repository root. It uses
the [example pubspec](pubspec.yaml) for dependencies and generation.

```sh
dart pub get
dart tool/validation/validate.dart example dddart_config_example --mode=ci
```

## Programs

| Program | How it runs | What it shows |
| --- | --- | --- |
| [basic_usage.dart](basic_usage.dart) | Local run | Finite script-relative YAML configuration demonstration. |
| [reload_example.dart](reload_example.dart) | Local run | Finite reload demonstration using a system temporary file. |
| [section_access.dart](section_access.dart) | Local run | Finite section-access demonstration. |
| [underscore_demo.dart](underscore_demo.dart) | Local run | Finite environment-key mapping demonstration. |
| [validation_example.dart](validation_example.dart) | Local run | Finite configuration-validation demonstration. |
