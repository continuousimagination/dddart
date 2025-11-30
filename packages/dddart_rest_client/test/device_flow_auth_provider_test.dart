import 'dart:convert';
import 'dart:io';

import 'package:dddart_rest_client/dddart_rest_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('DeviceFlowAuthProvider', () {
    late String tempCredentialsPath;

    setUp(() {
      // Create temp file path
      tempCredentialsPath = '${Directory.systemTemp.path}/test_creds.json';
    });

    tearDown(() async {
      // Clean up temp file
      try {
        final file = File(tempCredentialsPath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        // Ignore cleanup errors
      }
    });

    test('should return access token if not expired', () async {
      // Save valid credentials
      final file = File(tempCredentialsPath);
      await file.parent.create(recursive: true);
      await file.writeAsString(
        jsonEncode({
          'access_token': 'valid-token',
          'refresh_token': 'refresh-token',
          'expires_at':
              DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
        }),
      );

      final provider = DeviceFlowAuthProvider(
        authUrl: 'https://api.example.com/auth',
        clientId: 'test-client',
        credentialsPath: tempCredentialsPath,
      );

      final token = await provider.getAccessToken();
      expect(token, equals('valid-token'));
    });

    test('should refresh token if expired', () async {
      // Save expired credentials
      final file = File(tempCredentialsPath);
      await file.parent.create(recursive: true);
      await file.writeAsString(
        jsonEncode({
          'access_token': 'expired-token',
          'refresh_token': 'refresh-token',
          'expires_at': DateTime.now()
              .subtract(const Duration(hours: 1))
              .toIso8601String(),
        }),
      );

      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/refresh')) {
          return http.Response(
            jsonEncode({
              'access_token': 'new-token',
              'refresh_token': 'new-refresh-token',
              'expires_in': 900,
              'token_type': 'Bearer',
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      final provider = DeviceFlowAuthProvider(
        authUrl: 'https://api.example.com/auth',
        clientId: 'test-client',
        credentialsPath: tempCredentialsPath,
        httpClient: mockClient,
      );

      final token = await provider.getAccessToken();
      expect(token, equals('new-token'));

      // Verify credentials were saved
      final savedCreds =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      expect(savedCreds['access_token'], equals('new-token'));
    });

    test('should throw if not authenticated and no refresh token', () async {
      final provider = DeviceFlowAuthProvider(
        authUrl: 'https://api.example.com/auth',
        clientId: 'test-client',
        credentialsPath: tempCredentialsPath,
      );

      expect(
        provider.getAccessToken,
        throwsA(isA<AuthenticationException>()),
      );
    });

    test('should return false for isAuthenticated when no credentials',
        () async {
      final provider = DeviceFlowAuthProvider(
        authUrl: 'https://api.example.com/auth',
        clientId: 'test-client',
        credentialsPath: tempCredentialsPath,
      );

      final isAuth = await provider.isAuthenticated();
      expect(isAuth, isFalse);
    });

    test('should return true for isAuthenticated when valid credentials',
        () async {
      // Save valid credentials
      final file = File(tempCredentialsPath);
      await file.parent.create(recursive: true);
      await file.writeAsString(
        jsonEncode({
          'access_token': 'valid-token',
          'refresh_token': 'refresh-token',
          'expires_at':
              DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
        }),
      );

      final provider = DeviceFlowAuthProvider(
        authUrl: 'https://api.example.com/auth',
        clientId: 'test-client',
        credentialsPath: tempCredentialsPath,
      );

      final isAuth = await provider.isAuthenticated();
      expect(isAuth, isTrue);
    });

    test('should delete credentials on logout', () async {
      // Save credentials
      final file = File(tempCredentialsPath);
      await file.parent.create(recursive: true);
      await file.writeAsString(
        jsonEncode({
          'access_token': 'token',
          'refresh_token': 'refresh',
          'expires_at':
              DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
        }),
      );

      final mockClient = MockClient((request) async {
        return http.Response('', 204);
      });

      final provider = DeviceFlowAuthProvider(
        authUrl: 'https://api.example.com/auth',
        clientId: 'test-client',
        credentialsPath: tempCredentialsPath,
        httpClient: mockClient,
      );

      await provider.logout();

      expect(await file.exists(), isFalse);
    });
  });
}
