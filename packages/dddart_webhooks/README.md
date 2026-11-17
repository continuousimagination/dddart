# dddart_webhooks

Typed Shelf webhook resources with application-supplied signature verification,
payload deserialization and handling.

[Complete examples](example/README.md) ·
[Slack server setup](../../docs/quickstarts/slack_server/README.md) ·
[Public API](lib/dddart_webhooks.dart)

## Request handling

`WebhookResource<TPayload, TVerification>` reads the raw body, calls the verifier,
deserializes verified content and invokes the handler. Register its
`handleRequest` with Shelf Router or `HttpServer.addRoute('POST', ...)`.
`HttpServer` has no `registerWebhook` method.

Supply a `WebhookVerifier<T>` whose result extends `WebhookVerificationResult`.
The [custom verifier example](example/custom_verifier_example.dart) contains the
full verifier and payload types. Signature algorithms, signed fields, timestamp
policy and sender identity are application/provider contracts. An unsigned header
must not become trusted user identity merely because the body signature is valid.

`WebhookDeserializers.json` delegates object conversion to an application factory;
`form` supplies form values. A raw String payload can omit the deserializer.
For other payload types, omission is not a compile-time error: the runtime cast
can fail and the resource returns its deserialization-error response.

## Errors and deployment

Invalid verification returns a sanitized 401. A verifier exception is logged and
returns generic 500. Deserialization failures return 400 or the application's
`onDeserializationError` response; handler failures return 500. Avoid exposing
payloads, signatures, credentials or internal exception details in responses/logs.

Use transport encryption and application request-size/rate controls for deployed
endpoints. The resource does not supply a deployment, request deduplication or
provider subscription. Timestamp windows reject stale requests but do not prevent
repeated delivery within the window; handlers must account for provider retries.

The complete examples cover raw JSON, forms, custom verification and combined
REST/webhook routing. They are compiled because they run servers and need actual
senders/configuration. Unit tests exercise request verification and error paths.
The [support matrix](../../docs/CAPABILITIES.md) and
[validation commands](../../scripts/README.md) state these boundaries.
