# DDDart capability and support matrix

This is the authoritative summary of the current supported compositions. The
[API inventory](PUBLIC_API.md) defines imports/extension points and the
[quickstart inventory](QUICKSTARTS.md) defines executable setup. **1.0 is the first
compatibility baseline.** Provision fresh pre-release fixtures and regenerate
code; old generated artifacts and schemas are not an upgrade commitment.

The table covers the 18 packages in the [validation inventory](../tool/validation/inventory.json).
It does not select the release set (#97), establish every minimum SDK (#98), or
claim published packages (#99/#100).
A runtime target is not certification of every Flutter device, browser, SDK,
database version or deployed cloud configuration.

| Package | Runtime/composition and prerequisites | Generation | Evidence and limits |
| --- | --- | --- | --- |
| dddart | Domain models, typed identities, repositories and local events on VM; portable domain paths can compile to JS. FileLogHandler requires native IO | None | [Core source](../packages/dddart/lib/dddart.dart), [core workflow](quickstarts/core/README.md), package tests; no durable storage in the reference repositories |
| dddart_serialization | Format-neutral contracts and instance-local identity codecs; no platform IO | None | [Exports](../packages/dddart_serialization/lib/dddart_serialization.dart), [JSON contract](SERIALIZATION.md); no YAML/Protobuf implementation included |
| dddart_json | Generated JSON maps/strings on VM and portable clients when the annotated library has portable imports | build_runner for annotated models | [Generator/parity tests](../packages/dddart_json/test/serializer_contract_test.dart), [JSON workflow](quickstarts/json/README.md); no arbitrary object reflection |
| dddart_config | Provider/lookup contracts; supplied environment and YAML-file providers require native process/filesystem IO | None | [Providers](../packages/dddart_config/lib/dddart_config.dart), finite config examples; custom providers must satisfy their own platform requirements |
| dddart_repository_sql | Runtime connection/dialect/query/mapping extension contracts; actual IO belongs to the concrete adapter | Its `generator.dart` helpers run at build time using analyzer | [Supported exports](PUBLIC_API.md), SQL package tests; not a database adapter, no generic runtime graph traversal |
| dddart_repository_sqlite | Native VM/Flutter composition with a usable SQLite shared library through FFI | Repository and JSON builders | [SQLite workflow](quickstarts/sqlite/README.md), native package/transaction tests; the supplied adapter has **no Web/WASM backend** |
| dddart_repository_mysql | Trusted native server; MySQL connection, InnoDB tables and database permissions | Repository builder (JSON builder when annotated for JSON) | [MySQL workflow](quickstarts/mysql/README.md), MySQL service lane; one physical connection, no pool; entity Set/Map collections are rejected |
| dddart_repository_mongodb | Trusted native server with MongoDB driver/connectivity and collection permissions | Repository and JSON builders | [Mongo workflow](quickstarts/mongodb/README.md), Mongo service lane; DocumentDB compatibility is not established by MongoDB Local tests |
| dddart_repository_dynamodb | Trusted service with DynamoDB SDK credentials/permissions, or disposable local endpoint | Repository and JSON builders | [DynamoDB Local workflow](quickstarts/dynamodb/README.md), local service lane; local tests do not certify AWS IAM, networking, Global Tables or a deployment |
| dddart_repository_rest | Generated HTTP client repository; reachable compatible server | Repository and JSON builders | [Public HTTP workflow](quickstarts/rest/README.md), transport tests; browser CORS/auth composition remains application-owned |
| dddart_repository_indexeddb | Browser native IndexedDB; explicit factory and application encode/decode callbacks | None required | [Native Chrome/VM lanes and limits](../packages/dddart_repository_indexeddb/README.md#validation-and-limits); VM memory backend is a test double, physical WebKit verification remains deferred |
| dddart_rest | Native Shelf server, optional authentication and per-operation policy | JSON/JWT builders for annotated app models/claims; packaged built-in models already generated | [Public/protected example](../packages/dddart_rest/example/public_leaderboard_example.dart), REST tests; server routing is not a browser server |
| dddart_rest_client | HTTP client and optional AuthProvider; built-in localhost/device/manual login and IO credential storage need native runtime | None | [Client sources](../packages/dddart_rest_client/lib/dddart_rest_client.dart), client tests; browser/mobile callback/token storage must be supplied and tested by the app |
| dddart_events_distributed | Shared aggregate client/transport/history contracts; HTTP client, server endpoints and instance-local reference stores | Registry/JSON builders only for annotated event models | [Finite polling example](../packages/dddart_events_distributed/example/http_polling.dart), distributed tests; HTTP-only operation requires no AppSync package |
| dddart_events_appsync | Optional live transport on the shared interface; configured endpoint/auth for live use; trusted backend/native invocation adapters | None in adapter; event model builders as above | [Local protocol tests/example](../packages/dddart_events_appsync/README.md); a deployed AppSync/IAM/auth integration is separate from local protocol verification |
| dddart_events_dynamodb | Trusted server using DynamoDB for event history and channel mappings | None in adapter | [History example](../packages/dddart_events_dynamodb/example/history.dart), local service lane; no automatic infrastructure provisioning |
| dddart_webhooks | Server-side Shelf request handling with application payload/verifier/handler | None | [Examples](../packages/dddart_webhooks/example/README.md), verification/handler tests; applications own sender identity and deployment |
| dddart_webhooks_slack | Slack signature/payload adapter for server-side webhooks; signing secret and clock | None | [Verifier tests](../packages/dddart_webhooks_slack/test), compile-checked examples; no claim of a live Slack deployment |

## Identity, serialization and imports

`Entity<I>`, `AggregateRoot<I>` and `Repository<T, I>` carry a concrete `Identity`.
Constructors take `id:` explicitly. `UuidValue` is one stock identity; application
constructors may call `UuidValue.generate()`. There are no UUID-specific entity or
aggregate base classes. `DomainEvent<I>.aggregateId` has the aggregate identity
kind; occurrence IDs and operation IDs remain UUIDs independently of it.

Core owns domain primitives, not serialization interfaces. Core depends on
`collection`, `logging`, `meta` and `uuid` as declared in its pubspec.
`dddart_serialization` owns annotations, typed `Serializer<T, C>`, config and
identity codecs. `dddart_json` supplies the JSON implementation and generator.
A generated part shares its model library's imports; importing native database
adapters into that library can make the entire model composition native-only.

The [serialization contract](SERIALIZATION.md) defines full-config precedence,
codec sharing and exact error boundaries. Runtime SQL imports contain runtime
extension contracts; analyzer-based schema helpers live in `generator.dart`.
SQLite's builder factory is separate from its runtime library. See
[PUBLIC_API.md](PUBLIC_API.md) for every exported module and intentional SDK re-export.

## Repository guarantees

| Capability | Guarantee and boundary |
| --- | --- |
| Repository CRUD | Typed get/save/delete. It does not promise CAS, detached reads, distributed isolation or durable receipts |
| InMemoryRepository | Instance-local reference storage. Mutating a returned aggregate changes that same object; not a detached durable store |
| InMemoryConditionalRepository | Explicit clone callback and optional shared in-isolate store provide detached revision checks; not durable or cross-process coordination |
| SQLite/MySQL generated repositories | Complete aggregate graph writes use a database transaction; narrow conditional operations own the commit and reject nesting; ordinary writes can join an outer transaction |
| MongoDB/DynamoDB generated repositories | Narrow conditional compare-and-write on one document/item with opaque revision; no multi-record transaction/operation receipt promise |
| REST generated repository | Narrow conditional behavior depends on the server's capability and strong revision ETag contract; cannot manufacture atomicity for a plain CRUD backend |
| IndexedDB ConditionalRepository | Stronger atomic multi-record changes, uniqueness claims and operation receipts; use its commit/reconciliation API. It is not interchangeable with the narrow single-aggregate capability |

[CONDITIONAL_WRITES.md](CONDITIONAL_WRITES.md) specifies confirmed conflicts,
uncertain outcomes, transaction ownership, adapter permissions and event behavior.
Service tests and the [shared conformance suite](../packages/dddart/test/support/conditional_aggregate_contract.dart)
are the verification path. A confirmed conflict is different from a lost response.

## Authentication and publication

Authentication stays optional. An unconfigured CRUD resource is public. Installing
an authentication handler makes the default policy authenticated; explicit public
operation policies still permit anonymous access (for example a leaderboard read).
Custom authorization receives a detached trusted snapshot; aggregate mutations
require the documented conditional capability. Query policy scopes rows and
counts before paging. See the [REST policy contract](../packages/dddart_rest/README.md).
The event service's configured visibility/auth policy is a separate contract; it
does not make every CRUD endpoint authenticated.

Saving an aggregate, accepting an event, and delivering it to listeners are
separate steps. Publication captures a pending batch before awaiting persistence,
acknowledges accepted occurrences only after confirmed save, and retains failed
or later events. Local EventBus delivery is asynchronous. HTTP polling and
AppSync implement the shared aggregate transport interface, with AppSync adding
live delivery. Neither a save hook nor a successful publication implies an atomic
outbox transaction or completed subscriber processing. See
[DISTRIBUTED_EVENTS.md](DISTRIBUTED_EVENTS.md) for durable acceptance, retries,
checkpoints, retention and application lifecycle responsibilities.

## Repeating the evidence

Use `dart tool/validation/validate.dart package PACKAGE --mode=ci` for package,
generation, test and archive checks. Required service lanes fail when a service is
missing. Native Chrome is required for IndexedDB; a VM-only run is narrower.
Use the [quickstarts](QUICKSTARTS.md) for fresh consumer setup and
[example inventory](../tool/validation/inventory.json) for exact run/compile scope.
The website build/link checker is not Dart compilation or live cloud verification.
