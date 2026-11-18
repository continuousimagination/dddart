# dddart_webhooks_slack

Slack request-signature verification and typed slash-command payloads for
[dddart_webhooks](../dddart_webhooks/README.md).

## Complete setup

Follow the [Slack quickstart](../../docs/quickstarts/slack_server/README.md)
to verify a slash command and return a response. It shows where to set
`SLACK_SIGNING_SECRET` and which HTTPS callback path to register with Slack.
For button clicks and view submissions, use the [interactive message example](example/README.md).

## Verification and payloads

`SlackWebhookVerifier` computes HMAC-SHA256 over the version, timestamp and exact
raw body, compares the signature and rejects timestamps outside its configured
past/future window. The default window is five minutes. This limits stale replay;
it is not a deduplication cache and does not guarantee exactly-once handling.

`SlackVerificationResult` reports validity and available metadata. The verifier
extracts `teamId`/`requestType` from top-level JSON when present; form-encoded slash
commands obtain their team and command fields from `SlackSlashCommand.fromForm`.
Do not assume verifier metadata is populated for every payload encoding.

Register `WebhookResource.handleRequest` with Shelf or `HttpServer.addRoute`.
Signature verification uses the original body before deserialization. Required
slash-command fields are validated by the payload factory. Interactive payloads
need the form's embedded JSON decoded by the application, as shown in the sample.
URL challenges and delayed response delivery are application handlers, not
features automatically supplied by the verifier.

## Lifecycle and errors

Keep the signing secret out of source and logs. Verification failures and
exceptions use the generic resource's sanitized responses. Applications own
transport security, request limits, rate controls, retry/deduplication behavior
and any asynchronous delivery to a response URL.
