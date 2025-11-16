import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dddart_webhooks_slack/dddart_webhooks_slack.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  group('SlackWebhookVerifier', () {
    const signingSecret = 'test-signing-secret';
    late SlackWebhookVerifier verifier;

    setUp(() {
      verifier = SlackWebhookVerifier(signingSecret: signingSecret);
    });

    test('should verify valid Slack signature', () async {
      // Arrange
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final body = jsonEncode({'team_id': 'T123', 'type': 'slash_command'});
      final baseString = 'v0:$timestamp:$body';
      final hmac = Hmac(sha256, utf8.encode(signingSecret));
      final digest = hmac.convert(utf8.encode(baseString));
      final signature = 'v0=$digest';

      final request = Request(
        'POST',
        Uri.parse('http://example.com/webhook'),
        headers: {
          'x-slack-signature': signature,
          'x-slack-request-timestamp': timestamp.toString(),
        },
      );

      // Act
      final result = await verifier.verify(request, body);

      // Assert
      expect(result.isValid, isTrue);
      expect(result.errorMessage, isNull);
      expect(result.teamId, equals('T123'));
      expect(result.requestType, equals('slash_command'));
      expect(result.timestamp, isNotNull);
    });

    test('should reject request with invalid signature', () async {
      // Arrange
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final body = jsonEncode({'team_id': 'T123'});
      final invalidSignature = 'v0=invalid_signature_hash';

      final request = Request(
        'POST',
        Uri.parse('http://example.com/webhook'),
        headers: {
          'x-slack-signature': invalidSignature,
          'x-slack-request-timestamp': timestamp.toString(),
        },
      );

      // Act
      final result = await verifier.verify(request, body);

      // Assert
      expect(result.isValid, isFalse);
      expect(result.errorMessage, equals('Signature mismatch'));
    });

    test('should reject request with missing headers', () async {
      // Arrange
      final body = jsonEncode({'team_id': 'T123'});
      final request = Request(
        'POST',
        Uri.parse('http://example.com/webhook'),
      );

      // Act
      final result = await verifier.verify(request, body);

      // Assert
      expect(result.isValid, isFalse);
      expect(
        result.errorMessage,
        contains('Missing required Slack headers'),
      );
    });

    test('should reject request with invalid timestamp format', () async {
      // Arrange
      final body = jsonEncode({'team_id': 'T123'});
      final request = Request(
        'POST',
        Uri.parse('http://example.com/webhook'),
        headers: {
          'x-slack-signature': 'v0=somehash',
          'x-slack-request-timestamp': 'invalid',
        },
      );

      // Act
      final result = await verifier.verify(request, body);

      // Assert
      expect(result.isValid, isFalse);
      expect(result.errorMessage, equals('Invalid timestamp format'));
    });

    test('should reject request with expired timestamp (replay attack)',
        () async {
      // Arrange
      final oldTimestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000) -
          (6 * 60); // 6 minutes ago
      final body = jsonEncode({'team_id': 'T123'});
      final baseString = 'v0:$oldTimestamp:$body';
      final hmac = Hmac(sha256, utf8.encode(signingSecret));
      final digest = hmac.convert(utf8.encode(baseString));
      final signature = 'v0=$digest';

      final request = Request(
        'POST',
        Uri.parse('http://example.com/webhook'),
        headers: {
          'x-slack-signature': signature,
          'x-slack-request-timestamp': oldTimestamp.toString(),
        },
      );

      // Act
      final result = await verifier.verify(request, body);

      // Assert
      expect(result.isValid, isFalse);
      expect(
        result.errorMessage,
        equals('Request timestamp too old (replay attack prevention)'),
      );
    });

    test('should handle non-JSON body gracefully', () async {
      // Arrange
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final body = 'command=/test&text=hello';
      final baseString = 'v0:$timestamp:$body';
      final hmac = Hmac(sha256, utf8.encode(signingSecret));
      final digest = hmac.convert(utf8.encode(baseString));
      final signature = 'v0=$digest';

      final request = Request(
        'POST',
        Uri.parse('http://example.com/webhook'),
        headers: {
          'x-slack-signature': signature,
          'x-slack-request-timestamp': timestamp.toString(),
        },
      );

      // Act
      final result = await verifier.verify(request, body);

      // Assert
      expect(result.isValid, isTrue);
      expect(result.teamId, isNull);
      expect(result.requestType, isNull);
    });

    test('should handle malformed JSON body gracefully', () async {
      // Arrange
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final body = '{invalid json}';
      final baseString = 'v0:$timestamp:$body';
      final hmac = Hmac(sha256, utf8.encode(signingSecret));
      final digest = hmac.convert(utf8.encode(baseString));
      final signature = 'v0=$digest';

      final request = Request(
        'POST',
        Uri.parse('http://example.com/webhook'),
        headers: {
          'x-slack-signature': signature,
          'x-slack-request-timestamp': timestamp.toString(),
        },
      );

      // Act
      final result = await verifier.verify(request, body);

      // Assert
      expect(result.isValid, isTrue);
      expect(result.teamId, isNull);
      expect(result.requestType, isNull);
    });

    test('should extract metadata from valid JSON with team_id and type',
        () async {
      // Arrange
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final body = jsonEncode({
        'team_id': 'T12345678',
        'type': 'event_callback',
        'event': {'type': 'message'},
      });
      final baseString = 'v0:$timestamp:$body';
      final hmac = Hmac(sha256, utf8.encode(signingSecret));
      final digest = hmac.convert(utf8.encode(baseString));
      final signature = 'v0=$digest';

      final request = Request(
        'POST',
        Uri.parse('http://example.com/webhook'),
        headers: {
          'x-slack-signature': signature,
          'x-slack-request-timestamp': timestamp.toString(),
        },
      );

      // Act
      final result = await verifier.verify(request, body);

      // Assert
      expect(result.isValid, isTrue);
      expect(result.teamId, equals('T12345678'));
      expect(result.requestType, equals('event_callback'));
    });

    test('should handle JSON without team_id or type fields', () async {
      // Arrange
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final body = jsonEncode({'other_field': 'value'});
      final baseString = 'v0:$timestamp:$body';
      final hmac = Hmac(sha256, utf8.encode(signingSecret));
      final digest = hmac.convert(utf8.encode(baseString));
      final signature = 'v0=$digest';

      final request = Request(
        'POST',
        Uri.parse('http://example.com/webhook'),
        headers: {
          'x-slack-signature': signature,
          'x-slack-request-timestamp': timestamp.toString(),
        },
      );

      // Act
      final result = await verifier.verify(request, body);

      // Assert
      expect(result.isValid, isTrue);
      expect(result.teamId, isNull);
      expect(result.requestType, isNull);
    });

    test('should use custom maxTimestampAge', () async {
      // Arrange
      final customVerifier = SlackWebhookVerifier(
        signingSecret: signingSecret,
        maxTimestampAge: const Duration(seconds: 30),
      );
      final oldTimestamp =
          (DateTime.now().millisecondsSinceEpoch ~/ 1000) - 60; // 1 minute ago
      final body = jsonEncode({'team_id': 'T123'});
      final baseString = 'v0:$oldTimestamp:$body';
      final hmac = Hmac(sha256, utf8.encode(signingSecret));
      final digest = hmac.convert(utf8.encode(baseString));
      final signature = 'v0=$digest';

      final request = Request(
        'POST',
        Uri.parse('http://example.com/webhook'),
        headers: {
          'x-slack-signature': signature,
          'x-slack-request-timestamp': oldTimestamp.toString(),
        },
      );

      // Act
      final result = await customVerifier.verify(request, body);

      // Assert
      expect(result.isValid, isFalse);
      expect(
        result.errorMessage,
        equals('Request timestamp too old (replay attack prevention)'),
      );
    });
  });
}
