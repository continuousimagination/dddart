import 'dart:convert';
import 'dart:io' as io;

import 'package:crypto/crypto.dart';
import 'package:dddart_http/dddart_http.dart';
import 'package:dddart_webhooks/dddart_webhooks.dart';
import 'package:dddart_webhooks_slack/dddart_webhooks_slack.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

// Helper to make HTTP requests
Future<HttpResponse> makeRequest({
  required String method,
  required String path,
  Map<String, String>? headers,
  String? body,
  int port = 8080,
}) async {
  final client = io.HttpClient();
  try {
    final request =
        await client.openUrl(method, Uri.parse('http://localhost:$port$path'));

    // Add headers
    if (headers != null) {
      headers.forEach((key, value) {
        request.headers.set(key, value);
      });
    }

    // Add body
    if (body != null) {
      request.write(body);
    }

    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();

    return HttpResponse(
      statusCode: response.statusCode,
      headers: response.headers,
      body: responseBody,
    );
  } finally {
    client.close();
  }
}

class HttpResponse {
  HttpResponse({
    required this.statusCode,
    required this.headers,
    required this.body,
  });

  final int statusCode;
  final io.HttpHeaders headers;
  final String body;

  String? header(String name) {
    return headers.value(name);
  }
}

// Helper to generate valid Slack signature
String generateSlackSignature(String body, int timestamp, String secret) {
  final baseString = 'v0:$timestamp:$body';
  final hmac = Hmac(sha256, utf8.encode(secret));
  final digest = hmac.convert(utf8.encode(baseString));
  return 'v0=$digest';
}

void main() {
  group('Slack Webhook Integration Tests', () {
    const signingSecret = 'test-slack-signing-secret';

    group('Slack slash command webhook', () {
      late HttpServer server;
      const port = 8093;

      tearDown(() async {
        await server.stop();
      });

      test('should process Slack slash command end-to-end', () async {
        var handlerCalled = false;
        SlackSlashCommand? receivedCommand;
        SlackVerificationResult? receivedVerification;

        server = HttpServer(port: port);

        final webhook =
            WebhookResource<SlackSlashCommand, SlackVerificationResult>(
          path: '/slack/commands',
          verifier: SlackWebhookVerifier(signingSecret: signingSecret),
          deserializer: (body) => WebhookDeserializers.form(
            body,
            SlackSlashCommand.fromForm,
          ),
          handler: (command, verification) async {
            handlerCalled = true;
            receivedCommand = command;
            receivedVerification = verification;
            return Response.ok('Command received!');
          },
        );

        server.registerWebhook(webhook);
        await server.start();

        // Create realistic Slack slash command payload
        final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final body = 'command=/test&'
            'text=hello+world&'
            'user_id=U123456&'
            'user_name=testuser&'
            'team_id=T123456&'
            'channel_id=C123456&'
            'response_url=https://hooks.slack.com/commands/123/456&'
            'trigger_id=123.456.789';

        final signature =
            generateSlackSignature(body, timestamp, signingSecret);

        final response = await makeRequest(
          method: 'POST',
          path: '/slack/commands',
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'X-Slack-Signature': signature,
            'X-Slack-Request-Timestamp': timestamp.toString(),
          },
          body: body,
          port: port,
        );

        expect(response.statusCode, equals(200));
        expect(response.body, equals('Command received!'));
        expect(handlerCalled, isTrue);
        expect(receivedCommand?.command, equals('/test'));
        expect(receivedCommand?.text, equals('hello world'));
        expect(receivedCommand?.userId, equals('U123456'));
        expect(receivedCommand?.userName, equals('testuser'));
        expect(receivedCommand?.teamId, equals('T123456'));
        expect(receivedCommand?.channelId, equals('C123456'));
        expect(
          receivedCommand?.responseUrl,
          equals('https://hooks.slack.com/commands/123/456'),
        );
        expect(receivedCommand?.triggerId, equals('123.456.789'));
        expect(receivedVerification?.isValid, isTrue);
        expect(receivedVerification?.teamId, isNull); // Form data, not JSON
      });

      test('should reject Slack webhook with invalid signature', () async {
        server = HttpServer(port: port);

        final webhook =
            WebhookResource<SlackSlashCommand, SlackVerificationResult>(
          path: '/slack/commands',
          verifier: SlackWebhookVerifier(signingSecret: signingSecret),
          deserializer: (body) => WebhookDeserializers.form(
            body,
            SlackSlashCommand.fromForm,
          ),
          handler: (command, verification) async {
            return Response.ok('Command received!');
          },
        );

        server.registerWebhook(webhook);
        await server.start();

        final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final body = 'command=/test&text=hello&user_id=U123&'
            'user_name=test&team_id=T123&channel_id=C123&'
            'response_url=https://example.com';

        final response = await makeRequest(
          method: 'POST',
          path: '/slack/commands',
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'X-Slack-Signature': 'v0=invalid_signature',
            'X-Slack-Request-Timestamp': timestamp.toString(),
          },
          body: body,
          port: port,
        );

        expect(response.statusCode, equals(401));
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        expect(json['error'], equals('Signature verification failed'));
        expect(json['message'], equals('Signature mismatch'));
      });

      test('should reject Slack webhook with expired timestamp', () async {
        server = HttpServer(port: port);

        final webhook =
            WebhookResource<SlackSlashCommand, SlackVerificationResult>(
          path: '/slack/commands',
          verifier: SlackWebhookVerifier(signingSecret: signingSecret),
          deserializer: (body) => WebhookDeserializers.form(
            body,
            SlackSlashCommand.fromForm,
          ),
          handler: (command, verification) async {
            return Response.ok('Command received!');
          },
        );

        server.registerWebhook(webhook);
        await server.start();

        // Create timestamp from 10 minutes ago (beyond default 5-minute window)
        final oldTimestamp =
            (DateTime.now().millisecondsSinceEpoch ~/ 1000) - (10 * 60);
        final body = 'command=/test&text=hello&user_id=U123&'
            'user_name=test&team_id=T123&channel_id=C123&'
            'response_url=https://example.com';

        final signature =
            generateSlackSignature(body, oldTimestamp, signingSecret);

        final response = await makeRequest(
          method: 'POST',
          path: '/slack/commands',
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'X-Slack-Signature': signature,
            'X-Slack-Request-Timestamp': oldTimestamp.toString(),
          },
          body: body,
          port: port,
        );

        expect(response.statusCode, equals(401));
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        expect(json['error'], equals('Signature verification failed'));
        expect(
          json['message'],
          equals('Request timestamp too old (replay attack prevention)'),
        );
      });
    });

    group('Slack event callback webhook', () {
      late HttpServer server;
      const port = 8094;

      tearDown(() async {
        await server.stop();
      });

      test('should process Slack event callback with JSON payload', () async {
        var handlerCalled = false;
        Map<String, dynamic>? receivedEvent;
        SlackVerificationResult? receivedVerification;

        server = HttpServer(port: port);

        final webhook =
            WebhookResource<Map<String, dynamic>, SlackVerificationResult>(
          path: '/slack/events',
          verifier: SlackWebhookVerifier(signingSecret: signingSecret),
          deserializer: (body) => jsonDecode(body) as Map<String, dynamic>,
          handler: (event, verification) async {
            handlerCalled = true;
            receivedEvent = event;
            receivedVerification = verification;
            return Response.ok(jsonEncode({'ok': true}));
          },
        );

        server.registerWebhook(webhook);
        await server.start();

        // Create realistic Slack event callback payload
        final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final eventPayload = {
          'token': 'verification_token',
          'team_id': 'T123456',
          'api_app_id': 'A123456',
          'event': {
            'type': 'message',
            'channel': 'C123456',
            'user': 'U123456',
            'text': 'Hello, world!',
            'ts': '1234567890.123456',
          },
          'type': 'event_callback',
          'event_id': 'Ev123456',
          'event_time': 1234567890,
        };

        final body = jsonEncode(eventPayload);
        final signature =
            generateSlackSignature(body, timestamp, signingSecret);

        final response = await makeRequest(
          method: 'POST',
          path: '/slack/events',
          headers: {
            'Content-Type': 'application/json',
            'X-Slack-Signature': signature,
            'X-Slack-Request-Timestamp': timestamp.toString(),
          },
          body: body,
          port: port,
        );

        expect(response.statusCode, equals(200));
        expect(handlerCalled, isTrue);
        expect(receivedEvent?['team_id'], equals('T123456'));
        expect(receivedEvent?['type'], equals('event_callback'));
        expect(receivedEvent?['event']['type'], equals('message'));
        expect(receivedEvent?['event']['text'], equals('Hello, world!'));
        expect(receivedVerification?.isValid, isTrue);
        expect(receivedVerification?.teamId, equals('T123456'));
        expect(receivedVerification?.requestType, equals('event_callback'));
      });

      test('should handle Slack URL verification challenge', () async {
        server = HttpServer(port: port);

        final webhook =
            WebhookResource<Map<String, dynamic>, SlackVerificationResult>(
          path: '/slack/events',
          verifier: SlackWebhookVerifier(signingSecret: signingSecret),
          deserializer: (body) => jsonDecode(body) as Map<String, dynamic>,
          handler: (event, verification) async {
            // Handle URL verification challenge
            if (event['type'] == 'url_verification') {
              return Response.ok(
                jsonEncode({'challenge': event['challenge']}),
                headers: {'Content-Type': 'application/json'},
              );
            }
            return Response.ok(jsonEncode({'ok': true}));
          },
        );

        server.registerWebhook(webhook);
        await server.start();

        final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final challengePayload = {
          'token': 'verification_token',
          'challenge': 'challenge_string_12345',
          'type': 'url_verification',
        };

        final body = jsonEncode(challengePayload);
        final signature =
            generateSlackSignature(body, timestamp, signingSecret);

        final response = await makeRequest(
          method: 'POST',
          path: '/slack/events',
          headers: {
            'Content-Type': 'application/json',
            'X-Slack-Signature': signature,
            'X-Slack-Request-Timestamp': timestamp.toString(),
          },
          body: body,
          port: port,
        );

        expect(response.statusCode, equals(200));
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        expect(json['challenge'], equals('challenge_string_12345'));
      });
    });

    group('Multiple Slack webhooks', () {
      late HttpServer server;
      const port = 8095;

      tearDown(() async {
        await server.stop();
      });

      test('should handle multiple Slack webhook endpoints', () async {
        var commandHandlerCalled = false;
        var eventHandlerCalled = false;
        var interactiveHandlerCalled = false;

        server = HttpServer(port: port);

        // Slash command webhook
        final commandWebhook =
            WebhookResource<SlackSlashCommand, SlackVerificationResult>(
          path: '/slack/commands',
          verifier: SlackWebhookVerifier(signingSecret: signingSecret),
          deserializer: (body) => WebhookDeserializers.form(
            body,
            SlackSlashCommand.fromForm,
          ),
          handler: (command, verification) async {
            commandHandlerCalled = true;
            return Response.ok('Command received');
          },
        );

        // Event callback webhook
        final eventWebhook =
            WebhookResource<Map<String, dynamic>, SlackVerificationResult>(
          path: '/slack/events',
          verifier: SlackWebhookVerifier(signingSecret: signingSecret),
          deserializer: (body) => jsonDecode(body) as Map<String, dynamic>,
          handler: (event, verification) async {
            eventHandlerCalled = true;
            return Response.ok(jsonEncode({'ok': true}));
          },
        );

        // Interactive message webhook
        final interactiveWebhook =
            WebhookResource<Map<String, dynamic>, SlackVerificationResult>(
          path: '/slack/interactive',
          verifier: SlackWebhookVerifier(signingSecret: signingSecret),
          deserializer: (body) {
            // Interactive messages come as form-encoded with 'payload' field
            final form = Uri.splitQueryString(body);
            return jsonDecode(form['payload']!) as Map<String, dynamic>;
          },
          handler: (payload, verification) async {
            interactiveHandlerCalled = true;
            return Response.ok(jsonEncode({'ok': true}));
          },
        );

        server
          ..registerWebhook(commandWebhook)
          ..registerWebhook(eventWebhook)
          ..registerWebhook(interactiveWebhook);

        await server.start();

        // Test slash command
        final commandTimestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final commandBody = 'command=/test&text=hello&user_id=U123&'
            'user_name=test&team_id=T123&channel_id=C123&'
            'response_url=https://example.com';
        final commandSignature = generateSlackSignature(
            commandBody, commandTimestamp, signingSecret);

        final commandResponse = await makeRequest(
          method: 'POST',
          path: '/slack/commands',
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'X-Slack-Signature': commandSignature,
            'X-Slack-Request-Timestamp': commandTimestamp.toString(),
          },
          body: commandBody,
          port: port,
        );

        expect(commandResponse.statusCode, equals(200));
        expect(commandHandlerCalled, isTrue);

        // Test event callback
        final eventTimestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final eventBody = jsonEncode({
          'team_id': 'T123',
          'type': 'event_callback',
          'event': {'type': 'message'},
        });
        final eventSignature =
            generateSlackSignature(eventBody, eventTimestamp, signingSecret);

        final eventResponse = await makeRequest(
          method: 'POST',
          path: '/slack/events',
          headers: {
            'Content-Type': 'application/json',
            'X-Slack-Signature': eventSignature,
            'X-Slack-Request-Timestamp': eventTimestamp.toString(),
          },
          body: eventBody,
          port: port,
        );

        expect(eventResponse.statusCode, equals(200));
        expect(eventHandlerCalled, isTrue);

        // Test interactive message
        final interactiveTimestamp =
            DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final interactivePayload = jsonEncode({
          'type': 'block_actions',
          'team': {'id': 'T123'},
          'user': {'id': 'U123'},
          'actions': [
            {'action_id': 'button_click', 'value': 'clicked'},
          ],
        });
        final interactiveBody =
            'payload=${Uri.encodeComponent(interactivePayload)}';
        final interactiveSignature = generateSlackSignature(
          interactiveBody,
          interactiveTimestamp,
          signingSecret,
        );

        final interactiveResponse = await makeRequest(
          method: 'POST',
          path: '/slack/interactive',
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'X-Slack-Signature': interactiveSignature,
            'X-Slack-Request-Timestamp': interactiveTimestamp.toString(),
          },
          body: interactiveBody,
          port: port,
        );

        expect(interactiveResponse.statusCode, equals(200));
        expect(interactiveHandlerCalled, isTrue);
      });
    });
  });
}
