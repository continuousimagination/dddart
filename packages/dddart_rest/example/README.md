# dddart_rest examples

Read a public leaderboard and see what happens when an anonymous caller tries to write a score. The program starts and stops its own local server.

From the root of a DDDart checkout, run the following with the [example pubspec](pubspec.yaml).

```sh
cd packages/dddart_rest/example
dart pub get
dart run public_leaderboard_example.dart
```

## Choose a program

| Program | How it runs | What it shows |
| --- | --- | --- |
| [authorization_example.dart](authorization_example.dart) | Configured integration | Restrict access by resource ownership. |
| [custom_routes_example.dart](custom_routes_example.dart) | Configured integration | Serve custom Shelf routes alongside CRUD routes. |
| [etag_concurrency_example.dart](etag_concurrency_example.dart) | Local run | Detect a stale update when two HTTP clients edit the same record. |
| [main.dart](main.dart) | Configured integration | Serve an aggregate through CRUD endpoints. |
| [oauth_auth_example.dart](oauth_auth_example.dart) | Configured integration | Validate tokens with your OAuth/OIDC provider. |
| [public_leaderboard_example.dart](public_leaderboard_example.dart) | Local run | Allow anonymous reads and authorize writes on the same leaderboard. |
| [self_hosted_auth_example.dart](self_hosted_auth_example.dart) | Configured integration | Run a device-flow server with in-memory credentials. |
