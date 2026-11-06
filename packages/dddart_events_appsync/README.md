# dddart_events_appsync

Optional AWS AppSync Events transport and native Lambda adapters for DDDart's
aggregate-watch API. It uses AppSync Events directly; no GraphQL schema, Flutter,
Amplify, mandatory Cognito, or mobile AWS keys are required. See the complete
[distributed events and deployment guide](../../docs/DISTRIBUTED_EVENTS.md).

Compose `AppSyncEventTransport` with `AggregateEventClient`. Supply the existing
application token callback to both the HTTP control transport and AppSync
authorization. HTTP control handles authenticated membership resolution, publish
routing and retained catch-up; one AppSync WebSocket multiplexes live watches.

`watch(reference)` starts at the current server head. Persist its opaque
`checkpoint` to resume that particular reference. A watch's `events` stream stays
stable across channel changes; `signals` reports `revoked` or `resyncRequired`.
The application reloads aggregate state explicitly after resynchronization is
required. `pause()` stops periodic work and closes live sockets; `resume()` obtains
current credentials, reauthorizes and recovers history. Live transports reconcile
once per minute by default, compared with the HTTP-only five-second default.

`client.publisher` is the same `EventPublisher` used by generated repository saves.
Client publication resolves a target using publish rights, separately from
subscribe rights. Retrying publication preserves the occurrence UUID. Payloads
are complete event envelopes, independently of public aggregate CRUD JSON.

Server code injects `AggregateEventService` into `AppSyncEventHandlers`. Its
`authorize`, `onSubscribe` and `onPublish` methods implement their distinct AWS
contracts and await durable processing. Register access-changing event types with
the service's `rotatesAccess` callback. Use `AppSyncHttpPublisher` for trusted IAM
relay/control and `AppSyncIamAuthorization` with current server credentials.
`AppSyncHttpBridge` is an optional backend-only HMAC-authenticated HTTP bridge;
direct Lambda integration needs no HTTP listener.

The [CloudFormation template](deploy/cloudformation.yaml),
[Dockerfile](deploy/Dockerfile) and complete
[Lambda Runtime API entrypoint](example/lambda.dart) implement a deployable
reference application with DynamoDB-backed ACLs. The sample ACL policy is explicit
application code; substitute your own authoritative repositories in a real app.
The template supports custom JWTs and existing Cognito/OIDC providers, creates no
user pool, and accepts an existing event table. Its HTTP function URL requires
application Bearer authentication on every route.

```bash
# Resolve from the workspace root, then:
cd packages/dddart_events_appsync
dart test
dart run example/native_invocation.dart
```

Protocol tests use a local WebSocket endpoint and real serialized AWS-shaped
frames. These are not live AWS tests. `example/aws_smoke.dart` is compile-checked
and runs only after explicit opt-in against an existing configured deployment.
Deployment, smoke configuration, schema validation and cleanup are documented in
the repository guide. This package never provisions resources during initialization.
