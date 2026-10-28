# Distributed events examples

The active `custom_stored_event_json_example.dart` proves a generated JSON
round trip for a concrete `StoredEvent<UuidValue>` subtype with application fields.
Run from this directory:

```bash
dart pub get
dart run build_runner build --delete-conflicting-outputs
dart run custom_stored_event_json_example.dart
```

Its build enables only `dddart_json:json_serializable` for
`lib/custom_stored_event.dart`; it makes no transport-envelope claim. The package's
separate identity fixture and clean-consumer tests prove current generated event
registries, native/scoped/UUID references, forwarding/filtering and cursor retry.
See the package README for the current combined-part workflow.

Old client/server/range sketches remain excluded under `legacy/` as `.skip` files.
Their unrelated EVENT-001 through EVENT-004 and optional transport work remains
deferred. They are historical context, not runnable framework contracts.
