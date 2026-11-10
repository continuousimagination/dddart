---
title: Package map
description: Find the 17 packages, their responsibilities, and the guides that show how to compose them.
section: Reference
order: 10
---

## Start small

Use `dddart` for the core model. Add JSON when you need a representation, a repository adapter when you need persistence, and the HTTP or event packages when you need a remote boundary. Configuration and webhooks can also be used independently.

All dddart dependencies in an application should use the same pinned Git revision. See [Getting started](/dddart/docs/getting-started/) before copying a hosted dependency from an older package README.

## Domain and serialization

| Package | Responsibility | Guide |
| --- | --- | --- |
| [dddart](https://github.com/continuousimagination/dddart/tree/main/packages/dddart) | Entities, aggregate roots, values, typed identities, repositories, local events, publication helpers, and logging | [Modeling](/dddart/docs/modeling/) |
| [dddart_serialization](https://github.com/continuousimagination/dddart/tree/main/packages/dddart_serialization) | Serialization interfaces, annotations, configuration, and identity codecs | [Serialization](/dddart/docs/serialization/) |
| [dddart_json](https://github.com/continuousimagination/dddart/tree/main/packages/dddart_json) | Generated JSON serializer services | [Serialization](/dddart/docs/serialization/) |

## Persistence

Every repository adapter implements the typed aggregate repository contract. Backend-specific query methods and constraints remain explicit.

| Package | Responsibility | Typical placement |
| --- | --- | --- |
| [dddart_repository_sql](https://github.com/continuousimagination/dddart/tree/main/packages/dddart_repository_sql) | Shared SQL connection, schema, mapping, and generation infrastructure | Supporting package for SQL adapters |
| [dddart_repository_sqlite](https://github.com/continuousimagination/dddart/tree/main/packages/dddart_repository_sqlite) | Generated SQLite persistence through native `sqlite3` | Native application or server |
| [dddart_repository_mysql](https://github.com/continuousimagination/dddart/tree/main/packages/dddart_repository_mysql) | Generated MySQL persistence | Trusted server |
| [dddart_repository_mongodb](https://github.com/continuousimagination/dddart/tree/main/packages/dddart_repository_mongodb) | Generated MongoDB document repositories | Trusted server |
| [dddart_repository_dynamodb](https://github.com/continuousimagination/dddart/tree/main/packages/dddart_repository_dynamodb) | Generated DynamoDB aggregate repositories | Trusted server / AWS integration |
| [dddart_repository_rest](https://github.com/continuousimagination/dddart/tree/main/packages/dddart_repository_rest) | Generated HTTP implementation of `Repository<T, I>` | Client or service calling a remote API |

See [Repositories](/dddart/docs/repositories/) for a complete SQLite walkthrough and an adapter comparison, and [Shared contracts](/dddart/docs/contracts/) for platform composition.

## HTTP and authentication

| Package | Responsibility | Guide |
| --- | --- | --- |
| [dddart_rest](https://github.com/continuousimagination/dddart/tree/main/packages/dddart_rest) | CRUD resources, Shelf HTTP composition, queries, JWT/OIDC verification, and authorization hooks | [HTTP](/dddart/docs/http/) |
| [dddart_rest_client](https://github.com/continuousimagination/dddart/tree/main/packages/dddart_rest_client) | HTTP client, auth-provider contract, device flow, and Cognito/OIDC login composition | [HTTP and platform authentication](/dddart/docs/http/#browser-and-mobile-composition) |

Server authorization and client token acquisition are different responsibilities. Platform-specific credential stores and redirect handling belong at the application's edge.

## Events

| Package | Responsibility | Guide |
| --- | --- | --- |
| [dddart_events_distributed](https://github.com/continuousimagination/dddart/tree/main/packages/dddart_events_distributed) | Event registry, aggregate watches, HTTP transport, retained-history contracts, publication, and policy | [Events](/dddart/docs/events/) |
| [dddart_events_dynamodb](https://github.com/continuousimagination/dddart/tree/main/packages/dddart_events_dynamodb) | Durable event history and shared channel mappings for concurrent servers | [Integrations](/dddart/docs/integrations/#keep-durable-event-infrastructure-on-the-server) |
| [dddart_events_appsync](https://github.com/continuousimagination/dddart/tree/main/packages/dddart_events_appsync) | Optional AppSync Events live transport, native handlers, and deployment reference | [Integrations](/dddart/docs/integrations/#add-live-events-with-appsync) |

Start with a local `EventBus` in core. Use `AggregateEventClient` for new per-aggregate remote watches. HTTP-only operation does not require AWS.

## Configuration and webhooks

| Package | Responsibility | Guide |
| --- | --- | --- |
| [dddart_config](https://github.com/continuousimagination/dddart/tree/main/packages/dddart_config) | Structured configuration, source precedence, typed access, and validation | [Configuration](/dddart/docs/configuration/) |
| [dddart_webhooks](https://github.com/continuousimagination/dddart/tree/main/packages/dddart_webhooks) | Typed webhook resources, verification contracts, and payload decoding | [Integrations](/dddart/docs/integrations/) |
| [dddart_webhooks_slack](https://github.com/continuousimagination/dddart/tree/main/packages/dddart_webhooks_slack) | Slack signature verification and typed Slack payloads | [Slack command how-to](/dddart/docs/integrations/#receive-a-verified-slack-command) |

## Explore the source

Each package contains its public exports, implementation, tests, and API notes. The [example catalog](/dddart/docs/examples/) distinguishes finite local examples, long-running servers, external-service integrations, and retained legacy sketches. A folder called `example` does not by itself mean every file can run without setup.

The packages are MIT licensed. The site documents a pre-release API; pin a revision and review migrations when upgrading, especially around typed identities and stored key formats.
