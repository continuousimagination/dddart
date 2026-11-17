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
