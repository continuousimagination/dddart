import 'dart:math';

import 'package:dddart_rest_client/src/auth_provider.dart';
import 'package:dddart_rest_client/src/oauth_callback_strategy.dart';
import 'package:test/test.dart';

void main() {
  group('CallbackResult', () {
    test('Property 3: Callback Strategy Contract - success case', () {
      // Feature: cognito-oauth-fix
      // Property 3: Callback Strategy Contract
      // For any callback strategy that completes successfully,
      // the result must contain a non-empty authorization code and state
      final random = Random();

      for (var i = 0; i < 100; i++) {
        // Generate random code and state
        final code = _generateRandomString(random, 20);
        final state = _generateRandomString(random, 16);

        final result = CallbackResult(
          code: code,
          state: state,
        );

        // Verify non-empty code and state
        expect(result.code, isNotEmpty);
        expect(result.state, isNotEmpty);
        expect(result.hasError, isFalse);
      }
    });

    test('Property 3: Callback Strategy Contract - error case', () {
      // Feature: cognito-oauth-fix
      // Property 3: Callback Strategy Contract
      // For any callback strategy that fails, an AuthenticationException
      // must be thrown (tested via hasError flag)
      final random = Random();

      for (var i = 0; i < 100; i++) {
        final error = _generateRandomString(random, 10);
        final errorDesc = _generateRandomString(random, 30);

        final result = CallbackResult(
          code: '',
          state: '',
          error: error,
          errorDescription: errorDesc,
        );

        // Verify error is detected
        expect(result.hasError, isTrue);
        expect(result.error, isNotEmpty);
      }
    });

    test('hasError returns true when error is present', () {
      final result = CallbackResult(
        code: 'code123',
        state: 'state456',
        error: 'access_denied',
      );

      expect(result.hasError, isTrue);
    });

    test('hasError returns false when error is null', () {
      final result = CallbackResult(
        code: 'code123',
        state: 'state456',
      );

      expect(result.hasError, isFalse);
    });
  });
}

/// Generates a random alphanumeric string
String _generateRandomString(Random random, int length) {
  const chars =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  return List.generate(length, (_) => chars[random.nextInt(chars.length)])
      .join();
}
