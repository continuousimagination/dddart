# dddart_repository_mongodb examples

Start the [disposable MongoDB service](../../../docs/quickstarts/mongodb/README.md) before running this lane. See the [package guide](../README.md) for its API.

## Run from a checkout

Resolve the workspace, then run this lane from the repository root. It uses
the [example pubspec](pubspec.yaml) for dependencies and generation.

```sh
dart pub get
dart tool/validation/validate.dart example dddart_repository_mongodb_example --mode=ci
```

## Programs

| Program | How it runs | What it shows |
| --- | --- | --- |
| [basic_crud_example.dart](basic_crud_example.dart) | Local database | Finite CRUD demonstration backed by the policy-provisioned MongoDB service. |
| [config_integration_example.dart](config_integration_example.dart) | Local database | Finite configuration integration backed by MongoDB. |
| [custom_interface_example.dart](custom_interface_example.dart) | Local database | Finite generated custom repository demonstration backed by MongoDB. |
| [error_handling_example.dart](error_handling_example.dart) | Local database | Finite repository error-mapping demonstration backed by MongoDB. |
| [repository_swapping_example.dart](repository_swapping_example.dart) | Local database | Finite repository swapping demonstration backed by MongoDB. |
