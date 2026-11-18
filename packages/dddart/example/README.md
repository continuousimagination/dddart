# dddart examples

Start here to see an aggregate raise an event and a listener react in the same process.

From the root of a DDDart checkout, run the following with the [example pubspec](pubspec.yaml).

```sh
cd packages/dddart/example
dart pub get
dart run events_example.dart
```

## Choose a program

| Program | How it runs | What it shows |
| --- | --- | --- |
| [conditional_writes.dart](conditional_writes.dart) | Local run | Handle a stale revision by reloading and reapplying an edit. |
| [error_handling_example.dart](error_handling_example.dart) | Local run | Handle a failure in an event listener. |
| [event_serialization_example.dart](event_serialization_example.dart) | Local run | Serialize and reconstruct a domain event by hand. |
| [events_example.dart](events_example.dart) | Local run | Raise an event and subscribe to its type. |
| [logging_console.dart](logging_console.dart) | Local run | Send framework logs to the console. |
| [logging_file.dart](logging_file.dart) | Local run | Write log records to a temporary file. |
| [logging_hierarchical.dart](logging_hierarchical.dart) | Local run | Choose different log levels for individual components. |
| [event_publication.dart](event_publication.dart) | Local run | Keep rejected events pending and acknowledge a successful retry. |
