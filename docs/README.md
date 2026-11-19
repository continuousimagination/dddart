# DDDart documentation

## Start here

If you're new to DDDart, [place an order in a small Dart app](quickstarts/core/README.md).
You’ll enforce a rule, save the order, and see a listener react. Read
[Why DDDart](guides/philosophy.md) for the ideas behind the example.

If you already have a Dart or Flutter app, [add DDDart from Git](GIT_INSTALLATION.md).
When you need working code for a particular task, use the [example catalog](QUICKSTARTS.md).

## Build an application

| If you want to… | Read |
| --- | --- |
| Model values, aggregates, and IDs | [Model a domain](guides/modeling.md), [share contracts](guides/contracts.md), [typed identities](../packages/dddart/IDENTITY_GUIDE.md) |
| Convert a model to JSON | [Generated JSON quickstart](quickstarts/json/README.md), [serialization contract](SERIALIZATION.md) |
| Store an aggregate | [Choose a repository](guides/repositories.md), [conditional writes](CONDITIONAL_WRITES.md) |
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
