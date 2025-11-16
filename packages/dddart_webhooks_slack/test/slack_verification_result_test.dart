import 'package:dddart_webhooks_slack/dddart_webhooks_slack.dart';
import 'package:test/test.dart';

void main() {
  group('SlackVerificationResult', () {
    test('should create valid result without metadata', () {
      const result = SlackVerificationResult(isValid: true);

      expect(result.isValid, isTrue);
      expect(result.errorMessage, isNull);
      expect(result.teamId, isNull);
      expect(result.timestamp, isNull);
      expect(result.requestType, isNull);
    });

    test('should create invalid result with error message', () {
      const result = SlackVerificationResult(
        isValid: false,
        errorMessage: 'Signature mismatch',
      );

      expect(result.isValid, isFalse);
      expect(result.errorMessage, equals('Signature mismatch'));
      expect(result.teamId, isNull);
      expect(result.timestamp, isNull);
      expect(result.requestType, isNull);
    });

    test('should include Slack-specific metadata', () {
      final timestamp = DateTime(2024, 1, 15, 10, 30);
      final result = SlackVerificationResult(
        isValid: true,
        teamId: 'T1234567890',
        timestamp: timestamp,
        requestType: 'slash_command',
      );

      expect(result.isValid, isTrue);
      expect(result.teamId, equals('T1234567890'));
      expect(result.timestamp, equals(timestamp));
      expect(result.requestType, equals('slash_command'));
    });

    test('should support partial metadata', () {
      final timestamp = DateTime(2024, 1, 15, 10, 30);
      final result = SlackVerificationResult(
        isValid: true,
        timestamp: timestamp,
      );

      expect(result.isValid, isTrue);
      expect(result.timestamp, equals(timestamp));
      expect(result.teamId, isNull);
      expect(result.requestType, isNull);
    });

    test('should include metadata with invalid result', () {
      final timestamp = DateTime(2024, 1, 15, 10, 30);
      final result = SlackVerificationResult(
        isValid: false,
        errorMessage: 'Request timestamp too old',
        timestamp: timestamp,
        teamId: 'T1234567890',
      );

      expect(result.isValid, isFalse);
      expect(result.errorMessage, equals('Request timestamp too old'));
      expect(result.timestamp, equals(timestamp));
      expect(result.teamId, equals('T1234567890'));
    });

    test('should support different request types', () {
      const types = [
        'slash_command',
        'interactive_message',
        'event_callback',
        'url_verification',
      ];

      for (final type in types) {
        final result = SlackVerificationResult(
          isValid: true,
          requestType: type,
        );

        expect(result.requestType, equals(type));
      }
    });
  });
}
