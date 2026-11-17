# Supported public API

This is the intended API surface for the first compatibility baseline, 1.0.
Package release inclusion, versions and SDK bounds are tracked separately in
#97–#99. `lib/src` files are implementation details even when a public library
exports selected declarations from them. Import the entrypoints below, never
another package's `src`. All public declarations in the listed exported modules
are supported at that entrypoint; private declarations remain internal.

## Application and extension contracts

| Package (main library has the package name) | Application API | Supported extension API |
| --- | --- | --- |
| dddart | Entity/aggregate/value/identity types, events, repositories, exceptions, logging | Identity, repository and event publisher implementations; optional conditional capabilities; `Logger`/`Level` are deliberately re-exported from logging |
| dddart_serialization | Serializable annotation, config, exceptions, codecs | Serializer, IdentityCodec/registry, SerializationUtils for format implementations |
| dddart_json | JsonSerializer | Handwritten JSON serializers; generated serializer constructors and methods |
| dddart_config | Layered Configuration, standard providers and errors | ConfigProvider, lookup and requirement contracts |
| dddart_rest | CRUD/resources, optional access policies, caller/context/results, tokens and auth endpoints | Auth/authorization handlers, query scopes/handlers, response/error mappers, lifecycle repository and credential hooks |
| dddart_rest_client | RestClient, optional authentication, credential stores and OAuth flows | AuthProvider, OAuthCallbackStrategy and stores |
| dddart_repository_sql | SQL connection/dialect, table values, mapping and query utilities | SqlConnection/coordinator, SqlDialect, ObjectMapper, QueryBuilder, JoinBuilder; runtime schema values used by these contracts |
| dddart_repository_sqlite | Annotation, SQLite connection/dialect, generated repositories | Generated custom repository base classes; connection/dialect implementations |
| dddart_repository_mysql | Annotation, MySQL connection/dialect, generated repositories | Generated custom repository base classes; connection/dialect implementations |
| dddart_repository_mongodb | Annotation, connection, generated repositories and errors | Generated custom bases, identity key encoding and acknowledged write-result validation used by generated/custom methods |
| dddart_repository_dynamodb | Annotation, connection, generated repositories and errors | Generated custom bases, attribute conversion, identity key encoding; the AWS DynamoDB SDK is deliberately re-exported for client requests, responses, credentials and generated schema calls. Its declarations retain the upstream SDK contract, not a separate DDDart guarantee |
| dddart_repository_rest | Annotation, REST connection and generated repositories | Generated custom repository bases; optional auth through RestClient |
| dddart_repository_indexeddb | Browser IndexedDB repositories and transactional results | Identity codecs and aggregate encode/decode callbacks; richer conditional repository contract |
| dddart_events_distributed | Aggregate event client, HTTP transport, service, envelopes, history and retry publisher | AggregateEventTransport/LiveAggregateEventTransport, history repository, codec/registry, visibility policy; EventPublisher comes from core |
| dddart_events_appsync | AppSync transport, HTTP publisher, native invocation adapters | Same aggregate transport and publication interfaces, native handler callbacks |
| dddart_events_dynamodb | Durable DynamoDB event history | Aggregate event history interface implementation |
| dddart_webhooks | WebhookResource, deserializers and verification results | WebhookVerifier and typed payload/result hooks |
| dddart_webhooks_slack | Slack signature verifier, result, slash command payload | WebhookVerifier implementation; no separate extension framework |

The SQL `generator.dart` entrypoint is a **supported build-time extension API**:
collection and relationship analyzers consume resolved analyzer elements,
IdentityTypeAnalysis resolves concrete inherited identities, TypeMapper maps
resolved types and SchemaGenerator emits DDL using a SqlDialect. It re-exports
the runtime SQL contracts so sibling builders need one import. These APIs are
coupled to the analyzer dependency range; do not import them into applications.
They do not reflect over arbitrary runtime object fields. The unused, incomplete
GraphTraverser has been removed.

`dddart_rest/credentials.dart` exposes verification without generated token
issuance models. `dddart_rest/http.dart` exposes routing and CRUD without those
models; import the main library when policies and other exported types are needed.

Builder URIs listed in each package's `build.yaml` are build-runner protocol
entrypoints, **not supported generator subclassing APIs**. SQLite uses
`dddart_repository_sqlite/builder.dart`, exporting only its factory. Other
builders may load their package's internal implementation directly. Applications
use annotations and run build_runner; they never instantiate generators.

## Export inventory

The following list records every public entrypoint and its explicit exports.
It is intentionally module-level: every public symbol in each module belongs to
the category above, including generated-code support helpers. A new entrypoint
or export requires review of this inventory.

### `dddart/dddart.dart`

- `'package:logging/logging.dart' show Level, Logger`
- `'src/aggregate_root.dart'`
- `'src/conditional_aggregate_repository.dart'`
- `'src/conditional_repository.dart'`
- `'src/domain_event.dart'`
- `'src/entity.dart'`
- `'src/event_bus.dart'`
- `'src/event_publisher.dart'`
- `'src/event_publishing_repository.dart'`
- `'src/file_log_handler.dart'`
- `'src/identity.dart'`
- `'src/in_memory_conditional_repository.dart'`
- `'src/in_memory_repository.dart'`
- `'src/repository.dart'`
- `'src/repository_exception.dart'`
- `'src/save_with_events.dart'`
- `'src/uuid_value.dart'`
- `'src/value.dart'`

### `dddart_config/dddart_config.dart`

- `'src/config_lookup.dart'`
- `'src/config_provider.dart'`
- `'src/config_requirement.dart'`
- `'src/configuration.dart'`
- `'src/environment_config_provider.dart'`
- `'src/exceptions.dart'`
- `'src/yaml_config_provider.dart'`

### `dddart_events_appsync/dddart_events_appsync.dart`

- `'src/appsync_event_handlers.dart'`
- `'src/appsync_event_transport.dart'`
- `'src/appsync_http_publisher.dart'`

### `dddart_events_distributed/dddart_events_distributed.dart`

- `'src/aggregate_event_client.dart'`
- `'src/aggregate_event_repository.dart'`
- `'src/aggregate_event_service.dart'`
- `'src/aggregate_event_transport.dart'`
- `'src/aggregate_reference.dart'`
- `'src/event_envelope.dart'`
- `'src/event_registry.dart'`
- `'src/in_memory_aggregate_event_repository.dart'`
- `'src/retrying_event_publisher.dart'`
- `'src/stored_event.dart'`

### `dddart_events_dynamodb/dddart_events_dynamodb.dart`

- `'src/dynamo_event_repository.dart'`

### `dddart_json/dddart_json.dart`

- `'src/json_serializer.dart'`

### `dddart_repository_dynamodb/dddart_repository_dynamodb.dart`

- `'package:aws_dynamodb_api/dynamodb-2012-08-10.dart'`
- `'src/annotations/generate_dynamo_repository.dart'`
- `'src/connection/dynamo_connection.dart'`
- `'src/exceptions/dynamo_repository_exception.dart'`
- `'src/utils/attribute_value_converter.dart'`
- `'src/utils/identity_key.dart'`

### `dddart_repository_indexeddb/dddart_repository_indexeddb.dart`

- `'src/indexeddb_repository.dart'`

### `dddart_repository_mongodb/dddart_repository_mongodb.dart`

- `'src/annotations/generate_mongo_repository.dart'`
- `'src/connection/mongo_connection.dart'`
- `'src/exceptions/mongo_repository_exception.dart'`
- `'src/identity_key.dart'`
- `'src/write_result.dart'`

### `dddart_repository_mysql/dddart_repository_mysql.dart`

- `'src/annotations/generate_mysql_repository.dart'`
- `'src/connection/mysql_connection.dart'`
- `'src/dialect/mysql_dialect.dart'`

### `dddart_repository_rest/dddart_repository_rest.dart`

- `'src/annotations/generate_rest_repository.dart'`
- `'src/connection/rest_connection.dart'`

### `dddart_repository_sql/dddart_repository_sql.dart`

- `'src/annotations/generate_sql_repository.dart'`
- `'src/connection/sql_connection.dart'`
- `'src/connection/sql_connection_coordinator.dart'`
- `'src/dialect/sql_dialect.dart'`
- `'src/mapping/object_mapper.dart'`
- `'src/query/join_builder.dart'`
- `'src/query/query_builder.dart'`
- `'src/schema/table_definition.dart'`

### `dddart_repository_sql/generator.dart`

- `namespace. library`
- `'dddart_repository_sql.dart'`
- `'src/schema/collection_analyzer.dart'`
- `'src/schema/identity_type.dart'`
- `'src/schema/relationship_analyzer.dart' hide CollectionKind`
- `'src/schema/schema_generator.dart'`
- `'src/schema/type_mapper.dart'`

### `dddart_repository_sqlite/builder.dart`

- `'src/generators/sqlite_repository_generator.dart' show sqliteRepositoryBuilder`

### `dddart_repository_sqlite/dddart_repository_sqlite.dart`

- `'src/annotations/generate_sqlite_repository.dart'`
- `'src/connection/sqlite_connection.dart'`
- `'src/dialect/sqlite_dialect.dart'`

### `dddart_rest/credentials.dart`

- `'src/authentication_result.dart'`
- `'src/jwt_credential_verifier.dart'`
- `'src/oauth_jwt_auth_handler.dart'`
- `'src/token_authentication_handler.dart'`

### `dddart_rest/dddart_rest.dart`

- `'src/access_policy.dart'`
- `'src/auth_endpoints.dart'`
- `'src/auth_error_mapper.dart'`
- `'src/authentication_handler.dart'`
- `'src/authentication_result.dart'`
- `'src/authorization_context.dart'`
- `'src/authorization_handler.dart'`
- `'src/authorization_result.dart'`
- `'src/crud_resource.dart'`
- `'src/device_code.dart'`
- `'src/device_code_lifecycle.dart'`
- `'src/device_code_repository.dart'`
- `'src/error_mapper.dart'`
- `'src/exceptions.dart'`
- `'src/http_server.dart'`
- `'src/jwt_auth_handler.dart'`
- `'src/jwt_credential_verifier.dart'`
- `'src/jwt_serializable_annotation.dart'`
- `'src/oauth_jwt_auth_handler.dart'`
- `'src/query_handler.dart'`
- `'src/refresh_token.dart'`
- `'src/refresh_token_lifecycle.dart'`
- `'src/refresh_token_repository.dart'`
- `'src/response_builder.dart'`
- `'src/revision_etag.dart'`
- `'src/security_utils.dart'`
- `'src/standard_claims.dart'`
- `'src/token_authentication_handler.dart'`
- `'src/tokens.dart'`

### `dddart_rest/http.dart`

- `'src/crud_resource.dart'`
- `'src/http_server.dart'`

### `dddart_rest_client/dddart_rest_client.dart`

- `'src/auth_provider.dart'`
- `'src/cognito_auth_provider.dart'`
- `'src/device_flow_auth_provider.dart'`
- `'src/localhost_callback_strategy.dart'`
- `'src/manual_callback_strategy.dart'`
- `'src/oauth_callback_strategy.dart'`
- `'src/oauth_credential_store.dart'`
- `'src/oauth_login_store.dart'`
- `'src/rest_client.dart'`

### `dddart_serialization/dddart_serialization.dart`

- `'src/identity_codec.dart'`
- `'src/serializable_annotation.dart'`
- `'src/serialization_config.dart'`
- `'src/serialization_contracts.dart'`
- `'src/serialization_utils.dart'`

### `dddart_webhooks/dddart_webhooks.dart`

- `'src/webhook_deserializers.dart'`
- `'src/webhook_resource.dart'`
- `'src/webhook_verification_result.dart'`
- `'src/webhook_verifier.dart'`

### `dddart_webhooks_slack/dddart_webhooks_slack.dart`

- `'src/slack_slash_command.dart'`
- `'src/slack_verification_result.dart'`
- `'src/slack_webhook_verifier.dart'`
