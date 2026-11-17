# Distributed event examples

From the workspace root:

```bash
dart pub get
dart run packages/dddart_events_distributed/example/http_polling.dart
dart tool/validation/validate.dart example dddart_events_distributed_example
```

`http_polling.dart` is a finite HTTP-only publish/watch example. It uses the shared
`AggregateEventTransport`, `AggregateEventClient` and `EventPublisher` contracts,
with an ephemeral loopback server, explicit local fixture authentication and
in-memory history/channel repositories. It prints the received counter value and
closes its resources. It requires no AppSync dependency, AWS account or database.

`custom_stored_event_json_example.dart` independently demonstrates generated JSON
for a concrete `StoredEvent` subtype. Its input is `lib/custom_stored_event.dart`;
`build.yaml` enables the JSON builder and disables the registry builder because
this example declares no domain event to register. The validation lane generates,
analyzes and runs the example. Generate manually before running it directly:

```bash
cd packages/dddart_events_distributed/example
dart run build_runner build --delete-conflicting-outputs
dart run custom_stored_event_json_example.dart
```

For optional live transport, reuse the [AppSync examples](../../dddart_events_appsync/example/)
and [protocol fixtures](../../dddart_events_appsync/test/websocket_protocol_test.dart).
The same application client/publisher APIs work with either transport.
