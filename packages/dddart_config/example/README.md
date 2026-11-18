# dddart_config examples

Read typed settings from the supplied YAML file, then override a value through the environment.

From the root of a DDDart checkout, run the following with the [example pubspec](pubspec.yaml).

```sh
cd packages/dddart_config/example
dart pub get
dart run basic_usage.dart
```

## Choose a program

| Program | How it runs | What it shows |
| --- | --- | --- |
| [basic_usage.dart](basic_usage.dart) | Local run | Read YAML settings with environment overrides. |
| [reload_example.dart](reload_example.dart) | Local run | Edit a settings file and reload the running configuration. |
| [section_access.dart](section_access.dart) | Local run | Read a whole section of nested settings. |
| [underscore_demo.dart](underscore_demo.dart) | Local run | Map environment variable names to nested keys and literal underscores. |
| [validation_example.dart](validation_example.dart) | Local run | Check required settings at startup. |
