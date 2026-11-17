# DDDart documentation

Start with the [complete quickstarts](QUICKSTARTS.md) and [Git installation](GIT_INSTALLATION.md).
1.0 is the first compatibility baseline; hosted package installation belongs to the release work.

| Topic | Current guide |
| --- | --- |
| API boundaries and imports | [Public API](PUBLIC_API.md) |
| Platforms and adapter limits | [Capability matrix](CAPABILITIES.md) |
| Models and identities | [Core guide](../packages/dddart/README.md), [typed IDs](../packages/dddart/IDENTITY_GUIDE.md) |
| JSON and generators | [Serialization contract](SERIALIZATION.md) |
| Persistence and concurrency | [Conditional writes](CONDITIONAL_WRITES.md) |
| HTTP and optional authentication | [REST guide](../packages/dddart_rest/README.md) |
| Local and remote events | [Domain events](../packages/dddart/DOMAIN_EVENTS_GUIDE.md), [polling/AppSync](DISTRIBUTED_EVENTS.md) |
| Configuration | [Configuration guide](../packages/dddart_config/README.md) |
| Webhooks | [Webhook guide](../packages/dddart_webhooks/README.md), [Slack](../packages/dddart_webhooks_slack/README.md) |
| Browsable tutorials | [Website source](../website/src/content/docs/), [published site](https://continuousimagination.github.io/dddart/) |
| Sample coverage | Each package's `example/README.md`; generated coverage tables match the [shared inventory](../tool/validation/inventory.json) |
| Maintaining documentation | [Documentation gate](../tool/documentation/README.md), [validation commands](../scripts/README.md) |

Every current Markdown guide and library Dartdoc comment participates in source/link checks.
Complete code inclusions are owned by executable quickstarts or inventoried samples.
Samples that require application credentials or a long-running host are explicitly compile-only.
Local databases and protocol fixtures are not evidence of a live cloud or device test.

`worky/`, changelogs and the application handoff are historical records.
Their visible notices distinguish them from current how-tos. The explicit
[surface inventory](../tool/documentation/surfaces.json) accounts for each document;
new guides fail validation until reviewed and inventoried. Historical code is not a current API promise.
