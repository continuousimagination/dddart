# dddart_repository_sqlite examples

These examples use an in-memory SQLite database through the native shared library. They generate and run without a database server. See the [package guide](../README.md) for its API.

## Run from a checkout

Resolve the workspace, then run this lane from the repository root. It uses
the [example pubspec](pubspec.yaml) for dependencies and generation.

```sh
dart pub get
dart tool/validation/validate.dart example dddart_repository_sqlite_example --mode=ci
```

## Programs

| Program | How it runs | What it shows |
| --- | --- | --- |
| [basic_crud_example.dart](basic_crud_example.dart) | Local run | Finite in-memory SQLite CRUD demonstration. |
| [complex_aggregate_example.dart](complex_aggregate_example.dart) | Local run | Round-trips an order with entity items and embedded values in memory. |
| [custom_repository_example.dart](custom_repository_example.dart) | Local run | Finite in-memory SQLite custom repository demonstration. |
