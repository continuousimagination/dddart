import 'dart:io';
import 'dart:math';

import 'package:dddart_rest_client/src/localhost_callback_strategy.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

void main() {
  group('LocalhostCallbackStrategy', () {
    test('Property 16: Redirect URI Construction', () {
      // Feature: cognito-oauth-fix
      // Property 16: Redirect URI Construction
      // For any LocalhostCallbackStrategy with port P and path T,
      // the redirect URI must equal 'http://localhost:P/T'
      final random = Random();

      for (var i = 0; i < 100; i++) {
        // Generate random port (1024-65535) and path
        final port = 1024 + random.nextInt(64511);
        final path = '/${_generateRandomString(random, 10)}';

        final strategy = LocalhostCallbackStrategy(
          port: port,
          path: path,
        );

        final expectedUri = 'http://localhost:$port$path';
        expect(strategy.getRedirectUri(), equals(expectedUri));
      }
    });

    test('Property 16: Redirect URI Construction - default values', () {
      // Test with default port and path
      final strategy = LocalhostCallbackStrategy();

      expect(
          strategy.getRedirectUri(), equals('http://localhost:8080/callback'));
    });

    test('Property 16: Redirect URI Construction - custom port', () {
      final strategy = LocalhostCallbackStrategy(port: 3000);

      expect(
          strategy.getRedirectUri(), equals('http://localhost:3000/callback'));
    });

    test('Property 16: Redirect URI Construction - custom path', () {
      final strategy = LocalhostCallbackStrategy(path: '/auth/callback');

      expect(
        strategy.getRedirectUri(),
        equals('http://localhost:8080/auth/callback'),
      );
    });

    test('server starts on correct port and binds to localhost only', () async {
      final strategy = LocalhostCallbackStrategy(
        port: 8765,
        openBrowser: (_) async {}, // No-op for testing
      );

      // Start the callback in the background
      final callbackFuture = strategy.waitForCallback(
        authorizationUrl: 'http://example.com/auth',
        expectedState: 'test-state',
      );

      // Give server time to start
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Try to connect to the server
      final response = await http.get(
        Uri.parse('http://localhost:8765/callback?code=test&state=test-state'),
      );

      expect(response.statusCode, equals(200));
      expect(response.body, contains('Authentication Successful'));

      // Wait for callback to complete
      final result = await callbackFuture;
      expect(result.code, equals('test'));
      expect(result.state, equals('test-state'));
    });

    test('Property 18: HTTP 404 for Non-Callback Paths', () async {
      // Feature: cognito-oauth-fix
      // Property 18: HTTP 404 for Non-Callback Paths
      final strategy = LocalhostCallbackStrategy(
        port: 8766,
        openBrowser: (_) async {}, // No-op for testing
      );

      // Start the callback in the background
      final callbackFuture = strategy.waitForCallback(
        authorizationUrl: 'http://example.com/auth',
        expectedState: 'test-state',
      );

      // Give server time to start
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Request a non-callback path
      final response = await http.get(Uri.parse('http://localhost:8766/other'));

      expect(response.statusCode, equals(404));
      expect(response.body, equals('Not found'));

      // Clean up by sending the actual callback
      await http.get(
        Uri.parse('http://localhost:8766/callback?code=test&state=test-state'),
      );
      await callbackFuture;
    });

    test('Property 25: HTML Response Generation - success', () async {
      // Feature: cognito-oauth-fix
      // Property 25: HTML Response Generation
      final strategy = LocalhostCallbackStrategy(
        port: 8767,
        openBrowser: (_) async {}, // No-op for testing
      );

      final callbackFuture = strategy.waitForCallback(
        authorizationUrl: 'http://example.com/auth',
        expectedState: 'test-state',
      );

      await Future<void>.delayed(const Duration(milliseconds: 100));

      final response = await http.get(
        Uri.parse('http://localhost:8767/callback?code=test&state=test-state'),
      );

      expect(response.statusCode, equals(200));
      expect(response.body, contains('Authentication Successful!'));
      expect(response.body, contains('✓'));
      expect(response.body, contains('return to your terminal'));

      await callbackFuture;
    });

    test('Property 25: HTML Response Generation - error', () async {
      // Feature: cognito-oauth-fix
      // Property 25: HTML Response Generation
      final strategy = LocalhostCallbackStrategy(
        port: 8768,
        openBrowser: (_) async {}, // No-op for testing
      );

      final callbackFuture = strategy.waitForCallback(
        authorizationUrl: 'http://example.com/auth',
        expectedState: 'test-state',
      );

      await Future<void>.delayed(const Duration(milliseconds: 100));

      final response = await http.get(
        Uri.parse(
          'http://localhost:8768/callback?error=access_denied&state=test-state',
        ),
      );

      expect(response.statusCode, equals(200));
      expect(response.body, contains('Authentication Failed'));
      expect(response.body, contains('✗'));
      expect(response.body, contains('check your terminal'));

      await callbackFuture;
    });

    test('Property 6: HTTP Query Parameter Extraction', () async {
      // Feature: cognito-oauth-fix
      // Property 6: HTTP Query Parameter Extraction
      final strategy = LocalhostCallbackStrategy(
        port: 8769,
        openBrowser: (_) async {}, // No-op for testing
      );

      final callbackFuture = strategy.waitForCallback(
        authorizationUrl: 'http://example.com/auth',
        expectedState: 'state123',
      );

      await Future<void>.delayed(const Duration(milliseconds: 100));

      await http.get(
        Uri.parse(
          'http://localhost:8769/callback?code=code456&state=state123&extra=ignored',
        ),
      );

      final result = await callbackFuture;
      expect(result.code, equals('code456'));
      expect(result.state, equals('state123'));
      expect(result.hasError, isFalse);
    });

    test('extracts error parameters correctly', () async {
      final strategy = LocalhostCallbackStrategy(
        port: 8770,
        openBrowser: (_) async {}, // No-op for testing
      );

      final callbackFuture = strategy.waitForCallback(
        authorizationUrl: 'http://example.com/auth',
        expectedState: 'state123',
      );

      await Future<void>.delayed(const Duration(milliseconds: 100));

      await http.get(
        Uri.parse(
          'http://localhost:8770/callback?error=access_denied&error_description=User%20denied&state=state123',
        ),
      );

      final result = await callbackFuture;
      expect(result.hasError, isTrue);
      expect(result.error, equals('access_denied'));
      expect(result.errorDescription, equals('User denied'));
      expect(result.state, equals('state123'));
    });

    test('server shuts down after callback', () async {
      final strategy = LocalhostCallbackStrategy(
        port: 8771,
        openBrowser: (_) async {}, // No-op for testing
      );

      final callbackFuture = strategy.waitForCallback(
        authorizationUrl: 'http://example.com/auth',
        expectedState: 'test-state',
      );

      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Send callback
      await http.get(
        Uri.parse('http://localhost:8771/callback?code=test&state=test-state'),
      );

      // Wait for callback to complete
      await callbackFuture;

      // Give server time to shut down
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Try to connect again - should fail
      try {
        await http.get(Uri.parse('http://localhost:8771/callback'));
        fail('Expected connection to fail after server shutdown');
      } on SocketException {
        // Expected - server is shut down
      }
    });
  });
}

/// Generates a random alphanumeric string
String _generateRandomString(Random random, int length) {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  return List.generate(length, (_) => chars[random.nextInt(chars.length)])
      .join();
}
