# dddart_repository_mongodb examples

Start the [disposable MongoDB service](../../../docs/quickstarts/mongodb/README.md#start-mongodb) before running a program.

From the root of a DDDart checkout, run the following with the [example pubspec](pubspec.yaml).

```sh
cd packages/dddart_repository_mongodb/example
dart pub get
dart run build_runner build --delete-conflicting-outputs
dart run basic_crud_example.dart
```

## Choose a program

| Program | How it runs | What it shows |
| --- | --- | --- |
| [basic_crud_example.dart](basic_crud_example.dart) | Local database | Store and retrieve a user as a MongoDB document. |
| [config_integration_example.dart](config_integration_example.dart) | Local database | Build a MongoDB connection from application settings. |
| [custom_interface_example.dart](custom_interface_example.dart) | Local database | Find users by email or last name. |
| [error_handling_example.dart](error_handling_example.dart) | Local database | Handle missing documents and other repository errors. |
| [repository_swapping_example.dart](repository_swapping_example.dart) | Local database | Swap the repository used by the same application code. |
