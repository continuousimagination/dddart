# dddart_repository_rest examples

These clients need an API that serves the matching model. Start a compatible `/users` endpoint on `localhost:8080` before trying basic CRUD. For a self-contained server and client, use the [public HTTP quickstart](../../../docs/quickstarts/rest/README.md).

From the root of a DDDart checkout, run the following with the [example pubspec](pubspec.yaml).

```sh
cd packages/dddart_repository_rest/example
dart pub get
dart run build_runner build --delete-conflicting-outputs
dart run basic_crud_example.dart
```

For the authenticated example, set `EXAMPLE_API_TOKEN` to a token accepted by your server before running `dart run authentication_example.dart`.

## Choose a program

| Program | How it runs | What it shows |
| --- | --- | --- |
| [authentication_example.dart](authentication_example.dart) | Configured integration | Supply an access token to a protected API. |
| [basic_crud_example.dart](basic_crud_example.dart) | Configured integration | Save, fetch and delete a user through HTTP. |
| [custom_repository_example.dart](custom_repository_example.dart) | Configured integration | Find products by category or price through server-side query routes. |
| [error_handling_example.dart](error_handling_example.dart) | Configured integration | Handle missing resources and connection failures in an HTTP client. |
