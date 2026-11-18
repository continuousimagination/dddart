# dddart_events_appsync

Add live AWS AppSync Events delivery to the
[shared aggregate event client](../../docs/DISTRIBUTED_EVENTS.md). The same
application can use HTTP polling independently of this package.

## Connect a client

Compose `AppSyncEventTransport` with `AggregateEventClient`. Give the HTTP
control transport and AppSync authorization a callback that supplies the
current application token. HTTP is used for watch resolution, catch-up, and
publication targets; one AppSync WebSocket carries live events for all watches.

The [native invocation example](example/native_invocation.dart) runs locally.
For a configured deployment, the [smoke client](example/aws_smoke.dart) shows
the endpoint and transport setup. Follow the [deployment guide](DEPLOY.md) to
run it with a sample stack and an authorized test aggregate.

The transport reconnects with bounded backoff, manages keepalives, and
reauthorizes connections and subscriptions. Live messages do not advance the
history checkpoint. Periodic HTTP catch-up handles missed frames; bounded
occurrence-ID deduplication handles overlap. See the
[watch lifecycle](../../docs/DISTRIBUTED_EVENTS.md#watch-and-resume) for
checkpoints, pause/resume, and cleanup.

## Compose server handlers

Supply an `AggregateEventService<C>` to `AppSyncEventHandlers<C>`. Its callbacks
have separate responsibilities:

| Handler | Purpose |
| --- | --- |
| `authorize` | Verify a custom token and authorize connect, subscribe, or publish using the verified principal |
| `onSubscribe` | Validate an exact current channel and current access on a native subscription invocation |
| `onPublish` | Validate a native publish invocation, process accepted envelopes durably, and return per-item results |

Use the shared verifier for custom JWTs or the verified provider claims on
native Cognito/OIDC invocations. Do not accept provider claims or handler
context from a public HTTP request body. Use `AppSyncHttpPublisher` with
`AppSyncIamAuthorization` to relay committed messages and refresh hints from
an authorized backend. Limit the injected `trustedRelay` to that backend's
IAM identity. For an application-owned server that needs an HTTP bridge,
[`AppSyncHttpBridge`](lib/src/appsync_event_handlers.dart) defines the separate
HMAC contract; keep its secret on the backend.

## Handle changes in access

Physical channels use a namespace and a random UUID. The server maps them to
a typed logical aggregate. It rejects wildcard, unknown, and retired channel
IDs. A physical channel is never a substitute for application policy.

Update authoritative membership before publishing an access change. Register
the relevant event types with the service's `rotatesAccess` callback. The
service assigns a fresh channel, stores the result for retained retries, and
sends a refresh hint to the retired channel. It routes the event payload to
the new channel. Clients resolve their rights again before joining it. A
removed subscriber sees `revoked`; other watches continue.

Revocation depends on propagation of the policy change and rotation trigger;
membership updates and rotation are separate operations. A missed trigger can
delay revocation, and already delivered messages cannot be recalled.

See the [examples](example/README.md) for local invocation and compile
checks. These exercises do not deploy to AWS.
