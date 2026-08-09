# Distributed events example status

The distributed client, server, registry, and bulk time-range examples are
legacy work-in-progress surfaces. They are preserved under `legacy/` as `.skip`
files and are not runnable. Their contracts remain deferred to EVENT-001 through
EVENT-004; this directory makes no current guarantee about registry generation,
HTTP transport, polling, or bulk-range semantics.

## Active JSON example

The one active example is an independent `dddart_json` round-trip for a
`StoredEvent` subtype with extra application fields. It exercises the current
JSON-004 constructor and inherited-field behavior only.

From this directory:

```bash
dart pub get
dart run build_runner clean
dart run build_runner build --delete-conflicting-outputs
dart run custom_stored_event_json_example.dart
```

The build config explicitly disables the deferred distributed-event registry
builder and generates only `lib/custom_stored_event.g.dart` with
`dddart_json:json_serializable`.
