# dddart_json examples

Start with an order and inspect how its items and values are represented in JSON.

From the root of a DDDart checkout, run the following with the [example pubspec](pubspec.yaml).

```sh
cd packages/dddart_json/example
dart pub get
dart run build_runner build --delete-conflicting-outputs
dart run serialization_example.dart
```

## Choose a program

| Program | How it runs | What it shows |
| --- | --- | --- |
| [enum_example_runner.dart](enum_example_runner.dart) | Local run | Preserve enum values through a JSON round trip. |
| [serialization_example.dart](serialization_example.dart) | Local run | Generate JSON for an order and change how fields are named. |
