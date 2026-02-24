import 'dart:convert';
import 'dart:io';

import 'package:dddart_rest_client/dddart_rest_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('CognitoAuthProvider', () {
    late String tempCredentialsPath;

    setUp(() {
      tempCredentialsPath =
          '${Directory.systemTemp.path}/test_cognito_creds.json';
    });

    tearDown(() async {
      try {
        final file = File(tempCredentialsPath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        // Ignore cleanup errors
      }
    });

    String createMockJwt(Map<String, dynamic> claims) {
      final header = base64Url.encode(
        utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})),
      );
      final payload = base64Url.encode(utf8.encode(jsonEncode(claims)));
      final signature = base64Url.encode(utf8.encode('fake-signature'));
      return '$header.$payload.$signature';
    }

    test('uses LocalhostCallbackStrategy by default', () {
      final provider = CognitoAuthProvider(
        cognitoDomain: 'https://test.auth.us-east-1.amazoncognito.com',
        clientId: 'test-client-id',
        credentialsPath: tempCredentialsPath,
      );

      expect(provider.callbackStrategy, isA<LocalhostCallbackStrategy>());
    });

    test('uses custom callback strategy when provided', () {
      final customStrategy = ManualCallbackStrategy(
        redirectUri: 'https://example.com/callback',
      );

      final provider = CognitoAuthProvider(
        cognitoDomain: 'https://test.auth.us-east-1.amazoncognito.com',
        clientId: 'test-client-id',
        credentialsPath: tempCredentialsPath,
        callbackStrategy: customStrategy,
      );

      expect(provider.callbackStrategy, equals(customStrategy));
    });

    test('uses default scopes when not provided', () {
      final provider = CognitoAuthProvider(
        cognitoDomain: 'https://test.auth.us-east-1.amazoncognito.com',
        clientId: 'test-client-id',
        credentialsPath: tempCredentialsPath,
      );

      expect(provider.scopes, equals(['openid', 'email', 'profile']));
    });

    test('uses custom scopes when provided', () {
      final provider = CognitoAuthProvider(
        cognitoDomain: 'https://test.auth.us-east-1.amazoncognito.com',
        clientId: 'test-client-id',
        credentialsPath: tempCredentialsPath,
        scopes: ['openid', 'custom:scope'],
      );

      expect(provider.scopes, equals(['openid', 'custom:scope']));
    });

    test('should return ID token when authenticated', () async {
      final idToken = createMockJwt({'sub': 'user-123'});

      final file = File(tempCredentialsPath);
      await file.parent.create(recursive: true);
      await file.writeAsString(
        jsonEncode({
          'access_token': 'valid-token',
          'id_token': idToken,
          'refresh_token': 'refresh-token',
          'expires_at':
              DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
        }),
      );

      final provider = CognitoAuthProvider(
        cognitoDomain: 'https://test.auth.us-east-1.amazoncognito.com',
        clientId: 'test-client-id',
        credentialsPath: tempCredentialsPath,
      );

      final token = await provider.getIdToken();
      expect(token, equals(idToken));
    });

    test('should throw when getting ID token if not authenticated', () async {
      final provider = CognitoAuthProvider(
        cognitoDomain: 'https://test.auth.us-east-1.amazoncognito.com',
        clientId: 'test-client-id',
        credentialsPath: tempCredentialsPath,
      );

      expect(
        provider.getIdToken,
        throwsA(isA<AuthenticationException>()),
      );
    });

    test('should extract cognitoSub from ID token', () async {
      final idToken = createMockJwt({
        'sub': 'test-user-id-123',
        'email': 'test@example.com',
      });

      final file = File(tempCredentialsPath);
      await file.parent.create(recursive: true);
      await file.writeAsString(
        jsonEncode({
          'access_token': 'test-access-token',
          'id_token': idToken,
          'refresh_token': 'test-refresh-token',
          'expires_at':
              DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
        }),
      );

      final provider = CognitoAuthProvider(
        cognitoDomain: 'https://test.auth.us-east-1.amazoncognito.com',
        clientId: 'test-client-id',
        credentialsPath: tempCredentialsPath,
      );

      final sub = await provider.getCognitoSub();
      expect(sub, equals('test-user-id-123'));
    });

    test('should throw when ID token has invalid format', () async {
      final file = File(tempCredentialsPath);
      await file.parent.create(recursive: true);
      await file.writeAsString(
        jsonEncode({
          'access_token': 'test-access-token',
          'id_token': 'invalid.token',
          'refresh_token': 'test-refresh-token',
          'expires_at':
              DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
        }),
      );

      final provider = CognitoAuthProvider(
        cognitoDomain: 'https://test.auth.us-east-1.amazoncognito.com',
        clientId: 'test-client-id',
        credentialsPath: tempCredentialsPath,
      );

      expect(
        provider.getCognitoSub,
        throwsA(
          isA<AuthenticationException>().having(
            (e) => e.message,
            'message',
            contains('Invalid ID token format'),
          ),
        ),
      );
    });

    test('should throw when ID token missing sub claim', () async {
      final idToken = createMockJwt({'email': 'test@example.com'});

      final file = File(tempCredentialsPath);
      await file.parent.create(recursive: true);
      await file.writeAsString(
        jsonEncode({
          'access_token': 'test-access-token',
          'id_token': idToken,
          'refresh_token': 'test-refresh-token',
          'expires_at':
              DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
        }),
      );

      final provider = CognitoAuthProvider(
        cognitoDomain: 'https://test.auth.us-east-1.amazoncognito.com',
        clientId: 'test-client-id',
        credentialsPath: tempCredentialsPath,
      );

      expect(
        provider.getCognitoSub,
        throwsA(
          isA<AuthenticationException>().having(
            (e) => e.message,
            'message',
            contains('ID token missing sub claim'),
          ),
        ),
      );
    });

    test('should extract all claims from ID token', () async {
      final claims = {
        'sub': 'user-123',
        'email': 'test@example.com',
        'email_verified': true,
      };
      final idToken = createMockJwt(claims);

      final file = File(tempCredentialsPath);
      await file.parent.create(recursive: true);
      await file.writeAsString(
        jsonEncode({
          'access_token': 'test-access-token',
          'id_token': idToken,
          'refresh_token': 'test-refresh-token',
          'expires_at':
              DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
        }),
      );

      final provider = CognitoAuthProvider(
        cognitoDomain: 'https://test.auth.us-east-1.amazoncognito.com',
        clientId: 'test-client-id',
        credentialsPath: tempCredentialsPath,
      );

      final extractedClaims = await provider.getIdTokenClaims();
      expect(extractedClaims['sub'], equals('user-123'));
      expect(extractedClaims['email'], equals('test@example.com'));
      expect(extractedClaims['email_verified'], isTrue);
    });

    test('should preserve ID token when refresh does not return new one',
        () async {
      final originalIdToken = createMockJwt({'sub': 'user-123'});

      final file = File(tempCredentialsPath);
      await file.parent.create(recursive: true);
      await file.writeAsString(
        jsonEncode({
          'access_token': 'expired-token',
          'id_token': originalIdToken,
          'refresh_token': 'refresh-token',
          'expires_at': DateTime.now()
              .subtract(const Duration(hours: 1))
              .toIso8601String(),
        }),
      );

      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/token')) {
          return http.Response(
            jsonEncode({
              'access_token': 'new-access-token',
              'refresh_token': 'new-refresh-token',
              'expires_in': 3600,
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      final provider = CognitoAuthProvider(
        cognitoDomain: 'https://test.auth.us-east-1.amazoncognito.com',
        clientId: 'test-client-id',
        credentialsPath: tempCredentialsPath,
        httpClient: mockClient,
      );

      await provider.getAccessToken();

      final savedCreds =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      expect(savedCreds['id_token'], equals(originalIdToken));
      expect(savedCreds['access_token'], equals('new-access-token'));
    });

    test('should use new ID token when refresh returns one', () async {
      final originalIdToken = createMockJwt({'sub': 'user-123'});
      final newIdToken = createMockJwt({'sub': 'user-123', 'updated': true});

      final file = File(tempCredentialsPath);
      await file.parent.create(recursive: true);
      await file.writeAsString(
        jsonEncode({
          'access_token': 'expired-token',
          'id_token': originalIdToken,
          'refresh_token': 'refresh-token',
          'expires_at': DateTime.now()
              .subtract(const Duration(hours: 1))
              .toIso8601String(),
        }),
      );

      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/token')) {
          return http.Response(
            jsonEncode({
              'access_token': 'new-access-token',
              'id_token': newIdToken,
              'refresh_token': 'new-refresh-token',
              'expires_in': 3600,
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      final provider = CognitoAuthProvider(
        cognitoDomain: 'https://test.auth.us-east-1.amazoncognito.com',
        clientId: 'test-client-id',
        credentialsPath: tempCredentialsPath,
        httpClient: mockClient,
      );

      await provider.getAccessToken();

      final savedCreds =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      expect(savedCreds['id_token'], equals(newIdToken));
    });

    test('should include response body in token refresh error', () async {
      final idToken = createMockJwt({'sub': 'user-123'});

      final file = File(tempCredentialsPath);
      await file.parent.create(recursive: true);
      await file.writeAsString(
        jsonEncode({
          'access_token': 'expired-token',
          'id_token': idToken,
          'refresh_token': 'invalid-refresh-token',
          'expires_at': DateTime.now()
              .subtract(const Duration(hours: 1))
              .toIso8601String(),
        }),
      );

      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/token')) {
          return http.Response(
            jsonEncode({'error': 'invalid_grant'}),
            400,
          );
        }
        return http.Response('Not found', 404);
      });

      final provider = CognitoAuthProvider(
        cognitoDomain: 'https://test.auth.us-east-1.amazoncognito.com',
        clientId: 'test-client-id',
        credentialsPath: tempCredentialsPath,
        httpClient: mockClient,
      );

      expect(
        provider.getAccessToken,
        throwsA(
          isA<AuthenticationException>().having(
            (e) => e.message,
            'message',
            contains('invalid_grant'),
          ),
        ),
      );
    });

    test('should return access token if not expired', () async {
      final idToken = createMockJwt({'sub': 'user-123'});

      final file = File(tempCredentialsPath);
      await file.parent.create(recursive: true);
      await file.writeAsString(
        jsonEncode({
          'access_token': 'valid-token',
          'id_token': idToken,
          'refresh_token': 'refresh-token',
          'expires_at':
              DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
        }),
      );

      final provider = CognitoAuthProvider(
        cognitoDomain: 'https://test.auth.us-east-1.amazoncognito.com',
        clientId: 'test-client-id',
        credentialsPath: tempCredentialsPath,
      );

      final token = await provider.getAccessToken();
      expect(token, equals('valid-token'));
    });

    test('should delete credentials on logout', () async {
      final idToken = createMockJwt({'sub': 'user-123'});

      final file = File(tempCredentialsPath);
      await file.parent.create(recursive: true);
      await file.writeAsString(
        jsonEncode({
          'access_token': 'token',
          'id_token': idToken,
          'refresh_token': 'refresh',
          'expires_at':
              DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
        }),
      );

      final provider = CognitoAuthProvider(
        cognitoDomain: 'https://test.auth.us-east-1.amazoncognito.com',
        clientId: 'test-client-id',
        credentialsPath: tempCredentialsPath,
      );

      await provider.logout();

      expect(await file.exists(), isFalse);
    });

    test('should return true for isAuthenticated when valid credentials',
        () async {
      final idToken = createMockJwt({'sub': 'user-123'});

      final file = File(tempCredentialsPath);
      await file.parent.create(recursive: true);
      await file.writeAsString(
        jsonEncode({
          'access_token': 'valid-token',
          'id_token': idToken,
          'refresh_token': 'refresh-token',
          'expires_at':
              DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
        }),
      );

      final provider = CognitoAuthProvider(
        cognitoDomain: 'https://test.auth.us-east-1.amazoncognito.com',
        clientId: 'test-client-id',
        credentialsPath: tempCredentialsPath,
      );

      final isAuth = await provider.isAuthenticated();
      expect(isAuth, isTrue);
    });

    test('should return false for isAuthenticated when no credentials',
        () async {
      final provider = CognitoAuthProvider(
        cognitoDomain: 'https://test.auth.us-east-1.amazoncognito.com',
        clientId: 'test-client-id',
        credentialsPath: tempCredentialsPath,
      );

      final isAuth = await provider.isAuthenticated();
      expect(isAuth, isFalse);
    });

    test('Property 4: Authorization URL Construction', () {
      // Feature: cognito-oauth-fix
      // Property 4: Authorization URL Construction
      final provider = CognitoAuthProvider(
        cognitoDomain: 'https://test.auth.us-east-1.amazoncognito.com',
        clientId: 'test-client-123',
        credentialsPath: tempCredentialsPath,
        scopes: ['openid', 'email'],
      );

      expect(provider.cognitoDomain,
          equals('https://test.auth.us-east-1.amazoncognito.com'));
      expect(provider.clientId, equals('test-client-123'));
      expect(provider.scopes, equals(['openid', 'email']));
      expect(provider.callbackStrategy.getRedirectUri(), contains('localhost'));
    });

    test('Property 17: Custom Scope Usage', () {
      // Feature: cognito-oauth-fix
      // Property 17: Custom Scope Usage
      final customScopes = ['openid', 'custom:read', 'custom:write'];
      final provider = CognitoAuthProvider(
        cognitoDomain: 'https://test.auth.us-east-1.amazoncognito.com',
        clientId: 'test-client-id',
        credentialsPath: tempCredentialsPath,
        scopes: customScopes,
      );

      expect(provider.scopes, equals(customScopes));
      expect(provider.scopes.length, equals(3));
      expect(provider.scopes, contains('custom:read'));
      expect(provider.scopes, contains('custom:write'));
    });

    test('should delete user successfully', () async {
      final idToken = createMockJwt({'sub': 'user-123'});

      final file = File(tempCredentialsPath);
      await file.parent.create(recursive: true);
      await file.writeAsString(
        jsonEncode({
          'access_token': 'valid-token',
          'id_token': idToken,
          'refresh_token': 'refresh-token',
          'expires_at':
              DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
        }),
      );

      final mockClient = MockClient((request) async {
        if (request.url.host.contains('cognito-idp')) {
          expect(request.headers['X-Amz-Target'],
              equals('AWSCognitoIdentityProviderService.DeleteUser'));
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['AccessToken'], equals('valid-token'));
          return http.Response('{}', 200);
        }
        return http.Response('Not found', 404);
      });

      final provider = CognitoAuthProvider(
        cognitoDomain: 'https://test.auth.us-east-1.amazoncognito.com',
        clientId: 'test-client-id',
        credentialsPath: tempCredentialsPath,
        httpClient: mockClient,
      );

      await provider.deleteUser();

      // Verify credentials were deleted
      expect(await file.exists(), isFalse);
    });

    test('should throw when deleting user without authentication', () async {
      final provider = CognitoAuthProvider(
        cognitoDomain: 'https://test.auth.us-east-1.amazoncognito.com',
        clientId: 'test-client-id',
        credentialsPath: tempCredentialsPath,
      );

      expect(
        provider.deleteUser,
        throwsA(isA<AuthenticationException>()),
      );
    });

    test('should throw when Cognito API returns error on delete', () async {
      final idToken = createMockJwt({'sub': 'user-123'});

      final file = File(tempCredentialsPath);
      await file.parent.create(recursive: true);
      await file.writeAsString(
        jsonEncode({
          'access_token': 'valid-token',
          'id_token': idToken,
          'refresh_token': 'refresh-token',
          'expires_at':
              DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
        }),
      );

      final mockClient = MockClient((request) async {
        if (request.url.host.contains('cognito-idp')) {
          return http.Response(
            jsonEncode({'__type': 'NotAuthorizedException'}),
            400,
          );
        }
        return http.Response('Not found', 404);
      });

      final provider = CognitoAuthProvider(
        cognitoDomain: 'https://test.auth.us-east-1.amazoncognito.com',
        clientId: 'test-client-id',
        credentialsPath: tempCredentialsPath,
        httpClient: mockClient,
      );

      expect(
        provider.deleteUser,
        throwsA(
          isA<AuthenticationException>().having(
            (e) => e.message,
            'message',
            contains('Failed to delete user'),
          ),
        ),
      );
    });

    test('should extract region from Cognito domain correctly', () async {
      final idToken = createMockJwt({'sub': 'user-123'});

      final file = File(tempCredentialsPath);
      await file.parent.create(recursive: true);
      await file.writeAsString(
        jsonEncode({
          'access_token': 'valid-token',
          'id_token': idToken,
          'refresh_token': 'refresh-token',
          'expires_at':
              DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
        }),
      );

      final mockClient = MockClient((request) async {
        if (request.url.host.contains('cognito-idp')) {
          // Verify the region is correctly extracted
          expect(request.url.host, contains('us-west-2'));
          return http.Response('{}', 200);
        }
        return http.Response('Not found', 404);
      });

      final provider = CognitoAuthProvider(
        cognitoDomain: 'https://test.auth.us-west-2.amazoncognito.com',
        clientId: 'test-client-id',
        credentialsPath: tempCredentialsPath,
        httpClient: mockClient,
      );

      await provider.deleteUser();
    });
  });
}
