# Set up a Slack webhook server

## Set up the application

Create a directory outside the repository and save the files below.

This is a **compile-only** integration example. Running the server requires an
application-owned `SLACK_SIGNING_SECRET`, a configured Slack sender and deployment.
The check never starts the server, reads a secret or contacts Slack.

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
dart analyze --fatal-infos
mkdir -p build
dart compile kernel bin/main.dart -o build/server.dill
```
<!-- /dddart-source -->

Remove the temporary application directory when finished. See the
[documentation gate](../../../tool/documentation/README.md) for isolation, CI,
service boundaries and the separate hosted release checks.
