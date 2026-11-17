# Shared event transport cleanup — issue #108

Base: authorization integration `1d339a0` (PR #111), which includes concurrency
PR #110. This issue is a separate PR stacked on #111 until its parents merge.
No parent PR is merged as part of this work. 1.0 is the first compatibility
baseline; no deprecated aliases, old timestamp cursor conversion or migration
layer is introduced.

## Supported architecture

One `AggregateEventClient` consumes `AggregateEventTransport`. HTTP supplies
polling and publication; AppSync adds the optional live capability and retains
HTTP control/history recovery. Both use the same `EventPublisher` hook for
repository saves. Retained `StoredEvent`, codecs/registrations, envelopes, typed
references, ingestion history, channel repositories and local/pending-event
contracts remain functional. Event credential/membership policy and optional
CRUD authentication are unchanged.

Removed the timestamp client/server/endpoints, their event repository interface
and in-memory implementation, and the exclusively legacy example sketches.
The unused legacy test-helper file and direct `uuid` dependency are removed.
The custom stored-record JSON example remains, independently of transport.

## Test classification before deletion

| Legacy tests | Disposition / supported coverage |
| --- | --- |
| `polling_retrieval_property_test`, timestamp ordering/cursor cases in `event_bus_client_test` | Timestamp semantics removed. `aggregate_history_test` and `aggregate_watch_test` cover committed ingestion positions, paging, tied/backdated occurrences, catch-up, bounded deduplication and expiration. |
| `cleanup_property_test`, `cleanup_integration_test` | Deleted background timestamp-server cleanup semantics. Shared in-memory history and DynamoDB Local suites cover ingestion-time retention and recovery floors. |
| `auto_forward_property_test`, `disabled_forwarding_property_test`, `event_persistence_property_test` | Deleted automatic forwarding/background persistence options. `retrying_event_publisher_test` and core pending-event tests retain acceptance/acknowledgment guarantees. New real-HTTP tests prove accepted retry identity and remote delivery without local re-publication. |
| `event_http_endpoints_test`, `authorization_filter_property_test`, `authorization_integration_test`, `no_filter_property_test`, `end_to_end_integration_test` | Deleted timestamp GET/filter/subtype-ingestion protocol. New real-HTTP tests cover the shared endpoint authentication, per-reference denial, exception containment, malformed identity/envelope rejection, retry classification and typed delivery. Existing watch/native-handler suites cover independent subscription/publication permissions and revocation. |
| `event_registry_deserialization_property_test`, `unknown_event_types_property_test` | Deleted wrappers exercising the old poller. Retained generated registry/StoredEvent property tests cover serialization; shared-watch tests cover unknown/malformed payload log/skip and subsequent progress. |
| `identity_events_test` | Retained generated UUID/native/scoped identity and metadata checks. Moved real transport identity coverage to `http_aggregate_transport_test`; removed old custom timestamp-ingestion and cursor-repair assumptions. |
| HTTP credential/cancellation cases in `event_bus_client_test` | New `http_aggregate_transport_test` covers per-request credentials, missing credentials and permanent/transient rejection. `http_transport_lifecycle_test` covers header/body timeout cancellation, late close and configured timeouts. Existing shared-watch tests cover suspension, refresh and single-flight recovery. |

The isolated generated HTTP consumer explicitly excludes AppSync from its resolved
package graph. A second isolated consumer, in the AppSync package, compiles both
implementations through `AggregateEventTransport`, `AggregateEventClient` and
`EventPublisher` using only public imports. Existing AppSync tests retain real
serialized local WebSocket/native-handler coverage; no second SDK or fake
replacement interface was added.

## Documentation and example ownership

`example/http_polling.dart` starts and closes a loopback server, accepts an event,
and waits for polling delivery. The package README includes its complete source
and shows AppSync transport configuration with the same client. The shared
validation inventory owns the runnable HTTP and custom-JSON examples and no
longer excludes deleted legacy sketches. Current package, generator, reference,
website and application handoff documentation describe the shared interfaces.

EVENT-001 is reconciled against existing combined-part generation tests; deletion
alone is not its fix. EVENT-002–004's timestamp implementations are removed.
Supported payload skip policy, bounded deduplication, best-effort revocation and
lack of outbox/exactly-once processing remain documented limits.

## Validation

Validation results are recorded after the integrated lanes complete. No live AWS
deployment or production credential use is part of this issue.
