---
title: Learn from working examples
description: Run a small local example first, then explore serialization, persistence, HTTP, and event integrations with their prerequisites made explicit.
section: Reference
order: 20
---

## Begin with a complete guide example

The shortest path is [Getting started](/dddart/docs/getting-started/): one dependency, one Dart file, no database. The other guides include complete examples or explicitly identify the objects your application must supply.

| What to learn | Start here | Required setup |
| --- | --- | --- |
| Domain behavior, identity, and values | [Modeling](/dddart/docs/modeling/) | Core package |
| Dependency injection through a repository | [Shared contracts](/dddart/docs/contracts/) | Core package |
| JSON and nested values | [Serialization](/dddart/docs/serialization/) | JSON packages and code generation |
| Durable local CRUD | [Repositories](/dddart/docs/repositories/) | Native SQLite and code generation |
| A server resource and matching client | [HTTP](/dddart/docs/http/) | REST packages; a running endpoint for network calls |
| Local delivery and aggregate watches | [Events](/dddart/docs/events/) | Core locally; an authenticated event endpoint for remote watches |
| Layered settings | [Configuration](/dddart/docs/configuration/) | Configuration package and a local YAML file |
| Verified Slack input or optional AppSync | [Integrations](/dddart/docs/integrations/) | Provider-specific credentials and deployment for live integration |

## Use the repository's example runner

Clone and resolve the pinned workspace shown in [Getting started](/dddart/docs/getting-started/). Run these commands from the repository root:

```bash
# Check the declared package/example inventory.
dart tool/validation/validate.dart check

# Resolve, generate, analyze, compile, and run the local JSON example lane.
dart tool/validation/validate.dart example dddart_json_example --mode=local

# Exercise the supported SQLite example lane.
dart tool/validation/validate.dart example dddart_repository_sqlite_example --mode=local
```

The validator uses each example's declared dependency closure and generation requirements. It runs finite local programs, compiles long-running servers, and does not assume a local external database or cloud account. It is more reliable than running an arbitrary file before its generated parts exist.

To validate all declared examples in local mode:

```bash
dart tool/validation/validate.dart examples --mode=local
```

This is a broader check and may take time. Local compilation of a service example is not evidence that it has connected to that service.

## Explore the example directories

Links in this table point to the source revision used by the documentation.

| Example | What it demonstrates | Runtime expectations |
| --- | --- | --- |
| [Core](https://github.com/continuousimagination/dddart/tree/b4aacf0671873e729a1a390dc2bb609b80c723e5/packages/dddart/example) | Domain concepts, values, events, logging, and repository use | Finite native examples; file logging is native-specific |
| [JSON](https://github.com/continuousimagination/dddart/tree/b4aacf0671873e729a1a390dc2bb609b80c723e5/packages/dddart_json/example) | Nested domain serialization, enums, naming, and configuration | Generation followed by local execution |
| [SQLite](https://github.com/continuousimagination/dddart/tree/b4aacf0671873e729a1a390dc2bb609b80c723e5/packages/dddart_repository_sqlite/example) | Basic CRUD, connection lifecycle, custom repositories | Native in-memory SQLite; no database server |
| [MySQL](https://github.com/continuousimagination/dddart/tree/b4aacf0671873e729a1a390dc2bb609b80c723e5/packages/dddart_repository_mysql/example) | CRUD, connection management, custom repositories | A configured MySQL service |
| [MongoDB](https://github.com/continuousimagination/dddart/tree/b4aacf0671873e729a1a390dc2bb609b80c723e5/packages/dddart_repository_mongodb/example) | Document repositories, swapping, configuration, custom queries | A configured MongoDB service |
| [DynamoDB](https://github.com/continuousimagination/dddart/tree/b4aacf0671873e729a1a390dc2bb609b80c723e5/packages/dddart_repository_dynamodb/example) | Tables, CRUD, errors, and custom interfaces | DynamoDB Local or explicitly configured AWS access |
| [REST server](https://github.com/continuousimagination/dddart/tree/b4aacf0671873e729a1a390dc2bb609b80c723e5/packages/dddart_rest/example) | CRUD resources, auth, queries, pagination, and errors | Long-running server programs |
| [REST repository](https://github.com/continuousimagination/dddart/tree/b4aacf0671873e729a1a390dc2bb609b80c723e5/packages/dddart_repository_rest/example) | Generated remote CRUD and custom interfaces | Matching local API; see that example's harness |
| [REST client](https://github.com/continuousimagination/dddart/tree/b4aacf0671873e729a1a390dc2bb609b80c723e5/packages/dddart_rest_client/example) | Client auth composition and device-flow usage | Auth provider and platform-specific setup |
| [Configuration](https://github.com/continuousimagination/dddart/tree/b4aacf0671873e729a1a390dc2bb609b80c723e5/packages/dddart_config/example) | Providers, precedence, defaults, and validation | Native local files/process environment |
| [Webhooks](https://github.com/continuousimagination/dddart/tree/b4aacf0671873e729a1a390dc2bb609b80c723e5/packages/dddart_webhooks/example) | JSON/form payloads and custom verifiers | Long-running HTTP endpoints |
| [Slack](https://github.com/continuousimagination/dddart/tree/b4aacf0671873e729a1a390dc2bb609b80c723e5/packages/dddart_webhooks_slack/example) | Slash commands and interactive messages | Slack credentials and public HTTPS ingress |
| [DynamoDB event history](https://github.com/continuousimagination/dddart/tree/b4aacf0671873e729a1a390dc2bb609b80c723e5/packages/dddart_events_dynamodb/example) | Durable ingestion history and channel rotation | Isolated DynamoDB Local table |
| [AppSync/native handlers](https://github.com/continuousimagination/dddart/tree/b4aacf0671873e729a1a390dc2bb609b80c723e5/packages/dddart_events_appsync/example) | Native invocation, Lambda composition, opt-in live smoke | Local invocation is finite; live AWS is separate |

The current [distributed-events reference](https://github.com/continuousimagination/dddart/blob/b4aacf0671873e729a1a390dc2bb609b80c723e5/docs/DISTRIBUTED_EVENTS.md) describes the new aggregate-watch flow. Some older files under `example/legacy` are explicitly excluded historical sketches. Do not use them as current end-to-end instructions.

## Run native event composition without AWS

With the workspace resolved, run:

```bash
dart run packages/dddart_events_appsync/example/native_invocation.dart
```

It exercises the native authorizer and subscription contracts with explicit local test authentication. It does not deploy infrastructure or use that test identity as production authentication.

For an actual AWS deployment, follow the [integration guide](/dddart/docs/integrations/#run-locally-deploy-deliberately). Its account, region, image, policy, credentials, and cleanup steps are separate from running a local example.

## What was checked for these guides

The documentation examples were checked against revision `b4aacf0671873e729a1a390dc2bb609b80c723e5` using Dart 3.9.4:

- Complete core/domain, configuration, and generated JSON examples were analyzed and run.
- The SQLite guide's generated model passed create, identity-preserving load, upsert, delete, and missing-record checks.
- Representative core, generated JSON, configuration, HTTP/auth, and aggregate/AppSync client compositions compiled to JavaScript. Selected domain, JSON, and configuration programs also ran under Node.
- The HTTP server helper and Slack server compiled; local event delivery/metadata checks and the native invocation example ran.

These checks are a foundation for the examples. They do not claim live Slack/AWS verification, testing on every Flutter device, or a browser login round trip. Test the endpoints, permissions, native plugins, and lifecycle behavior of your own application.

## When a copied example fails

**Pub cannot find a dddart package:** use Git dependencies and same-revision overrides, not unpublished hosted versions.

**A generated part or class is missing:** run generation from the owning package after resolving dependencies. Import `dart:convert` and the JSON/serialization libraries when the generated JSON part needs them.

**An old aggregate constructor no longer compiles:** use `UuidAggregateRoot` for generated UUIDs, or supply an identity to `AggregateRoot<I>`. Aggregate constructors are not `const`.

**A browser path reaches an unsupported operation:** check native adapter imports, filesystem token stores, process environment, and callback strategies. Use a platform-compatible implementation at the edge.

**An external example cannot connect:** confirm its declared service requirement. Local compile validation does not start a database, create AWS resources, or supply Slack credentials.
