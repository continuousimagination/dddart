# dddart_events_dynamodb examples

Start [DynamoDB Local](../../../docs/quickstarts/dynamodb/README.md) before running this lane. See the [package guide](../README.md) for its API.

## Run from a checkout

Resolve the workspace, then run this lane from the repository root. It uses
the [example pubspec](pubspec.yaml) for dependencies and generation.

```sh
dart pub get
dart tool/validation/validate.dart example dddart_events_dynamodb_example --mode=ci
```

## Programs

| Program | How it runs | What it shows |
| --- | --- | --- |
| [history.dart](history.dart) | Local database | Finite history and rotation against an isolated DynamoDB Local table. |
