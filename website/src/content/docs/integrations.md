---
title: Receive webhooks
description: Verify a request, decode its payload, and pass it to a Dart handler.
section: Connect the pieces
order: 50
---

A webhook is a request another service sends to your application. DDDart's
`WebhookResource` verifies the original request body, decodes the accepted
payload, and calls your handler. Keep the provider's payload type in this
handler and call your domain model or application service from there.

## Try a local sender and receiver

Run the [JSON webhook example](https://github.com/continuousimagination/dddart/blob/main/packages/dddart_webhooks/example/README.md).
It prints a shell command that signs a sample `user.created` payload and sends
it to the loopback server. The response tells you which event was processed.

## Receive a Slack command

Follow the [Slack server quickstart](https://github.com/continuousimagination/dddart/blob/main/docs/quickstarts/slack_server/README.md)
to configure a signing secret, register the callback, and handle the command.
Slack signs the original body and includes a timestamp. A timestamp window
limits stale replays. If a command changes state, account for retries within
that window.

For another sender, choose a verifier for its signing scheme and a deserializer
for its body format. The [webhook package guide](https://github.com/continuousimagination/dddart/blob/main/packages/dddart_webhooks/README.md)
describes the response when verification or decoding fails.
