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

Implementation `aa8a8d2`; HTTP example formatting/README synchronization through
`d813dbb`; external public-contract assertion refined at `7051bfa`. The integrated
sequence ran across these commits. Runtime implementation did not change after
`aa8a8d2`; the later AppSync consumer and example lanes tested those refinements.
All commands below passed using Dart 3.13.7. Commands run from the repository root
unless otherwise stated.

| Command | Result |
| --- | --- |
| `dart tool/validation/validate.dart check` | Inventory covers 18 public packages and 15 examples; deleted sketches have no stale exclusions. |
| `dart tool/validation/validate.dart package dddart --mode=ci` | 231 tests; includes local delivery and safe pending-event publication/acknowledgment. |
| `dart tool/validation/validate.dart package dddart_serialization --mode=ci` | 23 tests. |
| `dart tool/validation/validate.dart package dddart_json --mode=ci` | 114 tests, including generated consumers and invalid generation inputs. |
| `dart tool/validation/validate.dart package dddart_events_distributed --mode=ci` | 58 tests, including 9 new real-HTTP/lifecycle cases and the isolated generated HTTP-only consumer. |
| `dart tool/validation/validate.dart package dddart_events_appsync --mode=ci` | 18 tests, including native/protocol fixtures and the isolated dual-transport consumer. |
| `dart tool/validation/validate.dart package dddart_events_dynamodb --mode=ci` | 8 tests against DynamoDB Local 3.1.0. |
| `dart tool/validation/validate.dart consumer NAME` for distributed, AppSync and DynamoDB event packages | All three isolated archive consumers resolve only their permitted local package closures, analyze and run. |
| `dart tool/validation/validate.dart example NAME --mode=ci` for all three event example packages | HTTP/custom-JSON examples run; AppSync native invocation runs and Lambda/live smoke compile; DynamoDB example runs on an isolated local table. |
| `npm ci` then `npm run check` from `website` | Node 24.15.0; builds 14 pages and checks 806 links/assets plus 12 searchable guides. |

Package gates include generation where required, fatal-info analysis, formatting
and the applicable publish dry-run policy. Core's dry-run has zero warnings; the
other five packages remain explicitly non-publishable and are dry-run exempt.
DynamoDB Local used an isolated in-memory container bound to loopback port 8000;
tests/examples clean their own tables and the container is removed afterward.

A final search found no active references to removed types in package code,
tests, examples, current reference/handoff documents or website content.
Intentional removal notes and historical changelog/work records retain their
names. The README HTTP program was compared with its runnable source exactly.
No live AWS deployment, production credential use, package publication or merge
of this PR or its parent PRs was performed. Local protocol fixtures are not a
claim of a live AppSync acceptance run.
