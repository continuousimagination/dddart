# DDDart documentation

## Start here

- [Run your first example](quickstarts/core/README.md): model, save, and publish
  a domain event in a small Dart application.
- [Install from Git](GIT_INSTALLATION.md): add DDDart to an existing Dart or
  Flutter application.
- [Find an example](QUICKSTARTS.md): choose a complete application or an
  integration sample.
- [Read the online guide](https://continuousimagination.github.io/dddart/):
  learn how the pieces fit together.

## Build an application

| If you want to… | Read |
| --- | --- |
| Model values, aggregates, and IDs | [Core package](../packages/dddart/README.md), [typed identities](../packages/dddart/IDENTITY_GUIDE.md) |
| Convert a model to JSON | [Generated JSON quickstart](quickstarts/json/README.md), [serialization contract](SERIALIZATION.md) |
| Store an aggregate | [Package and adapter guide](CAPABILITIES.md), [conditional writes](CONDITIONAL_WRITES.md) |
| Expose an HTTP API with public or protected routes | [HTTP quickstart](quickstarts/rest/README.md), [REST authorization guide](../packages/dddart_rest/README.md#optional-access-policies) |
| Deliver events | [Local events](../packages/dddart/DOMAIN_EVENTS_GUIDE.md), [remote watches and publication](DISTRIBUTED_EVENTS.md) |
| Read application settings | [Configuration quickstart](quickstarts/configuration/README.md), [provider and lookup rules](../packages/dddart_config/README.md) |
| Receive webhooks | [Webhook guide](../packages/dddart_webhooks/README.md), [Slack commands](../packages/dddart_webhooks_slack/README.md) |

## Look up a contract

Use the [package and adapter guide](CAPABILITIES.md) for platform support, and
the [public API reference](PUBLIC_API.md) for imports and supported extension
points. Each package README describes behavior specific to that package.

To contribute, see [development and validation](../scripts/README.md) and
[editing and checking documentation](../tool/documentation/README.md).
