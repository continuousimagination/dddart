import 'package:dddart_webhooks/dddart_webhooks.dart';
import 'package:test/test.dart';

// Test implementation of WebhookVerificationResult
class TestVerificationResult extends WebhookVerificationResult {
  const TestVerificationResult({
    required super.isValid,
    super.errorMessage,
    this.metadata,
  });

  final String? metadata;
}

void main() {
  group('WebhookVerificationResult', () {
    test('should create valid result without error message', () {
      const result = TestVerificationResult(isValid: true);

      expect(result.isValid, isTrue);
      expect(result.errorMessage, isNull);
      expect(result.metadata, isNull);
    });

    test('should create invalid result with error message', () {
      const result = TestVerificationResult(
        isValid: false,
        errorMessage: 'Signature mismatch',
      );

      expect(result.isValid, isFalse);
      expect(result.errorMessage, equals('Signature mismatch'));
    });

    test('should support provider-specific metadata', () {
      const result = TestVerificationResult(
        isValid: true,
        metadata: 'custom-data',
      );

      expect(result.isValid, isTrue);
      expect(result.metadata, equals('custom-data'));
    });

    test('should allow null error message for valid results', () {
      const result = TestVerificationResult(
        isValid: true,
      );

      expect(result.isValid, isTrue);
      expect(result.errorMessage, isNull);
    });

    test('should allow error message with invalid result', () {
      const result = TestVerificationResult(
        isValid: false,
        errorMessage: 'Missing required headers',
      );

      expect(result.isValid, isFalse);
      expect(result.errorMessage, equals('Missing required headers'));
    });
  });
}
