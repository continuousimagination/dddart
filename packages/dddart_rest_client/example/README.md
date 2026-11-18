# dddart_rest_client examples

Print the available CLI commands first. To try login, configure the API URL and client ID in the program for your device-flow server.

From the root of a DDDart checkout, run the following with the [example pubspec](pubspec.yaml).

```sh
cd packages/dddart_rest_client/example
dart pub get
dart run cli_tool_example.dart help
```

The `help` command works locally. `login` and the data commands require the configured server.

[cli_tool_example.dart](cli_tool_example.dart) — Log in with device flow, store credentials and call a user API.
