# dddart_repository_mysql examples

Start the [disposable MySQL service](../../../docs/quickstarts/mysql/README.md) before running this lane. See the [package guide](../README.md) for its API.

## Run from a checkout

Resolve the workspace, then run this lane from the repository root. It uses
the [example pubspec](pubspec.yaml) for dependencies and generation.

```sh
dart pub get
dart tool/validation/validate.dart example dddart_repository_mysql_example --mode=ci
```

## Programs

| Program | How it runs | What it shows |
| --- | --- | --- |
| [basic_crud_example.dart](basic_crud_example.dart) | Local database | Finite CRUD demonstration backed by the policy-provisioned MySQL database. |
| [connection_management_example.dart](connection_management_example.dart) | Local database | Finite connection lifecycle demonstration backed by MySQL. |
| [custom_repository_example.dart](custom_repository_example.dart) | Local database | Finite generated custom repository demonstration backed by MySQL. |
| [error_handling_example.dart](error_handling_example.dart) | Local database | Finite repository error-mapping demonstration backed by MySQL. |
