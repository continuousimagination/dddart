# dddart examples

Build and query domain objects, react to events, or try a revision check locally. See the [package guide](../README.md) for its API.

## Run from a checkout

Resolve the workspace, then run this lane from the repository root. It uses
the [example pubspec](pubspec.yaml) for dependencies and generation.

```sh
dart pub get
dart tool/validation/validate.dart example dddart_events_example --mode=ci
```

## Programs

| Program | How it runs | What it shows |
| --- | --- | --- |
| [conditional_writes.dart](conditional_writes.dart) | Local run | Finite detached revision-read, confirmed conflict and deliberate retry demonstration. |
| [error_handling_example.dart](error_handling_example.dart) | Local run | Finite in-process domain-event error-handling demonstration. |
| [event_serialization_example.dart](event_serialization_example.dart) | Local run | Finite manual domain-event serialization demonstration. |
| [events_example.dart](events_example.dart) | Local run | Finite in-process domain-event demonstration. |
| [logging_console.dart](logging_console.dart) | Local run | Finite console logging demonstration. |
| [logging_file.dart](logging_file.dart) | Local run | Finite logging demonstration isolated in a system temporary directory. |
| [logging_hierarchical.dart](logging_hierarchical.dart) | Local run | Finite hierarchical logging demonstration. |
| [event_publication.dart](event_publication.dart) | Local run | Finite assertions for captured pending events, rejection and accepted retry. |
