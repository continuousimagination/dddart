# dddart_events_distributed examples

Watch one aggregate over HTTP, publish an event, and wait for it to reach the listener. The example supplies a loopback server and local credentials.

From the root of a DDDart checkout, run the following with the [example pubspec](pubspec.yaml).

```sh
cd packages/dddart_events_distributed/example
dart pub get
dart run http_polling.dart
```

For the custom stored event, first run `dart run build_runner build --delete-conflicting-outputs` in this example directory.

## Choose a program

| Program | How it runs | What it shows |
| --- | --- | --- |
| [custom_stored_event_json_example.dart](custom_stored_event_json_example.dart) | Local run | Round-trip a custom stored event with generated JSON. |
| [http_polling.dart](http_polling.dart) | Local run | Publish and receive an aggregate event through the HTTP polling transport. |
