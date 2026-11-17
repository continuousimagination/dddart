# dddart_repository_dynamodb examples

Start [DynamoDB Local](../../../docs/quickstarts/dynamodb/README.md) before running this lane. See the [package guide](../README.md) for its API.

## Run from a checkout

Resolve the workspace, then run this lane from the repository root. It uses
the [example pubspec](pubspec.yaml) for dependencies and generation.

```sh
dart pub get
dart tool/validation/validate.dart example dddart_repository_dynamodb_example --mode=ci
```

## Programs

| Program | How it runs | What it shows |
| --- | --- | --- |
| [basic_crud_example.dart](basic_crud_example.dart) | Local database | Finite CRUD demonstration backed by DynamoDB Local. |
| [custom_interface_example.dart](custom_interface_example.dart) | Local database | Finite generated custom repository demonstration backed by DynamoDB Local. |
| [error_handling_example.dart](error_handling_example.dart) | Local database | Finite repository error-mapping demonstration backed by DynamoDB Local. |
| [local_development_example.dart](local_development_example.dart) | Local database | Finite DynamoDB Local development demonstration. |
| [table_creation_example.dart](table_creation_example.dart) | Local database | Finite DynamoDB Local table creation demonstration. |
