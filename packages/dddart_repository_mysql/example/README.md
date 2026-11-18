# dddart_repository_mysql examples

Start the [disposable MySQL database](../../../docs/quickstarts/mysql/README.md#start-mysql). The settings below connect to that container.

From the root of a DDDart checkout, run the following with the [example pubspec](pubspec.yaml).

```sh
cd packages/dddart_repository_mysql/example
dart pub get
dart run build_runner build --delete-conflicting-outputs
export MYSQL_PORT=3307 MYSQL_DATABASE=test_db MYSQL_USER=root MYSQL_PASSWORD=test_password
dart run basic_crud_example.dart
```

## Choose a program

| Program | How it runs | What it shows |
| --- | --- | --- |
| [basic_crud_example.dart](basic_crud_example.dart) | Local database | Persist an order and its line items together. |
| [connection_management_example.dart](connection_management_example.dart) | Local database | Open and close connections and handle connection failures. |
| [custom_repository_example.dart](custom_repository_example.dart) | Local database | Find orders by customer or minimum amount. |
| [error_handling_example.dart](error_handling_example.dart) | Local database | Handle repository exceptions while working with MySQL. |
