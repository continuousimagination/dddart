# DDDart examples

Start with a standalone application. Follow the linked guide in a fresh
directory outside the DDDart checkout. The guide links to the example
`pubspec.yaml` template and shows what to run and what output to expect.

## Start with a complete application

| Goal | Example | What you need |
| --- | --- | --- |
| Model an aggregate and publish a local event | [Core](quickstarts/core/README.md) | Dart |
| Generate a JSON serializer for a model | [JSON](quickstarts/json/README.md) | Dart and the builders in the example pubspec |
| Layer environment variables over a YAML file | [Configuration](quickstarts/configuration/README.md) | Native Dart |
| Try SQL persistence without a server | [SQLite](quickstarts/sqlite/README.md) | Native Dart and the SQLite library |
| Store aggregates on a SQL server | [MySQL](quickstarts/mysql/README.md) | Disposable MySQL database |
| Store aggregates in collections | [MongoDB](quickstarts/mongodb/README.md) | Disposable MongoDB database |
| Store aggregates in DynamoDB | [DynamoDB Local](quickstarts/dynamodb/README.md) | DynamoDB Local; no AWS account |
| Serve and fetch public resources over HTTP | [REST](quickstarts/rest/README.md) | Native Dart; no login or token |
| Receive a verified Slack command | [Slack server](quickstarts/slack_server/README.md) | Compile locally; configure a signing secret and Slack sender to run |

<a id="explore-a-package-sample"></a>

## Explore a specific integration

These examples use the DDDart checkout. The package guide explains how to run or
compile each one and what it needs.

| Goal | Where to look |
| --- | --- |
| Mix public reads and protected writes | [REST examples](../packages/dddart_rest/example/README.md) |
| Use conditional writes or publish after a save | [Core examples](../packages/dddart/example/README.md) |
| Persist in a browser | [IndexedDB guide](../packages/dddart_repository_indexeddb/README.md) |
| Subscribe without an AWS account | [HTTP polling example](../packages/dddart_events_distributed/example/README.md) |
| Add live event delivery | [AppSync examples](../packages/dddart_events_appsync/example/README.md) |
| Persist event history | [DynamoDB history example](../packages/dddart_events_dynamodb/example/README.md) |
| Receive events from other webhook senders | [Webhook examples](../packages/dddart_webhooks/example/README.md) |

For platform requirements and other integrations, use the [package and adapter guide](CAPABILITIES.md).

## Troubleshoot a run

| Symptom | Check |
| --- | --- |
| Pub cannot find a DDDart package | Use the linked example pubspec or follow [Git installation](GIT_INSTALLATION.md) |
| A generated library or type is missing | Run the quickstart's build step from the package owning the model |
| A browser build includes native IO | Move the native adapter to the server or choose a [browser-compatible composition](guides/contracts.md) |
| An external sample cannot connect | Review its service, address, credentials, and provider setup |
