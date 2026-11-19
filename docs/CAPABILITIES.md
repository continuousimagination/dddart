# Choose packages and adapters

Start with `dddart` for the model. Add a serializer, repository, or transport
when the application's boundary needs it. Keep platform dependencies in that
boundary so the model can also run in a client or in tests.

<a id="start-with-the-problem-you-need-to-solve"></a>

## Model data and configure the application

| Package | Use it for | Requirements and limits |
| --- | --- | --- |
| dddart | [Aggregates, values, typed identities, repositories and local events](../packages/dddart/README.md) | Core domain paths can run on the VM and compile to JavaScript. File logging requires native IO. In-memory CRUD retains object references |
| dddart_serialization | [Format-neutral annotations, serializers and identity codecs](../packages/dddart_serialization/README.md) | No platform IO or supplied wire format |
| dddart_json | [Generated JSON maps and strings](../packages/dddart_json/README.md) | Build runner; the generated code shares the model library's platform imports |
| dddart_config | [Layered configuration](../packages/dddart_config/README.md) | Environment and YAML file providers require native IO; custom providers can read other sources |

## Store and retrieve aggregates

| Package | Use it for | Requirements and limits |
| --- | --- | --- |
| dddart_repository_sqlite | [Embedded SQLite persistence](../packages/dddart_repository_sqlite/README.md) | Native SQLite library through FFI. No Web/WASM backend |
| dddart_repository_mysql | [MySQL persistence on a server](../packages/dddart_repository_mysql/README.md) | InnoDB and application DB permissions. One physical connection per wrapper; entity Set/Map collections are unsupported |
| dddart_repository_mongodb | [MongoDB document persistence](../packages/dddart_repository_mongodb/README.md) | Trusted server with collection permissions; local MongoDB tests do not establish DocumentDB compatibility |
| dddart_repository_dynamodb | [DynamoDB item persistence](../packages/dddart_repository_dynamodb/README.md) | Trusted backend with DynamoDB permissions, or a local test endpoint |
| dddart_repository_indexeddb | [Native browser persistence](../packages/dddart_repository_indexeddb/README.md) | Application codecs, native factory, same-origin storage. Supports atomic multi-record changes and operation receipts |
| dddart_repository_rest | [A repository backed by an HTTP API](../packages/dddart_repository_rest/README.md) | Compatible server. Conditional writes depend on the server; browser CORS and sign-in belong to the application |
| dddart_repository_sql | [SQL mapping and adapter extension contracts](../packages/dddart_repository_sql/README.md) | Supporting library for adapters; no database driver |

The [conditional writes guide](CONDITIONAL_WRITES.md) explains which
repositories can prevent lost updates and how to handle conflicts or uncertain
outcomes. Repository APIs share CRUD semantics; query capabilities,
transactions, and backend consistency vary.

## Expose APIs, publish events, and receive webhooks

| Package | Use it for | Requirements and limits |
| --- | --- | --- |
| dddart_rest | [HTTP resources, optional authentication, and access policies](../packages/dddart_rest/README.md) | Shelf on a native server; define the allowed operations and queries |
| dddart_rest_client | [Authenticated HTTP clients and credential handling](../packages/dddart_rest_client/README.md) | Built-in IO storage and several interactive flows need a native runtime; supply platform-appropriate callbacks and storage |
| dddart_events_distributed | [Aggregate publication and watches using HTTP polling](../packages/dddart_events_distributed/README.md) | A server with the shared event service. In-memory history is suitable for a development process, not shared durable history |
| dddart_events_appsync | [Live delivery on the same aggregate watch interface](../packages/dddart_events_appsync/README.md) | Configured AppSync Events endpoint and server-side authorization |
| dddart_events_dynamodb | [Durable event history and channel mapping](../packages/dddart_events_dynamodb/README.md) | Server-side DynamoDB access; provision storage separately |
| dddart_webhooks | [Typed webhook receivers](../packages/dddart_webhooks/README.md) | Shelf server; applications supply their verifier and handlers |
| dddart_webhooks_slack | [Slack command and signature handling](../packages/dddart_webhooks_slack/README.md) | Server-side Slack signing secret and access to the request body |

## Look up supported imports

See the [public API reference](PUBLIC_API.md) for supported imports and the
[examples](QUICKSTARTS.md) for runnable setup. A supported composition still needs
testing with the actual platform, backend, credentials, and deployment.
