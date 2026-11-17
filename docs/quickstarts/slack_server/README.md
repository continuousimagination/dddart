# Slack server compilation context

Use Dart 3.13.7. Create an empty application directory outside the repository
and copy the following named files. The manifest pins Git dependencies to the
same revision as the primary quickstarts.

This is a **compile-only** integration example. Running the server requires an
application-owned `SLACK_SIGNING_SECRET`, a configured Slack sender and deployment.
The check never starts the server, reads a secret or contacts Slack.

Save as `pubspec.yaml`:

<!-- dddart-source: docs/quickstarts/slack_server/pubspec.yaml.txt -->
```yaml
name: dddart_slack_server_quickstart
publish_to: none
environment:
  sdk: '>=3.13.7 <4.0.0'
dependencies:
  dddart_rest:
    git:
      url: https://github.com/continuousimagination/dddart.git
      ref: 56607ac8d3913b8e896ac03f8ecff58473d62ce2
      path: packages/dddart_rest
  dddart_webhooks:
    git:
      url: https://github.com/continuousimagination/dddart.git
      ref: 56607ac8d3913b8e896ac03f8ecff58473d62ce2
      path: packages/dddart_webhooks
  dddart_webhooks_slack:
    git:
      url: https://github.com/continuousimagination/dddart.git
      ref: 56607ac8d3913b8e896ac03f8ecff58473d62ce2
      path: packages/dddart_webhooks_slack
  shelf: ^1.4.0
dependency_overrides:
  dddart:
    git:
      url: https://github.com/continuousimagination/dddart.git
      ref: 56607ac8d3913b8e896ac03f8ecff58473d62ce2
      path: packages/dddart
  dddart_json:
    git:
      url: https://github.com/continuousimagination/dddart.git
      ref: 56607ac8d3913b8e896ac03f8ecff58473d62ce2
      path: packages/dddart_json
  dddart_rest:
    git:
      url: https://github.com/continuousimagination/dddart.git
      ref: 56607ac8d3913b8e896ac03f8ecff58473d62ce2
      path: packages/dddart_rest
  dddart_serialization:
    git:
      url: https://github.com/continuousimagination/dddart.git
      ref: 56607ac8d3913b8e896ac03f8ecff58473d62ce2
      path: packages/dddart_serialization
  dddart_webhooks:
    git:
      url: https://github.com/continuousimagination/dddart.git
      ref: 56607ac8d3913b8e896ac03f8ecff58473d62ce2
      path: packages/dddart_webhooks
  dddart_webhooks_slack:
    git:
      url: https://github.com/continuousimagination/dddart.git
      ref: 56607ac8d3913b8e896ac03f8ecff58473d62ce2
      path: packages/dddart_webhooks_slack
```
<!-- /dddart-source -->

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

Run these commands:

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
