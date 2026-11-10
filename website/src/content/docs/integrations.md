---
title: Add adapters at the edges
description: Connect Slack webhooks, optional AppSync live events, and serverless handlers while keeping the domain contracts shared.
section: Connect the pieces
order: 50
---

External systems have their own protocols. An adapter translates those protocols into your application's language. It should not make a Slack request, an AWS channel, or a database connection part of a domain object's identity.

These integrations are optional. You can use the core package without a server, use HTTP events without AWS, or expose a webhook without adopting distributed events.

## Receive a verified Slack command

`WebhookResource<TPayload, TVerification>` reads the body once, verifies that exact body, deserializes the payload, and then invokes your handler. A failed verification returns 401; a malformed payload returns 400. The handler receives both a typed payload and the verifier's typed result.

This complete server program uses the supplied Slack verifier and form decoder:

```dart
import 'dart:io' as io;

import 'package:dddart_rest/dddart_rest.dart';
import 'package:dddart_webhooks/dddart_webhooks.dart';
import 'package:dddart_webhooks_slack/dddart_webhooks_slack.dart';
import 'package:shelf/shelf.dart';

Future<void> main() async {
  final secret = io.Platform.environment['SLACK_SIGNING_SECRET'];
  if (secret == null || secret.isEmpty) {
    throw StateError('Set SLACK_SIGNING_SECRET before starting the server.');
  }

  final webhook = WebhookResource<SlackSlashCommand, SlackVerificationResult>(
    path: '/webhooks/slack',
    verifier: SlackWebhookVerifier(signingSecret: secret),
    deserializer: (body) => WebhookDeserializers.form(
      body,
      SlackSlashCommand.fromForm,
    ),
    handler: (command, verification) async {
      // Translate the command into an application use case here.
      return Response.ok('Received ${command.command} from ${command.userId}');
    },
  );

  final server = HttpServer(port: 8080)
    ..addRoute('POST', webhook.path, webhook.handleRequest);
  await server.start();
}
```

Install `dddart_rest`, `dddart_webhooks`, `dddart_webhooks_slack`, and `shelf` through your application's dependency setup. Use the [Git installation guide](/dddart/docs/getting-started/) for the dddart packages. Configure Slack's command request URL to reach this route through your deployment's HTTPS endpoint.

The verifier checks Slack's HMAC-SHA256 signature and rejects timestamps outside a five-minute past-or-future window by default. A timestamp window is not a permanent duplicate-request ledger. If a command causes a non-repeatable action, give the application use case its own idempotency strategy.

Use `command.teamId` for a slash command's workspace: the verifier's optional `teamId` metadata is extracted from JSON, while slash commands are form encoded. Use `userId` as the stable user identity; `userName` is optional.

The handler above only acknowledges the input. Authorization to perform an application action still belongs to that action. A valid Slack signature proves the request came through Slack; it does not by itself give a user permission to approve an order.

## Add another webhook provider

Implement `WebhookVerifier<YourVerificationResult>` for the provider's exact signature format, and choose a decoder with `WebhookDeserializers.json` or `.form`. Signature verification happens before deserialization. A raw `String` payload can omit a deserializer.

Register the handler with `HttpServer.addRoute('POST', path, resource.handleRequest)`, or mount it in your existing Shelf router. There is no `registerWebhook` method on `HttpServer`.

See the [webhook resource](https://github.com/continuousimagination/dddart/blob/b4aacf0671873e729a1a390dc2bb609b80c723e5/packages/dddart_webhooks/lib/src/webhook_resource.dart), [Slack verifier](https://github.com/continuousimagination/dddart/blob/b4aacf0671873e729a1a390dc2bb609b80c723e5/packages/dddart_webhooks_slack/lib/src/slack_webhook_verifier.dart), and [Slack examples](https://github.com/continuousimagination/dddart/tree/b4aacf0671873e729a1a390dc2bb609b80c723e5/packages/dddart_webhooks_slack/example).

## Add live events with AppSync

`dddart_events_appsync` implements an optional transport for the [aggregate-watch contract](/dddart/docs/events/). It uses AppSync Events directly. There is no GraphQL schema to maintain, and clients do not need Amplify, Flutter, or AWS access keys merely to watch aggregates.

HTTP control routes still resolve membership, authorize publication targets, and recover retained history. The live transport multiplexes watches over one WebSocket. The following helper is complete; provide endpoints from an existing deployment and the current application-token callback:

```dart
import 'package:dddart/dddart.dart';
import 'package:dddart_events_appsync/dddart_events_appsync.dart';
import 'package:dddart_events_distributed/dddart_events_distributed.dart';

AggregateEventClient liveEvents({
  required Uri controlUrl,
  required Uri eventHttpUrl,
  required Uri eventRealtimeUrl,
  required EventRegistry registry,
  required Future<String> Function() currentToken,
  required String Function(DomainEvent<Identity>) aggregateKind,
}) {
  final wire = AggregateEventWire(registry.identityCodecs);
  final control = HttpAggregateEventTransport(
    baseUrl: controlUrl,
    wire: wire,
    tokenProvider: currentToken,
  );
  final live = AppSyncEventTransport(
    httpEndpoint: eventHttpUrl,
    realtimeEndpoint: eventRealtimeUrl,
    namespace: 'aggregates',
    control: control,
    wire: wire,
    authorization: () async => {'Authorization': await currentToken()},
  );
  return AggregateEventClient(
    transport: live,
    registry: registry,
    aggregateKind: aggregateKind,
  );
}
```

The namespace must match the deployment. Connections, subscriptions, and publications obtain current credentials. The client uses portable HTTP and WebSocket abstractions for browser and native applications. Pause, resume, disposal, history expiration, and duplicate handling remain the responsibilities described in the event guide; this foreground transport does not supply background mobile notifications.

## Keep durable event infrastructure on the server

For multiple server processes or Lambda invocations, use shared event history and channel mappings. With a configured `DynamoConnection` and an existing event table:

```dart
final history = DynamoAggregateEventRepository(
  client: connection.client,
  tableName: eventTableName,
  identityCodecs: registry.identityCodecs,
);
final channels = DynamoEventChannelRepository(
  client: connection.client,
  tableName: eventTableName,
  identityCodecs: registry.identityCodecs,
);
```

These classes come from `dddart_events_dynamodb`; `DynamoConnection` comes from `dddart_repository_dynamodb`. Pass the repositories into `AggregateEventService` alongside the registry and application policy. Clients do not need this database package or their own event database.

The table uses string `pk` / `sk` keys and an `expiresAt` TTL attribute. An append transaction commits the history record, occurrence lookup, and ingestion head together. Retention defaults to seven days; reads enforce expiration even when physical TTL deletion has not happened yet. Current heads and channel mappings do not expire. Adapter construction does not create the table.

## Reuse authentication in native handlers

`CredentialVerifier<C>.verifyCredential(token)` is independent of an HTTP request. `JwtAuthHandler` and `OAuthJwtAuthHandler` expose that contract, so an application can reuse its verified claims for HTTP and native event handlers. `JwtCredentialVerifier` is available without token-issuance or refresh-token repositories.

`AppSyncEventHandlers<C>` receives an `AggregateEventService<C>` plus authentication and claims callbacks. Its operations have distinct native contracts:

| Operation | Responsibility |
| --- | --- |
| `authorize` | Validate the token and operation; return verified handler context. |
| `onSubscribe` | Check the current channel and current aggregate membership. |
| `onPublish` | Validate each envelope, await durable acceptance, and return accepted payloads or item errors. |

The supplied custom runtime awaits invocation work. Your Lambda handler should likewise await `repository.save` or `publisher.publish` before returning. A fire-and-forget local bus listener is not a durable serverless publication boundary.

AppSync physical channels use random IDs, separate from logical aggregate identities. When application access changes, update authoritative membership and publish a registered access-changing event. The service can rotate the channel and prompt subscribers to reauthorize. Revocation is best effort: membership changes, rotation, and in-flight delivery are not one atomic operation.

## Run locally, deploy deliberately

From a checkout with workspace dependencies resolved, this finite example exercises native invocation composition without provisioning AWS:

```bash
dart run packages/dddart_events_appsync/example/native_invocation.dart
```

The repository also includes a [CloudFormation template](https://github.com/continuousimagination/dddart/blob/b4aacf0671873e729a1a390dc2bb609b80c723e5/packages/dddart_events_appsync/deploy/cloudformation.yaml), [container definition](https://github.com/continuousimagination/dddart/blob/b4aacf0671873e729a1a390dc2bb609b80c723e5/packages/dddart_events_appsync/deploy/Dockerfile), and [Lambda entrypoint](https://github.com/continuousimagination/dddart/blob/b4aacf0671873e729a1a390dc2bb609b80c723e5/packages/dddart_events_appsync/example/lambda.dart). The template supports custom JWTs or an existing Cognito/OIDC provider; it does not create a user pool. Its reference ACL policy is example application code that you replace with your own authoritative policy.

Follow the [deployment and cleanup guide](https://github.com/continuousimagination/dddart/blob/b4aacf0671873e729a1a390dc2bb609b80c723e5/docs/DISTRIBUTED_EVENTS.md#build-and-deploy-the-reference-application) for account, region, image, table, and authentication configuration. That workflow creates billable AWS resources and is separate from this documentation site's free GitHub Pages hosting. The opt-in smoke program requires an existing configured deployment; local protocol fixtures are not a live AWS test.
