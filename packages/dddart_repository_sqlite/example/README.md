# dddart_repository_sqlite examples

Use a native Dart process with the SQLite shared library installed. The sample creates its database in memory.

From the root of a DDDart checkout, run the following with the [example pubspec](pubspec.yaml).

```sh
cd packages/dddart_repository_sqlite/example
dart pub get
dart run build_runner build --delete-conflicting-outputs
dart run basic_crud_example.dart
```

## Choose a program

| Program | How it runs | What it shows |
| --- | --- | --- |
| [basic_crud_example.dart](basic_crud_example.dart) | Local run | Save, reload, update and delete a user in SQLite. |
| [complex_aggregate_example.dart](complex_aggregate_example.dart) | Local run | Round-trip an order with child entities and embedded values. |
| [custom_repository_example.dart](custom_repository_example.dart) | Local run | Add application queries such as finding active users. |
