# dddart_events_distributed examples

Run the HTTP polling example for publication and delivery over a loopback server. It needs no AWS resources. See the [package guide](../README.md) for its API.

## Run from a checkout

Resolve the workspace, then run this lane from the repository root. It uses
the [example pubspec](pubspec.yaml) for dependencies and generation.

```sh
dart pub get
dart tool/validation/validate.dart example dddart_events_distributed_example --mode=ci
```

## Programs

| Program | How it runs | What it shows |
| --- | --- | --- |
| [custom_stored_event_json_example.dart](custom_stored_event_json_example.dart) | Local run | Round-trips a custom StoredEvent subtype with generated JSON. |
| [http_polling.dart](http_polling.dart) | Local run | Finite real HTTP publish/watch example using shared interfaces, local history and explicit fixture credentials; no AppSync or AWS dependency. |
