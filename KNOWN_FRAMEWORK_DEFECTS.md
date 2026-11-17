# Framework defect register

Updated for the 1.0-readiness integration on 2026-11-17. No unresolved entry from
this register remains in the supported APIs. This is not an exhaustive issue
tracker or a claim that all release work is complete; source, executable tests
and the issue tracker remain authoritative.

## Reconciled event entries

| ID | Disposition | Evidence in the supported API |
| --- | --- | --- |
| EVENT-001 | Already repaired by the combined serializer/registry generation work; verified again during #108. | `event_registry_generator_test.dart` and `clean_consumer_generation_test.dart` generate one owning part, compile public consumers, and round-trip typed domain events. Removing a transport does not itself fix a generator. |
| EVENT-002 | Obsolete with the timestamp ingestion endpoint/server removal in #108. | `AggregateEventHttpEndpoints` accepts `EventEnvelope` through `AggregateEventService`, awaits processing, and uses a separate shared history contract. Arbitrary stored-subtype ingestion is not promised. |
| EVENT-003 | Legacy auto-forward implementation removed in #108. | Shared-client remote receipt uses `EventBus.deliver`; `http_aggregate_transport_test.dart` verifies no `onPublished` echo, and AppSync protocol tests exercise the same client. |
| EVENT-004 | Timestamp cursor implementation removed in #108. | Supported history uses committed ingestion positions, not occurrence timestamps. Watch/history tests cover catch-up, deduplication and expiration. Unknown or malformed event payloads deliberately log/skip while valid progress advances; retrying those payloads is not a new guarantee. |

Event suites live under `packages/dddart_events_distributed/test` and
`packages/dddart_events_appsync/test`; DynamoDB Local tests additionally cover
durable transaction/retention behavior. Existing limits remain: bounded overlap
deduplication, best-effort revocation, no transactional outbox and no exactly-once
consumer processing. See `docs/DISTRIBUTED_EVENTS.md` for the supported contracts.

## Resolved concurrency regression

REST-004 was resolved by #91. REST validators now carry coherent storage
revisions and requested conditions execute through atomic repository operations.
The regression in `packages/dddart_repository_mysql/test/rest_concurrency_integration_test.dart`
uses two HTTP servers and independent MySQL connections: exactly one competing
If-Match write succeeds. REST and generated-client suites also cover absence,
recreation, unsupported capabilities and uncertain outcomes. Unconditional CRUD
remains optional by design; `requirePrecondition` enables mandatory conditions.

## Resolved optional authorization regressions

AUTH-002 and the proposed-owner mutation bypass were resolved by #92. Every item
and collection read now resolves an explicit policy. Anonymous public operations
remain supported on otherwise protected resources. Custom policies receive typed
callers, persisted/current/proposed snapshots and explicit application query scopes.
Custom mutations bind permission to a stored revision and POST is create-only.
Aggregate policies use an explicit complete domain snapshot function, so a lossy
public response projection cannot change the owner/permission state they inspect.

`packages/dddart_rest/test/read_authorization_test.dart`,
`mutation_authorization_test.dart`, and `optional_auth_http_test.dart` cover private
read denial, scoped rows/counts, public objects, forged fields, create/update bypass,
ownership races, event retention and the real HTTP caller/operation matrix.
`example/public_leaderboard_example.dart` runs all three intended use cases:
public leaderboard/protected writes, private documents with public objects, and
unconfigured public CRUD. Domain query scoping remains application-owned. Basic
repositories cannot provide atomic custom mutation enforcement and fail closed;
plain public CRUD retains its documented concurrent-creation limitation.
