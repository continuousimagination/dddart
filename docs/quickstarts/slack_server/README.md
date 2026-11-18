# Set up a Slack webhook server

Receive a slash command, verify Slack’s signature, and return a message to
the caller. You can compile the server locally before connecting Slack.

## Set up the application

Create an empty directory outside the repository with a `bin` subdirectory.
Copy the [example pubspec](pubspec.yaml.txt) into the application as `pubspec.yaml`.

## Add the application files

Save as `bin/main.dart`:

<!-- dddart-source: docs/quickstarts/slack_server/bin/main.dart -->
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
<!-- /dddart-source -->

## Compile the server

<!-- dddart-source: docs/quickstarts/slack_server/commands.sh -->
```sh
dart pub get
mkdir -p build
dart compile kernel bin/main.dart -o build/server.dill
```
<!-- /dddart-source -->

## Receive a command from Slack

Set `SLACK_SIGNING_SECRET` in the server environment and run `dart run bin/main.dart`.
Make port 8080 reachable through a public HTTPS address. In your Slack app,
set the slash command’s Request URL to that address with the path
`/webhooks/slack`. Invoke the command in a workspace where the app is
installed. The response includes the command and the caller’s Slack user ID.

See the [Slack examples](../../../packages/dddart_webhooks_slack/example/README.md)
for interactive messages and richer command responses.
