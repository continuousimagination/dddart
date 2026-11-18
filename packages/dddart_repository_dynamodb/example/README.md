# dddart_repository_dynamodb examples

Start [DynamoDB Local](../../../docs/quickstarts/dynamodb/README.md#start-dynamodb-local). Use a disposable instance for these examples.

From the root of a DDDart checkout, run the following with the [example pubspec](pubspec.yaml).

```sh
cd packages/dddart_repository_dynamodb/example
dart pub get
dart run build_runner build --delete-conflicting-outputs
dart run basic_crud_example.dart
```

## Choose a program

| Program | How it runs | What it shows |
| --- | --- | --- |
| [basic_crud_example.dart](basic_crud_example.dart) | Local database | Store, fetch and delete a user by ID. |
| [custom_interface_example.dart](custom_interface_example.dart) | Local database | Query users by email or last name with secondary indexes. |
| [error_handling_example.dart](error_handling_example.dart) | Local database | Handle a repository lookup failure. |
| [local_development_example.dart](local_development_example.dart) | Local database | Connect to a local instance and exercise the generated repository. |
| [table_creation_example.dart](table_creation_example.dart) | Local database | Create local tables and inspect the generated AWS CLI and CloudFormation definitions. |
