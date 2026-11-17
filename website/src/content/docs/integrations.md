---
title: Connect external services
description: Receive verified webhooks and add optional live publication to the shared event client.
section: Connect the pieces
order: 50
---

Keep credentials, transport setup, and provider-specific payloads at the
application's edge. Convert accepted inputs into domain actions through your
application service.

## Receive a verified Slack command

Use the
[Slack server example](https://github.com/continuousimagination/dddart/blob/main/docs/quickstarts/slack_server/README.md)
to assemble a Shelf route, `SlackWebhookVerifier`, a form deserializer, and a
typed handler. Compile locally first. To run it with Slack, supply your
signing secret and configure Slack to send to your callback URL.

The signature check uses the original request body before decoding. Keep the
secret on the server. A timestamp window limits stale replays; handlers must
account for retries within that window. The
[Slack package guide](https://github.com/continuousimagination/dddart/blob/main/packages/dddart_webhooks_slack/README.md)
shows the payload types and error behavior.

## Add another webhook provider

Use `WebhookResource` with a verifier and deserializer for that provider.
Verify what the provider actually signs before trusting any claimed sender
identity. See the
[webhook examples](https://github.com/continuousimagination/dddart/blob/main/packages/dddart_webhooks/example/README.md)
for JSON, forms, and custom verification.

## Add live events with AppSync

Keep the [same event client and watch contract](/dddart/docs/events/). Use an
`AppSyncEventTransport` for live delivery and give its HTTP control transport
and AppSync connection access to the current token. The
[native handler example](https://github.com/continuousimagination/dddart/blob/main/packages/dddart_events_appsync/example/README.md)
runs without deploying anything. To connect a real app, follow the
[AppSync deployment guide](https://github.com/continuousimagination/dddart/blob/main/packages/dddart_events_appsync/DEPLOY.md)
for resource configuration, authorization, smoke testing, and cleanup.

## Keep durable event infrastructure on the server

Multiple processes need a shared history and channel mapping. Use the
[DynamoDB event store](https://github.com/continuousimagination/dddart/blob/main/packages/dddart_events_dynamodb/README.md)
on the server. Clients use the event API and keep their own watch checkpoints.
The history example runs against DynamoDB Local; deploy and verify application
permissions separately.
